const swaggerAutogen = require("swagger-autogen")();
const fs = require("fs");
const path = require("path");
const joiToSwagger = require("joi-to-swagger");

const outputFile = "./docs/api/swagger.json";
const endpointsFiles = ["./src/routes/index.js"];

const doc = {
  info: {
    version: "1.0.0",
    title: "Rentify API",
    description:
      "Rentify is a tech rental platform API that allows users to rent electronic devices like mobile phones, laptops, tablets, cameras, gaming consoles, and accessories for short-term or long-term use.",
  },
  host: "localhost:3000",
  basePath: "/api",
  schemes: ["http", "https"],
  consumes: ["application/json"],
  produces: ["application/json"],
  tags: [
    {
      name: "Health",
      description: "Health check endpoints",
    },
    {
      name: "Authentication",
      description:
        "Authentication endpoints for OTP-based registration and login",
    },
    {
      name: "Business",
      description: "Business management endpoints",
    },
    {
      name: "Customers",
      description: "Customer management endpoints",
    },
    {
      name: "Inventory",
      description: "Inventory management endpoints",
    },
    {
      name: "Products",
      description: "Product management endpoints",
    },
    {
      name: "Rentals",
      description: "Rental management endpoints",
    },
    {
      name: "Maintenance",
      description: "Maintenance management endpoints",
    },
    {
      name: "Notifications",
      description: "Notification endpoints",
    },
  ],
  definitions: {}, // we'll fill from Joi schemas
};

(async () => {
  // load Joi schemas exported from validators
  // adjust paths to where your validators live
  const {
    schemas: authSchemas,
  } = require("../src/modules/auth/auth.validator");

  // convert Joi -> OpenAPI (swagger) using joi-to-swagger
  const convertedAuth = {
    SendOTPRequest: joiToSwagger(authSchemas.sendOTPSchema).swagger,
    VerifyOTPRequest: joiToSwagger(authSchemas.verifyOTPSchema).swagger,
    CompleteRegistrationRequest: joiToSwagger(
      authSchemas.completeRegistrationSchema
    ).swagger,
    // add more conversions for other modules here...
  };

  // attach to doc.definitions
  doc.definitions = {
    ...doc.definitions,
    ...convertedAuth,
    // add any shared response objects (SuccessResponse, ErrorResponse) manually if you like
    SuccessResponse: {
      type: "object",
      properties: {
        success: { type: "boolean", example: true },
        message: {
          type: "string",
          example: "Operation completed successfully",
        },
        data: { type: "object" },
      },
    },
    ErrorResponse: {
      type: "object",
      properties: {
        success: { type: "boolean", example: false },
        message: { type: "string", example: "Error occurred" },
        error: { type: "string" },
      },
    },
  };

  await swaggerAutogen(outputFile, endpointsFiles, doc);
  console.log(
    "✅ Swagger documentation generated successfully!," + " At :" + outputFile
  );
})();
