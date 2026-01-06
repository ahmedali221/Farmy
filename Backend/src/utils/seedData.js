const mongoose = require('mongoose');
const User = require('../managers/models/User');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config({ path: '../../.env' });

// Connect to MongoDB
mongoose.connect(process.env.MONGO_URI , {
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

// Sample user data
const users = [
  {
    username: 'admin',
    password: 'admin123',
    role: 'manager'
  },
  {
    username: 'employee1',
    password: 'employee123',
    role: 'employee'
  },
  {
    username: 'manager1',
    password: 'manager123',
    role: 'manager'
  }
];

// Seed function
async function seedUsers() {
  try {
    // Clear existing users
    await User.deleteMany({});
    console.log('Existing users deleted');
    
    // Create new users
    const createdUsers = await User.create(users);
    console.log(`${createdUsers.length} users created successfully`);
    console.log('Sample users created:');
    createdUsers.forEach(user => {
      console.log(`- ${user.username} (${user.role})`);
    });
    
    // Disconnect from MongoDB
    mongoose.disconnect();
    console.log('MongoDB disconnected');
  } catch (error) {
    console.error('Error seeding users:', error);
    process.exit(1);
  }
}

// Run the seed function
seedUsers();