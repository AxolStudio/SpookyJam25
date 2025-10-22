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

	// AI parameters (set randomly at spawn)
	public var aggression:Float = 0.0; // 0..1, higher => more likely to attack
	public var skittishness:Float = 0.0; // 0..1, higher => more likely to flee
	public var wanderSpeed:Float = 40.0; // base wander speed (pixels/sec)

	private var _wanderTimer:Float = 0.0;
	private var _actionCooldown:Float = 0.0;
	private var _isWandering:Bool = false;
	private var _targetX:Float = 0.0;
	private var _targetY:Float = 0.0;
	private var _captured:Bool = false;
	private var _pursuingThrough:Bool = false;

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
		if (FlxG.state != null)
		{
			try
			{
				FlxG.state.add(emitter);
			}
			catch (e:Dynamic) {}
		}
	}

	public function capture(byPlayer:Player):Void
	{
		if (!exists)
			return;
		// stop motion immediately
		velocity.set(0, 0);
		acceleration.set(0, 0);
		_captured = true;
		// optional trace for debugging
		if (variant != null)
			try
			{
				trace("Enemy.capture() start - variant=" + variant);
			}
			catch (e:Dynamic) {}
		if (animation != null)
			animation.stop();

		// Try to apply a PhotoDissolve shader; if shader creation fails, fall back to a simple fade.
		try
		{
			var sh = new shaders.PhotoDissolve();
			sh.desat = 1.0;
			sh.dissolve = 0.0;
			this.shader = sh;
			FlxTween.tween(sh, {dissolve: 1.0}, Constants.PHOTO_DISSOLVE_DURATION, {
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
					kill();
				}
			});
		}
		catch (e:Dynamic)
		{
			// fallback: simple fade out
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
		// slightly reduce hitbox so enemies fit corridors better (demo-friendly)
		try
		{
			this.setOffsetAmount(2);
		}
		catch (e:Dynamic) {}
	}

	// Initialize randomized behavior and color. Call after construction (or from spawn code).
	public function randomizeBehavior(atmosphereHue:Int):Void
	{
		// aggression and skittishness: skew towards low-medium values but allow extremes
		aggression = Math.max(0.0, Math.min(1.0, FlxG.random.float() * FlxG.random.float()));
		skittishness = Math.max(0.0, Math.min(1.0, FlxG.random.float() * FlxG.random.float()));
		// pick wander speed between 20 and 70
		wanderSpeed = 20 + FlxG.random.float() * 50.0;
		// set base speed to wanderSpeed
		speed = wanderSpeed;
		// color tint using same hue algorithm as GameMap.getHueColoredBmp but applied as a simple tint
		// choose a hue avoiding atmosphereHue +/- 5 degrees
		var hAvoidMin = (atmosphereHue - 15 + 360) % 360;
		var hAvoidMax = (atmosphereHue + 15) % 360;
		var hue:Int = 0;
		for (i in 0...8)
		{
			var cand = Std.int(FlxG.random.float() * 360);
			var diff = Math.abs((cand - atmosphereHue + 540) % 360 - 180);
			if (diff > 5)
			{
				hue = cand;
				break;
			}
			// on last attempt just accept
			if (i == 7)
				hue = cand;
		}
		// convert hue to an approximate RGB tint using same HSV->RGB as GameMap
		var sat:Float = 0.7;
		var vLight:Float = 0.60;
		var vDark:Float = 0.18;
		var hn:Float = (hue % 360) / 360.0;
		var hh:Float = (hn - Math.floor(hn)) * 6.0;
		var ii:Int = Std.int(Math.floor(hh));
		var ff:Float = hh - ii;
		var vv:Float = vLight; // use lighter value for a tint
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
		color = (0xFF << 24) | (ri << 16) | (gi << 8) | bi;
	}

	// Basic line-of-sight check against the tilemap's wallGrid (tile coordinates)
	private function hasLineOfSightTo(px:Float, py:Float, tilemap:GameMap):Bool
	{
		if (tilemap == null || tilemap.wallGrid == null)
			return false;
		var tx0:Int = Std.int((x + width * 0.5) / Constants.TILE_SIZE);
		var ty0:Int = Std.int((y + height * 0.5) / Constants.TILE_SIZE);
		var tx1:Int = Std.int(px / Constants.TILE_SIZE);
		var ty1:Int = Std.int(py / Constants.TILE_SIZE);
		// Bresenham-ish step along line in tile-space
		var rawdx:Int = tx1 - tx0;
		var rawdy:Int = ty1 - ty0;
		var dx:Int = rawdx >= 0 ? rawdx : -rawdx;
		var dy:Int = rawdy >= 0 ? rawdy : -rawdy;
		var sx:Int = tx0 < tx1 ? 1 : -1;
		var sy:Int = ty0 < ty1 ? 1 : -1;
		var err:Int = dx - dy;
		var cx:Int = tx0;
		var cy:Int = ty0;
		while (true)
		{
			if (cx < 0 || cy < 0 || cy >= tilemap.wallGrid.length || cx >= tilemap.wallGrid[0].length)
				return false;
			if (tilemap.wallGrid[cy][cx] == 1)
				return false;
			if (cx == tx1 && cy == ty1)
				break;
			var e2:Int = 2 * err;
			if (e2 > -dy)
			{
				err -= dy;
				cx += sx;
			}
			if (e2 < dx)
			{
				err += dx;
				cy += sy;
			}
		}
		return true;
	}

	// Simple AI update: wander, occasionally roll to chase or flee when player is nearby and visible
	public override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (_captured)
		{
			// ensure they're not moving
			velocity.set(0, 0);
			acceleration.set(0, 0);
			return;
		}
		// don't run AI for offscreen enemies to save CPU and avoid surprise spawns
		try
		{
			var cam = FlxG.camera;
			if (cam != null)
			{
				var screenX:Float = (x + width * 0.5) - cam.scroll.x;
				var screenY:Float = (y + height * 0.5) - cam.scroll.y;
				var margin:Float = 32.0; // pixels offscreen tolerance
				if (screenX < -margin || screenY < -margin || screenX > cam.width + margin || screenY > cam.height + margin)
					return;
			}
		}
		catch (e:Dynamic) {}
		// if we are pursuing through the player's position, continue toward the through-target
		if (_pursuingThrough)
		{
			// compute distance to through-target
			var dxT:Float = _targetX - (x + width * 0.5);
			var dyT:Float = _targetY - (y + height * 0.5);
			var distT:Float = Math.sqrt(dxT * dxT + dyT * dyT);
			if (distT <= 6 || _actionCooldown <= 0)
			{
				_pursuingThrough = false;
				// stop or resume wander next tick
				stop();
			}
			else
			{
				// keep velocity towards target
				move(Math.atan2(dyT, dxT) * 180.0 / Math.PI);
				return;
			}
		}
		// decay action cooldown
		_actionCooldown -= elapsed;
		_wanderTimer -= elapsed;
		// get playstate and player if available
		var ps:PlayState = cast(FlxG.state, PlayState);
		if (ps == null)
			return;
		var player:Player = ps.player;
		// if player visible and close enough, consider reacting
		if (player != null)
		{
			var dx:Float = (player.x + player.width * 0.5) - (x + width * 0.5);
			var dy:Float = (player.y + player.height * 0.5) - (y + height * 0.5);
			var dist:Float = Math.sqrt(dx * dx + dy * dy);
			var visible:Bool = (dist < 160) && hasLineOfSightTo(player.x + player.width * 0.5, player.y + player.height * 0.5, ps.tilemap);
			if (visible && _actionCooldown <= 0)
			{
				// roll vs aggression and skittishness
				var aRoll:Float = FlxG.random.float();
				var sRoll:Float = FlxG.random.float();
				if (aRoll < aggression && aRoll > skittishness)
				{
					// chase: set speed high and set a through-target beyond the player's position
					speed = wanderSpeed * (1.5 + FlxG.random.float() * 1.0);
					// compute a point beyond the player so enemy runs through
					var angleToPlayer:Float = Math.atan2(dy, dx);
					var extraDistance:Float = 48.0 + FlxG.random.float() * 24.0; // pixels beyond player
					_targetX = (player.x + player.width * 0.5) + Math.cos(angleToPlayer) * extraDistance;
					_targetY = (player.y + player.height * 0.5) + Math.sin(angleToPlayer) * extraDistance;
					_pursuingThrough = true;
					move(angleToPlayer * 180.0 / Math.PI);
					_actionCooldown = 0.6 + FlxG.random.float() * 0.8;
					return;
				}
				else if (sRoll < skittishness && sRoll > aggression)
				{
					// flee: pick a nearby tile that is not visible (very simple: move opposite direction)
					speed = wanderSpeed * (1.8 + FlxG.random.float() * 0.6);
					var fleeAngle = Math.atan2(-dy, -dx) + (FlxG.random.float() - 0.5) * 0.8;
					move(fleeAngle * 180.0 / Math.PI);
					_actionCooldown = 0.8 + FlxG.random.float() * 1.2;
					return;
				}
			}
		}
		// wander behavior: occasionally pick a random direction and move for a bit
		if (_wanderTimer <= 0)
		{
			_wanderTimer = 0.6 + FlxG.random.float() * 1.6;
			if (FlxG.random.float() < 0.55)
			{
				// move
				var ang = (FlxG.random.float() * Math.PI * 2);
				move(ang * 180.0 / Math.PI);
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
