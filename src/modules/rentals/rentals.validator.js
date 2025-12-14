// src/modules/rentals/rentals.validator.js
const Joi = require("joi");

// Schema for creating/issuing a new rental
const issueRentalSchema = Joi.object({
  customer_id: Joi.number().integer().positive().required().messages({
    "number.base": "Customer ID must be a number",
    "number.positive": "Customer ID must be positive",
    "any.required": "Customer ID is required",
  }),
  invoice_url: Joi.string().uri().allow(null, "").optional().messages({
    "string.base": "Invoice URL must be text",
    "string.uri": "Invoice URL must be a valid URI",
  }),
  invoice_no: Joi.string().min(1).max(255).required().messages({
    "string.base": "Invoice number must be text",
    "string.min": "Invoice number must be at least 1 character",
    "string.max": "Invoice number must be at most 255 characters",
    "any.required": "Invoice number is required",
  }),
  start_date: Joi.date().iso().required().messages({
    "date.base": "Start date must be a valid date",
    "date.format": "Start date must be in ISO format",
    "any.required": "Start date is required",
  }),
  due_date: Joi.date().iso().min(Joi.ref("start_date")).required().messages({
    "date.base": "Due date must be a valid date",
    "date.format": "Due date must be in ISO format",
    "date.min": "Due date must be after start date",
    "any.required": "Due date is required",
  }),
  billing_period_id: Joi.number().integer().positive().required().messages({
    "number.base": "Billing period ID must be a number",
    "number.positive": "Billing period ID must be positive",
    "any.required": "Billing period ID is required",
  }),
  asset_ids: Joi.array()
    .items(Joi.number().integer().positive())
    .min(1)
    .required()
    .messages({
      "array.base": "Asset IDs must be an array",
      "array.min": "At least one asset ID is required",
      "any.required": "Asset IDs are required",
    }),
  total_items: Joi.number().integer().min(0).required().default(0).messages({
    "number.base": "Total items must be a number",
    "number.min": "Total items must be at least 0",
    "any.required": "Total items is required",
  }),
  security_deposit: Joi.number()
    .precision(2)
    .min(0)
    .required()
    .default(0)
    .messages({
      "number.base": "Security deposit must be a number",
      "number.min": "Security deposit must be at least 0",
      "any.required": "Security deposit is required",
    }),
  subtotal_amount: Joi.number()
    .precision(2)
    .min(0)
    .required()
    .default(0)
    .messages({
      "number.base": "Subtotal amount must be a number",
      "number.min": "Subtotal amount must be at least 0",
      "any.required": "Subtotal amount is required",
    }),
  tax_amount: Joi.number().precision(2).min(0).required().default(0).messages({
    "number.base": "Tax amount must be a number",
    "number.min": "Tax amount must be at least 0",
    "any.required": "Tax amount is required",
  }),
  discount_amount: Joi.number()
    .precision(2)
    .min(0)
    .required()
    .default(0)
    .messages({
      "number.base": "Discount amount must be a number",
      "number.min": "Discount amount must be at least 0",
      "any.required": "Discount amount is required",
    }),
  total_amount: Joi.number()
    .precision(2)
    .min(0)
    .required()
    .default(0)
    .messages({
      "number.base": "Total amount must be a number",
      "number.min": "Total amount must be at least 0",
      "any.required": "Total amount is required",
    }),
  paid_amount: Joi.number().precision(2).min(0).required().default(0).messages({
    "number.base": "Paid amount must be a number",
    "number.min": "Paid amount must be at least 0",
    "any.required": "Paid amount is required",
  }),
  reference_no: Joi.string().max(255).allow(null, "").optional().messages({
    "string.base": "Reference number must be text",
    "string.max": "Reference number must be at most 255 characters",
  }),
  notes: Joi.string().max(2000).allow(null, "").optional().messages({
    "string.base": "Notes must be text",
    "string.max": "Notes must be at most 2000 characters",
  }),
});

// Schema for getting a single rental
const getRentalSchema = Joi.object({
  rental_id: Joi.number().integer().positive().required().messages({
    "number.base": "Rental ID must be a number",
    "number.positive": "Rental ID must be positive",
    "any.required": "Rental ID is required",
  }),
});

