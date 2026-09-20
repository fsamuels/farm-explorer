# Distribution — Web export to itch.io

## One-time setup (per machine)

1. In the Godot editor: **Editor → Manage Export Templates** → install templates
   matching the editor version (must match exactly, or Web export fails).
2. `project/export_presets.cfg` already defines a `Web` preset (export path
   `builds/web/index.html`, relative to `project/` — gitignored, regenerated
   each export).

## Exporting a build

1. Open the project in Godot, **Project → Export…**, select the `Web` preset,
   **Export Project**. This writes `builds/web/` (an `index.html` plus `.wasm`,
   `.pck`, and `.js` files).
2. Zip the *contents* of `builds/web/` (not the folder itself — itch.io expects
   `index.html` at the zip root).

## Uploading to itch.io

1. Create a new project at itch.io → **Kind of project: HTML**.
2. Upload the zip from the step above; check **"This file will be played in
   the browser"** on it.
3. Under **Embed options**, set a viewport large enough for the game (matches
   `project/project.godot`'s `window/size/viewport_width/height`, 3072×1728 —
   itch.io will scale it, but starting close to native avoids upscaling
   blur) and enable **fullscreen button** and **SharedArrayBuffer support**
   (required for Godot 4 Web exports; itch.io serves the COOP/COEP headers
   this needs automatically once checked).
4. Publish as free / pay-what-you-want, per draft or public as desired.

## Known risk, untested

This project has never done a Web export before. Two things to check on the
first attempt, before assuming the itch.io page is broken:

- **Asset size / load time** — the NAIP ground texture and multiple `.glb`
  models (see [repo-structure.md](repo-structure.md)) may make the initial
  `.pck` download large for a browser context; if load hangs, check the
  browser console for fetch/decompress errors before suspecting itch.io.
- **SharedArrayBuffer** — if the page loads but the canvas stays black with a
  console error mentioning `SharedArrayBuffer`, double check the itch.io
  embed setting above; it's the most common cause of an otherwise-correct
  Godot Web export failing only when hosted.
