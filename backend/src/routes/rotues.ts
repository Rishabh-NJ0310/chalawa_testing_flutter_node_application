import * as userController from "../controller/controller";
import { Router } from "express";
import { decryptPasswordMiddleware, decryptSessionMiddleware } from "../middleware/middleware";

const router = Router();

// Key Exchange endpoints (no encryption needed - public)
router.get("/public-key", userController.getPublicKey);
router.post("/key-exchange", userController.keyExchange);

// Registration - uses password-based encryption (recommended method)
router.post("/register", decryptPasswordMiddleware, userController.registerUser);

// Login endpoints - use DH session-based encryption after key exchange
router.post("/login-otp", decryptSessionMiddleware, userController.loginWithOTP);
router.post("/verify-otp", decryptSessionMiddleware, userController.verifyOTP);
router.post("/loginWithPassword", decryptSessionMiddleware, userController.loginWithPassword);
router.post("/logout", userController.logout);

// Data endpoints - use DH session-based encryption
router.get("/getData/:id", userController.getDataById);
router.post("/addData", decryptSessionMiddleware, userController.submitData);
router.put("/updateData/:id", decryptSessionMiddleware, userController.updateDataById);


export default router;