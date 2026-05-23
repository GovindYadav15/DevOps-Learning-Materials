import mongoose from "mongoose";

const dbConnection = async () => {
  if (!process.env.DB_URL) {
    throw new Error("DB_URL environment variable is required");
  }

  await mongoose.connect(`${process.env.DB_URL}/tagify`);
  console.log("Database connection is established");
};
export default dbConnection;
