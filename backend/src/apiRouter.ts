import { Router } from "express";
import router from "./routes/rotues";


const apiRouter = Router();

apiRouter.use("/user", router);

export default apiRouter;