/**
 * scripts/generate-postman-from-routes.js
 *
 * Enhanced Postman collection generator that:
 * - Properly resolves route paths by tracing from main router
 * - Accurately infers request bodies from Joi validators
 * - Organizes endpoints by module structure
 * - Generates industry-standard Postman collections
 *
 * Usage:
 *   node scripts/generate-postman-from-routes.js
 *
 * Environment Variables:
 *   BASE_URL (default: http://localhost:3000)
 *   API_PREFIX (default: /api)
 *   SRC_DIR (default: ./src)
 */

const fs = require("fs-extra");
const path = require("path");
const parser = require("@babel/parser");
const traverse = require("@babel/traverse").default;

// Configuration
const PROJECT_ROOT = path.resolve(__dirname, "..");
const SRC_DIR = process.env.SRC_DIR || path.join(PROJECT_ROOT, "src");
const BASE_URL = process.env.BASE_URL || "http://localhost:3000";
const API_PREFIX = process.env.API_PREFIX || "/api";
const OUTPUT_FILE = path.join(
  PROJECT_ROOT,
  "docs",
  "api",
  "Rentify-postman.json"
);

// Utility: Read file safely
function readFile(filePath) {
  try {
    return fs.readFileSync(filePath, "utf8");
  } catch (error) {
    console.warn(`Could not read file: ${filePath}`);
    return null;
  }
}

// Utility: Parse code to AST
function parseToAST(code, filePath) {
  try {
    return parser.parse(code, {
      sourceType: "unambiguous",
      plugins: [
        "jsx",
        "flow",
        "classProperties",
        "dynamicImport",
        "optionalChaining",
        "objectRestSpread",
      ],
    });
  } catch (error) {
    console.warn(`Parse error in ${filePath}:`, error.message);
    return null;
  }
}

// Utility: Resolve require/import path to actual file
function resolveModulePath(currentFile, importPath) {
  if (!importPath || !importPath.startsWith(".")) {
    return null; // External module
  }

  const baseDir = path.dirname(currentFile);
  let resolved = path.resolve(baseDir, importPath);

  // Try exact path
  if (fs.existsSync(resolved) && fs.statSync(resolved).isFile()) {
    return resolved;
  }

  // Try with .js extension
  if (fs.existsSync(resolved + ".js")) {
    return resolved + ".js";
  }

  // Try index.js in directory
  const indexPath = path.join(resolved, "index.js");
  if (fs.existsSync(indexPath)) {
    return indexPath;
  }

  return null;
}

// Extract imports/requires from a file
function extractImports(ast) {
  const imports = {};

  traverse(ast, {
    // Handle: const x = require('./path')
    VariableDeclarator({ node }) {
      if (
        node.init &&
        node.init.type === "CallExpression" &&
        node.init.callee.name === "require" &&
        node.init.arguments.length > 0 &&
        node.init.arguments[0].type === "StringLiteral"
      ) {
        const varName = node.id.name;
        const modulePath = node.init.arguments[0].value;
        imports[varName] = modulePath;
      }
    },
    // Handle: import x from './path'
    ImportDeclaration({ node }) {
      const modulePath = node.source.value;
      node.specifiers.forEach((spec) => {
        if (spec.local) {
          imports[spec.local.name] = modulePath;
        }
      });
    },
  });

  return imports;
}

// Extract router.use() calls from main router
function extractRouterMounts(filePath) {
  const code = readFile(filePath);
  if (!code) return [];

  const ast = parseToAST(code, filePath);
  if (!ast) return [];

  const imports = extractImports(ast);
  const mounts = [];

  traverse(ast, {
    // Look for router.use('/path', routerVariable)
    CallExpression({ node }) {
      if (
        node.callee.type === "MemberExpression" &&
        node.callee.object.name === "router" &&
        node.callee.property.name === "use" &&
        node.arguments.length >= 2
      ) {
        const pathArg = node.arguments[0];
        const routerArg = node.arguments[1];

        if (
          pathArg.type === "StringLiteral" &&
          routerArg.type === "Identifier"
        ) {
          const mountPath = pathArg.value;
          const routerVar = routerArg.name;
          const modulePath = imports[routerVar];

          if (modulePath) {
            mounts.push({
              mountPath,
              routerVar,
              modulePath,
            });
          }
        }
      }
    },
  });

  return mounts;
}

