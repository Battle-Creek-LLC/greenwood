# Dynamic API route over-matches and passes `undefined` params → unhandled 500

- **Severity:** Medium (error/DoS + route confusion; new dynamic-routing feature in v0.34.0)
- **Type:** Routing correctness / unhandled exception
- **Threat model:** HTTP client → `greenwood serve` (and dev server)
- **Affected version:** v0.34.0 (verified end-to-end)
- **Component:** `packages/cli/src/lib/url-utils.js`

## Summary

The dynamic **API** route matcher tests the segment pattern with a trailing `*`
(`:id*`), which greedily matches extra path segments and even the bare prefix. But
parameter extraction uses the pattern **without** the `*`, so those over-matched requests
resolve to the `[id]` handler with `params = undefined`. Typical handler code
(`params.id`) then throws → HTTP 500 instead of a clean 404.

## Root cause

```js
// packages/cli/src/lib/url-utils.js:15-23  — match uses `*`
function getMatchingDynamicApiRoute(apis, route) {
  return Array.from(apis.keys()).find((key) => {
    const page = apis.get(key);
    return page.segment &&
      new URLPattern({ pathname: `${page.segment.pathname}*` }).test(`https://example.com${route}`);
  });
}

// url-utils.js:41-45  — extraction does NOT use `*`
function getParamsFromSegment(compilation, segment, route) {
  return new URLPattern({ pathname: `${compilation.config.basePath}${segment.pathname}` })
    .exec(`https://example.com${route}`)?.pathname?.groups;   // undefined when the path has extra segments
}
```

For a route `/api/users/[id]` (segment `/api/users/:id`):

| request                | `:id*` match | extracted params |
|------------------------|:------------:|------------------|
| `/api/users/42`        | true         | `{ id: "42" }`   |
| `/api/users/42/99/x`   | **true**     | **undefined**    |
| `/api/users` (bare)    | **true**     | **undefined**    |
| `/api/users/`          | false        | undefined        |

The `[id]` handler receives `{ params: undefined }` (see `serve.js:493` /
`plugin-api-routes.js:81`).

Note the **SSR page** matcher (`getMatchingDynamicSsrRoute`, url-utils.js:26-38) does
*not* append `*`, so this inconsistency is specific to API routes.

## Reproduction

Prereq: `yarn install` at repo root, Node >= 22.18.

```sh
cd security-repro/api-route-overmatch-500
./repro.sh
```

### Observed (v0.34.0)

```
GET /api/users/42        ->  {"id":"42"} [200]
GET /api/users/42/99/x   ->  Not Found [500]
GET /api/users           ->  Not Found [500]
GET /api/users/          ->  Not Found [404]
--- server stderr ---
TypeError: Cannot read properties of undefined (reading 'id')
    at handler (.../public/api/users--id-.js:2:21)
```

### Expected

`/api/users/42/99/x` and bare `/api/users` should `404` (they do not match a single
`[id]` segment), matching the behavior of `/api/users/`.

## Suggested fix

Use the same pattern for matching and extraction (drop the `*`, or anchor it), and return
`undefined`/`404` when `getParamsFromSegment` yields no groups for a segmented route.
Related: `getMatchingDynamicApiRoute` also omits `config.basePath` from the pattern (unlike
the SSR matcher), so dynamic API routes fail to match when a `basePath` is configured.
