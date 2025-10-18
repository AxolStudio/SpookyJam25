SpookyJam25 - Small code style guide

Principles
- Prefer Flixel built-ins over custom helpers. Use FlxMath, FlxVelocity, FlxPoint, FlxG helpers where possible.
- Keep code small, obvious, and easy to read. Avoid large helper functions in game object classes.
- Comments: only short headers for public functions/constants and brief notes where behavior is non-obvious.

Examples
- Use `FlxPoint.get()` / `put()` for temporary points.
- Use `this.velocity.set(...)` to set movement for crisp control.

If in doubt: favor clarity and Flixel helpers.