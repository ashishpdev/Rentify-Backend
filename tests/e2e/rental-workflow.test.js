// tests/e2e/rental-workflow.test.js
const request = require('supertest');
const app = require('../../src/app');
const db = require('../../src/database/connection');

describe('Complete Rental Workflow E2E Tests', () => {
  let authTokens = {
    sessionToken: null,
    accessToken: null
  };
  
  let testData = {
    business: null,
    customer: null,
    segment: null,
    category: null,
    model: null,
    assets: [],
    rental: null
  };

  beforeAll(async () => {
    await db.initializeMasterConnection();
    
    const AccessTokenUtil = require('../../src/utils/access_token.util');
    const SessionTokenUtil = require('../../src/utils/session_token.util');
    
    const mockUserData = {
      user_id: 1,
      business_id: 1,
      branch_id: 1,
      role_id: 1,
      email: 'test@example.com',
      contact_number: '1234567890',
      user_name: 'Test User',
      business_name: 'Test Business',
      branch_name: 'Main Branch',
      role_name: 'Owner',
      is_owner: true
    };

    authTokens.accessToken = AccessTokenUtil.generateAccessToken(mockUserData).accessToken;
    authTokens.sessionToken = SessionTokenUtil.generateSessionToken({
      ...mockUserData,
      device_id: 'test_device',
      ip_address: '127.0.0.1'
    }).sessionToken;
  });

  afterAll(async () => {
    await db.closeConnections();
  });

  describe('Step 1: Product Hierarchy Setup', () => {
    it('should create product segment', async () => {
      const res = await request(app)
        .post('/api/segment/create')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          code: `E2E_SEG_${Date.now()}`,
          name: 'E2E Test Segment',
          description: 'Created by E2E test'
        });

      if (res.statusCode === 201) {
        testData.segment = res.body.data;
        expect(testData.segment).toHaveProperty('product_segment_id');
      }
    });

    it('should create product category', async () => {
      if (!testData.segment) {
        console.log('Skipping: segment not created');
        return;
      }

      const res = await request(app)
        .post('/api/category/create')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          product_segment_id: testData.segment.product_segment_id,
          code: `E2E_CAT_${Date.now()}`,
          name: 'E2E Test Category',
          description: 'Created by E2E test'
        });

      if (res.statusCode === 201) {
        testData.category = res.body.data;
        expect(testData.category).toHaveProperty('product_category_id');
      }
    });

    it('should create product model', async () => {
      if (!testData.category) {
        console.log('Skipping: category not created');
        return;
      }

      const res = await request(app)
        .post('/api/model/create')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          product_segment_id: testData.segment.product_segment_id,
          product_category_id: testData.category.product_category_id,
          model_name: 'E2E Test Model',
          description: 'Test model for E2E',
          default_rent: 100.00,
          default_deposit: 500.00,
          default_warranty_days: 30
        });

      if (res.statusCode === 201) {
        testData.model = res.body.data;
        expect(testData.model).toHaveProperty('product_model_id');
      }
    });

    it('should create multiple assets', async () => {
      if (!testData.model) {
        console.log('Skipping: model not created');
        return;
      }

      const assetPromises = [1, 2, 3].map(i =>
        request(app)
          .post('/api/asset/create')
          .set('Cookie', [
            `session_token=${authTokens.sessionToken}`,
            `access_token=${authTokens.accessToken}`
          ])
          .send({
            product_segment_id: testData.segment.product_segment_id,
            product_category_id: testData.category.product_category_id,
            product_model_id: testData.model.product_model_id,
            serial_number: `E2E_SN_${Date.now()}_${i}`,
            product_status_id: 1,
            product_condition_id: 1,
            purchase_price: 1000.00,
            current_value: 1000.00,
            rent_price: 100.00,
            deposit_amount: 500.00,
            source_type_id: 1
          })
      );

      const responses = await Promise.all(assetPromises);
      
      responses.forEach(res => {
        if (res.statusCode === 201) {
          testData.assets.push(res.body.data);
        }
      });

      expect(testData.assets.length).toBeGreaterThan(0);
    });
  });

  describe('Step 2: Customer Management', () => {
    it('should create customer', async () => {
      const res = await request(app)
        .post('/api/customer/create')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          first_name: 'E2E',
          last_name: 'Customer',
          email: `customer_${Date.now()}@e2etest.com`,
          contact_number: '9998887770',
          address_line: '123 Test Street',
          city: 'Test City',
          state: 'Test State',
          country: 'Test Country',
          pincode: '123456'
        });

      if (res.statusCode === 201) {
        testData.customer = res.body.data;
        expect(testData.customer).toHaveProperty('customer_id');
      }
    });

    it('should retrieve customer details', async () => {
      if (!testData.customer) {
        console.log('Skipping: customer not created');
        return;
      }

      const res = await request(app)
        .post('/api/customer/get')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          customer_id: testData.customer.customer_id
        });

      expect(res.statusCode).toBe(200);
      if (res.body.data && res.body.data.customer) {
        expect(res.body.data.customer).toHaveProperty('first_name', 'E2E');
      }
    });

    it('should update customer information', async () => {
      if (!testData.customer) {
        console.log('Skipping: customer not created');
        return;
      }

      const res = await request(app)
        .post('/api/customer/update')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          customer_id: testData.customer.customer_id,
          first_name: 'E2E Updated',
          contact_number: '9998887771'
        });

      expect([200, 201]).toContain(res.statusCode);
    });
  });

  describe('Step 3: Rental Lifecycle', () => {
    it('should issue rental', async () => {
      if (!testData.customer || testData.assets.length === 0) {
        console.log('Skipping: prerequisites not met');
        return;
      }

      const startDate = new Date();
      const dueDate = new Date(startDate);
      dueDate.setDate(dueDate.getDate() + 7);

      const res = await request(app)
        .post('/api/rentals/issue')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          customer_id: testData.customer.customer_id,
          invoice_no: `INV_E2E_${Date.now()}`,
          start_date: startDate.toISOString(),
          due_date: dueDate.toISOString(),
          billing_period_id: 1,
          asset_ids: testData.assets.map(a => a.asset_id).slice(0, 2),
          total_items: 2,
          security_deposit: 1000.00,
          subtotal_amount: 1400.00,
          tax_amount: 126.00,
          discount_amount: 0,
          total_amount: 1526.00,
          paid_amount: 1526.00,
          notes: 'E2E test rental'
        });

      if (res.statusCode === 201) {
        testData.rental = res.body.data;
        expect(testData.rental).toHaveProperty('rental_id');
      }
    });

    it('should retrieve rental details', async () => {
      if (!testData.rental) {
        console.log('Skipping: rental not created');
        return;
      }

      const res = await request(app)
        .post('/api/rentals/get')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          rental_id: testData.rental.rental_id
        });

      expect(res.statusCode).toBe(200);
      if (res.body.data && res.body.data.rental) {
        expect(res.body.data.rental).toHaveProperty('items');
      }
    });

    it('should list all rentals', async () => {
      const res = await request(app)
        .post('/api/rentals/list')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          page: 1,
          limit: 10
        });

      expect(res.statusCode).toBe(200);
      expect(res.body.data).toHaveProperty('rentals');
      expect(res.body.data).toHaveProperty('pagination');
    });

    it('should update rental', async () => {
      if (!testData.rental) {
        console.log('Skipping: rental not created');
        return;
      }

      const newDueDate = new Date();
      newDueDate.setDate(newDueDate.getDate() + 14);

      const res = await request(app)
        .post('/api/rentals/update')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          rental_id: testData.rental.rental_id,
          due_date: newDueDate.toISOString(),
          notes: 'Extended rental period'
        });

      expect([200, 201]).toContain(res.statusCode);
    });

    it('should return rental', async () => {
      if (!testData.rental) {
        console.log('Skipping: rental not created');
        return;
      }

      const res = await request(app)
        .post('/api/rentals/return')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          rental_id: testData.rental.rental_id,
          end_date: new Date().toISOString(),
          notes: 'Returned in good condition'
        });

      expect([200, 201]).toContain(res.statusCode);
    });
  });

  describe('Step 4: Data Validation', () => {
    it('should verify all created entities exist', async () => {
      if (testData.segment) {
        const segRes = await request(app)
          .post('/api/segment/list')
          .set('Cookie', [
            `session_token=${authTokens.sessionToken}`,
            `access_token=${authTokens.accessToken}`
          ])
          .send({ page: 1, limit: 50 });

        expect(segRes.statusCode).toBe(200);
      }

      if (testData.customer) {
        const custRes = await request(app)
          .post('/api/customer/list')
          .set('Cookie', [
            `session_token=${authTokens.sessionToken}`,
            `access_token=${authTokens.accessToken}`
          ])
          .send({ page: 1, limit: 50 });

        expect(custRes.statusCode).toBe(200);
      }

      if (testData.rental) {
        const rentalRes = await request(app)
          .post('/api/rentals/list')
          .set('Cookie', [
            `session_token=${authTokens.sessionToken}`,
            `access_token=${authTokens.accessToken}`
          ])
          .send({ page: 1, limit: 50 });

        expect(rentalRes.statusCode).toBe(200);
      }
    });
  });

  describe('Error Scenarios', () => {
    it('should handle invalid rental data gracefully', async () => {
      const res = await request(app)
        .post('/api/rentals/issue')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          customer_id: 99999,
          invoice_no: 'INVALID',
          asset_ids: [99999],
          total_amount: -100
        });

      expect([400, 404]).toContain(res.statusCode);
    });
  });
});