# Code injection in `@greenwood/plugin-import-raw` (unescaped template literal)

- **Severity:** High (build-time RCE and/or shipped-to-browser code execution)
- **Type:** Code injection via template-literal interpolation
- **Threat model:** Author of any file imported with `?type=raw` — a dependency asset, CMS
  content, or user upload processed at build time. Not a direct HTTP-client vector.
- **Affected version:** v0.34.0 (verified — the injected expression executes)
- **Component:** `packages/plugin-import-raw/src/index.js:100`

## Summary

The raw-import loader wraps a file's contents in a JS **template literal** but only escapes
newlines and backslashes — **not** backticks or `${` interpolation. File contents
containing `${ ... }` are interpolated as live JavaScript when the generated module is
evaluated (during SSR/prerender at build time, and in the browser, since the module is
shipped to the client). A lone backtick also breaks the build.

## Root cause

```js
// packages/plugin-import-raw/src/index.js:100
const contents =
  `const raw = \`${body.replace(/\r?\n|\r/g, " ").replace(/\\/g, "\\\\")}\`;\nexport default raw;`;
```

`body` (untrusted file bytes) is placed inside a backtick template with no escaping of
`` ` `` or `${`. Sibling loaders handle this correctly with `JSON.stringify`
(`plugin-import-json/src/index.js:26`); this one does not.

## Reproduction

```sh
cd security-repro/import-raw-code-injection
node repro.mjs
```

### Observed (v0.34.0)

```
generated module (shipped to bundler + browser):
const raw = `prefix ${ globalThis.__PWNED__ = 40 + 2 } suffix`;
export default raw;

default export => "prefix 42 suffix"
globalThis.__PWNED__ => 42   <-- INJECTED EXPRESSION EXECUTED
```

A payload such as `${globalThis.process.mainModule.require('child_process').execSync('id')}`
executes at module evaluation.

## Suggested fix

Build the module body with `JSON.stringify(body)` instead of a raw template literal:

```js
const contents = `const raw = ${JSON.stringify(body)};\nexport default raw;`;
```
