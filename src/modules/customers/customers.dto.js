// src/modules/customers/customers.dto.js



class CustomerCreateDTO {
    constructor(data) {
        this.business_id = data.businessId;
        this.branch_id = data.branchId;
        this.first_name = data.firstName;
        this.last_name = data.lastName;
        this.email = data.email;
        this.contact_number = data.contactNumber;
        this.address_line = data.addressLine;
        this.city = data.city;
        this.state = data.state;
        this.country = data.country;
        this.postal_code = data.pincode;
    }
}


module.exports = {
    CustomerCreateDTO,
};