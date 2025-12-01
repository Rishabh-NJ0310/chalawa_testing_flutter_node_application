import jwt, { TokenExpiredError } from 'jsonwebtoken'
import { Request, Response, NextFunction } from 'express';
import { 
    decryptWithSession, 
    decryptWithPassword,
    encryptWithSession,
    encryptWithPassword 
} from '../encryption/chalawa';

// Extend Express Request to include decrypted body and session info
declare global {
    namespace Express {
        interface Request {
            decryptedBody?: any;
            sessionId?: string;
            encryptionType?: 'dh' | 'password' | 'none';
        }
    }
}

export async function generateJWTToken(hospitalId: string, username: string): Promise<string> {
    const payLoad = { hospitalId, username }
    const secret = process.env.JWT_SECRET_KEY ?? "hplusbackendsecretkey";
    const expiresIn = `40h`;  // This line is hardcoded because jwt.sign expects a string for expiresIn and unable to use env variable directly
    return jwt.sign(payLoad, secret || "hplusbackendsecretkey", { expiresIn })
}

export async function verifyJWT(req: Request, res: Response, next: NextFunction) {
    try {
        let sessionToken = req.headers?.authorization?.split(" ")[1] || req.body.sessionToken
        if (!sessionToken?.trim()) {
            return res.status(400).json({
                success: true,
                message: "Session token is required"
            })
        }
        const _ = jwt.verify(sessionToken, process.env.JWT_SECRET_KEY as string || "hplusbackendsecretkey");
        return next();
    }
    catch (error) {
        console.log("JWT verification failed due to following error: \n", error);
        if (error instanceof TokenExpiredError) {
            return res.status(400).json({
                success: false,
                message: "JWT token expired !!"
            })
        }
        return res.status(500).json({
            success: "false",
            message: "Invalid Session Token !!"
        })
    }
}

/**
 * Middleware to decrypt request body using password-based encryption
 * Used for registration endpoint
 * The password can be sent in the request body alongside encryptedData
 */
export function decryptPasswordMiddleware(req: Request, res: Response, next: NextFunction) {
    try {
        const { encryptedData, password } = req.body;
        
        // If no encrypted data, check if it's plain request (for testing)
        if (!encryptedData) {
            req.encryptionType = 'none';
            return next();
        }

        // Use password from request if provided, otherwise use default
        const decryptedData = decryptWithPassword(encryptedData, password);
        
        if (!decryptedData) {
            return res.status(400).json({
                success: false,
                message: "Failed to decrypt request data"
            });
        }

        req.body = decryptedData;
        req.encryptionType = 'password';
        next();
    } catch (error) {
        console.error('Password decryption middleware error:', error);
        return res.status(400).json({
            success: false,
            message: "Invalid encrypted data format"
        });
    }
}

/**
 * Middleware to decrypt request body using DH session-based encryption
 * Used for authenticated endpoints after login
 */
export function decryptSessionMiddleware(req: Request, res: Response, next: NextFunction) {
    try {
        const sessionId = req.headers['x-session-id'] as string;
        const { encryptedData } = req.body;

        // If no encrypted data, check if it's plain request (for testing)
        if (!encryptedData) {
            req.encryptionType = 'none';
            req.sessionId = sessionId;
            return next();
        }

        if (!sessionId) {
            return res.status(400).json({
                success: false,
                message: "Session ID required for encrypted requests"
            });
        }

        const decryptedData = decryptWithSession(sessionId, encryptedData);
        
        if (!decryptedData) {
            return res.status(400).json({
                success: false,
                message: "Failed to decrypt request data. Invalid session or corrupted data."
            });
        }

        req.body = decryptedData;
        req.sessionId = sessionId;
        req.encryptionType = 'dh';
        next();
    } catch (error) {
        console.error('Session decryption middleware error:', error);
        return res.status(400).json({
            success: false,
            message: "Invalid encrypted data format"
        });
    }
}

/**
 * Helper to send encrypted response using session-based encryption
 */
export function sendEncryptedResponse(res: Response, sessionId: string, statusCode: number, data: any) {
    const encryptedData = encryptWithSession(sessionId, data);
    
    if (!encryptedData) {
        // Fallback to plain response if encryption fails
        return res.status(statusCode).json(data);
    }

    return res.status(statusCode).json({
        encrypted: true,
        data: encryptedData
    });
}

/**
 * Helper to send encrypted response using password-based encryption
 */
export function sendPasswordEncryptedResponse(res: Response, statusCode: number, data: any) {
    const encryptedData = encryptWithPassword(data);
    
    return res.status(statusCode).json({
        encrypted: true,
        data: encryptedData
    });
}