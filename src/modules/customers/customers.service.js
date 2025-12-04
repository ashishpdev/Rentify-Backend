// src/modules/customers/customers.service.js
const customersRepository = require("./customers.repository");
const logger = require("../../config/logger.config");

class CustomerService {
  // ======================== CREATE CUSTOMER ========================
  async createCustomer(customerData, userData) {
    try {
      const result = await customersRepository.manageCustomer({
        action: 1, // Create
        customerId: null,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        firstName: customerData.first_name,
        lastName: customerData.last_name || null,
        email: customerData.email,
        contactNumber: customerData.contact_number,
        addressLine: customerData.address_line || null,
        city: customerData.city || null,
        state: customerData.state || null,
        country: customerData.country || null,
        pincode: customerData.pincode || null,
        userId: userData.user_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success ? { customer_id: result.customerId } : null,
      };
    } catch (error) {
      logger.error("CustomerService.createCustomer error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== UPDATE CUSTOMER ========================
  async updateCustomer(customerData, userData) {
    try {
      const result = await customersRepository.manageCustomer({
        action: 2, // Update
        customerId: customerData.customer_id,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        firstName: customerData.first_name || null,
        lastName: customerData.last_name || null,
        email: customerData.email || null,
        contactNumber: customerData.contact_number || null,
        addressLine: customerData.address_line || null,
        city: customerData.city || null,
        state: customerData.state || null,
        country: customerData.country || null,
        pincode: customerData.pincode || null,
        userId: userData.user_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success
          ? { customer_id: customerData.customer_id }
          : null,
      };
    } catch (error) {
      logger.error("CustomerService.updateCustomer error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== GET CUSTOMER ========================
  async getCustomer(customerId, userData) {
    try {
      const result = await customersRepository.manageCustomer({
        action: 4, // Get List (will filter by customer_id)
        customerId: customerId,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        firstName: null,
        lastName: null,
        email: null,
        contactNumber: null,
        addressLine: null,
        city: null,
        state: null,
        country: null,
        pincode: null,
        userId: userData.user_id,
      });

      if (!result.success || !result.data || result.data.length === 0) {
        return {
          success: false,
          message: "Customer not found",
          data: null,
        };
      }

      // Find the specific customer
      const customer = result.data.find((c) => c.customer_id === customerId);
      if (!customer) {
        return {
          success: false,
          message: "Customer not found",
          data: null,
        };
      }

      return {
        success: true,
        message: "Customer retrieved successfully",
        data: { customer },
      };
    } catch (error) {
      logger.error("CustomerService.getCustomer error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== LIST CUSTOMERS ========================
  async listCustomers(userData, paginationParams = {}) {
    try {
      const result = await customersRepository.manageCustomer({
        action: 5, // Get List Based On Role
        customerId: null,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        firstName: null,
        lastName: null,
        email: null,
        contactNumber: null,
        addressLine: null,
        city: null,
        state: null,
        country: null,
        pincode: null,
        userId: userData.user_id,
      });

      // Apply pagination on the result
      const allCustomers = result.data || [];
      const total = allCustomers.length;
      const page = paginationParams.page || 1;
      const limit = paginationParams.limit || 50;
      const totalPages = Math.ceil(total / limit);
      const startIndex = (page - 1) * limit;
      const endIndex = startIndex + limit;
      const paginatedCustomers = allCustomers.slice(startIndex, endIndex);

      return {
        success: result.success,
        message: result.message,
        data: {
          customers: paginatedCustomers,
          pagination: {
            page: page,
            limit: limit,
            total: total,
            total_pages: totalPages,
            has_next: page < totalPages,
            has_prev: page > 1,
          },
        },
      };
    } catch (error) {
      logger.error("CustomerService.listCustomers error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== DELETE CUSTOMER ========================
  async deleteCustomer(customerId, userData) {
    try {
      const result = await customersRepository.manageCustomer({
        action: 3, // Delete
        customerId: customerId,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        firstName: null,
        lastName: null,
        email: null,
        contactNumber: null,
        addressLine: null,
        city: null,
        state: null,
        country: null,
        pincode: null,
        userId: userData.user_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success ? { customer_id: customerId } : null,
      };
    } catch (error) {
      logger.error("CustomerService.deleteCustomer error", {
        error: error.message,
      });
      throw error;
    }
  }
}

module.exports = new CustomerService();