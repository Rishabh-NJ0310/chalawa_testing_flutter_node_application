import { IData, IUser } from "../model/user.model";
import { getCollection } from "../db/db";
import { Request, Response } from "express";
import { v4 as uuidv4 } from 'uuid';
import { 
    getServerPublicKey, 
    establishSession, 
    encryptWithSession,
    clearSessionSecret 
} from "../encryption/chalawa";
import { sendEncryptedResponse, sendPasswordEncryptedResponse } from "../middleware/middleware";


const otpMap: Map<string, string> = new Map();
// Store session IDs mapped to phone numbers for lookup
const sessionMap: Map<string, string> = new Map();


/**
 * Key Exchange endpoint - returns server's public key and establishes session
 * This should be called before login to set up DH encryption
 */
export const keyExchange = async (req: Request, res: Response): Promise<void> => {
    try {
        const { clientPublicKey } = req.body;
        
        if (!clientPublicKey) {
            res.status(400).json({ message: "Client public key is required" });
            return;
        }

        // Generate a unique session ID
        const sessionId = uuidv4();
        
        // Establish the session with DH key exchange
        establishSession(sessionId, clientPublicKey);
        
        // Return server's public key and session ID
        res.status(200).json({
            message: "Key exchange successful",
            serverPublicKey: getServerPublicKey(),
            sessionId: sessionId
        });
    } catch (error) {
        console.error('Key exchange error:', error);
        res.status(500).json({ message: "Key exchange failed" });
    }
};

/**
 * Get server's public key (for initial setup before key exchange)
 */
export const getPublicKey = async (req: Request, res: Response): Promise<void> => {
    try {
        res.status(200).json({
            publicKey: getServerPublicKey()
        });
    } catch (error) {
        res.status(500).json({ message: "Failed to get public key" });
    }
};


export const registerUser = async (req: Request, res: Response): Promise<void> => {
    try{
        const {
            phoneNumber,
            name,
            password
        } = req.body;
        const usersCollection = await getCollection<IUser>("users");
        
        const existingUser = await usersCollection.findOne({ phoneNumber });
        if (existingUser) {
            // Send encrypted response if request was encrypted
            if (req.encryptionType === 'password') {
                sendPasswordEncryptedResponse(res, 400, { message: "User already exists" });
                return;
            }
            res.status(400).json({ message: "User already exists" });
            return;
        }
        
        const newUser: IUser = {
            phoneNumber,
            name,
            password
        };
        await usersCollection.insertOne(newUser);
        
        // Send encrypted response if request was encrypted
        if (req.encryptionType === 'password') {
            sendPasswordEncryptedResponse(res, 201, { message: "User registered successfully" });
            return;
        }
        res.status(201).json({ message: "User registered successfully" });
    }catch(error){
        res.status(500).json({ message: "Internal server error" });
    }
}


export const loginWithOTP = async (req: Request, res: Response): Promise<void> => {
    try{
        const { phoneNumber } = req.body;
        const sessionId = req.sessionId;
        
        const usersCollection = await getCollection<IUser>("users");
        const user = await usersCollection.findOne({ phoneNumber });
        if(!user){
            if (sessionId && req.encryptionType === 'dh') {
                sendEncryptedResponse(res, sessionId, 404, { message: "User not found" });
                return;
            }
            res.status(404).json({ message: "User not found" });
            return;
        }

        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        otpMap.set(phoneNumber, otp);
        
        // Map session to phone number for later use
        if (sessionId) {
            sessionMap.set(sessionId, phoneNumber);
        }
        
        console.log(`OTP for ${phoneNumber}: ${otp}`);
        
        const responseData = { message: "OTP sent successfully", otp: otp };
        
        if (sessionId && req.encryptionType === 'dh') {
            sendEncryptedResponse(res, sessionId, 200, responseData);
            return;
        }
        res.status(200).json(responseData);
    }catch(error){
        res.status(500).json({ message: "Internal server error" });
    }
}


