package;

import flixel.FlxG;
import flixel.effects.particles.FlxEmitter;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import haxe.ds.StringMap;
import flixel.math.FlxPoint;
import flixel.math.FlxAngle;

class Enemy extends GameObject
{
	public var variant:String;

	public static var SHARED_FRAMES:FlxAtlasFrames = null;
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

	private var _wanderTimer:Float = 0.0;
	private var _actionCooldown:Float = 0.0;
	private var _isWandering:Bool = false;
	private var _targetX:Float = 0.0;
	private var _targetY:Float = 0.0;
	private var _hasTarget:Bool = false;
	private var _captured:Bool = false;
	private var _pursuingThrough:Bool = false;

	/**
	 * Start moving in the given angle (degrees) for approximately duration seconds.
	 * This is a lighter-weight alternative to startPursuit when we only care about
	 * a timed movement (based on speed) instead of a world target point.
	 */
	public function startTimedMove(angleDeg:Float, duration:Float):Void
	{
		_pursuingThrough = true;
		_actionCooldown = duration;
		// timed move: don't set a persistent target - keep it purely time-driven
		_hasTarget = false;
		move(angleDeg);
	}

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
		if (!exists)
			return;
		velocity.set(0, 0);
		acceleration.set(0, 0);
		_captured = true;
		alive = false;
		exists = true;
		#if (debug)
		if (variant != null)
			trace("Enemy.capture() start - variant=" + variant);
		#end
		if (animation != null)
			animation.stop();
		stop();
		var shaderOk:Bool = false;
		try
		{
			var sh = new shaders.PhotoDissolve();
			sh.desat = 1.0;
			sh.dissolve = 0.0;
			this.shader = sh;
			shaderOk = true;
		}
		catch (e:Dynamic)
		{
			shaderOk = false;
		}
		if (shaderOk)
		{
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
					if (byPlayer != null)
						byPlayer.captured.push(variant != null ? variant : "enemy");

				}
			});
		}
		else
		{
			color = 0xAAAAAA;
			if (animation != null)
				animation.stop();
			FlxTween.tween(this, {alpha: 0}, Constants.PHOTO_DISSOLVE_DURATION, {
				startDelay: Constants.PHOTO_DISSOLVE_DELAY,
				onStart: function(_)
				{
					spawnCrumbleParticles(24);
				},
				onComplete: function(_)
				{
					exists = false;
					alive = false;
					if (byPlayer != null)
						byPlayer.captured.push(variant != null ? variant : "enemy");

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
		width = height = 12;
		offset.x = 2;
		offset.y = 4;
		x += 2;
		y += 4;
	}

	public function randomizeBehavior(atmosphereHue:Int):Void
	{
		// pick base values and round to nearest 0.1 so they behave like percentages (0.0..1.0)
		aggression = Math.max(0.0, Math.min(1.0, FlxG.random.float() * FlxG.random.float()));
		aggression = Math.round(aggression * 10.0) / 10.0;
		skittishness = Math.max(0.0, Math.min(1.0, FlxG.random.float() * FlxG.random.float()));
		skittishness = Math.round(skittishness * 10.0) / 10.0;

		wanderSpeed = 20 + FlxG.random.float() * 50.0;

		speed = wanderSpeed;
		var hue:Int = -1;
		for (i in 0...8)
		{
			var cand = Std.int(FlxG.random.float() * 360);
			var diff = Math.abs(((cand - atmosphereHue + 540) % 360) - 180);
			if (diff > 5)
			{
				hue = cand;
				break;
			}
			if (i == 7)
				hue = cand;
		}
		var sat:Float = 0.7;
		var vLight:Float = 0.60;
		var vDark:Float = 0.18;
		var hn:Float = (hue % 360) / 360.0;
		var hh:Float = (hn - Math.floor(hn)) * 6.0;
		var ii:Int = Std.int(Math.floor(hh));
		var ff:Float = hh - ii;
		var vv:Float = vLight;
		var p:Float = vv * (1.0 - sat);
		var q:Float = vv * (1.0 - sat * ff);
		var t:Float = vv * (1.0 - sat * (1.0 - ff));
		var rf:Float = 0.0;
		var gf:Float = 0.0;
		var bf:Float = 0.0;
		if (ii == 0)
		{
			rf = vv;
			gf = t;
			bf = p;
		}
		else if (ii == 1)
		{
			rf = q;
			gf = vv;
			bf = p;
		}
		else if (ii == 2)
		{
			rf = p;
			gf = vv;
			bf = t;
		}
		else if (ii == 3)
		{
			rf = p;
			gf = q;
			bf = vv;
		}
		else if (ii == 4)
		{
			rf = t;
			gf = p;
			bf = vv;
		}
		else
		{
			rf = vv;
			gf = p;
			bf = q;
		}
		var ri:Int = Std.int(Math.max(0, Math.min(255, Std.int(Math.round(rf * 255.0)))));
		var gi:Int = Std.int(Math.max(0, Math.min(255, Std.int(Math.round(gf * 255.0)))));
		var bi:Int = Std.int(Math.max(0, Math.min(255, Std.int(Math.round(bf * 255.0)))));
		color = (ri << 16) | (gi << 8) | bi;
		// AI tuning: decision interval and value (points)
		aiDecisionInterval = 0.3 + FlxG.random.float() * 0.9; // 0.3..1.2s
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

		if (_pursuingThrough)
		{
			var mid:FlxPoint = this.getMidpoint();
			var dxT:Float = _targetX - mid.x;
			var dyT:Float = _targetY - mid.y;
			var distT:Float = Math.sqrt(dxT * dxT + dyT * dyT);
			if (distT <= 6 || _actionCooldown <= 0)
			{
				_pursuingThrough = false;

				stop();
			}
			else
			{
				var radT:Float = Math.atan2(dyT, dxT);
				move(radT * FlxAngle.TO_DEG);
				mid.put();
				return;
			}
		}

		_actionCooldown -= elapsed;
		_wanderTimer -= elapsed;

		var ps:PlayState = cast(FlxG.state, PlayState);
		if (ps == null)
			return;
		var player:Player = ps.player;

		if (player != null)
		{
			var pm:FlxPoint = player.getMidpoint();
			var em:FlxPoint = this.getMidpoint();
			var dx:Float = pm.x - em.x;
			var dy:Float = pm.y - em.y;
			var dist:Float = Math.sqrt(dx * dx + dy * dy);
			var visible:Bool = (dist < 160);
			if (visible && _actionCooldown <= 0)
			{
				var aRoll:Float = FlxG.random.float();
				var sRoll:Float = FlxG.random.float();
				if (aRoll < aggression && aRoll > skittishness)
				{
					speed = wanderSpeed * (1.5 + FlxG.random.float() * 1.0);

					var angleToPlayer:Float = Math.atan2(pm.y - em.y, pm.x - em.x) * FlxAngle.TO_DEG;
					var extraDistance:Float = 48.0 + FlxG.random.float() * 24.0;
					// compute a world point at extraDistance along the angle
					var rad:Float = angleToPlayer * FlxAngle.TO_RAD;
					_targetX = pm.x + Math.cos(rad) * extraDistance;
					_targetY = pm.y + Math.sin(rad) * extraDistance;
					_pursuingThrough = true;
					move(angleToPlayer);
					_actionCooldown = 0.6 + FlxG.random.float() * 0.8;
					pm.put();
					em.put();
					return;
				}
				else if (sRoll < skittishness && sRoll > aggression)
				{
					speed = wanderSpeed * (1.8 + FlxG.random.float() * 0.6);
					var fleeAngle = Math.atan2(-dy, -dx) * FlxAngle.TO_DEG + (FlxG.random.float() - 0.5) * 0.8;
					move(fleeAngle);
					_actionCooldown = 0.8 + FlxG.random.float() * 1.2;
					return;
				}
			}
		}

		if (_wanderTimer <= 0)
		{
			_wanderTimer = 0.6 + FlxG.random.float() * 1.6;
			if (FlxG.random.float() < 0.55)
			{
				var ang = (FlxG.random.float() * Math.PI * 2);
				move(ang * FlxAngle.TO_DEG);
				speed = wanderSpeed * (0.7 + FlxG.random.float() * 0.8);
				_actionCooldown = 0.2 + FlxG.random.float() * 0.6;
			}
			else
			{
				stop();
			}
		}
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
