import app from "./app.js";
import dbConnection from "./src/config/db.js";
import "dotenv/config";

const PORT = process.env.PORT || 4000;

const startServer = async () => {
  try {
    await dbConnection();

    app.listen(PORT, () => {
      console.log(`Server is running on http://localhost:${PORT}`);
    });
  } catch (error) {
    console.error("Failed to start server", error);
    process.exit(1);
  }
};

startServer();
