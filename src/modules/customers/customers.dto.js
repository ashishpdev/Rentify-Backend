// src/modules/customers/customers.dto.js



class CustomerCreateDTO {
    constructor(data, userData) {
        this.business_id = userData.business_id;
        this.branch_id = userData.branch_id;
        this.first_name = data.firstName;
        this.last_name = data.lastName;
        this.email = data.email;
        this.contact_number = data.contactNumber;
        this.address_line = data.addressLine;
        this.city = data.city;
        this.state = data.state;
        this.country = data.country;
        this.postal_code = data.pincode;
        this.created_by = userData.user_id // User who created this customer
        this.role_user = userData.user_id // Role user ID (not needed for create)
    }
}


module.exports = {
    CustomerCreateDTO,
};