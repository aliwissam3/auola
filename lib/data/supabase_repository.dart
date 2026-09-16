import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/connectivity_status.dart';
import '../services/store_account_service.dart';

Future<String?> _migrateFromSharedPreferences(String boxKey) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('repo_cache_$boxKey');
    if (raw == null) return null;
    await prefs.remove('repo_cache_$boxKey');
    return raw;
  } catch (_) {
    return null;
  }
}

/// Same public shape as [JsonRepository] (items / byId / load / upsert /
/// upsertAll / delete / seedIfEmpty), backed by Supabase Postgres instead
/// of local SharedPreferences — so swapping one for the other in
/// [AppData] doesn't require touching any screen that already calls
/// these methods.
///
/// All collections share ONE generic table (`store_records`: id,
/// collection, data jsonb, updated_at) rather than a bespoke table per
/// model. That means zero manual SQL per screen/feature going forward —
/// only the one-time table creation in Supabase's SQL editor — at the
/// cost of losing server-side type checking on individual fields (fine
/// for a single-pharmacy app; Dart's own `fromJson`/`toJson` still
/// validates shape on the client).
///
/// Local persistence: every item is also mirrored into a Hive box keyed
/// by [boxKey] (IndexedDB-backed on web, well past localStorage's ~5-10MB
/// per-origin ceiling — a real risk once a pharmacy's product/sales
/// history grows past a few thousand records). This app is meant to keep
/// working with no internet at all, so relying on Supabase alone would
/// mean anything entered offline — or with the cloud simply unreachable
/// for that session — lived only in memory and vanished the moment the
/// app closed, with nothing to show for it and no error ever surfaced.
/// The local copy is what actually survives a restart; the cloud write is
/// a best-effort mirror on top of it, not a precondition for the data
/// being kept at all.
///
/// Realtime: subscribes to Postgres changes for this collection so a
/// change made on one device (phone) shows up on another (laptop)
/// within a second or two, without the person needing to refresh.
class SupabaseRepository<T> extends ChangeNotifier {
  SupabaseRepository({
    required this.boxKey,
    required this.toJson,
    required this.fromJson,
    required this.idOf,
  });

  final String boxKey; // used as the `collection` column value, and the local cache key
  final Map<String, dynamic> Function(T) toJson;
  final T Function(Map<String, dynamic>) fromJson;
  final String Function(T) idOf;

  static const _table = 'store_records';
  static const _cacheBoxName = 'repo_cache';

  SupabaseClient get _client => Supabase.instance.client;

  final List<T> _items = [];
  bool _loaded = false;
  bool get isLoaded => _loaded;

  List<T> get items => List.unmodifiable(_items);

  T? byId(String id) {
    for (final item in _items) {
      if (idOf(item) == id) return item;
    }
    return null;
  }

  RealtimeChannel? _channel;

  // One Hive box shared by every collection (each keyed by its own
  // boxKey within it) - opening a box per collection would work too, but
  // this way there's exactly one IndexedDB object store to reason about.
  // Cached as a Future so concurrent load()/upsert() calls on different
  // collections don't race to open it twice.
  static Future<Box>? _cacheBoxFuture;
  static Future<Box> _cacheBox() {
    return _cacheBoxFuture ??= Hive.openBox(_cacheBoxName);
  }

  // Scoped to the signed-in pharmacy account so a device that's ever
  // signed into more than one pharmacy (a demo account, a shared
  // computer) doesn't show one pharmacy's cached data to another before
  // the first server refresh overwrites it.
  String get _cacheKey => '$boxKey:${StoreAccountService.instance.storeId}';

