// src/modules/customers/customers.repository.js
const dbConnection = require("../../database/connection");

class CustomerRepository {

    async manageCustomer(params) {
        const pool = dbConnection.getMasterPool();
        const connection = await pool.getConnection();

        try {
            const [result] = await connection.query(
                `CALL sp_manage_customer(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
                [
                    params.action,
                    params.customerId,
                    params.businessId,
                    params.branchId,
                    params.firstName,
                    params.lastName,
                    params.email,
                    params.contactNumber,
                    params.addressLine,
                    params.city,
                    params.state,
                    params.country,
                    params.pincode,
                    params.user,
                    params.roleUser
                ]
            );

            connection.release();

            // For GET actions (4, 5), return the data array
            if (params.action === 4 || params.action === 5) {
                return {
                    success: true,
                    data: result[0] || []
                };
            }

            // For CUD actions (1, 2, 3), return message and success
            const response = result[0]?.[0];
            return {
                success: response?.success ?? false,
                message: response?.message || 'Operation completed'
            };

        } catch (error) {
            connection.release();
            throw error;
        }
    }
}

module.exports = new CustomerRepository();