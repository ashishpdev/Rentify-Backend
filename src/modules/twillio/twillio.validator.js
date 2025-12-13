// modules/twillio/twillio.validator.js
const Joi = require("joi");

class TwillioValidator {
    static validateSendMessage(body) {
        const schema = Joi.object({
            to: Joi.string()
                .pattern(/^\+\d+$/)
                .required()
                .messages({
                    "string.pattern.base": "Phone number must be in E.164 format (e.g., +919898989898)",
                }),

            message: Joi.string().min(1).max(2000).required(),
        });

        return schema.validate(body);
    }
}

module.exports = { TwillioValidator };
