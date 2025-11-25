/**
 * scripts/generate-postman-from-routes-v2.js
 *
 * Usage:
 *   node scripts/generate-postman-from-routes-v2.js
 * Options (env):
 *   BASE_URL (default http://localhost:3000)
 *   API_PREFIX (default /api)
 *   SRC_DIR  (default ./src)
 *   INPUT_FILE (optional) - if provided the script will also scan a single JS file (eg. uploaded merged.txt)
 *
 * Output: ./docs/api/postman-from-routes-v2.json
 *
 * Notes:
 * - AST-based parsing using @babel/parser + @babel/traverse
 * - Attempts to find router.<method>(path, ...middlewares, handler)
 * - Resolves controller requires/imports and finds validator usage
 * - Parses Joi.object(...) AST to infer accurate example request bodies
 *
 * Limitations: dynamic route composition or runtime-created routes may be missed.
 */

const fs = require("fs-extra");
const path = require("path");
const glob = require("glob");
const parser = require("@babel/parser");
const traverse = require("@babel/traverse").default;

const PROJECT_ROOT = path.resolve(__dirname, "..");
const SRC_DIR = process.env.SRC_DIR || path.join(PROJECT_ROOT, "src");
const INPUT_FILE = process.env.INPUT_FILE || ""; // e.g. /mnt/data/merged.txt
const BASE_URL = process.env.BASE_URL || "http://localhost:3000";
const API_PREFIX = process.env.API_PREFIX || "/api";

function read(file) {
  try {
    return fs.readFileSync(file, "utf8");
  } catch (e) {
    return "";
  }
}

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
      ],
    });
  } catch (err) {
    console.warn("Parse error for", filePath, err.message);
    return null;
  }
}

function collectRouteFiles() {
  const patterns = [
    path.join(SRC_DIR, "**", "*.routes.js"),
    path.join(SRC_DIR, "**", "routes.js"),
  ];
  let files = [];
  for (const p of patterns) files = files.concat(glob.sync(p));
  // include top-level index if exists
  const idx = path.join(SRC_DIR, "routes", "index.js");
  if (fs.existsSync(idx) && !files.includes(idx)) files.push(idx);
  if (INPUT_FILE && fs.existsSync(INPUT_FILE)) files.push(INPUT_FILE);
  // uniq
  return [...new Set(files)];
}

// Resolve a require/import path to actual file path (try .js, /index.js)
function resolveRequire(currentFile, relPath) {
  if (!relPath) return null;
  if (!relPath.startsWith(".")) {
    // could be module, skip
    return null;
  }
  let resolved = path.resolve(path.dirname(currentFile), relPath);
  if (fs.existsSync(resolved) && fs.statSync(resolved).isFile())
    return resolved;
  if (fs.existsSync(resolved + ".js")) return resolved + ".js";
  if (fs.existsSync(path.join(resolved, "index.js")))
    return path.join(resolved, "index.js");
  return null;
}

