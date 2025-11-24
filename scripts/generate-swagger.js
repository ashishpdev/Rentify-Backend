const swaggerAutogen = require("swagger-autogen")();

const outputFile = "./docs/api/swagger.json";
const endpointsFiles = ["./src/app.js"]; // OR your central router

swaggerAutogen(outputFile, endpointsFiles).then(() => {
  console.log("Swagger file generated.");
});
