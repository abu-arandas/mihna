import 'package:http/http.dart' as http;

http.Client platformHttpClient() => http.Client();

const bool isBrowser = false;
