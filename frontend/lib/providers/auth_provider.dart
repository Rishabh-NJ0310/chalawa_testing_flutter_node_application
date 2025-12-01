import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/encryption_service.dart';

enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService.instance;
  final EncryptionService _encryptionService = EncryptionService.instance;

  AuthState _state = AuthState.initial;
  String? _errorMessage;
  String? _phoneNumber;
  String? _userName;
  bool _isOtpSent = false;

  AuthState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get phoneNumber => _phoneNumber;
  String? get userName => _userName;
  bool get isOtpSent => _isOtpSent;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get hasSession => _encryptionService.hasSession;

  AuthProvider() {
    _loadSavedSession();
  }

  Future<void> _loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    _phoneNumber = prefs.getString('phoneNumber');
    _userName = prefs.getString('userName');
    
    if (_phoneNumber != null) {
      // We have saved user info but need to re-establish session
      _state = AuthState.unauthenticated;
    } else {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_phoneNumber != null) {
      await prefs.setString('phoneNumber', _phoneNumber!);
    }
    if (_userName != null) {
      await prefs.setString('userName', _userName!);
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('phoneNumber');
    await prefs.remove('userName');
  }

  /// Initialize secure connection
  Future<bool> initializeSecureConnection() async {
    try {
      _state = AuthState.loading;
      notifyListeners();

      final result = await _apiService.keyExchange();
      
      if (result.success) {
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      
      _errorMessage = result.error;
      _state = AuthState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  /// Register a new user
  Future<bool> register({
    required String phoneNumber,
    required String name,
    required String password,
  }) async {
    try {
      _state = AuthState.loading;
      _errorMessage = null;
      notifyListeners();

      final result = await _apiService.register(
        phoneNumber: phoneNumber,
        name: name,
        password: password,
      );

      if (result.success) {
        _phoneNumber = phoneNumber;
        _userName = name;
        _state = AuthState.unauthenticated; // Still need to login
        notifyListeners();
        return true;
      }

      _errorMessage = result.error;
      _state = AuthState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  /// Request OTP for login
  Future<bool> requestOtp(String phoneNumber) async {
    try {
      _state = AuthState.loading;
      _errorMessage = null;
      _isOtpSent = false;
      notifyListeners();

      final result = await _apiService.loginWithOTP(phoneNumber: phoneNumber);

      if (result.success) {
        _phoneNumber = phoneNumber;
        _isOtpSent = true;
        _state = AuthState.unauthenticated;
        notifyListeners();
        return true;
      }

      _errorMessage = result.error;
      _state = AuthState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  /// Verify OTP
  Future<bool> verifyOtp(String otp) async {
    try {
      if (_phoneNumber == null) {
        _errorMessage = 'Phone number not set';
        _state = AuthState.error;
        notifyListeners();
        return false;
      }

      _state = AuthState.loading;
      _errorMessage = null;
      notifyListeners();

      final result = await _apiService.verifyOTP(
        phoneNumber: _phoneNumber!,
        otp: otp,
      );

      if (result.success) {
        _userName = result.data?['name'] ?? result.data?['user']?['name'];
        _state = AuthState.authenticated;
        await _saveSession();
        notifyListeners();
        return true;
      }

      _errorMessage = result.error;
      _state = AuthState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  /// Login with password
  Future<bool> loginWithPassword({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      _state = AuthState.loading;
      _errorMessage = null;
      notifyListeners();

      final result = await _apiService.loginWithPassword(
        phoneNumber: phoneNumber,
        password: password,
      );

      if (result.success) {
        _phoneNumber = phoneNumber;
        _userName = result.data?['name'] ?? result.data?['user']?['name'];
        _state = AuthState.authenticated;
        await _saveSession();
        notifyListeners();
        return true;
      }

      _errorMessage = result.error;
      _state = AuthState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _apiService.logout();
    } finally {
      _phoneNumber = null;
      _userName = null;
      _isOtpSent = false;
      _state = AuthState.unauthenticated;
      await _clearSession();
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    if (_state == AuthState.error) {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  void resetOtpState() {
    _isOtpSent = false;
    notifyListeners();
  }
}
