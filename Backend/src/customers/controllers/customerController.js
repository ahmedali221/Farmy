const Customer = require('../models/Customer');
const Joi = require('joi');
const logger = require('../../utils/logger');

// Validation schemas
const customerSchema = Joi.object({
  name: Joi.string().required(),
  contactInfo: Joi.object({
    phone: Joi.string(),
    address: Joi.string()
  })
});

const paymentSchema = Joi.object({
  amount: Joi.number().min(0).required(),
  date: Joi.date()
});

exports.createCustomer = async (req, res) => {
  const { error } = customerSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const customer = new Customer(req.body);
    await customer.save();
    logger.info(`Created new customer: ${customer.name}`);
    res.status(201).json(customer);
  } catch (err) {
    logger.error(`Error creating customer: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getAllCustomers = async (req, res) => {
  try {
    const customers = await Customer.find().populate('orders receipts');
    logger.info('Fetched all customers');
    res.json(customers);
  } catch (err) {
    logger.error(`Error fetching customers: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.updateCustomer = async (req, res) => {
  const { error } = customerSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const customer = await Customer.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!customer) return res.status(404).json({ message: 'Customer not found' });
    res.json(customer);
  } catch (err) {
    logger.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.addPayment = async (req, res) => {
  const { error } = paymentSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const customer = await Customer.findById(req.params.id);
    if (!customer) return res.status(404).json({ message: 'Customer not found' });
    customer.payments.push(req.body);
    customer.outstandingDebts -= req.body.amount;
    await customer.save();
    res.json(customer);
  } catch (err) {
    logger.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.deleteCustomer = async (req, res) => {
  try {
    const customer = await Customer.findByIdAndDelete(req.params.id);
    if (!customer) return res.status(404).json({ message: 'Customer not found' });
    logger.info(`Deleted customer: ${customer.name}`);
    res.json({ message: 'Customer deleted successfully', customer });
  } catch (err) {
    logger.error(`Error deleting customer: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getCustomerById = async (req, res) => {
  try {
    const customer = await Customer.findById(req.params.id).populate('orders receipts');
    if (!customer) return res.status(404).json({ message: 'Customer not found' });
    logger.info(`Fetched customer with ID: ${req.params.id}`);
    res.json(customer);
  } catch (err) {
    logger.error(`Error fetching customer ${req.params.id}: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};