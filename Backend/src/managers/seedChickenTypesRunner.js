const mongoose = require('mongoose');
const dotenv = require('dotenv');
const { seedChickenTypes } = require('./seedChickenTypes');

// Load environment variables
dotenv.config();

// Connect to MongoDB
mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/farmy', {
  useNewUrlParser: true,
  useUnifiedTopology: true,
  serverSelectionTimeoutMS: 30000, // 30 seconds
  socketTimeoutMS: 45000, // 45 seconds
  maxPoolSize: 10, // Maintain up to 10 socket connections
  minPoolSize: 5, // Maintain a minimum of 5 socket connections
  maxIdleTimeMS: 30000, // Close connections after 30 seconds of inactivity
  connectTimeoutMS: 30000, // Give up initial connection after 30 seconds
})
.then(() => console.log('MongoDB connected for seeding'))
.catch(err => {
  console.error('MongoDB connection error:', err);
  process.exit(1);
});

// Run the seed function
async function runSeed() {
  try {
    const seededTypes = await seedChickenTypes();
    console.log('Chicken types seeded successfully:');
    seededTypes.forEach(type => {
      console.log(`- ${type.name} (Price: ${type.price} EGP, Stock: ${type.stock})`);
    });
    
    // Disconnect from MongoDB
    await mongoose.disconnect();
    console.log('MongoDB disconnected');
    process.exit(0);
  } catch (error) {
    console.error('Error seeding chicken types:', error);
    await mongoose.disconnect();
    process.exit(1);
  }
}

runSeed();




