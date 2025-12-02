// src/modules/customers/customers.validator.js
const Joi = require("joi");

const createCustomerSchema = Joi.object({
    firstName: Joi.string().min(2).max(200).required().messages({
        'string.base': 'First name must be text',
        'string.min': 'First name must be at least 2 characters',
        'string.max': 'First name must be at most 200 characters',
        'any.required': 'First name is required'
    }),
    lastName: Joi.string().max(200).allow(null, '').optional().messages({
        'string.base': 'Last name must be text',
        'string.max': 'Last name must be at most 200 characters'
    }),
    email: Joi.string().email().max(255).required().messages({
        'string.email': 'Provide a valid email address',
        'string.max': 'Email must be at most 255 characters',
        'any.required': 'Email is required'
    }),
    contactNumber: Joi.string().pattern(/^[0-9+\-()\s]{7,13}$/).required().messages({
        'string.pattern.base': 'Contact number must be 7-13 characters and contain only digits, spaces, +, - or ()',
        'any.required': 'Contact number is required'
    }),
    addressLine: Joi.string().max(255).allow(null, '').optional(),
    city: Joi.string().max(100).allow(null, '').optional(),
    state: Joi.string().max(100).allow(null, '').optional(),
    country: Joi.string().max(100).allow(null, '').optional(),
    pincode: Joi.string().max(20).allow(null, '').optional()
});

const updateCustomerSchema = Joi.object({
    firstName: Joi.string().min(2).max(200).optional().messages({
        'string.base': 'First name must be text',
        'string.min': 'First name must be at least 2 characters',
        'string.max': 'First name must be at most 200 characters'
    }),
    lastName: Joi.string().max(200).allow(null, '').optional(),
    email: Joi.string().email().max(255).optional().messages({
        'string.email': 'Provide a valid email address',
        'string.max': 'Email must be at most 255 characters'
    }),
    contactNumber: Joi.string().pattern(/^[0-9+\-()\s]{7,13}$/).optional().messages({
        'string.pattern.base': 'Contact number must be 7-13 characters and contain only digits, spaces, +, - or ()'
    }),
    addressLine: Joi.string().max(255).allow(null, '').optional(),
    city: Joi.string().max(100).allow(null, '').optional(),
    state: Joi.string().max(100).allow(null, '').optional(),
    country: Joi.string().max(100).allow(null, '').optional(),
    pincode: Joi.string().max(20).allow(null, '').optional()
});

const getCustomerSchema = Joi.object({
    customerId: Joi.number().integer().positive().required().messages({
        'number.base': 'Customer ID must be a number',
        'number.positive': 'Customer ID must be positive',
        'any.required': 'Customer ID is required'
    })
});

const deleteCustomerSchema = Joi.object({
    customerId: Joi.number().integer().positive().required().messages({
        'number.base': 'Customer ID must be a number',
        'number.positive': 'Customer ID must be positive',
        'any.required': 'Customer ID is required'
    })
});

class CustomerValidator {
    static validateCreateCustomer(data) {
        return createCustomerSchema.validate(data);
    }

    static validateUpdateCustomer(data) {
        return updateCustomerSchema.validate(data);
    }

    static validateGetCustomer(data) {
        return getCustomerSchema.validate(data);
    }

    static validateDeleteCustomer(data) {
        return deleteCustomerSchema.validate(data);
    }
}

module.exports = {
    CustomerValidator,
    schemas: {
        createCustomerSchema,
        updateCustomerSchema,
        getCustomerSchema,
        deleteCustomerSchema
    }
};