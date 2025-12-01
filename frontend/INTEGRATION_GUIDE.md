# Flutter-Node.js Integration Guide

This guide shows how to use the Chalawa Flutter package with your Node.js TypeScript backend for secure communication.

## Installation

### Flutter (Frontend)
```yaml
# pubspec.yaml
dependencies:
  chalawa: ^0.0.1
```

### Node.js (Backend)
```bash
npm install chalawa
```

## Basic Usage Pattern

### 1. Flutter Client Code
```dart
import 'package:chalawa/chalawa.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SecureCommunication {
  static String? _sharedSecret;
  
  // Step 1: Initialize secure connection
  static Future<void> initializeSecureConnection(String serverUrl) async {
    // Generate client key pair
    final clientKeys = generateDHKeyPair();
    
    // Send public key to server
    final response = await http.post(
      Uri.parse('$serverUrl/api/key-exchange'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'clientPublicKey': clientKeys.publicKey,
      }),
    );
    
    final serverData = jsonDecode(response.body);
    final serverPublicKey = serverData['serverPublicKey'];
    
    // Compute shared secret
    _sharedSecret = computeSharedSecret(DHSharedSecretInput(
      privateKey: clientKeys.privateKey,
      otherPublicKey: serverPublicKey,
    ));
    
    print('Secure connection established');
  }
  
  // Step 2: Send encrypted data
  static Future<Map<String, dynamic>> sendSecureData(
    String serverUrl, 
    Map<String, dynamic> data
  ) async {
    if (_sharedSecret == null) {
      throw Exception('Secure connection not initialized');
    }
    
    final encrypted = dhEncrypt(DHEncryptionInput(
      plainText: jsonEncode(data),
      sharedSecret: _sharedSecret!,
    ));
    
    final response = await http.post(
      Uri.parse('$serverUrl/api/secure-data'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'encryptedData': encrypted}),
    );
    
    final responseData = jsonDecode(response.body);
    
    // Decrypt server response
    final decryptedResponse = dhDecrypt(DHDecryptionInput(
      encryptedText: responseData['encryptedResponse'],
      sharedSecret: _sharedSecret!,
    ));
    
    return jsonDecode(decryptedResponse);
  }
}

// Usage example
void main() async {
  await SecureCommunication.initializeSecureConnection('http://localhost:9000');
  
  final userData = {
    'userId': 123,
    'action': 'update_profile',
    'data': {'name': 'John Doe', 'email': 'john@example.com'}
  };
  
  final result = await SecureCommunication.sendSecureData(
    'http://localhost:9000',
    userData
  );
  
  print('Server response: $result');
}
```

### 2. Node.js Server Code
```typescript
import express from 'express';
import { generateDHKeyPair, computeSharedSecret, dhEncrypt, dhDecrypt } from 'chalawa';

const app = express();
app.use(express.json());

const sessions = new Map<string, string>(); // sessionId -> sharedSecret

// Step 1: Handle key exchange
app.post('/api/key-exchange', (req, res) => {
  const { clientPublicKey } = req.body;
  
  // Generate server key pair
  const serverKeys = generateDHKeyPair();
  
  // Compute shared secret
  const sharedSecret = computeSharedSecret({
    privateKey: serverKeys.privateKey,
    otherPublicKey: clientPublicKey
  });
  
  // Store shared secret (in production, use proper session management)
  const sessionId = Math.random().toString(36);
  sessions.set(sessionId, sharedSecret);
  
  res.json({
    serverPublicKey: serverKeys.publicKey,
    sessionId: sessionId
  });
});

// Step 2: Handle encrypted data
app.post('/api/secure-data', (req, res) => {
  const { encryptedData, sessionId } = req.body;
  const sharedSecret = sessions.get(sessionId);
  
  if (!sharedSecret) {
    return res.status(401).json({ error: 'Invalid session' });
  }
  
  try {
    // Decrypt client data
    const decryptedData = dhDecrypt({
      encryptedText: encryptedData,
      sharedSecret: sharedSecret
    });
    
    console.log('Received secure data:', decryptedData);
    
    // Process the data...
    const responseData = {
      status: 'success',
      message: 'Data processed securely',
      timestamp: new Date().toISOString()
    };
    
    // Encrypt response
    const encryptedResponse = dhEncrypt({
      plainText: JSON.stringify(responseData),
      sharedSecret: sharedSecret
    });
    
    res.json({ encryptedResponse });
    
  } catch (error) {
    console.error('Decryption failed:', error);
    res.status(400).json({ error: 'Invalid encrypted data' });
  }
});

app.listen(3000, () => {
  console.log('Secure server running on port 3000');
});
```

## Security Best Practices

### 1. Session Management
- Use proper session tokens instead of storing shared secrets in memory
- Implement session expiration
- Clear shared secrets after use

### 2. Key Rotation
```dart
// Rotate keys periodically
class KeyRotation {
  static Timer? _rotationTimer;
  
  static void startKeyRotation() {
    _rotationTimer = Timer.periodic(Duration(hours: 1), (timer) {
      SecureCommunication.initializeSecureConnection('http://localhost:9000');
    });
  }
}
```

### 3. Error Handling
```dart
try {
  final result = await SecureCommunication.sendSecureData(url, data);
} catch (e) {
  if (e is SocketException) {
    // Handle network errors
  } else if (e.toString().contains('Decryption failed')) {
    // Handle encryption errors - possibly re-establish connection
    await SecureCommunication.initializeSecureConnection(serverUrl);
  }
}
```

## Testing Integration

### Flutter Test
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:chalawa/chalawa.dart';

void main() {
  test('Integration with Node.js format', () {
    // Test data from Node.js
    const nodeJsEncrypted = "data:iv:tag"; // From your Node.js test
    const sharedSecret = "your-shared-secret";
    
    final decrypted = dhDecrypt(DHDecryptionInput(
      encryptedText: nodeJsEncrypted,
      sharedSecret: sharedSecret,
    ));
    
    expect(decrypted, isNotNull);
  });
}
```

## Production Deployment

### Environment Variables
```dart
// Flutter
class Config {
  static const serverUrl = String.fromEnvironment('SERVER_URL', 
    defaultValue: 'https://api.yourapp.com');
}
```

### HTTPS Only
Always use HTTPS in production for the initial key exchange to prevent man-in-the-middle attacks.

### Certificate Pinning
Consider implementing certificate pinning for additional security:

```dart
import 'package:http/io_client.dart';
import 'dart:io';

class SecureHttpClient {
  static HttpClient createSecureClient() {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) {
      // Implement certificate pinning logic
      return false; // Only allow trusted certificates
    };
    return client;
  }
}
