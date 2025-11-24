// API documentation configuration
const swaggerUi = require("swagger-ui-express");
const swaggerDocument = require("../../docs/api/swagger.json");

module.exports = (app) => {
  // Configure Swagger UI options
  const options = {
    explorer: true,
    customCss: ".swagger-ui .topbar { display: none }",
    customSiteTitle: "Rentify API Documentation",
  };

  app.use("/docs", swaggerUi.serve, swaggerUi.setup(swaggerDocument, options));
};
