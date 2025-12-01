import apiRouter from "./apiRouter";
import cors from "cors";
import express, { Application } from "express";

const app: Application = express();


app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const corsOptions = {
  origin: '*', 
  methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
  preflightContinue: false,
  optionsSuccessStatus: 204
};

app.use(cors(corsOptions))

app.use("/api", apiRouter);

app.listen(9000, () => {
    console.log("Server is running on port 9000");
})


process.on('SIGINT', async() => {
    console.log("Shutting down server...");

    process.exit();
});