// src/modules/customers/customers.service.js

const customersRepository = require("./customers.repository");

class CustomerService {

    async createCustomer(customerData, userData) {
        const result = await customersRepository.manageCustomer({
            action: 1, // Create
            customerId: null,
            businessId: userData.business_id,
            branchId: userData.branch_id,
            firstName: customerData.firstName,
            lastName: customerData.lastName,
            email: customerData.email,
            contactNumber: customerData.contactNumber,
            addressLine: customerData.addressLine,
            city: customerData.city,
            state: customerData.state,
            country: customerData.country,
            pincode: customerData.pincode,
            user: userData.user_id,
            roleUser: userData.user_id
        });

        if (!result.success) {
            throw new Error(result.message);
        }

        return { message: result.message };
    }

    async updateCustomer(customerId, customerData, userData) {
        const result = await customersRepository.manageCustomer({
            action: 2, // Update
            customerId: parseInt(customerId),
            businessId: userData.business_id,
            branchId: userData.branch_id,
            firstName: customerData.firstName,
            lastName: customerData.lastName,
            email: customerData.email,
            contactNumber: customerData.contactNumber,
            addressLine: customerData.addressLine,
            city: customerData.city,
            state: customerData.state,
            country: customerData.country,
            pincode: customerData.pincode,
            user: userData.user_id,
            roleUser: userData.user_id
        });

        if (!result.success) {
            throw new Error(result.message);
        }

        return { message: result.message };
    }

    async getCustomer(customerId, userData) {
        const result = await customersRepository.manageCustomer({
            action: 4, // Get List (filtered by customer_id in repo)
            customerId: parseInt(customerId),
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
            user: userData.user_id,
            roleUser: userData.user_id
        });

        if (result.data && result.data.length > 0) {
            const customer = result.data.find(c => c.customer_id === parseInt(customerId));
            if (customer) {
                return { customer };
            }
        }

        throw new Error('Customer not found');
    }

    async getAllCustomers(userData) {
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
            user: userData.user_id,
            roleUser: userData.user_id
        });

        return { customers: result.data || [] };
    }

    async deleteCustomer(customerId, userData) {
        const result = await customersRepository.manageCustomer({
            action: 3, // Delete
            customerId: parseInt(customerId),
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
            user: userData.user_id,
            roleUser: userData.user_id
        });

        if (!result.success) {
            throw new Error(result.message);
        }

        return { message: result.message };
    }
}

module.exports = new CustomerService();