/**
 * Test Client for Chalawa Encryption
 * 
 * This file demonstrates how a client would interact with the encrypted API.
 * Run this after starting the server to test the encryption flow.
 */

import { 
    generateDHKeyPair, 
    computeSharedSecret, 
    dhEncrypt, 
    dhDecrypt,
    encrypt,
    decrypt 
} from 'chalawa';

const BASE_URL = 'http://localhost:9000/api/user';
const ENCRYPTION_PASSWORD = process.env.ENCRYPTION_PASSWORD || 'chalawa-test-encryption-key-2024';

// Store client's DH keys and session info
let clientKeyPair: { privateKey: string; publicKey: string };
let sharedSecret: string;
let sessionId: string;

interface ApiResponse {
    encrypted?: boolean;
    data?: string;
    message?: string;
    serverPublicKey?: string;
    sessionId?: string;
    otp?: string;
    [key: string]: unknown;
}

/**
 * Step 1: Register a new user using password-based encryption (recommended)
 */
async function registerUser(phoneNumber: string, name: string, password: string) {
    console.log('\n=== REGISTRATION (Password-Based Encryption) ===');
    
    const userData = { phoneNumber, name, password };
    console.log('Original data:', userData);
    
    // Encrypt using password-based method
    const encryptedData = encrypt({
        plainText: JSON.stringify(userData),
        password: ENCRYPTION_PASSWORD
    });
    console.log('Encrypted data:', encryptedData.substring(0, 50) + '...');
    
    const response = await fetch(`${BASE_URL}/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ encryptedData })
    });
    
    const result = await response.json() as ApiResponse;
    
    // Decrypt response if encrypted
    if (result.encrypted && result.data) {
        const decryptedResult = decrypt({
            encryptedText: result.data,
            password: ENCRYPTION_PASSWORD
        });
        console.log('Decrypted response:', decryptedResult);
        return decryptedResult;
    }
    
    console.log('Response:', result);
    return result;
}

/**
 * Step 2: Perform DH Key Exchange before login
 */
async function performKeyExchange() {
    console.log('\n=== KEY EXCHANGE (Diffie-Hellman) ===');
    
    // Generate client's key pair
    clientKeyPair = generateDHKeyPair();
    console.log('Client public key generated:', clientKeyPair.publicKey.substring(0, 50) + '...');
    
    // Send client's public key to server
    const response = await fetch(`${BASE_URL}/key-exchange`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ clientPublicKey: clientKeyPair.publicKey })
    });
    
    const result = await response.json() as ApiResponse;
    console.log('Server public key received:', result.serverPublicKey?.substring(0, 50) + '...');
    console.log('Session ID:', result.sessionId);
    
    // Compute shared secret
    sharedSecret = computeSharedSecret({
        privateKey: clientKeyPair.privateKey,
        otherPublicKey: result.serverPublicKey!
    });
    sessionId = result.sessionId!;
    
    console.log('Shared secret computed:', sharedSecret.substring(0, 50) + '...');
    console.log('Key exchange complete! Both parties now have the same shared secret.');
    
    return { sessionId, sharedSecret };
}

/**
 * Step 3: Login with OTP using DH encryption
 */
async function loginWithOTP(phoneNumber: string) {
    console.log('\n=== LOGIN WITH OTP (DH Encryption) ===');
    
    const loginData = { phoneNumber };
    console.log('Original data:', loginData);
    
    // Encrypt using DH shared secret
    const encryptedData = dhEncrypt({
        plainText: JSON.stringify(loginData),
        sharedSecret
    });
    console.log('Encrypted data:', encryptedData.substring(0, 50) + '...');
    
    const response = await fetch(`${BASE_URL}/login-otp`, {
        method: 'POST',
        headers: { 
            'Content-Type': 'application/json',
            'x-session-id': sessionId
        },
        body: JSON.stringify({ encryptedData })
    });
    
    const result = await response.json() as ApiResponse;
    
    // Decrypt response if encrypted
    if (result.encrypted && result.data) {
        const decryptedResult = dhDecrypt({
            encryptedText: result.data,
            sharedSecret
        });
        console.log('Decrypted response:', decryptedResult);
        return decryptedResult as ApiResponse;
    }
    
    console.log('Response:', result);
    return result;
}

/**
 * Step 4: Verify OTP using DH encryption
 */
async function verifyOTP(phoneNumber: string, otp: string) {
    console.log('\n=== VERIFY OTP (DH Encryption) ===');
    
    const verifyData = { phoneNumber, otp };
    console.log('Original data:', verifyData);
    
    const encryptedData = dhEncrypt({
        plainText: JSON.stringify(verifyData),
        sharedSecret
    });
    
    const response = await fetch(`${BASE_URL}/verify-otp`, {
        method: 'POST',
        headers: { 
            'Content-Type': 'application/json',
            'x-session-id': sessionId
        },
        body: JSON.stringify({ encryptedData })
    });
    
    const result = await response.json() as ApiResponse;
    
    if (result.encrypted && result.data) {
        const decryptedResult = dhDecrypt({
            encryptedText: result.data,
            sharedSecret
        });
        console.log('Decrypted response:', decryptedResult);
        return decryptedResult;
    }
    
    console.log('Response:', result);
    return result;
}

/**
 * Step 5: Submit data using DH encryption
 */
async function submitData(id: string, name: string, message: string) {
    console.log('\n=== SUBMIT DATA (DH Encryption) ===');
    
    const data = { id, name, message };
    console.log('Original data:', data);
    
    const encryptedData = dhEncrypt({
        plainText: JSON.stringify(data),
        sharedSecret
    });
    
    const response = await fetch(`${BASE_URL}/addData`, {
        method: 'POST',
        headers: { 
            'Content-Type': 'application/json',
            'x-session-id': sessionId
        },
        body: JSON.stringify({ encryptedData })
    });
    
    const result = await response.json() as ApiResponse;
    
    if (result.encrypted && result.data) {
        const decryptedResult = dhDecrypt({
            encryptedText: result.data,
            sharedSecret
        });
        console.log('Decrypted response:', decryptedResult);
        return decryptedResult;
    }
    
    console.log('Response:', result);
    return result;
}

/**
 * Get data with encrypted response
 */
async function getData(id: string) {
    console.log('\n=== GET DATA (DH Encrypted Response) ===');
    
    const response = await fetch(`${BASE_URL}/getData/${id}`, {
        method: 'GET',
        headers: { 
            'Content-Type': 'application/json',
            'x-session-id': sessionId
        }
    });
    
    const result = await response.json() as ApiResponse;
    
    if (result.encrypted && result.data) {
        const decryptedResult = dhDecrypt({
            encryptedText: result.data,
            sharedSecret
        });
        console.log('Decrypted response:', decryptedResult);
        return decryptedResult;
    }
    
    console.log('Response:', result);
    return result;
}

/**
 * Main test flow
 */
async function runTests() {
    console.log('='.repeat(60));
    console.log('CHALAWA ENCRYPTION TEST CLIENT');
    console.log('='.repeat(60));
    
    try {
        // Test 1: Register with password-based encryption
        await registerUser('1234567890', 'Test User', 'testpass123');
        
        // Test 2: Perform key exchange
        await performKeyExchange();
        
        // Test 3: Login with OTP (DH encrypted)
        const loginResult = await loginWithOTP('1234567890');
        
        // Test 4: Verify OTP (use the OTP from login result)
        if (loginResult.otp) {
            await verifyOTP('1234567890', loginResult.otp);
        }
        
        // Test 5: Submit data (DH encrypted)
        await submitData('data-001', 'Test Data', 'This is a secret message');
        
        // Test 6: Get data (DH encrypted response)
        await getData('data-001');
        
        console.log('\n' + '='.repeat(60));
        console.log('ALL TESTS COMPLETED SUCCESSFULLY!');
        console.log('='.repeat(60));
        
    } catch (error) {
        console.error('Test failed:', error);
    }
}

// Run if executed directly
runTests();