export const verifyOTP = async (req: Request, res: Response): Promise<void> => {
    try{
        const { phoneNumber, otp } = req.body;
        const sessionId = req.sessionId;
        
        const storedOtp = otpMap.get(phoneNumber);
        if(storedOtp !== otp){
            if (sessionId && req.encryptionType === 'dh') {
                sendEncryptedResponse(res, sessionId, 400, { message: "Invalid OTP" });
                return;
            }
            res.status(400).json({ message: "Invalid OTP" });
            return;
        }
        otpMap.delete(phoneNumber);
        
        const responseData = { 
            message: "OTP verified successfully",
            sessionId: sessionId // Return session ID for future encrypted requests
        };
        
        if (sessionId && req.encryptionType === 'dh') {
            sendEncryptedResponse(res, sessionId, 200, responseData);
            return;
        }
        res.status(200).json(responseData);
    }catch(error){
        res.status(500).json({ message: "Internal server error" });
    }
}


export const loginWithPassword = async (req: Request, res: Response): Promise<void> => {
    try{
        const { phoneNumber, password } = req.body;
        const sessionId = req.sessionId;
        
        const usersCollection = await getCollection<IUser>("users");
        const user = await usersCollection.findOne({ phoneNumber, password });
        if(!user){
            if (sessionId && req.encryptionType === 'dh') {
                sendEncryptedResponse(res, sessionId, 400, { message: "Invalid phone number or password" });
                return;
            }
            res.status(400).json({ message: "Invalid phone number or password" });
            return;
        }
        
        // Map session to phone number
        if (sessionId) {
            sessionMap.set(sessionId, phoneNumber);
        }
        
        const responseData = { 
            message: "Login successful",
            sessionId: sessionId // Return session ID for future encrypted requests
        };
        
        if (sessionId && req.encryptionType === 'dh') {
            sendEncryptedResponse(res, sessionId, 200, responseData);
            return;
        }
        res.status(200).json(responseData);
    }catch(error){
        res.status(500).json({ message: "Internal server error" });
    }
}


/**
 * Logout - clears the session encryption key
 */
export const logout = async (req: Request, res: Response): Promise<void> => {
    try {
        const sessionId = req.sessionId || req.headers['x-session-id'] as string;
        
        if (sessionId) {
            clearSessionSecret(sessionId);
            sessionMap.delete(sessionId);
        }
        
        res.status(200).json({ message: "Logged out successfully" });
    } catch (error) {
        res.status(500).json({ message: "Internal server error" });
    }
};


export const submitData = async (req: Request, res: Response): Promise<void> => {
    try{
        const {
            id,
            name,
            message
        } = req.body;
        const sessionId = req.sessionId;
        
        const dataCollection = await getCollection<IData>("data");
        const newData: IData = {
            id,
            name,
            message
        };
        await dataCollection.insertOne(newData);
        
        const responseData = { message: "Data submitted successfully" };
        
        if (sessionId && req.encryptionType === 'dh') {
            sendEncryptedResponse(res, sessionId, 201, responseData);
            return;
        }
        res.status(201).json(responseData);
    }catch(error){
        res.status(500).json({ message: "Internal server error" });
    }
}


export const getDataById = async (req: Request, res: Response): Promise<void> => {
    try{
        const { id } = req.params;
        const sessionId = req.headers['x-session-id'] as string;
        
        const dataCollection = await getCollection<IData>("data");
        const data = await dataCollection.findOne({ id });
        if(!data){
            if (sessionId) {
                sendEncryptedResponse(res, sessionId, 404, { message: "Data not found" });
                return;
            }
            res.status(404).json({ message: "Data not found" });
            return;
        }
        
        if (sessionId) {
            sendEncryptedResponse(res, sessionId, 200, data);
            return;
        }
        res.status(200).json(data);
    }catch(error){
        res.status(500).json({ message: "Internal server error" });
    }
}


export const updateDataById = async (req: Request, res: Response): Promise<void> => {
    try{
        const { id } = req.params;
        const { name, message } = req.body;
        const sessionId = req.sessionId;
        
        const dataCollection = await getCollection<IData>("data");
        const updateResult = await dataCollection.updateOne(
            { id },
            { $set: { name, message } }
        );
        if(updateResult.matchedCount === 0){
            if (sessionId && req.encryptionType === 'dh') {
                sendEncryptedResponse(res, sessionId, 404, { message: "Data not found" });
                return;
            }
            res.status(404).json({ message: "Data not found" });
            return;
        }
        
        const responseData = { message: "Data updated successfully" };
        
        if (sessionId && req.encryptionType === 'dh') {
            sendEncryptedResponse(res, sessionId, 200, responseData);
            return;
        }
        res.status(200).json(responseData);
    }catch(error){
        res.status(500).json({ message: "Internal server error" });
    }
}