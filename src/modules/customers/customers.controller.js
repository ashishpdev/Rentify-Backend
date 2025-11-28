//  src/modules/customers/customers.controller.js
const ResponseUtil = require("../../utils/response.util");
const logger = require("../../config/logger.config");
const TokenUtil = require("../../utils/token.util");
const SessionValidator = require("../../middlewares/session-validator.middleware");
const { CustomerValidator } = require("./customers.validator");

class CustomerController {

    async createCustomer(req, res, next) {
        try {

            const { error, value } = CustomerValidator.validateCreateCustomer(req.body);
            console.log(error, value);
            res.send("Customer created");
            

        } catch (error) {
            logger.logError(error, req, {
                operation: "sendOTP",
                email: req.body.email,
            });
            next(error);
        }

    }
}


module.exports = new CustomerController();