// Extract individual routes from a route file
function extractRoutes(filePath) {
  const code = readFile(filePath);
  if (!code) return [];

  const ast = parseToAST(code, filePath);
  if (!ast) return [];

  const imports = extractImports(ast);
  const routes = [];

  traverse(ast, {
    // Look for router.get/post/put/delete/patch(path, ...handlers)
    CallExpression({ node }) {
      if (
        node.callee.type === "MemberExpression" &&
        node.callee.object.name === "router" &&
        node.callee.property.type === "Identifier"
      ) {
        const method = node.callee.property.name.toLowerCase();
        const validMethods = ["get", "post", "put", "delete", "patch"];

        if (validMethods.includes(method) && node.arguments.length >= 2) {
          const pathArg = node.arguments[0];

          if (pathArg.type === "StringLiteral") {
            const routePath = pathArg.value;
            const lastArg = node.arguments[node.arguments.length - 1];

            let handler = null;
            let controllerName = null;
            let methodName = null;

            // Extract handler information
            if (lastArg.type === "MemberExpression") {
              // e.g., authController.sendOTP
              controllerName = lastArg.object.name;
              methodName = lastArg.property.name;
              handler = `${controllerName}.${methodName}`;
            } else if (lastArg.type === "Identifier") {
              handler = lastArg.name;
              methodName = lastArg.name;
            } else if (
              lastArg.type === "ArrowFunctionExpression" ||
              lastArg.type === "FunctionExpression"
            ) {
              handler = "<inline>";
            }

            routes.push({
              method: method.toUpperCase(),
              path: routePath,
              handler,
              controllerName,
              methodName,
              imports,
            });
          }
        }
      }
    },
  });

  return routes;
}

// Find validator file for a controller
function findValidatorFile(controllerFilePath) {
  const dir = path.dirname(controllerFilePath);
  const baseName = path.basename(controllerFilePath, ".controller.js");

  // Try common validator file patterns
  const patterns = [
    path.join(dir, `${baseName}.validator.js`),
    path.join(dir, `${baseName}.validation.js`),
    path.join(dir, "validators.js"),
  ];

  for (const pattern of patterns) {
    if (fs.existsSync(pattern)) {
      return pattern;
    }
  }

  return null;
}

// Extract Joi schemas from validator file
function extractJoiSchemas(validatorFilePath) {
  const code = readFile(validatorFilePath);
  if (!code) return {};

  const ast = parseToAST(code, validatorFilePath);
  if (!ast) return {};

  const schemas = {};

  traverse(ast, {
    // Look for: const schemaName = Joi.object({...})
    VariableDeclarator({ node }) {
      if (
        node.id.type === "Identifier" &&
        node.init &&
        node.init.type === "CallExpression" &&
        node.init.callee.type === "MemberExpression" &&
        node.init.callee.object.name === "Joi" &&
        node.init.callee.property.name === "object"
      ) {
        const schemaName = node.id.name;
        const schemaObj = node.init.arguments[0];

        if (schemaObj && schemaObj.type === "ObjectExpression") {
          schemas[schemaName] = parseJoiObject(schemaObj);
        }
      }
    },
  });

  return schemas;
}

// Parse Joi.object() definition to generate example
function parseJoiObject(objectExpression) {
  const example = {};

  if (!objectExpression || objectExpression.type !== "ObjectExpression") {
    return example;
  }

  objectExpression.properties.forEach((prop) => {
    if (prop.type === "ObjectProperty") {
      const key = prop.key.name || prop.key.value;
      const value = parseJoiChain(prop.value);
      example[key] = value;
    }
  });

  return example;
}

