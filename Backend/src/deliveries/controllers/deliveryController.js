const Delivery = require('../models/Delivery');
const ChickenType = require('../../managers/models/ChickenType');
const Joi = require('joi');
const logger = require('../../utils/logger');

// Validation schema
const deliverySchema = Joi.object({
  customer: Joi.string().required(),
  chickenType: Joi.string().required(),
  quantity: Joi.number().min(1).required()
});

exports.createDelivery = async (req, res) => {
  const { error } = deliverySchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const chickenType = await ChickenType.findById(req.body.chickenType);
    if (!chickenType) return res.status(404).json({ message: 'Chicken type not found' });
    const amountDue = chickenType.price * req.body.quantity;
    const delivery = new Delivery({ ...req.body, amountDue });
    await delivery.save();
    logger.info(`Created new delivery for customer ${req.body.customer}`);
    res.status(201).json(delivery);
  } catch (err) {
    logger.error(`Error creating delivery: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getAllDeliveries = async (req, res) => {
  try {
    const deliveries = await Delivery.find().populate('customer chickenType');
    logger.info('Fetched all deliveries');
    res.json(deliveries);
  } catch (err) {
    logger.error(`Error fetching deliveries: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.updateDelivery = async (req, res) => {
  try {
    const delivery = await Delivery.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!delivery) return res.status(404).json({ message: 'Delivery not found' });
    res.json(delivery);
  } catch (err) {
    logger.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.issueReceipt = async (req, res) => {
  try {
    const delivery = await Delivery.findByIdAndUpdate(req.params.id, { receiptIssued: true }, { new: true });
    if (!delivery) return res.status(404).json({ message: 'Delivery not found' });
    res.json(delivery);
  } catch (err) {
    logger.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};