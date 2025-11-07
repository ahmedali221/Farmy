const ChickenType = require('./models/ChickenType');
const logger = require('../utils/logger');

const chickenTypes = [
  {
    name: 'أبيض',
    price: 0,
    stock: 0,
    date: new Date()
  },
  {
    name: 'تسمين',
    price: 0,
    stock: 0,
    date: new Date()
  },
  {
    name: 'بلدي',
    price: 0,
    stock: 0,
    date: new Date()
  },
  {
    name: 'احمر',
    price: 0,
    stock: 0,
    date: new Date()
  },
  {
    name: 'ساسو',
    price: 0,
    stock: 0,
    date: new Date()
  },
  {
    name: 'بط',
    price: 0,
    stock: 0,
    date: new Date()
  }
];

async function seedChickenTypes() {
  try {
    // Clear existing chicken types
    await ChickenType.deleteMany({});
    logger.info('Existing chicken types cleared');

    // Insert chicken types
    const seededTypes = await ChickenType.insertMany(chickenTypes);
    logger.info(`${seededTypes.length} chicken types seeded successfully`);

    return seededTypes;
  } catch (error) {
    logger.error(`Error seeding chicken types: ${error.message}`);
    throw error;
  }
}

module.exports = { seedChickenTypes };