// Parse Joi validation chain (e.g., Joi.string().email().required())
function parseJoiChain(node) {
  const chain = [];
  let current = node;

  // Walk through the call chain
  while (current) {
    if (current.type === "CallExpression") {
      if (current.callee.type === "MemberExpression") {
        const methodName = current.callee.property.name;
        const args = current.arguments || [];
        chain.push({ method: methodName, args });
        current = current.callee.object;
      } else {
        break;
      }
    } else if (current.type === "MemberExpression") {
      const propName = current.property.name;
      chain.push({ method: propName, args: [] });
      current = current.object;
    } else if (current.type === "Identifier") {
      chain.push({ method: current.name, args: [] });
      break;
    } else {
      break;
    }
  }

  chain.reverse(); // Base type first

  // Determine base type and modifiers
  let baseType = null;
  let defaultValue = undefined;
  let validValues = [];
  let hasEmail = false;
  let hasPattern = false;
  let isRequired = false;

  for (const { method, args } of chain) {
    // Base types
    if (
      ["string", "number", "integer", "boolean", "array", "object"].includes(
        method
      )
    ) {
      baseType = method;
    }

    // Modifiers
    if (method === "default" && args.length > 0) {
      const arg = args[0];
      if (arg.type === "StringLiteral") defaultValue = arg.value;
      else if (arg.type === "NumericLiteral") defaultValue = arg.value;
      else if (arg.type === "BooleanLiteral") defaultValue = arg.value;
    }

    if (method === "valid" && args.length > 0) {
      args.forEach((arg) => {
        if (arg.type === "StringLiteral") validValues.push(arg.value);
        else if (arg.type === "NumericLiteral") validValues.push(arg.value);
      });
    }

    if (method === "email") hasEmail = true;
    if (method === "pattern") hasPattern = true;
    if (method === "required") isRequired = true;
  }

  // Generate example value
  if (validValues.length > 0) return validValues[0];
  if (defaultValue !== undefined) return defaultValue;

  // Type-based defaults
  switch (baseType) {
    case "string":
      if (hasEmail) return "user@example.com";
      if (hasPattern) return "pattern123";
      return "string";
    case "number":
    case "integer":
      return 123;
    case "boolean":
      return true;
    case "array":
      return [];
    case "object":
      return {};
    default:
      return null;
  }
}

// Match schema to method name
function findSchemaForMethod(schemas, methodName) {
  if (!methodName) return null;

  const methodLower = methodName.toLowerCase();

  // Try direct match first: sendOTPSchema -> sendOTP, loginOTPSchema -> loginWithOTP, etc.
  for (const [schemaName, schema] of Object.entries(schemas)) {
    const schemaNameWithoutSuffix = schemaName.replace(/Schema$/, "");
    const schemaLower = schemaNameWithoutSuffix.toLowerCase();

    // Exact match after removing 'Schema' suffix
    if (schemaLower === methodLower) {
      return schema;
    }

    // Substring match (either way)
    if (
      schemaLower.includes(methodLower) ||
      methodLower.includes(schemaLower)
    ) {
      return schema;
    }

    // Handle word boundary matches (e.g., loginWithOTP matches loginOTP when both are lowercased)
    // Remove common words/separators and compare
    const methodNormalized = methodLower.replace(/with|for|by/g, "");
    const schemaNormalized = schemaLower.replace(/with|for|by/g, "");

    if (
      methodNormalized === schemaNormalized ||
      schemaNormalized.includes(methodNormalized) ||
      methodNormalized.includes(schemaNormalized)
    ) {
      return schema;
    }
  }

  return null;
}

