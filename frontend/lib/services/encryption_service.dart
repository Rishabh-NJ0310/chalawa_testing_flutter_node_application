import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:chalawa/chalawa.dart';

class EncryptionService {
  static EncryptionService? _instance;
  
  String? _sharedSecret;
  String? _sessionId;
  DHKeyPair? _clientKeyPair;

  EncryptionService._();

  static EncryptionService get instance {
    _instance ??= EncryptionService._();
    return _instance!;
  }

  bool get hasSession => _sharedSecret != null && _sessionId != null;
  String? get sessionId => _sessionId;

  /// Generate client DH key pair
  DHKeyPair generateClientKeyPair() {
    _clientKeyPair = generateDHKeyPair();
    return _clientKeyPair!;
  }

  /// Store server public key and session ID, then compute shared secret
  void establishSession({
    required String serverPublicKey,
    required String sessionId,
  }) {
    if (_clientKeyPair == null) {
      throw Exception('Client key pair not generated. Call generateClientKeyPair first.');
    }

    _sessionId = sessionId;

    // Compute shared secret using DH
    _sharedSecret = computeSharedSecret(DHSharedSecretInput(
      privateKey: _clientKeyPair!.privateKey,
      otherPublicKey: serverPublicKey,
    ));
  }

  /// Encrypt data using DH session-based encryption
  String encryptWithSession(Map<String, dynamic> data) {
    if (_sharedSecret == null) {
      throw Exception('No session established. Call establishSession first.');
    }

    final plainText = jsonEncode(data);
    return dhEncrypt(DHEncryptionInput(
      plainText: plainText,
      sharedSecret: _sharedSecret!,
    ));
  }

  /// Decrypt data using DH session-based encryption
  Map<String, dynamic> decryptWithSession(String encryptedData) {
    if (_sharedSecret == null) {
      throw Exception('No session established. Call establishSession first.');
    }

    final decrypted = dhDecrypt(DHDecryptionInput(
      encryptedText: encryptedData,
      sharedSecret: _sharedSecret!,
    ));

    if (decrypted is Map<String, dynamic>) {
      return decrypted;
    }
    return jsonDecode(decrypted.toString());
  }

  /// Custom password-based encryption that matches Node.js chalawa exactly
  /// The chalawa Flutter package has a bug where it double-encodes JSON
  String encryptWithPassword(Map<String, dynamic> data, String password) {
    final plainText = jsonEncode(data);
    return _passwordEncrypt(plainText, password);
  }

  /// Password-based encryption matching Node.js implementation exactly
  String _passwordEncrypt(String plainText, String password) {
    // Generate random IV (16 bytes)
    final random = Random.secure();
    final iv = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      iv[i] = random.nextInt(256);
    }

    // Create key from password using SHA-512 hash (matching Node.js)
    // Node.js: hash.update(password, "utf-8").digest("hex").substring(0, 32)
    final hash = sha512.convert(utf8.encode(password));
    final hexHash = hash.toString();
    final keyString = hexHash.substring(0, 32);
    final key = Uint8List.fromList(utf8.encode(keyString));

    // Initialize AES-256-GCM cipher
    final cipher = GCMBlockCipher(AESEngine());
    final keyParam = KeyParameter(key);
    final params = AEADParameters(keyParam, 128, iv, Uint8List(0));
    
    cipher.init(true, params);

    // Encrypt the plaintext directly (no double JSON encoding!)
    final plainTextBytes = Uint8List.fromList(utf8.encode(plainText));
    final encryptedBytes = cipher.process(plainTextBytes);
    
    // Extract encrypted data and auth tag (last 16 bytes)
    final encryptedData = encryptedBytes.sublist(0, encryptedBytes.length - 16);
    final authTag = encryptedBytes.sublist(encryptedBytes.length - 16);
    
    // Format: encryptedData:iv:authTag (all base64 encoded)
    final encryptedBase64 = base64.encode(encryptedData);
    final ivBase64 = base64.encode(iv);
    final authTagBase64 = base64.encode(authTag);
    
    return '$encryptedBase64:$ivBase64:$authTagBase64';
  }

  /// Decrypt data using password-based encryption
  Map<String, dynamic> decryptWithPassword(String encryptedData, String password) {
    final decrypted = decrypt(DecryptionInput(
      encryptedText: encryptedData,
      password: password,
    ));
    if (decrypted is Map<String, dynamic>) {
      return decrypted;
    }
    return jsonDecode(decrypted.toString());
  }

  /// Clear the current session
  void clearSession() {
    _sharedSecret = null;
    _sessionId = null;
    _clientKeyPair = null;
  }

  /// Get the client's public key for key exchange
  String? get clientPublicKey => _clientKeyPair?.publicKey;
}