// Schema for listing rentals with filters
const listRentalsSchema = Joi.object({
  customer_id: Joi.number().integer().positive().optional(),
  product_rental_status_id: Joi.number().integer().positive().optional(),
  is_overdue: Joi.boolean().optional(),
  start_date_from: Joi.date().iso().optional(),
  start_date_to: Joi.date().iso().optional(),
  page: Joi.number().integer().positive().optional().default(1),
  limit: Joi.number().integer().positive().max(100).optional().default(50),
});

// Schema for updating rental
const updateRentalSchema = Joi.object({
  rental_id: Joi.number().integer().positive().required().messages({
    "number.base": "Rental ID must be a number",
    "number.positive": "Rental ID must be positive",
    "any.required": "Rental ID is required",
  }),
  due_date: Joi.date().iso().optional().messages({
    "date.base": "Due date must be a valid date",
    "date.format": "Due date must be in ISO format",
  }),
  notes: Joi.string().max(2000).allow(null, "").optional().messages({
    "string.base": "Notes must be text",
    "string.max": "Notes must be at most 2000 characters",
  }),
  product_rental_status_id: Joi.number().integer().positive().optional(),
});

// Schema for returning rental items
const returnRentalSchema = Joi.object({
  rental_id: Joi.number().integer().positive().required().messages({
    "number.base": "Rental ID must be a number",
    "number.positive": "Rental ID must be positive",
    "any.required": "Rental ID is required",
  }),
  end_date: Joi.date().iso().required().messages({
    "date.base": "End date must be a valid date",
    "date.format": "End date must be in ISO format",
    "any.required": "End date is required",
  }),
  notes: Joi.string().max(2000).allow(null, "").optional().messages({
    "string.base": "Notes must be text",
    "string.max": "Notes must be at most 2000 characters",
  }),
});

// Schema for recording payment
const recordPaymentSchema = Joi.object({
  rental_id: Joi.number().integer().positive().required().messages({
    "number.base": "Rental ID must be a number",
    "number.positive": "Rental ID must be positive",
    "any.required": "Rental ID is required",
  }),
  amount: Joi.number().precision(2).positive().required().messages({
    "number.base": "Amount must be a number",
    "number.positive": "Amount must be positive",
    "any.required": "Amount is required",
  }),
  mode_of_payment_id: Joi.number().integer().positive().required().messages({
    "number.base": "Payment mode ID must be a number",
    "number.positive": "Payment mode ID must be positive",
    "any.required": "Payment mode ID is required",
  }),
  reference_no: Joi.string().max(255).allow(null, "").optional().messages({
    "string.base": "Reference number must be text",
    "string.max": "Reference number must be at most 255 characters",
  }),
  notes: Joi.string().max(2000).allow(null, "").optional().messages({
    "string.base": "Notes must be text",
    "string.max": "Notes must be at most 2000 characters",
  }),
});

// Schema for getting rental payments
const getRentalPaymentsSchema = Joi.object({
  rental_id: Joi.number().integer().positive().required().messages({
    "number.base": "Rental ID must be a number",
    "number.positive": "Rental ID must be positive",
    "any.required": "Rental ID is required",
  }),
});

class RentalValidator {
  static validateIssueRental(data) {
    return issueRentalSchema.validate(data);
  }

  static validateGetRental(data) {
    return getRentalSchema.validate(data);
  }

  static validateListRentals(data) {
    return listRentalsSchema.validate(data);
  }

  static validateUpdateRental(data) {
    return updateRentalSchema.validate(data);
  }

  static validateReturnRental(data) {
    return returnRentalSchema.validate(data);
  }

  static validateRecordPayment(data) {
    return recordPaymentSchema.validate(data);
  }

  static validateGetRentalPayments(data) {
    return getRentalPaymentsSchema.validate(data);
  }
}

module.exports = {
  RentalValidator,
  schemas: {
    issueRentalSchema,
    getRentalSchema,
    listRentalsSchema,
    updateRentalSchema,
    returnRentalSchema,
    recordPaymentSchema,
    getRentalPaymentsSchema,
  },
};