// Extract router.* calls
function findRoutesInFile(filePath) {
  const code = read(filePath);
  const ast = parseToAST(code, filePath);
  if (!ast) return [];

  // map of local variable name -> required path
  const requires = {};

  traverse(ast, {
    // handle: const X = require('./x.controller');
    VariableDeclarator({ node }) {
      try {
        if (
          node.init &&
          node.init.callee &&
          node.init.callee.name === "require"
        )
          return; // skip require() transpiled variants
        if (
          node.init &&
          node.init.type === "CallExpression" &&
          node.init.callee.name === "require" &&
          node.init.arguments.length
        ) {
          const varName = node.id.name;
          const arg = node.init.arguments[0];
          if (arg && arg.type === "StringLiteral")
            requires[varName] = arg.value;
        }
      } catch (e) {}
    },
    // handle: import authController from './auth.controller';
    ImportDeclaration({ node }) {
      try {
        const source = node.source.value;
        for (const spec of node.specifiers) {
          const local = spec.local.name;
          requires[local] = source;
        }
      } catch (e) {}
    },
  });

  const routes = [];

  traverse(ast, {
    ExpressionStatement(pathExp) {
      const node = pathExp.node.expression;
      if (!node) return;
      // look for router.<method> calls
      if (
        node.type === "CallExpression" &&
        node.callee &&
        node.callee.type === "MemberExpression" &&
        node.callee.object &&
        (node.callee.object.name === "router" ||
          (node.callee.object.type === "Identifier" &&
            node.callee.object.name === "router")) &&
        node.callee.property &&
        node.callee.property.type === "Identifier"
      ) {
        const method = node.callee.property.name.toUpperCase();
        const args = node.arguments || [];
        if (args.length >= 2) {
          const first = args[0];
          let routePath = null;
          if (first.type === "StringLiteral") routePath = first.value;
          // last argument is usually handler
          const handlerNode = args[args.length - 1];
          let handler = null;
          if (handlerNode.type === "Identifier") handler = handlerNode.name;
          else if (handlerNode.type === "MemberExpression") {
            // e.g. authController.sendOTP
            const obj =
              handlerNode.object.name ||
              (handlerNode.object.type === "Identifier" &&
                handlerNode.object.name);
            const prop = handlerNode.property.name;
            handler = `${obj}.${prop}`;
          } else if (
            handlerNode.type === "ArrowFunctionExpression" ||
            handlerNode.type === "FunctionExpression"
          ) {
            handler = "<inline>";
          }
          routes.push({ method, routePath, handler, file: filePath, requires });
        }
      }
    },
  });

  return routes;
}

// parse controller file to detect which validator is called in the handler method
function findValidatorUsed(controllerFile, handlerName) {
  if (!controllerFile || !fs.existsSync(controllerFile)) return null;
  const code = read(controllerFile);
  const ast = parseToAST(code, controllerFile);
  if (!ast) return null;

  // build local requires map for controller file
  const requires = {};
  traverse(ast, {
    VariableDeclarator({ node }) {
      try {
        if (
          node.init &&
          node.init.type === "CallExpression" &&
          node.init.callee.name === "require" &&
          node.init.arguments.length
        ) {
          const varName = node.id.name;
          const arg = node.init.arguments[0];
          if (arg && arg.type === "StringLiteral")
            requires[varName] = arg.value;
        }
      } catch (e) {}
    },
    ImportDeclaration({ node }) {
      try {
        const source = node.source.value;
        for (const spec of node.specifiers) {
          const local = spec.local.name;
          requires[local] = source;
        }
      } catch (e) {}
    },
  });

  let validatorRef = null;

  // find function named handlerName (either as function declaration or property on exports)
  traverse(ast, {
    // function declarations: async function sendOTP(req, res) { ... }
    FunctionDeclaration(path) {
      const n = path.node;
      if (n.id && n.id.name === handlerName) {
        // inspect body for CallExpression nodes invoking *.validate*
        path.traverse({
          CallExpression(p) {
            const callee = p.node.callee;
            if (
              callee.type === "MemberExpression" &&
              callee.property &&
              /validate/i.test(callee.property.name)
            ) {
              // object name may be AuthValidator or something
              if (callee.object && callee.object.type === "Identifier") {
                validatorRef = callee.object.name; // e.g. AuthValidator
              }
            }
          },
        });
      }
    },
    // method in exports e.g. exports.sendOTP = async (req,res) => {}
    AssignmentExpression(path) {
      try {
        const left = path.node.left;
        if (
          left.type === "MemberExpression" &&
          left.object.name === "exports"
        ) {
          const prop = left.property.name;
          if (prop === handlerName) {
            path.traverse({
              CallExpression(p) {
                const callee = p.node.callee;
                if (
                  callee.type === "MemberExpression" &&
                  callee.property &&
                  /validate/i.test(callee.property.name)
                ) {
                  if (callee.object && callee.object.type === "Identifier") {
                    validatorRef = callee.object.name;
                  }
                }
              },
            });
          }
        }
      } catch (e) {}
    },
    // object export: module.exports = { sendOTP: (req,res) => { ... } }
    ObjectExpression(path) {
      const parent = path.parentPath && path.parentPath.node;
      if (
        parent &&
        parent.type === "AssignmentExpression" &&
        parent.left &&
        parent.left.type === "MemberExpression" &&
        parent.left.object.name === "module" &&
        parent.left.property.name === "exports"
      ) {
        // search properties
        for (const prop of path.node.properties) {
          if (prop.key && prop.key.name === handlerName) {
            // traverse that function
            traverse(
              prop,
              {
                CallExpression(p) {
                  const callee = p.node.callee;
                  if (
                    callee.type === "MemberExpression" &&
                    callee.property &&
                    /validate/i.test(callee.property.name)
                  ) {
                    if (callee.object && callee.object.type === "Identifier") {
                      validatorRef = callee.object.name;
                    }
                  }
                },
              },
              path.scope,
              path
            );
          }
        }
      }
    },
  });

  // if validatorRef points to some var, see requires map to find file
  if (validatorRef && requires[validatorRef]) {
    const rel = requires[validatorRef];
    const resolved = resolveRequire(controllerFile, rel);
    return resolved;
  }

  // fallback: try to find any Joi.object in module sibling validator files
  // We'll let caller search for a matching validator file later
  return null;
}

