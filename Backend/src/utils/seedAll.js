const mongoose = require('mongoose');
const User = require('../managers/models/User');
const Employee = require('../employees/models/Employee');
const Customer = require('../customers/models/Customer');
const ChickenType = require('../managers/models/ChickenType');
const dotenv = require('dotenv');

require('dotenv').config();

// Connect to MongoDB
mongoose.connect(process.env.MONGO_URI , {
  serverSelectionTimeoutMS: 30000, // 30 seconds
  socketTimeoutMS: 45000, // 45 seconds
  maxPoolSize: 10,
  minPoolSize: 5,
  maxIdleTimeMS: 30000,
  connectTimeoutMS: 30000,
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
    username: 'manager1',
    password: 'manager123',
    role: 'manager'
  },
  {
    username: 'employee1',
    password: 'employee123',
    role: 'employee'
  },
  {
    username: 'employee2',
    password: 'employee123',
    role: 'employee'
  }
];

// Sample employee data
const employees = [
  {
    name: 'أحمد محمد',
    email: 'ahmed.mohamed@farmy.com',
    assignedShops: [],
    dailyLogs: []
  },
  {
    name: 'محمد علي',
    email: 'mohamed.ali@farmy.com',
    assignedShops: [],
    dailyLogs: []
  },
  {
    name: 'علي حسن',
    email: 'ali.hassan@farmy.com',
    assignedShops: [],
    dailyLogs: []
  }
];

// Sample customer data
const customers = [
  {
    name: 'متجر الخضار المركزي',
    contactInfo: {
      phone: '01234567890',
      address: 'شارع النصر، القاهرة'
    },
    orders: [],
    outstandingDebts: 0,
    payments: [],
    receipts: []
  },
  {
    name: 'سوق الدواجن',
    contactInfo: {
      phone: '01234567891',
      address: 'شارع الجيزة، الجيزة'
    },
    orders: [],
    outstandingDebts: 0,
    payments: [],
    receipts: []
  },
  {
    name: 'مطعم الطيور الطازجة',
    contactInfo: {
      phone: '01234567892',
      address: 'شارع المعادي، القاهرة'
    },
    orders: [],
    outstandingDebts: 0,
    payments: [],
    receipts: []
  },
  {
    name: 'سوبر ماركت النور',
    contactInfo: {
      phone: '01234567893',
      address: 'شارع العباسية، القاهرة'
    },
    orders: [],
    outstandingDebts: 0,
    payments: [],
    receipts: []
  },
  {
    name: 'متجر الدجاج الذهبي',
    contactInfo: {
      phone: '01234567894',
      address: 'شارع شبرا، القاهرة'
    },
    orders: [],
    outstandingDebts: 0,
    payments: [],
    receipts: []
  }
];

// Sample chicken types data
const chickenTypes = [
  {
    name: 'أبيض',
    price: 45.00,
    stock: 0,
    date: new Date()
  },
  {
    name: 'تسمين',
    price: 50.00,
    stock: 0,
    date: new Date()
  },
  {
    name: 'بلدي',
    price: 60.00,
    stock: 0,
    date: new Date()
  },
  {
    name: 'احمر',
    price: 55.00,
    stock: 0,
    date: new Date()
  },
  {
    name: 'ساسو',
    price: 48.00,
    stock: 0,
    date: new Date()
  },
  {
    name: 'بط',
    price: 70.00,
    stock: 0,
    date: new Date()
  }
];

// Seed all data
async function seedAll() {
  try {
    console.log('\n=== Starting Database Seeding ===\n');
    
    // Seed Users
    console.log('Seeding users...');
    await User.deleteMany({});
    const createdUsers = await User.create(users);
    console.log(`✓ Created ${createdUsers.length} users`);
    createdUsers.forEach(user => {
      console.log(`  - ${user.username} (${user.role})`);
    });
    
    // Seed Employees
    console.log('\nSeeding employees...');
    await Employee.deleteMany({});
    const createdEmployees = await Employee.create(employees);
    console.log(`✓ Created ${createdEmployees.length} employees`);
    createdEmployees.forEach(employee => {
      console.log(`  - ${employee.name} (${employee.email})`);
    });
    
    // Seed Customers
    console.log('\nSeeding customers...');
    await Customer.deleteMany({});
    const createdCustomers = await Customer.create(customers);
    console.log(`✓ Created ${createdCustomers.length} customers`);
    createdCustomers.forEach(customer => {
      console.log(`  - ${customer.name} (${customer.contactInfo.phone})`);
    });
    
    // Seed Chicken Types
    console.log('\nSeeding chicken types...');
    await ChickenType.deleteMany({});
    const createdChickenTypes = await ChickenType.create(chickenTypes);
    console.log(`✓ Created ${createdChickenTypes.length} chicken types`);
    createdChickenTypes.forEach(type => {
      console.log(`  - ${type.name} (${type.price} EGP/kg)`);
    });
    
    console.log('\n=== Database Seeding Completed ===');
    console.log(`Total users: ${createdUsers.length}`);
    console.log(`Total employees: ${createdEmployees.length}`);
    console.log(`Total customers: ${createdCustomers.length}`);
    console.log(`Total chicken types: ${createdChickenTypes.length}`);
    
    // Disconnect from MongoDB
    await mongoose.disconnect();
    console.log('\nMongoDB disconnected');
    process.exit(0);
  } catch (error) {
    console.error('Error seeding database:', error);
    await mongoose.disconnect();
    process.exit(1);
  }
}

// Run the seed function
seedAll();

