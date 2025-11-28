// src/modules/customers/customers.repository.js
const dbConnection = require("../../database/connection");

class CustomerRepository {

    async createCustomer(customerDTO) {
        // Placeholder for creating a customer in the database
        try {
            const pool = dbConnection.getMasterPool();
            const connection = await pool.getConnection();


            await connection.query(
                `CALL sp_customer_manage(1,NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, @p_error_message)`,
                [
                    customerDTO.businessId, // business_id
                    customerDTO.branchId,   // branch_id
                    customerDTO.firstName,  // first_name
                    customerDTO.lastName,   // last_name
                    customerDTO.email,      // email
                    customerDTO.contactNumber, // contact_number
                    customerDTO.addressLine,   // address_line
                    customerDTO.city,          // city
                    customerDTO.state,         // state
                    customerDTO.country,       // country
                    customerDTO.pincode       // postal_code
                ]
            );

        } catch (error) {

        }
    }
}


module.exports = new CustomerRepository();