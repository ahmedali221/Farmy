const mongoose = require('mongoose');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config({ path: '../../.env' });

// Clean database function - removes ALL data
async function cleanDatabase() {
  try {
    // Get database using native MongoDB client (more reliable)
    const client = mongoose.connection.getClient();
    
    // Extract database name from connection string or use default
    const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/farmy';
    const dbName = mongoUri.split('/').pop().split('?')[0] || 'farmy';
    const db = client.db(dbName);
    
    // Get all collections in the database
    const collections = await db.listCollections().toArray();
    const collectionNames = collections.map(col => col.name);
    
    console.log('\n=== Database Cleanup Started ===');
    console.log(`Found ${collectionNames.length} collections in the database`);
    console.log('Removing ALL data from all collections...\n');
    
    let deletedCount = 0;
    let totalDocumentsDeleted = 0;
    
    // Delete all documents from all collections
    for (const collectionName of collectionNames) {
      // Skip system collections
      if (collectionName.startsWith('system.')) {
        console.log(`Skipping system collection: ${collectionName}`);
        continue;
      }
      
      try {
        const result = await db.collection(collectionName).deleteMany({});
        console.log(`✗ Deleted ${result.deletedCount} documents from: ${collectionName}`);
        totalDocumentsDeleted += result.deletedCount;
        deletedCount++;
      } catch (error) {
        console.error(`Error deleting from ${collectionName}:`, error.message);
      }
    }
    
    console.log('\n=== Database Cleanup Completed ===');
    console.log(`Collections cleaned: ${deletedCount}`);
    console.log(`Total documents deleted: ${totalDocumentsDeleted}`);
    console.log('\nNote: Collections were cleaned but not dropped. Empty collections may still exist.');
    
    // Disconnect from MongoDB
    await mongoose.disconnect();
    console.log('\nMongoDB disconnected');
    process.exit(0);
  } catch (error) {
    console.error('Error cleaning database:', error);
    await mongoose.disconnect();
    process.exit(1);
  }
}

// Connect to MongoDB and run cleanup
mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/farmy', {
  serverSelectionTimeoutMS: 30000, // 30 seconds
  socketTimeoutMS: 45000, // 45 seconds
  maxPoolSize: 10,
  minPoolSize: 5,
  maxIdleTimeMS: 30000,
  connectTimeoutMS: 30000,
})
.then(() => {
  console.log('MongoDB connected for database cleanup');
  return cleanDatabase();
})
.catch(err => {
  console.error('MongoDB connection error:', err);
  process.exit(1);
});
