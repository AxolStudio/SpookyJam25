# game-jam-template

[![CI](https://img.shields.io/github/actions/workflow/status/HaxeFlixel/game-jam-template/main.yml?branch=dev&logo=github)](https://github.com/HaxeFlixel/game-jam-template/actions?query=workflow%3ACI)

This is a HaxeFlixel template that is particularly helpful for game jams. It consists of:


This is a [template repository](https://help.github.com/en/github/creating-cloning-and-archiving-repositories/creating-a-repository-from-a-template), simply click "Use this template" to create a copy of it on your own GitHub account!


## Packing sprites at build time

You can pack raw sprite PNGs into a spritesheet automatically during the Haxe compile using the supplied macro and batch helper.

1. Put raw enemy frames in `RAW/sprites/*.png`.
2. Configure a packer by setting one of these environment variables:
	- `TP_PATH` -> path to TexturePacker executable
	- `SHOEBOX_PATH` -> path to Shoebox executable
3. Run the batch script locally to produce `assets/images/enemies.png` and `assets/images/enemies.json`:

```
tools\pack_enemies.bat
```

4. To run the packer automatically at compile time, add the following line to your `.hxml` before compilation steps:

```
--macro "macros.ShoeboxMacro.run('tools/pack_enemies.bat')"
```

This will call the batch script during macro execution; if it fails, the macro will abort compilation with an error.
**Notes:**
- For the first GitHub pages deployment, it can take around 10 minutes for the page to show up. Also, the repository needs to be public.
- The HTML5 builds are made [with the `-final` flag](https://github.com/HaxeFlixel/game-jam-template/blob/105be8f21d3880736ab056da22cb9e4d04d5536c/.github/workflows/main.yml#L19), which means [Dead Code Elimination](https://haxe.org/manual/cr-dce.html) and Minification are active to create smaller `.js` files. However, your code needs to be DCE-safe (avoid reflection or use `@:keep`).
