package;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.ds.StringMap;

class Enemy extends GameObject
{
	// shared frames and variant list (initialized once)
	public static var SHARED_FRAMES:FlxAtlasFrames = null;
	public static var VARIANTS:Array<String> = [];
	// map from variant id -> array of frame names (as present in the atlas)
	public static var VARIANT_FRAMES:StringMap<Array<String>> = null;

	private static function ensureFrames():Void
	{
		if (SHARED_FRAMES != null)
			return;
		SHARED_FRAMES = FlxAtlasFrames.fromSparrow("assets/images/enemies.png", "assets/images/enemies.xml");
		VARIANTS = [];
		VARIANT_FRAMES = new StringMap<Array<String>>();

		// Iterate atlas frames and collect prefixes where frame names end with a single letter suffix (a,b,c...)
		for (f in 0...SHARED_FRAMES.numFrames)
		{
			var rawName:String = SHARED_FRAMES.getByIndex(f).name;
			// strip extension if present
			var base = rawName;
			var dot = base.lastIndexOf('.');
			if (dot >= 0)
				base = base.substr(0, dot);
			if (base.length < 2)
				continue;
			var lastChar = base.charAt(base.length - 1);
			if (lastChar >= 'a' && lastChar <= 'z')
			{
				var prefix = base.substr(0, base.length - 1);
				var list = VARIANT_FRAMES.get(prefix);
				if (list == null)
				{
					list = [];
					VARIANT_FRAMES.set(prefix, list);
					VARIANTS.push(prefix);
				}
				// store the atlas frame name (use rawName as that's what the atlas uses)
				list.push(rawName);
			}
		}
	}

	public static function pickVariant():String
	{
		ensureFrames();
		if (VARIANTS == null || VARIANTS.length == 0)
			return null;
		var idx:Int = Std.int(FlxG.random.float() * VARIANTS.length);
		if (idx < 0)
			idx = 0;
		if (idx >= VARIANTS.length)
			idx = VARIANTS.length - 1;
		return VARIANTS[idx];
	}

	public function new(tileX:Int, tileY:Int, ?variant:String)
	{
		super(tileX, tileY);
		speed = 50;
	}

	public override function buildGraphics():Void
	{
		ensureFrames();
		if (SHARED_FRAMES != null)
		{
			this.frames = SHARED_FRAMES;
			var variant:String = pickVariant();
			if (variant != null)
			{
				var names = VARIANT_FRAMES.get(variant);
				if (names != null && names.length > 0)
				{
					animation.addByNames(variant, names, 12, true);
					animation.play(variant);
				}
				else
				{
					animation.addByPrefix(variant, variant, 12, true);
					animation.play(variant);
				}
			}
		}
	}
}
