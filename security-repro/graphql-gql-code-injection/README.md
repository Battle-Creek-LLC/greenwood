# Code injection in `@greenwood/plugin-graphql` `.gql` loader (unescaped template literal)

- **Severity:** High (build-time RCE and/or shipped-to-browser code execution)
- **Type:** Code injection via template-literal interpolation
- **Threat model:** Author of a `.gql` file loaded by the plugin — e.g. a query file pulled
  from a dependency or untrusted source.
- **Affected version:** v0.34.0 (verified — the injected statement executes)
- **Component:** `packages/plugin-graphql/src/index.js:33-34`

## Summary

The `.gql` loader wraps file contents in a JS template literal with **no escaping at all**
(worse than the sibling `plugin-import-raw`, which at least handles backslashes/newlines).
A `.gql` file containing a backtick can close the literal and inject arbitrary top-level
statements/exports, which run when the generated module is evaluated at build time and in
the browser.

## Root cause

```js
// packages/plugin-graphql/src/index.js:31-42
async serve(url) {
  const js = await fs.readFile(url, "utf-8");
  const body = `
      export default \`${js}\`;
    `;
  return new Response(body, { headers: new Headers({ "Content-Type": this.contentType[0] }) });
}
```

## Reproduction

```sh
cd security-repro/graphql-gql-code-injection
node repro.mjs
```

### Observed (v0.34.0)

```
generated module:
      export default `query { a }` ; globalThis.__PWNED__ = 40 + 2; export const x = ``;

globalThis.__PWNED__ => 42   <-- INJECTED STATEMENT EXECUTED
```

## Suggested fix

Serialize the query text safely:

```js
const body = `export default ${JSON.stringify(js)};`;
```
