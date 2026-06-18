import 'package:flutter/foundation.dart';

// Local development fallback (mobile only).
// Web production uses same-origin (no host:port needed).
const String _devBackendHost = 'localhost';
const int _devBackendPort = 8081;

String getBaseUrl() {
  if (kIsWeb) {
    // In production the Flutter web build is served by the same Dart backend,
    // so all API calls are same-origin — no host or port needed.
    // In local development (localhost) we still append the port.
    final uri = Uri.base;
    final host = uri.host;
    if (host == 'localhost' || host == '127.0.0.1') {
      return 'http://$host:$_devBackendPort';
    }
    // Production: same origin, no port suffix.
    return '${uri.scheme}://$host';
  }
  // Mobile: point at the development machine.
  return 'http://$_devBackendHost:$_devBackendPort';
}