  Future<List<T>> _readLocalCache() async {
    try {
      final box = await _cacheBox();
      var raw = box.get(_cacheKey) as String?;
      if (raw == null) {
        // One-time carry-over from an older build, which cached this
        // same data unscoped (from before multi-pharmacy accounts
        // existed) — first under this same Hive box, and before that in
        // SharedPreferences entirely — otherwise either change would
        // look, to whoever's already using the app, exactly like every
        // product/sale they'd entered had been wiped.
        raw = box.get(boxKey) as String? ?? await _migrateFromSharedPreferences(boxKey);
        if (raw != null) await box.put(_cacheKey, raw);
      }
      if (raw == null) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((m) => fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      // Corrupt/missing cache - just start empty rather than crashing.
      return [];
    }
  }

  Future<void> _writeLocalCache() async {
    try {
      final box = await _cacheBox();
      final encoded = jsonEncode(_items.map(toJson).toList());
      await box.put(_cacheKey, encoded);
    } catch (_) {
      // Storage full/unavailable - the item is still kept in memory for
      // this session; nothing more useful to do here.
    }
  }

  Future<void> load() async {
    if (_loaded) return;

    // Local-first: whatever survived from the last session is what this
    // app can actually promise to keep, regardless of network state -
    // shown immediately rather than starting blank.
    final cached = await _readLocalCache();
    _items
      ..clear()
      ..addAll(cached);

    try {
      // The Supabase client can hang indefinitely (never throwing) when
      // the network is unreachable rather than merely erroring out fast
      // (observed with no internet at all, not just a slow connection) -
      // bounded here so a fully offline machine still reaches the first
      // frame instead of spinning forever.
      final rows = await _client
          .from(_table)
          .select('data')
          .eq('collection', boxKey)
          .eq('store_id', StoreAccountService.instance.storeId!)
          .timeout(const Duration(seconds: 5));
      final fromServer = <T>[];
      for (final row in rows as List) {
        final data = (row as Map)['data'];
        if (data is Map) {
          fromServer.add(fromJson(Map<String, dynamic>.from(data)));
        }
      }
      // The server is the source of truth once actually reachable - it
      // already reflects every device's writes, including any made here
      // before the last successful sync.
      _items
        ..clear()
        ..addAll(fromServer);
      await _writeLocalCache();
      ConnectivityStatus.instance.markConnected();
    } catch (_) {
      // Offline or the table isn't set up yet — keep whatever the local
      // cache already gave us instead of wiping it out.
      ConnectivityStatus.instance.markDisconnected();
    }
    _loaded = true;
    notifyListeners();
    _subscribe();
  }

  /// Re-fetches this collection from Supabase right now, replacing local
  /// items with whatever the server currently has — a manual fallback
  /// for when realtime sync hasn't (yet) reflected a change made from
  /// another device (e.g. a sale made from a phone logged in over the
  /// LAN-QR feature), such as a stale local network, a missed realtime
  /// event, or the two devices simply not being online at the same
  /// moment. Silently does nothing if the network/table is unreachable,
  /// same as [load] — whatever's already showing locally is kept rather
  /// than being wiped out by a failed refresh.
  Future<void> refresh() async {
    try {
      final rows = await _client
          .from(_table)
          .select('data')
          .eq('collection', boxKey)
          .eq('store_id', StoreAccountService.instance.storeId!)
          .timeout(const Duration(seconds: 8));
      final fresh = <T>[];
      for (final row in rows as List) {
        final data = (row as Map)['data'];
        if (data is Map) {
          fresh.add(fromJson(Map<String, dynamic>.from(data)));
        }
      }
      _items
        ..clear()
        ..addAll(fresh);
      notifyListeners();
      await _writeLocalCache();
      ConnectivityStatus.instance.markConnected();
    } catch (_) {
      // Offline right now - keep showing whatever's already local.
      ConnectivityStatus.instance.markDisconnected();
    }
  }

  void _subscribe() {
    _channel = _client
        .channel('public:$_table:$boxKey')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'collection', value: boxKey),
          callback: (payload) => _applyRemoteChange(payload),
        )
        .subscribe();
  }

  void _applyRemoteChange(PostgresChangePayload payload) {
    try {
      if (payload.eventType == PostgresChangeEvent.delete) {
        final oldId = payload.oldRecord['id'] as String?;
        if (oldId != null) _items.removeWhere((e) => idOf(e) == oldId);
      } else {
        final data = payload.newRecord['data'];
        if (data is Map) {
          final item = fromJson(Map<String, dynamic>.from(data));
          final id = idOf(item);
          final idx = _items.indexWhere((e) => idOf(e) == id);
          if (idx >= 0) {
            _items[idx] = item;
          } else {
            _items.add(item);
          }
        }
      }
      notifyListeners();
      // ignore: unawaited_futures
      _writeLocalCache();
    } catch (_) {
      // A malformed/foreign payload shouldn't crash the live sync loop.
    }
  }

  Future<void> upsert(T item) async {
    final id = idOf(item);
    final idx = _items.indexWhere((e) => idOf(e) == id);
    if (idx >= 0) {
      _items[idx] = item;
    } else {
      _items.add(item);
    }
    notifyListeners();
    // Written to local storage right away, independent of the cloud
    // write below — this is what actually survives closing the app,
    // whether or not (or how long) the cloud write below takes.
    await _writeLocalCache();
    try {
      await _client.from(_table).upsert({
        'id': id,
        'collection': boxKey,
        'store_id': StoreAccountService.instance.storeId,
        'data': toJson(item),
        'updated_at': DateTime.now().toIso8601String(),
      });
      ConnectivityStatus.instance.markConnected();
    } catch (_) {
      // Already safe on disk via the local cache above even though the
      // network write failed.
      ConnectivityStatus.instance.markDisconnected();
    }
  }

  Future<void> upsertAll(Iterable<T> newItems) async {
    for (final item in newItems) {
      final id = idOf(item);
      final idx = _items.indexWhere((e) => idOf(e) == id);
      if (idx >= 0) {
        _items[idx] = item;
      } else {
        _items.add(item);
      }
    }
    notifyListeners();
    await _writeLocalCache();
    try {
      await _client.from(_table).upsert([
        for (final item in newItems)
          {
            'id': idOf(item),
            'collection': boxKey,
            'store_id': StoreAccountService.instance.storeId,
            'data': toJson(item),
            'updated_at': DateTime.now().toIso8601String(),
          },
      ]);
      ConnectivityStatus.instance.markConnected();
    } catch (_) {
      ConnectivityStatus.instance.markDisconnected();
    }
  }

  Future<void> delete(String id) async {
    _items.removeWhere((e) => idOf(e) == id);
    notifyListeners();
    await _writeLocalCache();
    try {
      await _client
          .from(_table)
          .delete()
          .eq('id', id)
          .eq('collection', boxKey)
          .eq('store_id', StoreAccountService.instance.storeId!);
      ConnectivityStatus.instance.markConnected();
    } catch (_) {
      ConnectivityStatus.instance.markDisconnected();
    }
  }

  /// Seeds initial/demo data only if the store is empty (first run).
  Future<void> seedIfEmpty(List<T> seed) async {
    if (_items.isEmpty && seed.isNotEmpty) {
      await upsertAll(seed);
    }
  }

  @override
  void dispose() {
    if (_channel != null) _client.removeChannel(_channel!);
    super.dispose();
  }
}