// Parse a validator file for Joi.object(...) and construct example body
function inferBodyFromValidatorFile(validatorFile, handlerNameCandidate) {
  if (!validatorFile || !fs.existsSync(validatorFile)) return null;
  const code = read(validatorFile);
  const ast = parseToAST(code, validatorFile);
  if (!ast) return null;

  // try to find a Joi.object argument assigned to a variable with name related to handlerNameCandidate
  let candidateNode = null;

  traverse(ast, {
    VariableDeclarator(path) {
      try {
        // const sendOTPSchema = Joi.object({...})
        const id = path.node.id;
        const init = path.node.init;
        if (
          init &&
          init.type === "CallExpression" &&
          init.callee.type === "MemberExpression" &&
          init.callee.object.name === "Joi" &&
          init.callee.property.name === "object"
        ) {
          // varName
          const varName = id.name.toLowerCase();
          if (
            handlerNameCandidate &&
            varName.includes(handlerNameCandidate.toLowerCase())
          ) {
            candidateNode = init.arguments[0]; // object expression
          } else if (!candidateNode) {
            candidateNode = init.arguments[0];
          }
        }
      } catch (e) {}
    },
    AssignmentExpression(path) {
      // direct assignment exports.mySchema = Joi.object({...})
      const left = path.node.left;
      const right = path.node.right;
      if (
        right &&
        right.type === "CallExpression" &&
        right.callee.type === "MemberExpression" &&
        right.callee.object.name === "Joi" &&
        right.callee.property.name === "object"
      ) {
        if (!candidateNode) candidateNode = right.arguments[0];
      }
    },
    CallExpression(path) {
      // catch Joi.object({...}) used directly
      const callee = path.node.callee;
      if (
        callee &&
        callee.type === "MemberExpression" &&
        callee.object.name === "Joi" &&
        callee.property.name === "object"
      ) {
        if (!candidateNode) candidateNode = path.node.arguments[0];
      }
    },
  });

  if (!candidateNode) return null;
  // candidateNode should be an ObjectExpression
  if (candidateNode.type !== "ObjectExpression") return null;

  const example = {};
  for (const prop of candidateNode.properties) {
    if (prop.type !== "ObjectProperty") continue;
    const key =
      prop.key.name || (prop.key.type === "StringLiteral" && prop.key.value);
    const val = prop.value;
    const inferred = inferFromJoiCallExpression(val, validatorFile);
    example[key] = inferred;
  }
  return example;
}

