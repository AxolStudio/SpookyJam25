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

	// Minimal AI fields used by EnemyBrain
	public var aiState:Int = 0; // 0=Wander,1=Attack,2=Flee
	public var aiTimer:Float = 0.0; // seconds until next decision
	public var aiDecisionInterval:Float = 0.6; // base decision interval
	public var aiValue:Int = 1; // score/value of this enemy
	// Track whether the enemy last saw the player (used by EnemyBrain to detect
	// transitions from not-seeing -> seeing so we can interrupt current actions)
	public var lastSawPlayer:Bool = false;

	// No aiControlled flag: the project's central AI (ai.EnemyBrain) is the
	// single source of decision-making. Enemy only exposes movement APIs
	// (startTimedMove/move/stop) and keeps minimal per-frame logic.

	private var _wanderTimer:Float = 0.0;
	private var _actionCooldown:Float = 0.0;
	private var _isWandering:Bool = false;
	private var _targetX:Float = 0.0;
	private var _targetY:Float = 0.0;
	private var _hasTarget:Bool = false;
	private var _captured:Bool = false;
	// Note: per-frame pursuit handling was removed. Timed moves now schedule
	// their own completion so the central AI can be the single decision-maker.

	/**
	 * Start moving in the given angle (degrees) for approximately duration seconds.
	 * This is a lighter-weight alternative to startPursuit when we only care about
	 * a timed movement (based on speed) instead of a world target point.
	 */
	public function startTimedMove(angleDeg:Float, duration:Float):Void
	{
		_actionCooldown = duration;
		// timed move: don't set a persistent target - keep it purely time-driven
		_hasTarget = false;
		// start moving immediately in the given angle
		move(angleDeg);
		// schedule stopping after duration so no per-frame pursuit logic is
		// required inside Enemy.update. The central AI can still call move()
		// each frame if it wants finer control.
		var ctl = {t: 0.0};
		FlxTween.tween(ctl, {t: 1.0}, duration, {
			type: FlxTweenType.ONESHOT,
			onComplete: function(_)
			{
				_actionCooldown = 0;
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
			var ci = new CapturedInfo(variant != null ? variant : "enemy", aggression, wanderSpeed, hue);
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
		// pick base values and round to nearest 0.1; aggression is now in -1.0..1.0
		// (signed) so negative values bias fleeing, positive bias attacking.
		var mag:Float = Math.max(0.0, Math.min(1.0, FlxG.random.float() * FlxG.random.float()));
		var sign:Int = if (FlxG.random.float() < 0.5) -1 else 1;
		aggression = (Math.round(mag * 10.0) / 10.0) * sign;
		skittishness = Math.max(0.0, Math.min(1.0, FlxG.random.float() * FlxG.random.float()));
		skittishness = Math.round(skittishness * 10.0) / 10.0;

		wanderSpeed = 20 + FlxG.random.float() * 50.0;

		speed = wanderSpeed;

		aiDecisionInterval = FlxG.random.float(0.3, 1.2);
		// Compute a simple value: base 1 + aggression weight + speed weight - skittish penalty
		var valF:Float = 1.0 + aggression * 3.0 + (wanderSpeed - 20.0) / 30.0 - skittishness * 2.0;
		var valI:Int = Std.int(Math.max(1, Math.round(valF)));
		aiValue = valI;
		// make sure first decision happens immediately
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

		// Decrement per-enemy timers. The central AI (EnemyBrain) will set
		// aiTimer and call movement APIs (startTimedMove/move/stop). Enemy keeps
		// only the low-level timed-move execution and timer ticks.
		_actionCooldown -= elapsed;
		_wanderTimer -= elapsed;

		// Note: wandering/decision logic moved to ai.EnemyBrain. Enemy.update now
		// avoids any high-level decisions and only ticks timers.
	}

	// Helper: handle ongoing timed-move / pursuit behavior that drives movement
	// toward a target point or stops when the duration elapses.
	// ...existing code...

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
