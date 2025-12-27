/**
 * scripts/generate-postman-from-routes.js
 *
 * Enhanced Postman collection generator that:
 * - Properly resolves route paths by tracing from main router
 * - Accurately infers request bodies from Joi validators (including nested Joi.object references used inside arrays)
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
const OUTPUT_FILE = path.join(PROJECT_ROOT, "docs", "api", "Rentify-postman.json");

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

/**
 * Extract Joi schemas from a validator file.
 * This function performs TWO passes:
 * 1) Collect all top-level Joi.object(...) variable declarators into localSchemas map (so we can resolve identifiers used later).
 * 2) Parse each schema into a structured schema map using parseJoiObject/parseJoiChain which can resolve identifier references from localSchemas.
 */
function extractJoiSchemas(validatorFilePath) {
  const code = readFile(validatorFilePath);
  if (!code) return {};

  const ast = parseToAST(code, validatorFilePath);
  if (!ast) return {};

  // First pass: collect Joi.object variable AST nodes
  const rawSchemas = {}; // name -> ObjectExpression node (AST)
  traverse(ast, {
    VariableDeclarator({ node }) {
      if (
        node.id &&
        node.id.type === "Identifier" &&
        node.init &&
        node.init.type === "CallExpression" &&
        node.init.callee.type === "MemberExpression" &&
        node.init.callee.object &&
        node.init.callee.object.name === "Joi" &&
        node.init.callee.property &&
        node.init.callee.property.name === "object"
      ) {
        const schemaName = node.id.name;
        const schemaObj = node.init.arguments[0];
        if (schemaObj && schemaObj.type === "ObjectExpression") {
          rawSchemas[schemaName] = schemaObj;
        } else {
          // still register the schema name with null to indicate presence
          rawSchemas[schemaName] = schemaObj || null;
        }
      }
    },
  });

  // Helper: parse Joi object AST into structured schema entry map, but pass localSchemas for identifier resolution
  function parseJoiObject(objectExpression, localSchemas) {
    const schema = {};

    if (!objectExpression || objectExpression.type !== "ObjectExpression") {
      return schema;
    }

    objectExpression.properties.forEach((prop) => {
      if (prop.type === "ObjectProperty") {
        const key = prop.key.name || prop.key.value;
        const valueNode = prop.value;
        const parsed = parseJoiChain(valueNode, localSchemas);
        schema[key] = parsed;
      }
    });

    return schema;
  }

  // Parse Joi chain AST node into a structured schema entry; can resolve identifier references from localSchemas
  function parseJoiChain(node, localSchemas) {
    const chain = [];
    let current = node;

    // walk call chain (Joi.string().min()....)
    while (current) {
      if (
        current.type === "CallExpression" &&
        current.callee.type === "MemberExpression"
      ) {
        const methodName = current.callee.property.name;
        const args = current.arguments || [];
        chain.push({ method: methodName, args });
        current = current.callee.object;
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

    chain.reverse(); // base type first

    // collectors
    let baseType = "any";
    let defaultValue = undefined;
    let validValues = [];
    let isRequired = false;
    let allowNull = false;
    let hasEmail = false;
    let hasPattern = false;
    let children = null; // for objects
    let items = null; // for arrays

    for (const { method, args } of chain) {
      // base types
      if (
        [
          "string",
          "number",
          "integer",
          "boolean",
          "array",
          "object",
          "any",
        ].includes(method)
      ) {
        baseType = method === "integer" ? "number" : method;
      }

      // default(...)

      if (method === "default" && args.length > 0) {
        const a = args[0];
        if (a.type === "StringLiteral") defaultValue = a.value;
        else if (a.type === "NumericLiteral") defaultValue = a.value;
        else if (a.type === "BooleanLiteral") defaultValue = a.value;
      }

      // valid(...)
      if (method === "valid" && args.length > 0) {
        args.forEach((a) => {
          if (a.type === "StringLiteral") validValues.push(a.value);
          else if (a.type === "NumericLiteral") validValues.push(a.value);
          else if (a.type === "BooleanLiteral") validValues.push(a.value);
        });
      }

      if (method === "required") isRequired = true;

      if (method === "allow" && args.length > 0) {
        args.forEach((a) => {
          if (a.type === "NullLiteral") allowNull = true;
          // we ignore empty-string allowances here (could be added if you need)
        });
      }

      if (method === "email") hasEmail = true;
      if (method === "pattern") hasPattern = true;

      // nested object: Joi.object({ ... })
      if (
        method === "object" &&
        args.length > 0 &&
        args[0] &&
        args[0].type === "ObjectExpression"
      ) {
        children = parseJoiObject(args[0], localSchemas);
        baseType = "object";
      }

      // array items: Joi.array().items(...)
      if (method === "items" && args.length > 0) {
        const first = args[0];

        // If items is Joi.object({...})
        if (
          first.type === "CallExpression" &&
          first.callee.type === "MemberExpression" &&
          first.callee.object &&
          first.callee.object.name === "Joi"
        ) {
          const innerMethod = first.callee.property.name;
          if (
            innerMethod === "object" &&
            first.arguments[0] &&
            first.arguments[0].type === "ObjectExpression"
          ) {
            items = parseJoiObject(first.arguments[0], localSchemas); // items is children map
          } else {
            // items could be Joi.string(), Joi.number(), etc.
            items = parseJoiChain(first, localSchemas);
          }
        } else if (first.type === "Identifier") {
          // items(someSchemaVar) -> try to resolve from localSchemas
          const refName = first.name;
          if (localSchemas && localSchemas[refName] && localSchemas[refName].type === "object" && localSchemas[refName].children) {
            // localSchemas entry already parsed into structured form (children map)
            items = localSchemas[refName].children;
          } else if (localSchemas && rawSchemas[refName]) {
            // parse raw AST into structured map now
            items = parseJoiObject(rawSchemas[refName], localSchemas);
          } else {
            // fallback: unknown identifier => leave as generic
            items = { type: "any", example: null, required: false };
          }
        } else {
          // fallback: if items is unknown or complex, keep generic
          items = { type: "any", example: null, required: false };
        }

        baseType = "array";
      }
    }

    // pick example priority: valid > default > type-based
    let example;
    if (validValues.length > 0) example = validValues[0];
    else if (defaultValue !== undefined) example = defaultValue;
    else {
      switch (baseType) {
        case "string":
          if (hasEmail) example = "user@example.com";
          else if (hasPattern) example = "pattern_example";
          else example = "string";
          break;
        case "number":
          example = 123;
          break;
        case "boolean":
          example = true;
          break;
        case "array":
          example = []; // representative array
          break;
        case "object":
          example = {}; // representative object
          break;
        default:
          example = null;
      }
    }

    const schemaEntry = {
      type: baseType || "any",
      required: !!isRequired,
      allowNull: !!allowNull,
      example: example,
      valid: validValues,
    };

    if (children) schemaEntry.children = children;
    if (items) schemaEntry.items = items;

    return schemaEntry;
  }

  // Second pass: produce final schemas map (name -> parsed structured schema)
  const schemas = {};

  // localSchemas map stores parsed entries so identifier references can be resolved
  const localSchemas = {};

  // Parse each collected raw schema AST into structured map and also register as localSchemas
  for (const [schemaName, objExpr] of Object.entries(rawSchemas)) {
    if (objExpr && objExpr.type === "ObjectExpression") {
      const parsedChildren = parseJoiObject(objExpr, localSchemas);
      // store a wrapper that mimics a top-level Joi.object({ ... }) entry
      const parsedSchemaWrapper = {
        type: "object",
        required: false,
        children: parsedChildren,
      };
      schemas[schemaName] = parsedSchemaWrapper.children;
      localSchemas[schemaName] = parsedSchemaWrapper;
    } else {
      // empty or unknown - mark as empty
      schemas[schemaName] = {};
      localSchemas[schemaName] = { type: "object", children: {} };
    }
  }

  // Additionally find Joi.object(...) assigned directly in declarations that we haven't captured (e.g., inline)
  traverse(ast, {
    VariableDeclarator({ node }) {
      if (
        node.id &&
        node.id.type === "Identifier" &&
        node.init &&
        node.init.type === "CallExpression" &&
        node.init.callee.type === "MemberExpression" &&
        node.init.callee.object &&
        node.init.callee.object.name === "Joi" &&
        node.init.callee.property &&
        node.init.callee.property.name === "object"
      ) {
        const name = node.id.name;
        // already parsed above, skip
      }
    },
    // Also capture exported schema assignments like module.exports = { createModelSchema: Joi.object({...}) }
    AssignmentExpression({ node }) {
      if (
        node.left &&
        (node.left.type === "MemberExpression" || node.left.type === "Identifier")
      ) {
        // handle cases if needed - but primary coverage is variable declarators above
      }
    },
  });

  // Finally build a simple map of top-level VariableDeclarator-style Joi.object schemas keyed by variable name (strip "Schema" suffix for convenience)
  // For outward-facing API we want names like createModelSchema etc.
  // We'll traverse top-level variable declarators again to pick up variable names used as schemas.
  traverse(ast, {
    VariableDeclarator({ node }) {
      if (
        node.id &&
        node.id.type === "Identifier" &&
        node.init &&
        node.init.type === "CallExpression" &&
        node.init.callee.type === "MemberExpression" &&
        node.init.callee.object &&
        node.init.callee.object.name === "Joi" &&
        node.init.callee.property &&
        node.init.callee.property.name === "object"
      ) {
        const schemaName = node.id.name;
        // if we have the parsed version in localSchemas, use it; else, parse now
        if (localSchemas[schemaName]) {
          schemas[schemaName] = localSchemas[schemaName].children || {};
        } else if (rawSchemas[schemaName]) {
          schemas[schemaName] = parseJoiObject(rawSchemas[schemaName], localSchemas);
        } else {
          schemas[schemaName] = {};
        }
      }
    },
    // Also support `const schemas = { createModelSchema: Joi.object({...}) }` style - object properties assigned to call expressions
    ObjectProperty({ node }) {
      if (
        node.value &&
        node.value.type === "CallExpression" &&
        node.value.callee &&
        node.value.callee.type === "MemberExpression" &&
        node.value.callee.object &&
        node.value.callee.object.name === "Joi" &&
        node.value.callee.property &&
        node.value.callee.property.name === "object"
      ) {
        const keyName = node.key.name || node.key.value;
        if (node.value.arguments && node.value.arguments[0] && node.value.arguments[0].type === "ObjectExpression") {
          schemas[keyName] = parseJoiObject(node.value.arguments[0], localSchemas);
        }
      }
    },
  });

  return schemas;
}

// Parse Joi.object({...}) AST node into a schema map: field -> schemaEntry
// (This function is kept for backward compatibility but not used directly anymore.)

// Parse Joi chain AST node into a structured schema entry
// (This function is kept for backward compatibility but not used directly anymore.)

function generateSampleFromSchema(schemaObj) {
  if (!schemaObj || Object.keys(schemaObj).length === 0) return {};

  const out = {};

  for (const [key, entry] of Object.entries(schemaObj)) {
    if (!entry) {
      out[key] = null;
      continue;
    }

    const t = entry.type || "any";

    // PRIMITIVE types
    if (t === "string" || t === "number" || t === "boolean" || t === "any") {
      if (entry.required) {
        out[key] =
          entry.example !== undefined
            ? entry.example
            : t === "number"
              ? 0
              : t === "boolean"
                ? false
                : "string";
      } else {
        // optional primitive -> null (explicitly show optional)
        out[key] = null;
      }
      continue;
    }

    // OBJECT
    if (t === "object") {
      if (entry.children && Object.keys(entry.children).length > 0) {
        // always show object shape so frontend sees nested fields
        const childObj = {};
        for (const [ck, centry] of Object.entries(entry.children)) {
          if (!centry) {
            childObj[ck] = null;
            continue;
          }
          if (centry.type === "object") {
            childObj[ck] = generateSampleFromSchema(centry.children || {});
          } else if (centry.type === "array") {
            // for nested arrays, produce one item
            if (centry.items) {
              if (
                // items is a children map (plain object of fields)
                typeof centry.items === "object" &&
                !centry.items.type &&
                Object.keys(centry.items).length > 0 &&
                Object.values(centry.items)[0] &&
                Object.values(centry.items)[0].type
              ) {
                childObj[ck] = [generateSampleFromSchema(centry.items)];
              } else if (centry.items && centry.items.type === "object" && centry.items.children) {
                childObj[ck] = [generateSampleFromSchema(centry.items.children)];
              } else if (centry.items && centry.items.type) {
                const it = centry.items;
                const val = it.required
                  ? it.example !== undefined
                    ? it.example
                    : it.type === "number"
                      ? 0
                      : it.type === "boolean"
                        ? false
                        : "string"
                  : null;
                childObj[ck] = [val];
              } else {
                childObj[ck] = [];
              }
            } else {
              childObj[ck] = [];
            }
          } else {
            // primitive inside object: required -> example, optional -> null
            childObj[ck] = centry.required
              ? centry.example !== undefined
                ? centry.example
                : centry.type === "number"
                  ? 0
                  : centry.type === "boolean"
                    ? false
                    : "string"
              : null;
          }
        }
        out[key] = childObj;
      } else {
        // no children info - either required -> example or optional -> null
        out[key] = entry.required
          ? entry.example !== undefined
            ? entry.example
            : {}
          : null;
      }
      continue;
    }

    // ARRAY
    if (t === "array") {
      // For arrays we show a representative array with one item (so frontend sees the item shape).
      if (entry.items) {
        // if items is a children map (object shape)
        if (
          typeof entry.items === "object" &&
          !entry.items.type &&
          Object.keys(entry.items).length > 0
        ) {
          out[key] = [generateSampleFromSchema(entry.items)];
        } else if (entry.items.type === "object" && entry.items.children) {
          out[key] = [generateSampleFromSchema(entry.items.children)];
        } else if (entry.items.type) {
          // primitive item schema
          const it = entry.items;
          const val = it.required
            ? it.example !== undefined
              ? it.example
              : it.type === "number"
                ? 0
                : it.type === "boolean"
                  ? false
                  : "string"
            : null;
          out[key] = [val];
        } else {
          out[key] = [];
        }
      } else {
        out[key] = [];
      }
      continue;
    }

    // fallback
    out[key] = entry.required
      ? entry.example !== undefined
        ? entry.example
        : null
      : null;
  }

  return out;
}

function buildFieldListDescription(schemaObj) {
  if (!schemaObj || Object.keys(schemaObj).length === 0) return "";

  const lines = [];
  lines.push("Fields (required vs optional):");
  for (const [key, entry] of Object.entries(schemaObj)) {
    const type = (entry && entry.type) || "any";
    const req = entry && entry.required ? "required" : "optional";
    const ex = (() => {
      if (!entry) return "null";
      // If primitive and optional -> show null
      if (
        (type === "string" ||
          type === "number" ||
          type === "boolean" ||
          type === "any") &&
        !entry.required
      )
        return "null";
      // show example or structural hint
      if (entry.example !== undefined && entry.example !== null) {
        try {
          return JSON.stringify(entry.example);
        } catch (e) {
          return String(entry.example);
        }
      }
      // objects/arrays show brief shape
      if (entry.type === "object" && entry.children) {
        return `{ ${Object.keys(entry.children).join(", ")} }`;
      }
      if (entry.type === "array" && entry.items) {
        if (entry.items.children)
          return `[ { ${Object.keys(entry.items.children).join(", ")} } ]`;
        if (entry.items.type) return `[ ${entry.items.type} ]`;
        if (typeof entry.items === "object" && !entry.items.type)
          return `[ { ${Object.keys(entry.items).join(", ")} } ]`;
      }
      return "null";
    })();

    lines.push(`- ${key}: ${type} (${req}) — example: ${ex}`);

    if (entry && entry.type === "object" && entry.children) {
      lines.push(
        `  - nested fields: ${Object.keys(entry.children).join(", ")}`
      );
    }
    if (entry && entry.type === "array" && entry.items) {
      if (entry.items && entry.items.children) {
        lines.push(
          `  - array item fields: ${Object.keys(entry.items.children).join(", ")}`
        );
      } else if (entry.items && entry.items.type) {
        lines.push(`  - array item type: ${entry.items.type}`);
      } else if (typeof entry.items === "object" && !entry.items.type) {
        lines.push(`  - array item fields: ${Object.keys(entry.items).join(", ")}`);
      }
    }
  }
  return lines.join("\n");
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

// Determine if endpoint requires only session token (for token refresh)
function requiresOnlySessionToken(path) {
  const sessionTokenOnlyPaths = ["/refresh-tokens"];

  return sessionTokenOnlyPaths.some((tokenPath) => path.includes(tokenPath));
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
      description:
        "Auto-generated API collection for Rentify Backend. Authentication uses HTTP-only cookies (access_token and session_token) set by the server on login.",
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
        const onlySessionToken = requiresOnlySessionToken(endpoint.path);
        const bothTokens = requiresBothTokens(endpoint.path);

        // Note: Authentication tokens are now handled via HTTP-only cookies
        // No manual headers needed - cookies are automatically sent by Postman

        // Add Content-Type header for requests with body
        if (endpoint.body && Object.keys(endpoint.body).length > 0) {
          request.request.header.push({
            key: "Content-Type",
            value: "application/json",
            type: "text",
          });

          // Build JSON sample from parsed schema (required fields -> example, optional primitives -> null, but show object/array shape)
          const sampleBody = generateSampleFromSchema(endpoint.body);

          request.request.body = {
            mode: "raw",
            raw: JSON.stringify(sampleBody, null, 2),
            options: {
              raw: {
                language: "json",
              },
            },
          };

          // Add field-level description (required vs optional, example/null)
          const fieldDesc = buildFieldListDescription(endpoint.body);
          request._fieldDesc = fieldDesc;
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
            "🔒 Requires both session_token and access_token cookies (set automatically on login)";
        } else if (onlyAccessToken) {
          description += "🔒 Requires access_token cookie only";
        } else if (onlySessionToken) {
          description +=
            "🔒 Requires session_token cookie only (used to refresh expired access_token)";
        } else {
          description +=
            "🔒 Protected endpoint - Requires session_token and access_token cookies (set automatically on login)";
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
