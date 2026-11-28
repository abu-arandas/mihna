import 'package:http/http.dart' as http;

import 'http_client_io.dart' if (dart.library.js_interop) 'http_client_web.dart' as impl;

/// The HTTP client for this platform. On the web it sends the browser's cookies along, which is how Neon Auth's
/// session reaches the server there; on a phone the app keeps the session cookie itself (NeonAuthService).
http.Client platformHttpClient() => impl.platformHttpClient();

/// Whether this build runs in a browser, which sets the `Origin` header itself.
const bool isBrowser = impl.isBrowser;
