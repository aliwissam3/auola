import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tiny generic local "table": a list of [T] persisted as one JSON blob
/// in [SharedPreferences]. Works identically on Windows, Android, iOS, Web,
/// macOS and Linux with zero platform-specific code or code generation,
/// which keeps the whole app buildable without running `build_runner`.
class JsonRepository<T> extends ChangeNotifier {
  JsonRepository({
    required this.boxKey,
    required this.toJson,
    required this.fromJson,
    required this.idOf,
  });

  final String boxKey;
  final Map<String, dynamic> Function(T) toJson;
  final T Function(Map<String, dynamic>) fromJson;
  final String Function(T) idOf;

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

  Future<void> load() async {
    if (_loaded) return;
    _items.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(boxKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _items.addAll(
          list.whereType<Map>().map((e) => fromJson(Map<String, dynamic>.from(e))),
        );
      }
    } catch (_) {
      // Corrupt data or unavailable storage (e.g. a sandboxed browser
      // context blocking localStorage): start fresh in-memory rather than
      // crashing the app before it can even render.
      _items.clear();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(boxKey, jsonEncode(_items.map(toJson).toList()));
    } catch (_) {
      // Storage unavailable: keep working in-memory for this session
      // rather than throwing out of every upsert/delete call.
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
    await _persist();
    notifyListeners();
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
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _items.removeWhere((e) => idOf(e) == id);
    await _persist();
    notifyListeners();
  }

  /// Seeds initial/demo data only if the store is empty (first run).
  Future<void> seedIfEmpty(List<T> seed) async {
    if (_items.isEmpty && seed.isNotEmpty) {
      _items.addAll(seed);
      await _persist();
      notifyListeners();
    }
  }
}
