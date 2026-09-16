import 'package:flutter/foundation.dart';

/// Tracks whether this session can currently reach the cloud (Supabase) -
/// updated by every real attempt (the initial connect in main.dart, and
/// every repository load/upsert/delete/refresh afterward) so the
/// dashboard's status badge reflects what's actually happening instead
/// of unconditionally claiming "متصل" regardless of whether anything is
/// really syncing. A phone session on a network that can't reach
/// Supabase at all (even with working general internet) now shows
/// "غير متصل" instead of silently losing every write with no visible
/// sign anything was wrong.
class ConnectivityStatus extends ChangeNotifier {
  ConnectivityStatus._();
  static final instance = ConnectivityStatus._();

  bool _connected = false;
  bool get isConnected => _connected;

  void markConnected() {
    if (!_connected) {
      _connected = true;
      notifyListeners();
    }
  }

  void markDisconnected() {
    if (_connected) {
      _connected = false;
      notifyListeners();
    }
  }
}
