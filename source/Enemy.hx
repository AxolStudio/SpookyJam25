package;

import flixel.FlxG;
import flixel.effects.particles.FlxEmitter;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import haxe.ds.StringMap;

class Enemy extends GameObject
{
	public var variant:String;
	public static var SHARED_FRAMES:FlxAtlasFrames = null;
	public static var VARIANTS:Array<String> = [];
	public static var VARIANT_FRAMES:StringMap<Array<String>> = null;

	private static function ensureFrames():Void
	{
		if (SHARED_FRAMES != null)
			return;
		SHARED_FRAMES = FlxAtlasFrames.fromSparrow("assets/images/enemies.png", "assets/images/enemies.xml");
		VARIANTS = [];
		VARIANT_FRAMES = new StringMap<Array<String>>();
		for (f in 0...SHARED_FRAMES.numFrames)
		{
			var rawName:String = SHARED_FRAMES.getByIndex(f).name;
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
				list.push(rawName);
			}
		}
	}

	private function spawnCrumbleParticles(count:Int):Void
	{
		try
		{
			var emitter = new FlxEmitter();
			// emit along the bottom of the sprite so particles "rain" down
			emitter.setPosition(x + 2, y + height - 2);
			emitter.setSize(Math.max(2, width - 4), 2);
			emitter.makeParticles(2, 2, 0xFF888888, count);
			// slightly longer lifespan for falling dust
			emitter.lifespan.max = 0.5;
			emitter.lifespan.min = 0.2;
			// small horizontal spread, positive Y speeds so particles fall downwards
			emitter.speed.start.min = -10;
			emitter.speed.start.max = 10;
			emitter.speed.end.min = 20;
			emitter.speed.end.max = 60;
			// gentle downward acceleration (gravity-like)
			emitter.acceleration.start.min.y = 40;
			emitter.acceleration.end.min.y = 120;
			emitter.alpha.start.min = 1.0;
			emitter.alpha.end.max = 0.0;
			emitter.start(true);
			try
			{
				FlxG.state.add(emitter);
			}
			catch (e:Dynamic) {}
		}
		catch (e:Dynamic) {}
	}

	public function capture(byPlayer:Player):Void
	{
		if (!exists)
			return;
		velocity.set(0, 0);
		acceleration.set(0, 0);
		try
		{
			trace("Enemy.capture() start - variant=" + (variant == null ? "null" : variant));
		}
		catch (e:Dynamic) {}
		try
		{
			if (animation != null)
			{
				animation.stop();
			}
		}
		catch (e:Dynamic) {}

		try
		{
			try
			{
				trace("Enemy.capture() creating shader");
			}
			catch (e:Dynamic) {}
			var sh = new shaders.PhotoDissolve();
			try
			{
				trace("Enemy.capture() shader created");
			}
			catch (e:Dynamic) {}
			sh.desat = 1.0;
			sh.dissolve = 0.0;
			this.shader = sh;
			try
			{
				trace("Enemy.capture() shader assigned: " + (this.shader != null));
			}
			catch (e:Dynamic) {}

			FlxTween.tween(sh, {dissolve: 1.0}, Constants.PHOTO_DISSOLVE_DURATION, {
				startDelay: Constants.PHOTO_DISSOLVE_DELAY,
				type: FlxTweenType.ONESHOT,
				ease: FlxEase.quadOut,
				onStart: function(_)
				{
					try
					{
						trace("Enemy.capture() tween started");
					}
					catch (e:Dynamic) {}
					try
					{
						spawnCrumbleParticles(20);
					}
					catch (e:Dynamic) {}
				},
				onComplete: function(_)
				{
					try
					{
						trace("Enemy.capture() tween complete");
					}
					catch (e:Dynamic) {}
					exists = false;
					alive = false;
					if (byPlayer != null)
						byPlayer.captured.push(variant != null ? variant : "enemy");
					kill();
				}
			});
		}
		catch (e:Dynamic)
		{
			try
			{
				trace("Enemy.capture() shader failed: " + Std.string(e));
			}
			catch (e:Dynamic) {}
			color = 0xAAAAAA;
			try
			{
				if (animation != null)
					animation.stop();
			}
			catch (e:Dynamic) {}
			FlxTween.tween(this, {alpha: 0}, Constants.PHOTO_DISSOLVE_DURATION, {
				startDelay: Constants.PHOTO_DISSOLVE_DELAY,
				onStart: function(_)
				{
					try
					{
						trace("Enemy.capture() fallback tween started");
					}
					catch (e:Dynamic) {}
					try
					{
						spawnCrumbleParticles(24);
					}
					catch (e:Dynamic) {}
				},
				onComplete: function(_)
				{
					try
					{
						trace("Enemy.capture() fallback complete");
					}
					catch (e:Dynamic) {}
					exists = false;
					alive = false;
					if (byPlayer != null)
						byPlayer.captured.push(variant != null ? variant : "enemy");
					kill();
				}
			});
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
		if (variant == null)
			this.variant = pickVariant();
		else
			this.variant = variant;
		speed = 50;
	}

	public override function buildGraphics():Void
	{
		ensureFrames();
		if (SHARED_FRAMES != null)
		{
			this.frames = SHARED_FRAMES;
			var variant:String = this.variant;
			if (variant == null)
				variant = pickVariant();
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
