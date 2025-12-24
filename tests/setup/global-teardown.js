// tests/setup/global-teardown.js
const db = require('../../src/database/connection');

module.exports = async () => {
  console.log('\n🧹 Cleaning up test environment...\n');
  
  try {
    await db.closeConnections();
    console.log('✅ Test cleanup complete\n');
  } catch (error) {
    console.error('❌ Cleanup error:', error);
  }
};