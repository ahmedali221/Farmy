const ChickenType = require('../../managers/models/ChickenType');
const Customer = require('../../customers/models/Customer');
const Joi = require('joi');
const logger = require('../../utils/logger');

// Validation schemas
const orderSchema = Joi.object({
  chickenType: Joi.string().required(),
  quantity: Joi.number().min(1).required(),
  customer: Joi.string().required(),
  type: Joi.string().required(),
  grossWeight: Joi.number().min(0).required(),
  loadingPrice: Joi.number().min(0).required(),
  // Auto calculated fields - will be calculated in controller
  netWeight: Joi.number().min(0),
  totalLoading: Joi.number().min(0),
  // Legacy fields for backward compatibility
  todayAccount: Joi.number().min(0),
  totalPrice: Joi.number().min(0),
  offer: Joi.string().allow('', null),
  orderDate: Joi.date().default(Date.now),
  status: Joi.string().valid('pending', 'delivered', 'cancelled').default('pending')
});

// Helper function to calculate loading values
const calculateLoadingValues = (orderData) => {
  const { grossWeight, quantity, loadingPrice } = orderData;
  
  // الوزن الصافي = الوزن القائم - (العدد × 8)
  const netWeight = grossWeight - (quantity * 8);
  
  // إجمالي التحميل = الوزن الصافي × سعر التحميل
  const totalLoading = netWeight * loadingPrice;
  
  return {
    netWeight: Math.max(0, netWeight), // Ensure non-negative
    totalLoading: Math.max(0, totalLoading) // Ensure non-negative
  };
};

exports.createOrder = async (req, res) => {
  const { error } = orderSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    // Calculate auto-calculated fields
    const calculatedValues = calculateLoadingValues(req.body);
    
    const orderData = {
      ...req.body,
      ...calculatedValues, // Add calculated netWeight and totalLoading
      employee: req.user.id // Current logged-in employee
    };

    // Check if chicken type exists and has sufficient stock
    const chickenType = await ChickenType.findById(orderData.chickenType);
    if (!chickenType) {
      return res.status(404).json({ message: 'Chicken type not found' });
    }

    if (chickenType.stock < orderData.quantity) {
      return res.status(400).json({ message: 'Insufficient stock' });
    }

    // Check if customer exists
    const customer = await Customer.findById(orderData.customer);
    if (!customer) {
      return res.status(404).json({ message: 'Customer not found' });
    }

    const order = new Order(orderData);
    await order.save();

    // Add order to customer's orders array
    customer.orders.push(order._id);
    await customer.save();

    // Update stock
    chickenType.stock -= orderData.quantity;
    await chickenType.save();

    // Populate references for response
    await order.populate('chickenType customer employee');

    logger.info(`Order created: ${order._id} by employee: ${req.user.id}`);
    res.status(201).json(order);
  } catch (err) {
    logger.error(`Error creating order: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getAllOrders = async (req, res) => {
  try {
    const orders = await Order.find()
      .populate('chickenType')
      .populate('customer')
      .populate('employee')
      .sort({ createdAt: -1 });
    
    logger.info('All orders fetched');
    res.json(orders);
  } catch (err) {
    logger.error(`Error fetching orders: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getOrdersByEmployee = async (req, res) => {
  try {
    const orders = await Order.find({ employee: req.user.id })
      .populate('chickenType')
      .populate('customer')
      .sort({ createdAt: -1 });
    
    logger.info(`Orders fetched for employee: ${req.user.id}`);
    res.json(orders);
  } catch (err) {
    logger.error(`Error fetching employee orders: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getOrderById = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id)
      .populate('chickenType')
      .populate('customer')
      .populate('employee');
    
    if (!order) {
      return res.status(404).json({ message: 'Order not found' });
    }
    
    logger.info(`Order fetched: ${req.params.id}`);
    res.json(order);
  } catch (err) {
    logger.error(`Error fetching order: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.updateOrderStatus = async (req, res) => {
  try {
    const { status } = req.body;
    
    if (!['pending', 'delivered', 'cancelled'].includes(status)) {
      return res.status(400).json({ message: 'Invalid status' });
    }

    const order = await Order.findByIdAndUpdate(
      req.params.id,
      { status },
      { new: true }
    ).populate('chickenType customer employee');

    if (!order) {
      return res.status(404).json({ message: 'Order not found' });
    }

    logger.info(`Order status updated: ${req.params.id} to ${status}`);
    res.json(order);
  } catch (err) {
    logger.error(`Error updating order status: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};