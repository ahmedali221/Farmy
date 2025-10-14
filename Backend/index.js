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

// Routes - with error handling for serverless
let auth, authController, managerController, managerRoutes, orderRoutes, deliveryRoutes;
let employeeRoutes, customerRoutes, financeRoutes, paymentRoutes, expenseRoutes;
let loadingRoutes, supplierRoutes, employeeExpenseRoutes, transferRoutes;
let distributionRoutes, wasteRoutes, dailyStockController;

try {
  auth = require('./src/middleware/auth');
  authController = require('./src/managers/controllers/authController');
  managerController = require('./src/managers/controllers/managerController');
  managerRoutes = require('./src/managers/routes/managerRoutes');
  orderRoutes = require('./src/orders/routes/orderRoutes');
  deliveryRoutes = require('./src/deliveries/routes/deliveryRoutes');
  employeeRoutes = require('./src/employees/routes/employeeRoutes');
  customerRoutes = require('./src/customers/routes/customerRoutes');
  financeRoutes = require('./src/finances/routes/financeRoutes');
  paymentRoutes = require('./src/payments/routes/paymentRoutes');
  expenseRoutes = require('./src/expenses/routes/expenseRoutes');
  loadingRoutes = require('./src/loadings/routes/loadingRoutes');
  supplierRoutes = require('./src/suppliers/routes/supplierRoutes');
  employeeExpenseRoutes = require('./src/employeeExpenses/routes/employeeExpenseRoutes');
  transferRoutes = require('./src/transfers/routes/transferRoutes');
  distributionRoutes = require('./src/distributions/routes/distributionRoutes');
  wasteRoutes = require('./src/waste/routes/wasteRoutes');
  dailyStockController = require('./src/stocks/controllers/dailyStockController');
} catch (err) {
  console.error('Error loading routes:', err.message);
  // Continue with basic functionality
}

// Healthcheck (public)
app.get('/api/health', (req, res) => {
  res.status(200).json({ 
    status: 'ok',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
    vercel: !!process.env.VERCEL
  });
});

// Simple test endpoint (no dependencies)
app.get('/api/test', (req, res) => {
  res.status(200).json({ 
    message: 'Serverless function is working',
    timestamp: new Date().toISOString(),
    method: req.method,
    url: req.url
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
if (authController) {
  app.post('/api/login', authController.login);
  app.post('/api/signup', authController.signup);
}

// Protected routes
if (auth && authController) {
  app.get('/api/validate', auth(['manager', 'employee']), authController.validate);
  app.post('/api/logout', auth(['manager', 'employee']), authController.logout);
}

// Shared routes (accessible by both managers and employees)
if (auth && managerController) {
  app.get('/api/chicken-types', auth(['manager', 'employee']), managerController.getAllChickenTypes);
}

// Protected routes - only register if modules are loaded
if (auth && managerRoutes) app.use('/api/managers', auth(['manager']), managerRoutes);
if (auth && orderRoutes) app.use('/api/orders', auth(['manager', 'employee']), orderRoutes);
if (auth && deliveryRoutes) app.use('/api/deliveries', auth(['manager', 'employee']), deliveryRoutes);
if (auth && employeeRoutes) app.use('/api/employees', auth(['manager', 'employee']), employeeRoutes);
if (auth && customerRoutes) app.use('/api/customers', auth(['manager', 'employee']), customerRoutes);
if (auth && financeRoutes) app.use('/api/finances', auth(['manager']), financeRoutes);
if (auth && paymentRoutes) app.use('/api/payments', auth(['manager', 'employee']), paymentRoutes);
if (auth && expenseRoutes) app.use('/api/expenses', auth(['manager', 'employee']), expenseRoutes);
if (auth && loadingRoutes) app.use('/api/loadings', auth(['manager', 'employee']), loadingRoutes);
if (auth && supplierRoutes) app.use('/api/suppliers', auth(['manager', 'employee']), supplierRoutes);
if (auth && employeeExpenseRoutes) app.use('/api/employee-expenses', auth(['manager', 'employee']), employeeExpenseRoutes);
if (auth && transferRoutes) app.use('/api/transfers', auth(['manager']), transferRoutes);
if (auth && distributionRoutes) app.use('/api/distributions', auth(['manager', 'employee']), distributionRoutes);
if (wasteRoutes) app.use('/api/waste', wasteRoutes);

// Stocks endpoints
if (auth && dailyStockController) {
  app.get('/api/stocks/week', auth(['manager']), dailyStockController.getWeek);
  app.get('/api/stocks/by-date', auth(['manager']), dailyStockController.getByDate);
  app.post('/api/stocks/upsert', auth(['manager']), dailyStockController.upsertForDate);
  app.get('/api/stocks/profit', auth(['manager']), dailyStockController.getDailyProfit);
}

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

// Export for Vercel (alternative approach)
module.exports = app;