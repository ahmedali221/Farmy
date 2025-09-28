const Supplier = require('./models/Supplier');
const logger = require('../utils/logger');

const sampleSuppliers = [
  {
    name: 'مورد الدجاج الأول',
    contactInfo: {
      phone: '01234567890',
      email: 'supplier1@example.com',
      address: 'القاهرة، مصر'
    },
    businessInfo: {
      companyName: 'شركة الدجاج الأول',
      taxNumber: '123456789',
      commercialRegister: 'CR001'
    },
    supplierType: 'chicken',
    creditLimit: 50000,
    paymentTerms: 'credit_15',
    qualityRating: 5,
    deliveryReliability: 4,
    status: 'active',
    notes: 'مورد موثوق للدجاج الطازج'
  },
  {
    name: 'مورد العلف المتخصص',
    contactInfo: {
      phone: '01234567891',
      email: 'feed@example.com',
      address: 'الإسكندرية، مصر'
    },
    businessInfo: {
      companyName: 'شركة العلف المتخصص',
      taxNumber: '123456790',
      commercialRegister: 'CR002'
    },
    supplierType: 'feed',
    creditLimit: 30000,
    paymentTerms: 'credit_30',
    qualityRating: 4,
    deliveryReliability: 5,
    status: 'active',
    notes: 'متخصص في أعلاف الدجاج عالية الجودة'
  },
  {
    name: 'مورد المعدات الزراعية',
    contactInfo: {
      phone: '01234567892',
      email: 'equipment@example.com',
      address: 'الجيزة، مصر'
    },
    businessInfo: {
      companyName: 'شركة المعدات الزراعية',
      taxNumber: '123456791',
      commercialRegister: 'CR003'
    },
    supplierType: 'equipment',
    creditLimit: 100000,
    paymentTerms: 'credit_60',
    qualityRating: 4,
    deliveryReliability: 3,
    status: 'active',
    notes: 'مورد لمعدات المزارع والمعدات الزراعية'
  },
  {
    name: 'مورد الأدوية البيطرية',
    contactInfo: {
      phone: '01234567893',
      email: 'medicine@example.com',
      address: 'المنصورة، مصر'
    },
    businessInfo: {
      companyName: 'شركة الأدوية البيطرية',
      taxNumber: '123456792',
      commercialRegister: 'CR004'
    },
    supplierType: 'medicine',
    creditLimit: 25000,
    paymentTerms: 'cash',
    qualityRating: 5,
    deliveryReliability: 4,
    status: 'active',
    notes: 'متخصص في الأدوية البيطرية والمكملات الغذائية'
  }
];

async function seedSuppliers() {
  try {
    // Clear existing suppliers
    await Supplier.deleteMany({});
    logger.info('Existing suppliers cleared');

    // Insert sample suppliers
    const suppliers = await Supplier.insertMany(sampleSuppliers);
    logger.info(`${suppliers.length} suppliers seeded successfully`);

    return suppliers;
  } catch (error) {
    logger.error(`Error seeding suppliers: ${error.message}`);
    throw error;
  }
}

module.exports = { seedSuppliers };



