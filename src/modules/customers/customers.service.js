// src/modules/customers/customers.service.js

const customersRepository = require("./customers.repository");


class CustomerService {
    // Business logic for customer management can be added here
    async createCustomer(customerDTO) {
        try {
            // Call repository to create customer
            const result = await customersRepository.createCustomer(customerDTO);

            if (!result || !result.success) {
                throw new Error('Failed to create customer');
            }

            return {
                message: result.message,
                customer: {
                    first_name: customerDTO.first_name,
                    last_name: customerDTO.last_name,
                    email: customerDTO.email,
                    contact_number: customerDTO.contact_number
                }
            };
        } catch (error) {
            // Re-throw with service context
            if (error.message.includes('already exists')) {
                throw new Error(`Duplicate customer: ${error.message}`);
            }
            if (error.message.includes('Database')) {
                throw new Error(`Database error: ${error.message}`);
            }
            throw new Error(`Customer service error: ${error.message}`);
        }
    }
}

module.exports = new CustomerService();