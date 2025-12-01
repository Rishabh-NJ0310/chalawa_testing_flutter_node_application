import { 
    generateDHKeyPair, 
    computeSharedSecret, 
    dhEncrypt, 
    dhDecrypt,
    encrypt,
    decrypt 
} from 'chalawa';

// Server's DH key pair - regenerated on server restart for forward secrecy
const serverKeyPair = generateDHKeyPair();

// Store shared secrets per session/user (in production, use Redis or similar)
const sharedSecretStore: Map<string, string> = new Map();

// Password for basic encryption (registration)
const ENCRYPTION_PASSWORD = process.env.ENCRYPTION_PASSWORD || 'chalawa-test-encryption-key-2024';

/**
 * Get server's public key for DH key exchange
 */
export const getServerPublicKey = (): string => {
    return serverKeyPair.publicKey;
};

/**
 * Compute and store shared secret for a session
 */
export const establishSession = (sessionId: string, clientPublicKey: string): string => {
    const sharedSecret = computeSharedSecret({
        privateKey: serverKeyPair.privateKey,
        otherPublicKey: clientPublicKey
    });
    sharedSecretStore.set(sessionId, sharedSecret);
    return sharedSecret;
};

/**
 * Get stored shared secret for a session
 */
export const getSessionSecret = (sessionId: string): string | undefined => {
    return sharedSecretStore.get(sessionId);
};

/**
 * Remove session secret (on logout)
 */
export const clearSessionSecret = (sessionId: string): void => {
    sharedSecretStore.delete(sessionId);
};

/**
 * Encrypt data using DH shared secret (for authenticated sessions)
 */
export const encryptWithSession = (sessionId: string, data: any): string | null => {
    const sharedSecret = sharedSecretStore.get(sessionId);
    if (!sharedSecret) {
        return null;
    }
    return dhEncrypt({
        plainText: JSON.stringify(data),
        sharedSecret
    });
};

/**
 * Decrypt data using DH shared secret (for authenticated sessions)
 */
export const decryptWithSession = (sessionId: string, encryptedData: string): any | null => {
    const sharedSecret = sharedSecretStore.get(sessionId);
    if (!sharedSecret) {
        return null;
    }
    try {
        return dhDecrypt({
            encryptedText: encryptedData,
            sharedSecret
        });
    } catch (error) {
        console.error('Decryption failed:', error);
        return null;
    }
};

/**
 * Encrypt data using basic password (for registration - recommended method)
 * @param data - The data to encrypt
 * @param password - Optional password, uses ENCRYPTION_PASSWORD if not provided
 */
export const encryptWithPassword = (data: any, password?: string): string => {
    return encrypt({
        plainText: JSON.stringify(data),
        password: password || ENCRYPTION_PASSWORD
    });
};

/**
 * Decrypt data using basic password (for registration)
 * @param encryptedData - The encrypted data string
 * @param password - Optional password, uses ENCRYPTION_PASSWORD if not provided
 */
export const decryptWithPassword = (encryptedData: string, password?: string): any => {
    try {
        return decrypt({
            encryptedText: encryptedData,
            password: password || ENCRYPTION_PASSWORD
        });
    } catch (error) {
        console.error('Password decryption failed:', error);
        return null;
    }
};

export {
    generateDHKeyPair,
    computeSharedSecret,
    dhEncrypt,
    dhDecrypt,
    encrypt,
    decrypt
};