// walk Joi call chains (e.g. Joi.string().email().default('a').required())
function inferFromJoiCallExpression(node, fileForContext) {
  // if node is CallExpression with callee MemberExpression whose object is Chain -> drill down
  // We want to find the base type (string, number, array, object, boolean) plus chained members like email, default, valid(...)
  try {
    // find chain of callee names and arguments
    const calls = [];
    let current = node;
    // handle direct nested CallExpression like Joi.string().email().required()
    while (current) {
      if (current.type === "CallExpression") {
        // callee can be MemberExpression or Identifier
        if (current.callee.type === "MemberExpression") {
          const prop = current.callee.property;
          const calleeName = prop && prop.name;
          // capture arguments for this call
          const args = current.arguments || [];
          calls.push({ name: calleeName, args });
          // move to callee.object
          current = current.callee.object;
        } else if (current.callee.type === "Identifier") {
          // rare case
          calls.push({
            name: current.callee.name,
            args: current.arguments || [],
          });
          break;
        } else {
          break;
        }
      } else if (current.type === "MemberExpression") {
        // maybe Joi.string (no call) - capture property
        if (current.property && current.property.name) {
          calls.push({ name: current.property.name, args: [] });
        }
        current = current.object;
      } else {
        break;
      }
    }

    // the calls array is from outermost to base; reverse to get base-first
    calls.reverse(); // now base type first
    // base type should be calls[0].name like 'string'
    const base = calls.length ? calls[0].name : null;
    // collect details
    let defaultVal = undefined;
    let enumVal = undefined;
    let hasEmail = false;
    let hasPattern = false;
    for (const call of calls) {
      if (/default/i.test(call.name) && call.args && call.args[0]) {
        const a = call.args[0];
        if (a.type === "StringLiteral") defaultVal = a.value;
        else if (a.type === "NumericLiteral") defaultVal = a.value;
        else if (a.type === "BooleanLiteral") defaultVal = a.value;
      }
      if (/valid/i.test(call.name) && call.args && call.args[0]) {
        const a = call.args[0];
        if (
          a.type === "StringLiteral" ||
          a.type === "NumericLiteral" ||
          a.type === "BooleanLiteral"
        ) {
          enumVal = a.value;
        }
      }
      if (/email/i.test(call.name)) hasEmail = true;
      if (/pattern/i.test(call.name)) hasPattern = true;
    }

    if (enumVal !== undefined) return enumVal;
    if (defaultVal !== undefined) return defaultVal;

    // base inference
    if (base === "string") {
      if (hasEmail) return "user@example.com";
      if (hasPattern) return "pattern-example";
      return "string";
    } else if (base === "number" || base === "integer") return 123;
    else if (base === "boolean") return true;
    else if (base === "array") {
      // try to infer items if .items(Joi.string())
      // naive: return empty array (Postman user can fill)
      return [];
    } else if (base === "object") return {};
    // fallback: if node is StringLiteral etc
    if (node.type === "StringLiteral") return node.value;
    if (node.type === "NumericLiteral") return node.value;
    if (node.type === "BooleanLiteral") return node.value;
  } catch (e) {
    // fallback
  }
  return null;
}

