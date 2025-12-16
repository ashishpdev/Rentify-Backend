// tests/setup/global-setup.js
const db = require('../../src/database/connection');

module.exports = async () => {
  console.log('\n🚀 Setting up test environment...\n');
  
  try {
    process.env.NODE_ENV = 'test';
    process.env.LOG_LEVEL = 'error';
    
    await db.initializeMasterConnection();
    console.log('✅ Test database connected\n');
    
  } catch (error) {
    console.error('❌ Failed to setup test environment:', error);
    throw error;
  }
};