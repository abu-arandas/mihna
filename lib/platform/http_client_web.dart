import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

http.Client platformHttpClient() => BrowserClient()..withCredentials = true;

const bool isBrowser = true;
