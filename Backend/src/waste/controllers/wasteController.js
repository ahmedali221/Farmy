const DailyWaste = require('../models/DailyWaste');
const logger = require('../../utils/logger');

// Get waste data for a specific date
exports.getWasteByDate = async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) {
      return res.status(400).json({ message: 'Date is required' });
    }

    const targetDate = new Date(date);
    const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());
    const endOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate() + 1);

    const wasteData = await DailyWaste.find({
      date: { $gte: startOfDay, $lt: endOfDay }
    })
    .populate('chickenType', 'name')
    .sort({ chickenType: 1 });

    // Calculate totals
    const totals = wasteData.reduce((acc, waste) => {
      acc.totalQuantity += waste.totalWasteQuantity;
      acc.totalNetWeight += waste.totalWasteNetWeight;
      acc.overDistributionQuantity += waste.overDistributionQuantity;
      acc.overDistributionNetWeight += waste.overDistributionNetWeight;
      return acc;
    }, {
      totalQuantity: 0,
      totalNetWeight: 0,
      overDistributionQuantity: 0,
      overDistributionNetWeight: 0,
    });

    res.json({
      date: targetDate,
      wasteByChickenType: wasteData,
      totals,
    });
  } catch (err) {
    logger.error(`Error fetching waste by date: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Add or update waste for a specific chicken type on a date
exports.upsertWaste = async (req, res) => {
  try {
    const { date, chickenType, overDistributionQuantity = 0, overDistributionNetWeight = 0, otherWasteQuantity = 0, otherWasteNetWeight = 0, notes } = req.body;
    
    if (!date || !chickenType) {
      return res.status(400).json({ message: 'Date and chickenType are required' });
    }

    const targetDate = new Date(date);
    const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());

    const wasteData = await DailyWaste.findOneAndUpdate(
      { 
        date: startOfDay, 
        chickenType 
      },
      {
        date: startOfDay,
        chickenType,
        overDistributionQuantity: Number(overDistributionQuantity) || 0,
        overDistributionNetWeight: Number(overDistributionNetWeight) || 0,
        otherWasteQuantity: Number(otherWasteQuantity) || 0,
        otherWasteNetWeight: Number(otherWasteNetWeight) || 0,
        notes: notes || '',
      },
      { 
        upsert: true, 
        new: true 
      }
    ).populate('chickenType', 'name');

    res.json(wasteData);
  } catch (err) {
    logger.error(`Error upserting waste: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get waste summary for a date range
exports.getWasteSummary = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    if (!startDate || !endDate) {
      return res.status(400).json({ message: 'Start date and end date are required' });
    }

    const start = new Date(startDate);
    const end = new Date(endDate);
    end.setDate(end.getDate() + 1); // Include the end date

    const wasteData = await DailyWaste.find({
      date: { $gte: start, $lt: end }
    })
    .populate('chickenType', 'name')
    .sort({ date: -1, chickenType: 1 });

    // Group by chicken type
    const wasteByChickenType = {};
    const dailyTotals = {};

    wasteData.forEach(waste => {
      const chickenTypeName = waste.chickenType.name;
      const dateKey = waste.date.toISOString().split('T')[0];

      // Initialize chicken type if not exists
      if (!wasteByChickenType[chickenTypeName]) {
        wasteByChickenType[chickenTypeName] = {
          chickenType: waste.chickenType,
          totalQuantity: 0,
          totalNetWeight: 0,
          overDistributionQuantity: 0,
          overDistributionNetWeight: 0,
          days: []
        };
      }

      // Add to chicken type totals
      wasteByChickenType[chickenTypeName].totalQuantity += waste.totalWasteQuantity;
      wasteByChickenType[chickenTypeName].totalNetWeight += waste.totalWasteNetWeight;
      wasteByChickenType[chickenTypeName].overDistributionQuantity += waste.overDistributionQuantity;
      wasteByChickenType[chickenTypeName].overDistributionNetWeight += waste.overDistributionNetWeight;
      wasteByChickenType[chickenTypeName].days.push({
        date: waste.date,
        quantity: waste.totalWasteQuantity,
        netWeight: waste.totalWasteNetWeight,
        overDistributionQuantity: waste.overDistributionQuantity,
        overDistributionNetWeight: waste.overDistributionNetWeight,
        notes: waste.notes
      });

      // Initialize daily total if not exists
      if (!dailyTotals[dateKey]) {
        dailyTotals[dateKey] = {
          date: waste.date,
          totalQuantity: 0,
          totalNetWeight: 0,
          overDistributionQuantity: 0,
          overDistributionNetWeight: 0,
        };
      }

      // Add to daily totals
      dailyTotals[dateKey].totalQuantity += waste.totalWasteQuantity;
      dailyTotals[dateKey].totalNetWeight += waste.totalWasteNetWeight;
      dailyTotals[dateKey].overDistributionQuantity += waste.overDistributionQuantity;
      dailyTotals[dateKey].overDistributionNetWeight += waste.overDistributionNetWeight;
    });

    res.json({
      period: { startDate, endDate },
      wasteByChickenType,
      dailyTotals: Object.values(dailyTotals).sort((a, b) => new Date(b.date) - new Date(a.date)),
    });
  } catch (err) {
    logger.error(`Error fetching waste summary: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};
