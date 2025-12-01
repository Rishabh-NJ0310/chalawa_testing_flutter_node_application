class AppConfig {
  // Backend URL - Linux localhost
  static const String baseUrl = 'http://localhost:9000';
  
  static const String apiPrefix = '/api/user';
  
  static String get apiUrl => '$baseUrl$apiPrefix';
}
