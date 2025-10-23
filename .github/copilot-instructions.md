```instructions
SpookyJam25 — Copilot instructions (canonical)

Purpose
Give clear, non-contradictory rules for assistants working on this HaxeFlixel repo. Follow these exactly.

Core repository facts
- Entry: `source/Main.hx` → `PlayState`.
- Key files: `source/GameMap.hx` (map gen & tilemaps), `source/Enemy.hx` (AI & LOS), `source/PlayState.hx` (game loop), `source/shaders/` (fog/photo shaders).

Assistant rules (must follow)
- DO NOT add comments inside source files. Prefer clear code and concise PR descriptions.
- ALWAYS prefer Flixel helpers (e.g., `FlxPoint`, `FlxRect`, `FlxColor`, `FlxTilemap.ray`) over custom implementations.
- KEEP core lifecycle methods (`new`, `create`, `update`) short; extract complex logic into well-named helpers.
- DO NOT launch or run the game (no interactive runs). Never run `lime test`, or VSCode tasks that open the game window. If you need to run the game for debugging, ask the maintainer first.
- MINIMIZE try/catch: only use when recovery is expected; prefer failing fast to reveal bugs.
- AVOID runtime reflection (`Reflect`) entirely; use static APIs and `cast` only when necessary.

Build & assets
- Packing: run `tools\pack_enemies.bat` locally to pack sprites. To invoke during compile, add the Shoebox macro to `.hxml` as documented in README.
- DO NOT run interactive `lime test` from an assistant; small non-interactive checks may be acceptable only after maintainer approval.

Editing patterns & safety
- Prefer `wallsMap` (`FlxTilemap`) APIs over manually iterating `wallGrid`. If you change tile data at runtime, ensure both stay consistent.
- When altering core behavior, add small focused tests or run a minimal static compile check (only with approval).

Non-discoverable questions to ask maintainer
- Preferred Haxe/Lime versions for CI, and whether deterministic seeds are required for map generation.

If anything needs clarification, always ask one concise question rather than guessing.
```

