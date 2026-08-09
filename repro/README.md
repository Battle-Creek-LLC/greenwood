# Reproduction: wasm direct import content-type gate (#1723)

## What this reproduces

`greenwood build` crashes with an acorn `SyntaxError` that is attributed to the
`greenwood-import-meta-url` Rollup plugin when a binary asset is reached through a
direct `import`, instead of failing with a normal Rollup parse error.

## The important discriminator

There are two ways to reference a binary asset like `.wasm` from a script:

- `new URL("./add.wasm", import.meta.url)` — this pattern is **not** affected. A build
  using it completes cleanly.
- `import * as wasm from "./add.wasm";` (a **direct** import) — this pattern crashes.

This repro uses the direct import form on purpose. If you swap it for the `new URL(...)`
form, you will get a clean build and may conclude the bug does not reproduce. It does;
you are just testing the unaffected code path.

## Setup

No Greenwood config file and no plugins are used. This reproduces on a default,
config-less Greenwood project.

## How to run

From inside this `repro/` directory:

```
npm install @greenwood/cli
npx greenwood build
```

## Expected output, unfixed

The build fails with an acorn `SyntaxError`, something like:

```
SyntaxError: Unexpected character ' ' (1:0)
```

with `plugin: 'greenwood-import-meta-url'` and `hook: 'transform'` in the error, and
the `id` pointing at `add.wasm`.

## Expected output, fixed

The build still fails — a direct import of a wasm module is genuinely unsupported —
but the error is a Rollup-native `PARSE_ERROR`, with no `greenwood-import-meta-url`
attribution.
