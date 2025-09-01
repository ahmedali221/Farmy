const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const dotenv = require('dotenv');
const mongoose = require('mongoose');
const errorHandler = require('./src/middleware/error');

dotenv.config();
mongoose.connect(process.env.MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log('MongoDB connected'))
  .catch(err => console.error('MongoDB connection error:', err));

const app = express();

app.use(express.json());
app.use(cors({
  origin: '*', // Allow all origins
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(morgan('dev'));

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

// Public routes
app.post('/api/login', authController.login);

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

app.use(errorHandler);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});