// Build final Postman collection grouped by module/folder
function buildCollection(items) {
  const collection = {
    info: {
      name: "Rentify",
      _postman_id: "generated-v2",
      description: `Auto-generated from files under ${SRC_DIR}${
        INPUT_FILE ? " and " + INPUT_FILE : ""
      }`,
      schema:
        "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
    },
    item: [],
  };

  // group by moduleKey
  const groups = {};
  for (const it of items) {
    const moduleKey = it.module || "root";
    groups[moduleKey] = groups[moduleKey] || [];
    groups[moduleKey].push(it);
  }

  for (const [moduleName, its] of Object.entries(groups)) {
    // folder
    const folder = {
      name: moduleName,
      item: its.map((i) => {
        const pathParts = i.path.replace(/^\/+/, "").split("/");
        return {
          name: `${i.method} ${i.path}`,
          request: {
            method: i.method,
            header:
              i.method === "GET"
                ? []
                : [{ key: "Content-Type", value: "application/json" }],
            body: i.body
              ? { mode: "raw", raw: JSON.stringify(i.body, null, 2) }
              : undefined,
            url: {
              raw: BASE_URL + i.path,
              host: BASE_URL.replace(/https?:\/\//, "").split("/")[0],
              path: pathParts,
            },
          },
        };
      }),
    };
    collection.item.push(folder);
  }

  return collection;
}

async function main() {
  const routeFiles = collectRouteFiles();
  if (!routeFiles.length) {
    console.error("No route files found under", SRC_DIR);
    process.exit(1);
  }

  const results = [];

  for (const rf of routeFiles) {
    const routes = findRoutesInFile(rf);
    for (const r of routes) {
      // determine module name: relative dir from SRC_DIR, or file basename
      let moduleName = path.relative(SRC_DIR, path.dirname(r.file));
      if (!moduleName || moduleName.startsWith(".."))
        moduleName = path.basename(path.dirname(r.file)) || "root";

      // Special handling for main routes/index.js - don't add extra path segment
      const isMainRouteIndex = r.file.includes(
        path.join("src", "routes", "index.js")
      );

      // For module routes, extract just the module name (e.g., "auth" from "modules/auth")
      let routePrefix = "";
      if (moduleName.includes("modules/")) {
        // Extract the actual module name after "modules/"
        const parts = moduleName.split(path.sep);
        const moduleIndex = parts.indexOf("modules");
        if (moduleIndex !== -1 && parts.length > moduleIndex + 1) {
          routePrefix = parts[moduleIndex + 1];
          moduleName = routePrefix; // Use just the module name for grouping
        }
      } else if (isMainRouteIndex) {
        // Main route index shouldn't add any prefix
        routePrefix = "";
        moduleName = "root";
      } else if (moduleName === "routes") {
        // Routes folder shouldn't add prefix
        routePrefix = "";
        moduleName = "root";
      }

      // Build final path
      let finalPath;
      if (routePrefix) {
        finalPath = path.posix.join(API_PREFIX, routePrefix, r.routePath || "");
      } else {
        finalPath = path.posix.join(API_PREFIX, r.routePath || "");
      }

      // find handler controller file if handler like authController.sendOTP
      let controllerFile = null;
      let handlerMethod = null;
      if (r.handler && r.handler.includes(".")) {
        const [ctrlVar, method] = r.handler.split(".");
        handlerMethod = method;
        if (r.requires && r.requires[ctrlVar]) {
          const resolved = resolveRequire(r.file, r.requires[ctrlVar]);
          if (resolved) controllerFile = resolved;
        }
      }

      // attempt to find validator file used by controller
      let bodyExample = null;
      if (controllerFile) {
        const validatorFile = findValidatorUsed(controllerFile, handlerMethod);
        if (validatorFile) {
          // parse validatorFile
          bodyExample = inferBodyFromValidatorFile(
            validatorFile,
            handlerMethod
          );
        }
        // fallback: search validator files in same module directory
        if (!bodyExample) {
          const moduleDir = path.dirname(r.file);
          const validators = glob.sync(path.join(moduleDir, "*validator.js"));
          for (const vf of validators) {
            const candidate = inferBodyFromValidatorFile(vf, handlerMethod);
            if (candidate) {
              bodyExample = candidate;
              break;
            }
          }
        }
      } else {
        // if inline handler or no controller, try to find a validator file next to route file
        const moduleDir = path.dirname(r.file);
        const validators = glob.sync(path.join(moduleDir, "*validator.js"));
        for (const vf of validators) {
          const candidate = inferBodyFromValidatorFile(
            vf,
            handlerMethod || r.handler
          );
          if (candidate) {
            bodyExample = candidate;
            break;
          }
        }
      }

      // If bodyExample still null and method is POST/PUT/PATCH, set empty placeholder
      if (!bodyExample && ["POST", "PUT", "PATCH"].includes(r.method)) {
        bodyExample = {
          /* fill required fields here */
        };
      }

      results.push({
        method: r.method,
        path: finalPath,
        module: moduleName,
        file: r.file,
        handler: r.handler,
        body: bodyExample,
      });
    }
  }

  const collection = buildCollection(results);

  const out = path.join(PROJECT_ROOT, "docs", "api", "Rentify-postman.json");
  await fs.ensureDir(path.dirname(out));
  await fs.writeFile(out, JSON.stringify(collection, null, 2), "utf8");

  console.log("Wrote Postman collection to", out);
  console.log("Source scan paths:");
  for (const f of routeFiles) console.log("  -", f);
  // if uploaded file present, print it (developer note: uploaded file path recorded)
  if (INPUT_FILE) console.log("Input file used:", INPUT_FILE);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
