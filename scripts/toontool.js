#!/usr/bin/env node
/**
 * toontool.js
 * CLI: node toontool.js --dir ./src --out project.toon --strip-comments
 *
 * Default behavior:
 *  - If no --out or --out-dir provided, writes to docs/toon/<project>.toon
 *  - If writing to docs/toon/... fails, falls back to ./<project>.toon and logs a warning
 */

const fs = require('fs-extra');
const path = require('path');
const glob = require('glob');
const crypto = require('crypto');
const minimist = require('minimist');

// Use the official TOON encoder/decoder
const { encode: toonEncode } = require('@toon-format/toon');

function sha256OfString(s) {
  return crypto.createHash('sha256').update(s, 'utf8').digest('hex');
}

function detectLanguage(filename) {
  const ext = path.extname(filename).toLowerCase();
  if (ext === '.js' || ext === '.jsx') return 'javascript';
  if (ext === '.ts' || ext === '.tsx') return 'typescript';
  if (ext === '.sql') return 'sql';
  if (ext === '.json') return 'json';
  return ext.replace('.', '') || 'text';
}

// VERY SIMPLE comment stripper — naive but useful for big comment blocks.
function stripCommentsSimple(code, lang) {
  if (!code) return code;
  if (lang === 'javascript' || lang === 'typescript') {
    return code
      .replace(/\/\*[\s\S]*?\*\//g, '') // block comments
      .replace(/(^|\s)\/\/.*$/gm, ''); // line comments
  }
  if (lang === 'sql') {
    return code
      .replace(/--.*$/gm, '')
      .replace(/\/\*[\s\S]*?\*\//g, '');
  }
  return code;
}

async function collectFiles(rootDir, patterns = ['**/*.js', '**/*.sql']) {
  const opts = { cwd: rootDir, nodir: true, absolute: true, dot: true };
  const found = new Set();
  for (const p of patterns) {
    const matches = glob.sync(p, opts);
    matches.forEach(m => found.add(m));
  }
  return Array.from(found).sort();
}

async function readAndDescribe(filePath, options = {}) {
  const rel = path.relative(process.cwd(), filePath);
  const contentRaw = await fs.readFile(filePath, 'utf8');
  const language = detectLanguage(filePath);
  let content = contentRaw;
  if (options.stripComments) content = stripCommentsSimple(content, language);
  if (options.normalizeEOL) content = content.replace(/\r\n/g, '\n');

  const stat = await fs.stat(filePath);
  const lines = content.split('\n').length;
  return {
    path: rel,
    filename: path.basename(filePath),
    language,
    bytes: stat.size,
    lineCount: lines,
    sha256: sha256OfString(contentRaw), // hash of original content
    content,
  };
}

async function main() {
  const argv = minimist(process.argv.slice(2), {
    string: ['dir', 'out', 'out-dir', 'patterns'],
    boolean: ['strip-comments', 'normalize-eol', 'pretty-json'],
    alias: { d: 'dir', o: 'out', D: 'out-dir', s: 'strip-comments' },
    default: { dir: '.', out: null, 'strip-comments': false, 'normalize-eol': true },
  });

  const rootDir = path.resolve(argv.dir || '.');
  const projectName = path.basename(rootDir) || 'project';

  // Determine output file:
  // Priority: --out (explicit file) > --out-dir (directory + <project>.toon) > default docs/toon/<project>.toon
  let outFile = null;
  if (argv.out) {
    outFile = path.resolve(argv.out);
  } else if (argv['out-dir']) {
    outFile = path.join(path.resolve(argv['out-dir']), `${projectName}.toon`);
  } else {
    outFile = path.join(process.cwd(), 'docs', 'toon', `${projectName}.toon`);
  }

  const stripComments = !!argv['strip-comments'];
  const normalizeEOL = !!argv['normalize-eol'];
  const patterns = argv.patterns ? argv.patterns.split(',') : ['**/*.js', '**/*.sql'];

  // Collect
  const paths = await collectFiles(rootDir, patterns);
  if (paths.length === 0) {
    console.error('No files found for patterns:', patterns);
    process.exit(1);
  }

  const files = [];
  for (const p of paths) {
    try {
      const meta = await readAndDescribe(p, { stripComments, normalizeEOL });
      files.push(meta);
    } catch (err) {
      console.warn('Failed to read', p, err.message);
    }
  }

  const payload = {
    project: projectName,
    root: rootDir,
    generatedAt: new Date().toISOString(),
    fileCount: files.length,
    files,
  };

  // Encode to TOON
  let toon = null;
  try {
    toon = toonEncode(payload);
  } catch (err) {
    console.error('Failed to encode to TOON:', err.message);
    process.exit(2);
  }

  if (outFile) {
    const outDirToCreate = path.dirname(outFile);
    try {
      await fs.ensureDir(outDirToCreate);
      await fs.outputFile(outFile, toon, 'utf8');
      console.log(`Wrote TOON to ${outFile} (${Buffer.byteLength(toon, 'utf8')} bytes)`);
    } catch (err) {
      // fallback to writing in current working dir
      const fallback = path.join(process.cwd(), `${projectName}.toon`);
      try {
        await fs.outputFile(fallback, toon, 'utf8');
        console.warn(`Could not write to ${outFile}; wrote to ${fallback} instead. (${err.message})`);
      } catch (err2) {
        console.error(`Failed to write TOON to both ${outFile} and fallback ${fallback}:`, err2.message);
        process.exit(3);
      }
    }
  } else {
    // write to stdout (shouldn't happen with the default)
    process.stdout.write(toon);
  }
}

if (require.main === module) {
  main().catch(err => {
    console.error('Fatal:', err);
    process.exit(99);
  });
}
