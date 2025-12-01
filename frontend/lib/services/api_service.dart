import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/user_model.dart';
import 'encryption_service.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
  });
}

class ApiService {
  static ApiService? _instance;
  final EncryptionService _encryptionService = EncryptionService.instance;

  ApiService._();

  static ApiService get instance {
    _instance ??= ApiService._();
    return _instance!;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  Map<String, String> get _headersWithSession => {
    'Content-Type': 'application/json',
    if (_encryptionService.sessionId != null)
      'x-session-id': _encryptionService.sessionId!,
  };

  // ==================== Key Exchange ====================

  /// Get server's RSA public key
  Future<ApiResponse<String>> getPublicKey() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/public-key'),
        headers: _headers,
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: data['publicKey'],
          message: data['message'],
        );
      }
      
      return ApiResponse(
        success: false,
        error: data['error'] ?? 'Failed to get public key',
      );
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  /// Perform DH key exchange with server
  Future<ApiResponse<Map<String, dynamic>>> keyExchange() async {
    try {
      // Generate client key pair
      final clientKeys = _encryptionService.generateClientKeyPair();

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/key-exchange'),
        headers: _headers,
        body: jsonEncode({
          'clientPublicKey': clientKeys.publicKey,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        // Establish session with server's public key
        _encryptionService.establishSession(
          serverPublicKey: data['serverPublicKey'],
          sessionId: data['sessionId'],
        );

        return ApiResponse(
          success: true,
          data: data,
          message: 'Key exchange successful',
        );
      }
      
      return ApiResponse(
        success: false,
        error: data['error'] ?? 'Key exchange failed',
      );
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  // ==================== Authentication ====================

  /// Register a new user (uses password-based encryption)
  Future<ApiResponse<Map<String, dynamic>>> register({
    required String phoneNumber,
    required String name,
    required String password,
  }) async {
    try {
      final userData = {
        'phoneNumber': phoneNumber,
        'name': name,
        'password': password,
      };

      // Encrypt with password
      final encryptedData = _encryptionService.encryptWithPassword(userData, password);

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/register'),
        headers: _headers,
        body: jsonEncode({
          'encryptedData': encryptedData,
          'password': password, // Server needs password to decrypt
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(
          success: true,
          data: data,
          message: data['message'] ?? 'Registration successful',
        );
      }
      
      return ApiResponse(
        success: false,
        error: data['error'] ?? 'Registration failed',
      );
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  /// Request OTP for login (uses DH session encryption)
  Future<ApiResponse<Map<String, dynamic>>> loginWithOTP({
    required String phoneNumber,
  }) async {
    try {
      // Ensure we have a session
      if (!_encryptionService.hasSession) {
        final keyExchangeResult = await keyExchange();
        if (!keyExchangeResult.success) {
          return ApiResponse(
            success: false,
            error: 'Failed to establish secure session',
          );
        }
      }

      final requestData = {'phoneNumber': phoneNumber};
      final encryptedData = _encryptionService.encryptWithSession(requestData);

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/login-otp'),
        headers: _headersWithSession,
        body: jsonEncode({'encryptedData': encryptedData}),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: data,
          message: data['message'] ?? 'OTP sent successfully',
        );
      }
      
      return ApiResponse(
        success: false,
        error: data['error'] ?? 'Failed to send OTP',
      );
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  /// Verify OTP (uses DH session encryption)
  Future<ApiResponse<Map<String, dynamic>>> verifyOTP({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      if (!_encryptionService.hasSession) {
        return ApiResponse(
          success: false,
          error: 'No secure session. Please request OTP again.',
        );
      }

      final requestData = {
        'phoneNumber': phoneNumber,
        'otp': otp,
      };
      final encryptedData = _encryptionService.encryptWithSession(requestData);

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/verify-otp'),
        headers: _headersWithSession,
        body: jsonEncode({'encryptedData': encryptedData}),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: data,
          message: data['message'] ?? 'OTP verified successfully',
        );
      }
      
      return ApiResponse(
        success: false,
        error: data['error'] ?? 'OTP verification failed',
      );
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  /// Login with password (uses DH session encryption)
  Future<ApiResponse<Map<String, dynamic>>> loginWithPassword({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      // Ensure we have a session
      if (!_encryptionService.hasSession) {
        final keyExchangeResult = await keyExchange();
        if (!keyExchangeResult.success) {
          return ApiResponse(
            success: false,
            error: 'Failed to establish secure session',
          );
        }
      }

      final requestData = {
        'phoneNumber': phoneNumber,
        'password': password,
      };
      final encryptedData = _encryptionService.encryptWithSession(requestData);

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/loginWithPassword'),
        headers: _headersWithSession,
        body: jsonEncode({'encryptedData': encryptedData}),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: data,
          message: data['message'] ?? 'Login successful',
        );
      }
      
      return ApiResponse(
        success: false,
        error: data['error'] ?? 'Login failed',
      );
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  /// Logout
  Future<ApiResponse<void>> logout() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/logout'),
        headers: _headersWithSession,
      );

      _encryptionService.clearSession();

      if (response.statusCode == 200) {
        return ApiResponse(success: true, message: 'Logged out successfully');
      }
      
      return ApiResponse(success: true, message: 'Logged out');
    } catch (e) {
      _encryptionService.clearSession();
      return ApiResponse(success: true, message: 'Logged out');
    }
  }

  // ==================== Data Operations ====================

  /// Get data by ID
  Future<ApiResponse<DataModel>> getDataById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/getData/$id'),
        headers: _headersWithSession,
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: DataModel.fromJson(data['data'] ?? data),
          message: data['message'],
        );
      }
      
      return ApiResponse(
        success: false,
        error: data['error'] ?? 'Failed to get data',
      );
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  /// Add new data (uses DH session encryption)
  Future<ApiResponse<Map<String, dynamic>>> addData({
    required String name,
    required String message,
  }) async {
    try {
      if (!_encryptionService.hasSession) {
        final keyExchangeResult = await keyExchange();
        if (!keyExchangeResult.success) {
          return ApiResponse(
            success: false,
            error: 'Failed to establish secure session',
          );
        }
      }

      final requestData = {
        'name': name,
        'message': message,
      };
      final encryptedData = _encryptionService.encryptWithSession(requestData);

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/addData'),
        headers: _headersWithSession,
        body: jsonEncode({'encryptedData': encryptedData}),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(
          success: true,
          data: data,
          message: data['message'] ?? 'Data added successfully',
        );
      }
      
      return ApiResponse(
        success: false,
        error: data['error'] ?? 'Failed to add data',
      );
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  /// Update data by ID (uses DH session encryption)
  Future<ApiResponse<Map<String, dynamic>>> updateData({
    required String id,
    required String name,
    required String message,
  }) async {
    try {
      if (!_encryptionService.hasSession) {
        final keyExchangeResult = await keyExchange();
        if (!keyExchangeResult.success) {
          return ApiResponse(
            success: false,
            error: 'Failed to establish secure session',
          );
        }
      }

      final requestData = {
        'name': name,
        'message': message,
      };
      final encryptedData = _encryptionService.encryptWithSession(requestData);

      final response = await http.put(
        Uri.parse('${AppConfig.apiUrl}/updateData/$id'),
        headers: _headersWithSession,
        body: jsonEncode({'encryptedData': encryptedData}),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: data,
          message: data['message'] ?? 'Data updated successfully',
        );
      }
      
      return ApiResponse(
        success: false,
        error: data['error'] ?? 'Failed to update data',
      );
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }
}
