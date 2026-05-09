// src/app.js
const express = require("express");
const morgan = require("morgan");

const app = express();
const todoRoutes = require("./routes/todoRoutes");

app.use(express.json());
app.use(morgan("dev"));

// Routes
app.get("/", (req, res) => {
  res.send("Todo API running inside Docker container!");
});

app.use("/api/todos", todoRoutes);

// Health check
app.get("/health", (req, res) => {
  res.status(200).json({ status: "OK" });
});

module.exports = app;
