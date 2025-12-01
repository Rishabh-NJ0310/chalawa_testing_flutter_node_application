import {
  MongoClient,
  Db,
  Collection,
  Document,
  MongoNetworkError,
  MongoNetworkTimeoutError,
  ServerApiVersion,
  ClientSession,
} from "mongodb";
import dotenv from "dotenv";
dotenv.config();

const dbName: string = "CHALAWA_DB";
const collectionCache: string[] = [];
export const MONGODB_URI = `mongodb://localhost:27017`;


console.log("MongoDB URI:", MONGODB_URI);
// console.log("Process Env: ",);
// Connection management variables
let mongoClient: MongoClient | null = null;
let isConnected = false;
let connectionTimeout: NodeJS.Timeout | null = null;
const IDLE_TIMEOUT = 600000; // Close connection after 60 seconds of inactivity
const MAX_POOL_SIZE = 10; // Limit maximum connections in the pool


// Create MongoDB client with optimized settings
function createMongoClient() {
  return new MongoClient(MONGODB_URI, {
    ssl: true,
    tls: true,
    connectTimeoutMS: 30000,
    socketTimeoutMS: 45000,
    maxPoolSize: MAX_POOL_SIZE, // Limit max connections
    minPoolSize: 1, // Minimum connections to maintain
    serverApi: {
      version: ServerApiVersion.v1,
      strict: false, // Set to false to allow operations not in API v1
      deprecationErrors: true,
    }
  });
}

// Connect to MongoDB with lazy connection
export async function connectMongoDB() {
  try {
    if (isConnected && mongoClient) {
      // Reset the timeout if connection is already active
      resetConnectionTimeout();
      return mongoClient;
    }

    // Create new client if needed
    if (!mongoClient) {
      mongoClient = createMongoClient();
    }

    await mongoClient.connect();
    isConnected = true;
    console.log("Connected to MongoDB");

    // Set timeout to close connection after inactivity
    resetConnectionTimeout();

    return mongoClient;
  } catch (error) {
    console.error("Error connecting to MongoDB:", error);
    isConnected = false;
    mongoClient = null;
    throw error;
  }
}

// Reset the connection timeout
function resetConnectionTimeout() {
  if (connectionTimeout) {
    clearTimeout(connectionTimeout);
  }

  connectionTimeout = setTimeout(async () => {
    try {
      if (isConnected && mongoClient) {
        console.log("Closing idle MongoDB connection");
        await mongoClient.close();
        isConnected = false;
        mongoClient = null;
      }
      if (!isConnected) {
        console.log("MongoDB connection closed due to inactivity");
      }
    } catch (error) {
      console.error("Error closing idle MongoDB connection:", error);
    }
  }, IDLE_TIMEOUT);
}


// Close MongoDB connection
export async function closeMongoDB() {
  try {
    if (connectionTimeout) {
      clearTimeout(connectionTimeout);
      connectionTimeout = null;
    }

    if (isConnected && mongoClient) {
      console.log("Closing MongoDB connection...");
      await mongoClient.close();
      console.log("MongoDB connection closed");
      isConnected = false;
      mongoClient = null;
    }
  } catch (error) {
    console.error("Error closing MongoDB connection:", error);
    throw error;
  }
}

// Handle MongoDB errors with reconnection logic
export async function mongoErrorHandler(
  error: Error | any,
  message: string,
  message2: string
) {
  if (
    error instanceof MongoNetworkError ||
    error instanceof MongoNetworkTimeoutError
  ) {
    // Try to reconnect
    isConnected = false;
    await connectMongoDB().then(() => {
      console.error(message, error);
    });
  } else {
    console.error(message2, error, error.stack);
  }
}


// Get collection with auto-connect
export async function getCollection<T extends Document>(
  collectionName: string
): Promise<Collection<T>> {
  // Ensure connection is active
  if (!isConnected || !mongoClient) {
    await connectMongoDB();
  }
  // Reset timeout since we're using the connection
  resetConnectionTimeout();

  // Get database and collection
  if (!mongoClient) throw new Error("MongoDB client is not initialized");
  const db: Db = mongoClient.db(dbName);
  return db.collection<T>(collectionName);
}


// Disconnect function (retains for backward compatibility)
export async function disConnect() {
  await closeMongoDB();
}
