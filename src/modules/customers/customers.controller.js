//  src/modules/customers/customers.controller.js
const ResponseUtil = require("../../utils/response.util");
const logger = require("../../config/logger.config");
const { CustomerValidator } = require("./customers.validator");
const { CustomerCreateDTO } = require("./customers.dto");
const customersService = require("./customers.service");

class CustomerController {

    async createCustomer(req, res, next) {
        try {

            const { error, value } = CustomerValidator.validateCreateCustomer(req.body);
            if (error) {
                logger.warn("Customer creation validation failed", {
                    email: req.body.email,
                    error: error.details[0].message,
                });
                return ResponseUtil.badRequest(res, error.details[0].message);
            }

            const dto = new CustomerCreateDTO(value, req.user);
            const result = await customersService.createCustomer(dto);
            
            return ResponseUtil.success(res, result);


        } catch (error) {
            logger.logError(error, req, {
                operation: "createCustomer",
                email: req.body.email,
            });
            next(error);
        }

    }
}


module.exports = new CustomerController();
