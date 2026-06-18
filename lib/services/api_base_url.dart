import 'package:flutter/foundation.dart';

// Configuration: Edit this if you need to change the backend server URL
// For web: typically the backend runs on the same host (e.g., localhost:8081 or yourdomain.com:8081)
// For mobile: use your development machine's IP and port
const String BACKEND_HOST = 'localhost';
const int BACKEND_PORT = 8081;

// For production, you can override this:
// const String BACKEND_HOST = 'your-production-domain.com';
// const int BACKEND_PORT = 80; // or 443 for HTTPS

String getBaseUrl() {
  if (kIsWeb) {
    // For web: use the same host as the frontend, with configured port
    final uri = Uri.base;
    final host = uri.host.isNotEmpty ? uri.host : BACKEND_HOST;
    final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'http';
    return '$scheme://$host:$BACKEND_PORT';
  }
  // For mobile apps: use configured backend host and port
  return 'http://$BACKEND_HOST:$BACKEND_PORT';
}