// Build complete endpoint information
async function buildEndpoints() {
  const mainRouterPath = path.join(SRC_DIR, "routes", "index.js");

  if (!fs.existsSync(mainRouterPath)) {
    console.error("Main router not found at:", mainRouterPath);
    return [];
  }

  const mounts = extractRouterMounts(mainRouterPath);
  const endpoints = [];

  for (const mount of mounts) {
    const moduleRouteFile = resolveModulePath(mainRouterPath, mount.modulePath);

    if (!moduleRouteFile) {
      console.warn(`Could not resolve module: ${mount.modulePath}`);
      continue;
    }

    const routes = extractRoutes(moduleRouteFile);
    const moduleName = mount.mountPath.replace(/^\//, "") || "root";

    for (const route of routes) {
      // Build full path
      const fullPath = path.posix.join(API_PREFIX, mount.mountPath, route.path);

      // Find validator and extract schemas
      let requestBody = null;
      let schemaFound = false;

      if (["POST", "PUT", "PATCH"].includes(route.method)) {
        if (route.controllerName && route.imports[route.controllerName]) {
          const controllerPath = resolveModulePath(
            moduleRouteFile,
            route.imports[route.controllerName]
          );

          if (controllerPath) {
            const validatorFile = findValidatorFile(controllerPath);

            if (validatorFile) {
              const schemas = extractJoiSchemas(validatorFile);
              requestBody = findSchemaForMethod(schemas, route.methodName);

              if (requestBody) {
                schemaFound = true;
              }
            }
          }
        }

        // Fallback: empty object for POST/PUT/PATCH if no schema found
        if (!requestBody) {
          requestBody = {};
        }
      }

      endpoints.push({
        module: moduleName,
        method: route.method,
        path: fullPath,
        handler: route.handler,
        body: requestBody,
        schemaFound: schemaFound,
      });
    }
  }

  return endpoints;
}

// Determine if endpoint requires authentication
function isPublicEndpoint(path) {
  const publicPaths = [
    "/send-otp",
    "/verify-otp",
    "/login",
    "/complete-registration",
  ];

  return publicPaths.some((publicPath) => path.includes(publicPath));
}

// Determine if endpoint requires only access token (not session token)
function requiresOnlyAccessToken(path) {
  const accessTokenOnlyPaths = ["/decrypt-token", "/logout"];

  return accessTokenOnlyPaths.some((tokenPath) => path.includes(tokenPath));
}

// Determine if endpoint requires both access token and session token
function requiresBothTokens(path) {
  const bothTokensPaths = ["/extend-session"];

  return bothTokensPaths.some((tokenPath) => path.includes(tokenPath));
}

// Generate Postman collection structure
function generatePostmanCollection(endpoints) {
  const collection = {
    info: {
      name: "Rentify API",
      description: "Auto-generated API collection for Rentify Backend",
      schema:
        "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
      version: "1.0.0",
    },
    item: [],
    variable: [
      {
        key: "baseUrl",
        value: BASE_URL,
        type: "string",
      },
      {
        key: "session_token",
        value: "",
        type: "string",
        description: "Session token from login response",
      },
      {
        key: "access_token",
        value: "",
        type: "string",
        description: "Access token from login response",
      },
    ],
  };

  // Group endpoints by module
  const moduleGroups = {};

  endpoints.forEach((endpoint) => {
    const moduleName = endpoint.module || "General";

    if (!moduleGroups[moduleName]) {
      moduleGroups[moduleName] = [];
    }

    moduleGroups[moduleName].push(endpoint);
  });

  // Create folder for each module
  for (const [moduleName, moduleEndpoints] of Object.entries(moduleGroups)) {
    const folder = {
      name: moduleName.charAt(0).toUpperCase() + moduleName.slice(1),
      item: moduleEndpoints.map((endpoint) => {
        const request = {
          name: `${endpoint.method} ${endpoint.path}`,
          request: {
            method: endpoint.method,
            header: [],
            url: {
              raw: `{{baseUrl}}${endpoint.path}`,
              host: ["{{baseUrl}}"],
              path: endpoint.path.split("/").filter(Boolean),
            },
          },
          response: [],
        };

        // Check if endpoint is public (no auth required)
        const isPublic = isPublicEndpoint(endpoint.path);
        const onlyAccessToken = requiresOnlyAccessToken(endpoint.path);
        const bothTokens = requiresBothTokens(endpoint.path);

        // Add authentication headers for protected endpoints
        if (!isPublic) {
          if (bothTokens) {
            // Both tokens required (e.g., extend-session)
            request.request.header.push(
              {
                key: "x-session-token",
                value: "{{session_token}}",
                type: "text",
                description:
                  "Session token from login response (required for authenticated requests)",
              },
              {
                key: "x-access-token",
                value: "{{access_token}}",
                type: "text",
                description:
                  "Access token from login response (required for authenticated requests)",
              }
            );
          } else if (onlyAccessToken) {
            // Only access token required (e.g., decrypt-token, logout)
            request.request.header.push({
              key: "x-access-token",
              value: "{{access_token}}",
              type: "text",
              description: "Access token from login response (required)",
            });
          } else {
            // Both session and access token required
            request.request.header.push(
              {
                key: "x-session-token",
                value: "{{session_token}}",
                type: "text",
                description:
                  "Session token from login response (required for authenticated requests)",
              },
              {
                key: "x-access-token",
                value: "{{access_token}}",
                type: "text",
                description:
                  "Access token from login response (required for authenticated requests)",
              }
            );
          }
        }

        // Add Content-Type header for requests with body
        if (endpoint.body && Object.keys(endpoint.body).length > 0) {
          request.request.header.push({
            key: "Content-Type",
            value: "application/json",
            type: "text",
          });

          request.request.body = {
            mode: "raw",
            raw: JSON.stringify(endpoint.body, null, 2),
            options: {
              raw: {
                language: "json",
              },
            },
          };
        }

        // Add description
        let description = "";
        if (endpoint.handler) {
          description += `Handler: ${endpoint.handler}\n`;
        }
        if (isPublic) {
          description += "🔓 Public endpoint - No authentication required";
        } else if (bothTokens) {
          description +=
            "🔒 Requires both x-session-token and x-access-token headers";
        } else if (onlyAccessToken) {
          description += "🔒 Requires x-access-token header only";
        } else {
          description +=
            "🔒 Protected endpoint - Requires x-session-token and x-access-token headers";
        }
        request.request.description = description;

        return request;
      }),
    };

    collection.item.push(folder);
  }

  return collection;
}

// Main execution
async function main() {
  try {
    console.log("🚀 Generating Postman collection...\n");
    console.log(`Source Directory: ${SRC_DIR}`);
    console.log(`Base URL: ${BASE_URL}`);
    console.log(`API Prefix: ${API_PREFIX}\n`);

    const endpoints = await buildEndpoints();

    if (endpoints.length === 0) {
      console.error("❌ No endpoints found!");
      process.exit(1);
    }

    console.log(`✅ Found ${endpoints.length} endpoints:`);
    endpoints.forEach((ep) => {
      const hasBody = ep.body && Object.keys(ep.body).length > 0;
      const bodyStatus = hasBody ? "✓" : "×";
      console.log(`   [${bodyStatus}] ${ep.method.padEnd(6)} ${ep.path}`);
    });

    const collection = generatePostmanCollection(endpoints);

    // Ensure output directory exists
    await fs.ensureDir(path.dirname(OUTPUT_FILE));
    await fs.writeFile(
      OUTPUT_FILE,
      JSON.stringify(collection, null, 2),
      "utf8"
    );

    console.log(`\n✨ Postman collection generated successfully!`);
    console.log(`📁 Output: ${OUTPUT_FILE}`);
    console.log(`\n📊 Summary:`);
    console.log(`   Total Endpoints: ${endpoints.length}`);
    console.log(`   Modules: ${collection.item.length}`);

    const withBody = endpoints.filter(
      (ep) => ep.body && Object.keys(ep.body).length > 0
    ).length;
    console.log(`   Endpoints with body: ${withBody}/${endpoints.length}`);

    collection.item.forEach((folder) => {
      console.log(`   - ${folder.name}: ${folder.item.length} endpoints`);
    });
  } catch (error) {
    console.error("❌ Error generating Postman collection:", error);
    process.exit(1);
  }
}

// Run the script
main();
