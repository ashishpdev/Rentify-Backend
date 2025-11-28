// src/modules/customers/customers.repository.js
const dbConnection = require("../../database/connection");

class CustomerRepository {

    async createCustomer(customerDTO) {
        const pool = dbConnection.getMasterPool();
        const connection = await pool.getConnection();

        try {
            // Call stored procedure with correct parameters
            const [result] = await connection.query(
                `CALL sp_customer_manage(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
                [
                    1,                          // p_action (1 = Create)
                    null,                       // p_customer_id (null for create)
                    customerDTO.business_id,    // p_business_id
                    customerDTO.branch_id,      // p_branch_id
                    customerDTO.first_name,     // p_first_name
                    customerDTO.last_name,      // p_last_name
                    customerDTO.email,          // p_email
                    customerDTO.contact_number, // p_contact_number
                    customerDTO.address_line,   // p_address_line
                    customerDTO.city,           // p_city
                    customerDTO.state,          // p_state
                    customerDTO.country,        // p_country
                    customerDTO.postal_code,    // p_pincode
                    customerDTO.created_by,     // p_user (created_by)
                    customerDTO.role_user       // p_role_user (not needed for create)
                ]
            );

            connection.release();

            // Extract the result message from stored procedure
            const response = result[0]?.[0];
            console.log("RESPONSE>>>", response);
            
            return {
                success: true,
                message: response.message || 'Customer created successfully',
            };

        } catch (error) {
            connection.release();
            throw error;
        }
    }
}


module.exports = new CustomerRepository();