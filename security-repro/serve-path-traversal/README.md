# Path traversal / arbitrary file read on the production `greenwood serve` static server

- **Severity:** Medium–High (bounded by the standard static-resource file-extension gate)
- **Type:** Path traversal / arbitrary file disclosure (unauthenticated)
- **Threat model:** HTTP client → the production static server (`greenwood serve`)
- **Affected version:** v0.34.0 (verified end-to-end)
- **Component:** `packages/cli/src/lifecycles/serve.js` (`getStaticServer`)

## Summary

`getStaticServer` builds a filesystem URL directly from the raw request path with no
dot-segment containment check. A request path containing literal `..` segments escapes
the output directory and is served by the standard static-resource plugins (js, css,
json, wasm, images, fonts, audio, video), disclosing files outside the web root.

## Root cause

```js
// packages/cli/src/lifecycles/serve.js:234
const url = new URL(`.${ctx.url.replace(basePath, "")}`, outputDir.href);

if (await checkResourceExists(url)) {           // no check that `url` stays under outputDir
  ...
  for (const plugin of resourcePlugins) {        // standard static plugins read `url` off disk
    if (plugin.shouldServe && (await plugin.shouldServe(url, request))) {
      response = await plugin.serve(url, request);
    }
  }
```

Node's HTTP server does not normalize `..` in the request target, so `ctx.url` still
contains literal `..`. `new URL('.' + '/../secrets.json', outputDir)` resolves above
`outputDir`; WHATWG-URL clamps excess `..` to the filesystem root, so any absolute path is
reachable. The standard static plugins (all `plugin-standard-*` except html — see
`lifecycles/config.js:36-38`) gate only on file extension and read whatever `file:` URL
they are handed (e.g. `plugin-standard-javascript.js:24`, `plugin-standard-json.js`).

## Reproduction

Prereq: `yarn install` at repo root, Node >= 22.18.

```sh
cd security-repro/serve-path-traversal
./repro.sh
```

### Observed (v0.34.0)

```
### 1) baseline: /secrets.json ... status=404          # correct
### 2) TRAVERSAL: GET /../secrets.json -> 200 leaks the file
{ "AWS_SECRET_ACCESS_KEY": "TOPSECRET-do-not-leak", "db_password": "hunter2" }
  status=200
### 3) absolute read ... /tmp/pwned.css -> status=200
ARBITRARY-FILE-READ-PROOF
```

## Scope / caveats (stated honestly)

- Limited to files whose extension a standard static plugin handles
  (`js`/`css`/`json`/`wasm`/images/fonts/audio/video). This still covers source, config,
  and `.json`/`.js` files that commonly hold secrets. `/etc/passwd` (no supported
  extension) and `.env` are **not** served.
- Requires a client that sends non-normalized `..` (e.g. `curl --path-as-is`, scripts,
  some proxies). Browsers normalize `..` before sending. Encoded `..%2f` does **not**
  traverse (the URL constructor keeps `%2f` intact).
- The `greenwood develop` server is **not** affected by this vector (it resolves through
  `resolveForRelativeUrl`); see the separate `/~` dev-server finding for a dev-server read.

## Suggested fix

After constructing `url`, resolve it and assert `url.pathname` starts with
`outputDir.pathname` (reject otherwise), or collapse/reject `..` segments before building
the path.
