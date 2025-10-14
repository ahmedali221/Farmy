const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const dotenv = require('dotenv');
const mongoose = require('mongoose');
const errorHandler = require('./src/middleware/error');

dotenv.config();

// MongoDB connection optimized for serverless environments
const connectDB = async () => {
  try {
    // Check if already connected
    if (mongoose.connection.readyState === 1) {
      return;
    }

    const mongoOptions = {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      // Serverless-optimized settings
      serverSelectionTimeoutMS: 5000, // 5 seconds for serverless
      socketTimeoutMS: 45000,
      connectTimeoutMS: 10000, // 10 seconds for serverless
      // Disable buffering for serverless
      bufferMaxEntries: 0,
      bufferCommands: false,
      // Optimized pool settings for serverless
      maxPoolSize: 1, // Single connection for serverless
      minPoolSize: 0, // No minimum for serverless
      maxIdleTimeMS: 10000, // Close quickly in serverless
      // Retry settings
      retryWrites: true,
      retryReads: true
    };

    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/farmy', mongoOptions);
    console.log('MongoDB connected successfully');
  } catch (err) {
    console.error('MongoDB connection error:', err);
    // Don't exit process in serverless - let the function handle the error
    throw err;
  }
};

// Connect to MongoDB
connectDB().catch(console.error);

const app = express();

app.use(express.json());
app.use(cors({
  origin: '*', // Allow all origins
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(morgan('dev'));

// Middleware to ensure DB connection in serverless
app.use(async (req, res, next) => {
  try {
    if (mongoose.connection.readyState !== 1) {
      await connectDB();
    }
    next();
  } catch (err) {
    console.error('Database connection middleware error:', err);
    res.status(503).json({ 
      message: 'Database connection failed',
      error: process.env.NODE_ENV === 'development' ? err.message : 'Service unavailable'
    });
  }
});

// Routes
const auth = require('./src/middleware/auth');
const authController = require('./src/managers/controllers/authController');
const managerController = require('./src/managers/controllers/managerController');
const managerRoutes = require('./src/managers/routes/managerRoutes');
const orderRoutes = require('./src/orders/routes/orderRoutes');
const deliveryRoutes = require('./src/deliveries/routes/deliveryRoutes');
const employeeRoutes = require('./src/employees/routes/employeeRoutes');
const customerRoutes = require('./src/customers/routes/customerRoutes');
const financeRoutes = require('./src/finances/routes/financeRoutes');
const paymentRoutes = require('./src/payments/routes/paymentRoutes');
const expenseRoutes = require('./src/expenses/routes/expenseRoutes');
const loadingRoutes = require('./src/loadings/routes/loadingRoutes');
const supplierRoutes = require('./src/suppliers/routes/supplierRoutes');
const employeeExpenseRoutes = require('./src/employeeExpenses/routes/employeeExpenseRoutes');
const transferRoutes = require('./src/transfers/routes/transferRoutes');
const distributionRoutes = require('./src/distributions/routes/distributionRoutes');
const wasteRoutes = require('./src/waste/routes/wasteRoutes');
const dailyStockController = require('./src/stocks/controllers/dailyStockController');

// Healthcheck (public)
app.get('/api/health', (req, res) => {
  res.status(200).json({ 
    status: 'ok',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
    vercel: !!process.env.VERCEL
  });
});

// Database health check (public)
app.get('/api/health/db', async (req, res) => {
  try {
    const connectionState = mongoose.connection.readyState;
    const states = {
      0: 'disconnected',
      1: 'connected',
      2: 'connecting',
      3: 'disconnecting'
    };
    
    if (connectionState === 1) {
      // Test a simple query to ensure database is responsive
      await mongoose.connection.db.admin().ping();
      res.status(200).json({ 
        status: 'ok', 
        database: 'connected',
        connectionState: states[connectionState]
      });
    } else {
      res.status(503).json({ 
        status: 'error', 
        database: 'disconnected',
        connectionState: states[connectionState]
      });
    }
  } catch (err) {
    res.status(503).json({ 
      status: 'error', 
      database: 'error',
      message: err.message
    });
  }
});

// Public routes
app.post('/api/login', authController.login);
app.post('/api/signup', authController.signup);

// Protected routes
app.get('/api/validate', auth(['manager', 'employee']), authController.validate);
app.post('/api/logout', auth(['manager', 'employee']), authController.logout);

// Shared routes (accessible by both managers and employees)
app.get('/api/chicken-types', auth(['manager', 'employee']), managerController.getAllChickenTypes);

// Protected routes
app.use('/api/managers', auth(['manager']), managerRoutes);
app.use('/api/orders', auth(['manager', 'employee']), orderRoutes);
app.use('/api/deliveries', auth(['manager', 'employee']), deliveryRoutes);
app.use('/api/employees', auth(['manager', 'employee']), employeeRoutes);
app.use('/api/customers', auth(['manager', 'employee']), customerRoutes);
app.use('/api/finances', auth(['manager']), financeRoutes);
app.use('/api/payments', auth(['manager', 'employee']), paymentRoutes);
app.use('/api/expenses', auth(['manager', 'employee']), expenseRoutes);
app.use('/api/loadings', auth(['manager', 'employee']), loadingRoutes);
app.use('/api/suppliers', auth(['manager', 'employee']), supplierRoutes);
app.use('/api/employee-expenses', auth(['manager', 'employee']), employeeExpenseRoutes);
app.use('/api/transfers', auth(['manager']), transferRoutes);
app.use('/api/distributions', auth(['manager', 'employee']), distributionRoutes);
app.use('/api/waste', wasteRoutes);
// Stocks endpoints
app.get('/api/stocks/week', auth(['manager']), dailyStockController.getWeek);
app.get('/api/stocks/by-date', auth(['manager']), dailyStockController.getByDate);
app.post('/api/stocks/upsert', auth(['manager']), dailyStockController.upsertForDate);
app.get('/api/stocks/profit', auth(['manager']), dailyStockController.getDailyProfit);

app.use(errorHandler);

// Export the app for serverless (Vercel)
if (process.env.VERCEL) {
  module.exports = app;
} else {
  // Local development server
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
    console.log(`Accessible from: http://127.0.0.1:${PORT} (localhost)`);
    console.log(`Accessible from: http://[YOUR_IP]:${PORT} (network)`);
  });
}