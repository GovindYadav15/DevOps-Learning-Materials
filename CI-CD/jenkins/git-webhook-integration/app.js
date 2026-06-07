import express from "express";
import { fileURLToPath } from "node:url";

const PORT = Number(process.env.PORT || 3000);
const APP_NAME = process.env.APP_NAME || "jenkins-webhook-node-app";
const currentFile = fileURLToPath(import.meta.url);

const app = express();

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "ok",
    app: APP_NAME,
    uptime: Math.round(process.uptime()),
  });
});

app.get("/", (req, res) => {
  res.status(200).json({
    message: "Node.js Express app deployed by Jenkins webhook and Docker.",
    app: APP_NAME,
    routes: ["/", "/health"],
  });
});

app.use((req, res) => {
  res.status(404).json({
    error: "Not found",
  });
});

function startServer(port = PORT) {
  return app.listen(port, () => {
    console.log(`${APP_NAME} is running on port ${port}`);
  });
}

if (process.argv[1] === currentFile) {
  startServer();
}

export {
  app,
  startServer,
};
