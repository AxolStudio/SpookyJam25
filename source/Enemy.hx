package;

import haxe.ds.StringMap;
import flixel.FlxG;
import flixel.effects.particles.FlxEmitter;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxAngle;
import flixel.math.FlxPoint;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import util.ColorHelpers;

class Enemy extends GameObject
{
	public var variant:String;

	private var hue:Int;

	public static var VARIANTS:Array<String> = [];
	public static var VARIANT_FRAMES:StringMap<Array<String>> = null;

	public var aggression:Float = 0.0;
	public var skittishness:Float = 0.0;
	public var wanderSpeed:Float = 40.0;
	public var power:Int = 3; // 1-5 stars, calculated from stats

	public var aiState:Int = 0;
	public var aiTimer:Float = 0.0;
	public var aiDecisionInterval:Float = 0.6;
	public var aiValue:Int = 1;
	public var lastSawPlayer:Bool = false;
	public var stunTimer:Float = 0;

	private var _captured:Bool = false;

	public function startTimedMove(angleDeg:Float, duration:Float):Void
	{
		move(angleDeg);
		var ctl = {t: 0.0};
		FlxTween.tween(ctl, {t: 1.0}, duration, {
			type: FlxTweenType.ONESHOT,
			onComplete: function(_)
			{
				stop();
			}
		});
	}

	private static function ensureFrames():Void
	{
		if (VARIANTS.length > 0)
			return;
		var SHARED_FRAMES:FlxAtlasFrames = FlxAtlasFrames.fromSparrow("assets/images/enemies.png", "assets/images/enemies.xml");
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
		var emitter = new FlxEmitter();
		emitter.setPosition(x + 2, y + height - 2);
		emitter.setSize(Math.max(2, width - 4), 2);
		emitter.makeParticles(2, 2, 0xFF888888, count);
		emitter.lifespan.max = 0.5;
		emitter.lifespan.min = 0.2;
		emitter.speed.start.min = -10;
		emitter.speed.start.max = 10;
		emitter.speed.end.min = 20;
		emitter.speed.end.max = 60;
		emitter.acceleration.start.min.y = 40;
		emitter.acceleration.end.min.y = 120;
		emitter.alpha.start.min = 1.0;
		emitter.alpha.end.max = 0.0;
		emitter.start(true);
		if (FlxG.state != null)
			FlxG.state.add(emitter);
	}

	public function capture(byPlayer:Player):Void
	{
		if (!exists || !alive)
			return;
		_captured = true;
		if (byPlayer != null)
		{
			var ci = new CapturedInfo(variant != null ? variant : "enemy", aggression, wanderSpeed, hue, 1, power);
			byPlayer.captured.push(ci);
		}

		velocity.set(0, 0);
		acceleration.set(0, 0);
		animation.stop();
		stop();

		alive = false;
		exists = true;
		var sh = new shaders.PhotoDissolve();
		sh.desat = 1.0;
		sh.dissolve = 0.0;
		this.shader = sh;
		FlxTween.tween(this.shader, {dissolve: 1.0}, Constants.PHOTO_DISSOLVE_DURATION, {
			startDelay: Constants.PHOTO_DISSOLVE_DELAY,
			type: FlxTweenType.ONESHOT,
			ease: FlxEase.quadOut,
			onStart: function(_)
			{
				spawnCrumbleParticles(20);
			},
			onComplete: function(_)
			{
				exists = false;
				alive = false;
			}
		});
	}

	public static function pickVariant():String
	{
		ensureFrames();
		FlxG.random.shuffle(VARIANTS);
		return VARIANTS[0];
	}

	public function new(tileX:Int, tileY:Int, ?AtmosphereHue:Int)
	{
		variant = pickVariant();
		hue = FlxG.random.int(0, 359, [for (h in AtmosphereHue - 10...AtmosphereHue + 11) (h + 360) % 360]);
		super(tileX, tileY);

		speed = 50;
		width = height = 12;
		offset.x = 2;
		offset.y = 4;
		x += 2;
		y += 4;
		randomizeBehavior();
	}

	public function randomizeBehavior():Void
	{
		var mag:Float = Math.max(0.0, Math.min(1.0, FlxG.random.float() * FlxG.random.float()));
		var sign:Int = if (FlxG.random.float() < 0.5) -1 else 1;
		aggression = (Math.round(mag * 10.0) / 10.0) * sign;
		skittishness = Math.max(0.0, Math.min(1.0, FlxG.random.float() * FlxG.random.float()));
		skittishness = Math.round(skittishness * 10.0) / 10.0;

		wanderSpeed = 20 + FlxG.random.float() * 50.0;

		speed = wanderSpeed;

		aiDecisionInterval = FlxG.random.float(0.3, 1.2);
		var valF:Float = 1.0 + aggression * 3.0 + (wanderSpeed - 20.0) / 30.0 - skittishness * 2.0;
		var valI:Int = Std.int(Math.max(1, Math.round(valF)));
		aiValue = valI;
		power = Std.int(Math.max(1, Math.min(5, valI)));

		aiTimer = 0.0;
	}

	public override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (_captured)
		{
			velocity.set(0, 0);
			acceleration.set(0, 0);
			return;
		}
		if (!this.isOnScreen())
			return;

		if (stunTimer > 0)
		{
			stunTimer -= elapsed;
			velocity.set(0, 0);
			acceleration.set(0, 0);
			return;
		}
	}

	public override function buildGraphics():Void
	{
		ensureFrames();
		frames = FlxAtlasFrames.fromSparrow(ColorHelpers.getHueColoredBmp("assets/images/enemies.png", hue), "assets/images/enemies.xml");
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
