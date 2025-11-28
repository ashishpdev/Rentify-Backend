// src/modules/customers/customers.validator.js
const Joi = require("joi");

/**
 * Export Joi schema objects so we can reuse them to generate docs.
 * Keep the validate* helpers for runtime validation.
 */


const createCustomerSchema = Joi.object({
    businessId: Joi.number().integer().positive().required().messages({
        'number.base': 'Business ID must be a number',
        'number.integer': 'Business ID must be an integer',
        'any.required': 'Business ID is required'
    }),

    branchId: Joi.number().integer().positive().required().messages({
        'number.base': 'Branch ID must be a number',
        'number.integer': 'Branch ID must be an integer',
        'any.required': 'Branch ID is required'
    }),

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

    contactNumber: Joi.string().pattern(/^[0-9+\-()\s]{7,20}$/).required().messages({
        'string.pattern.base': 'Contact number must be 7-20 characters and contain only digits, spaces, +, - or ()',
        'any.required': 'Contact number is required'
    }),

    addressLine: Joi.string().max(255).required().messages({
        'string.base': 'Address must be text',
        'string.max': 'Address must be at most 255 characters',
        'any.required': 'Address is required'
    }),

    city: Joi.string().max(100).required().messages({
        'string.base': 'City must be text',
        'string.max': 'City must be at most 100 characters',
        'any.required': 'City is required'
    }),

    state: Joi.string().max(100).required().messages({
        'string.base': 'State must be text',
        'string.max': 'State must be at most 100 characters',
        'any.required': 'State is required'
    }),

    country: Joi.string().max(100).required().messages({
        'string.base': 'Country must be text',
        'string.max': 'Country must be at most 100 characters',
        'any.required': 'Country is required'
    }),

    pincode: Joi.string().max(20).required().messages({
        'string.base': 'Pincode must be text',
        'string.max': 'Pincode must be at most 20 characters',
        'any.required': 'Pincode is required'
    }),

    created_by: Joi.number().integer().positive().required().messages({
        'number.base': 'Created by ID must be a number',
        'number.integer': 'Created by ID must be an integer',
        'any.required': 'Created by ID is required'
    }),

    // Control fields (optional/managed by system)
    created_at: Joi.date().iso().optional(),
    updated_by: Joi.string().max(255).optional().allow(null, ''),
    updated_at: Joi.date().iso().optional(),
    deleted_at: Joi.date().iso().optional(),
    is_active: Joi.boolean().optional().default(true),
    is_deleted: Joi.number().valid(0, 1).optional().default(0)
});


class CustomerValidator {
    static validateCreateCustomer(data) {
        return createCustomerSchema.validate(data);
    }
}


module.exports =
{
    CustomerValidator,
    schemas: {
        createCustomerSchema
    }
};