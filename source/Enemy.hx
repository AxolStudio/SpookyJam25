package;

import flixel.util.FlxColor;
import haxe.ds.StringMap;
import flixel.FlxG;
import flixel.effects.particles.FlxEmitter;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import ai.EnemyBrain;
import util.ColorHelpers;
import Types;

class Enemy extends GameObject
{
	public var variant:String;

	private var hue:Int;

	public static var VARIANTS:Array<String> = [];
	public static var VARIANT_FRAMES:StringMap<Array<String>> = null;

	public var aggression:Float = 0.0;
	public var skittishness:Float = 0.0;
	public var wanderSpeed:Float = 40.0;
	public var power:Int = 10; // 5-15 damage, calculated from stats

	// AI State Machine
	public var aiState:EnemyState = EnemyState.IDLE;
	public var aiTimer:Float = 0.0;
	public var aiDecisionInterval:Float = 0.6;
	public var aiValue:Int = 1;
	public var lastSawPlayer:Bool = false;
	public var seenPlayer:Bool = false; // Track if enemy has EVER seen player (for icon logic)
	public var stunTimer:Float = 0;

	// Pathfinding support
	public var needsPathUpdate:Bool = false;
	public var lastPathTarget:FlxPoint = null;

	// Aggression personality
	public var aggressionType:AggressionType = HUNTER;

	// Variant type
	public var variantType:EnemyVariant = NORMAL;

	private var variantScale:Float = 1.0;
	private var variantSpeedMult:Float = 1.0;
	private var variantDamageMult:Float = 1.0;

	// Detection ranges (scaled by fame level)
	public var detectionRange:Float = 120;
	public var hearingRange:Float = 160;
	public var attackRange:Float = 20;

	// Alert icon (recycled from pool)
	public var alertIcon:flixel.FlxSprite = null;

	private var alertIconTimer:Float = 0;

	private static inline var ALERT_ICON_DURATION:Float = 0.5;

	// Attack telegraph system
	public var isAttacking:Bool = false;
	public var attackPhase:Int = 0; // 0=pullback, 1=pause, 2=lunge
	public var attackTimer:Float = 0;

	private var attackStartPos:FlxPoint = null;
	private var attackTargetPos:FlxPoint = null;

	private static inline var PULLBACK_DISTANCE:Float = 8.0;
	private static inline var PULLBACK_TIME:Float = 0.15;
	private static inline var PAUSE_TIME:Float = 0.3;
	private static inline var LUNGE_DISTANCE:Float = 32.0;
	private static inline var LUNGE_TIME:Float = 0.2;

	private var _captured:Bool = false;

	// Shiny rainbow effect
	private var shinyHueTimer:Float = 0;
	private var shinyBaseHue:Int = 0;

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
		// Create particles manually to avoid FlxG logo bug
		for (i in 0...count)
		{
			var p = new flixel.effects.particles.FlxParticle();
			p.makeGraphic(2, 2, FlxColor.TRANSPARENT);
			// Set pixels manually to avoid logo
			p.pixels.setPixel32(0, 0, 0xFF888888);
			p.pixels.setPixel32(1, 0, 0xFF888888);
			p.pixels.setPixel32(0, 1, 0xFF888888);
			p.pixels.setPixel32(1, 1, 0xFF888888);
			p.exists = false;
			emitter.add(p);
		}
		
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
			var ci = new CapturedInfo(variant != null ? variant : "enemy", aggression, wanderSpeed, hue, 1, power, skittishness, variantType);
			byPlayer.captured.push(ci);
		}

		// Stop ALL movement completely
		velocity.set(0, 0);
		acceleration.set(0, 0);
		drag.set(0, 0);
		animation.stop();
		stop();
		// Unregister from EnemyBrain pathfinding
		ai.EnemyBrain.unregister(this);

		// Cancel any active pathfinding
		if (path != null)
		{
			path.cancel();
			path = null;
		}

		// Cancel all tweens on this object
		FlxTween.cancelTweensOf(this);

		// Hide alert icon when captured/killed
		hideAlertIcon();

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
		// Assign variant (rare chance for special variants)
		#if debug
		// Debug mode: Force all enemies to be Shiny
		variantType = SHINY;
		variantScale = 1.0;
		variantSpeedMult = 1.0;
		variantDamageMult = 1.0;
		shinyBaseHue = hue; // Save original hue for rainbow cycling
		#else
		var variantRoll = FlxG.random.float(0, 1);
		if (variantRoll < 0.05) // 5% Alpha
		{
			variantType = ALPHA;
			variantScale = 1.5;
			variantSpeedMult = 1.25;
			variantDamageMult = 1.5;
			scale.set(variantScale, variantScale);
			updateHitbox();
		}
		else if (variantRoll < 0.15) // 10% Shiny (5-15% range)
		{
			variantType = SHINY;
			variantScale = 1.0;
			variantSpeedMult = 1.0;
			variantDamageMult = 1.0;
			shinyBaseHue = hue; // Save original hue for rainbow cycling
		}
		else
		{
			variantType = NORMAL;
			variantScale = 1.0;
			variantSpeedMult = 1.0;
			variantDamageMult = 1.0;
		}
		#end

		// Rebuild graphics now that variantType is set (for shader application)
		if (variantType == SHINY)
			buildGraphics();

		randomizeBehavior();
		assignAggressionType();
	}

	/**
	 * Assign aggression type based on stats
	 */
	private function assignAggressionType():Void
	{
		// Shiny variants are always skittish (hard to photograph)
		if (variantType == SHINY)
		{
			aggressionType = SKITTISH;
			skittishness = 1.0; // Max skittishness
		}
		else if (aggression >= 0.5 && skittishness < 0.3)
			aggressionType = HUNTER;
		else if (aggression >= 0 && aggression < 0.5)
			aggressionType = TERRITORIAL;
		else if (skittishness >= 0.6)
			aggressionType = SKITTISH;
		else
			aggressionType = AMBUSHER;

		// Scale detection ranges by fame level
		var fameLevel:Int = Globals.fameLevel;
		var fameScale:Float = 0.8 + ((fameLevel - 1) / 9.0) * 0.4; // 0.8 to 1.2
		detectionRange = 120 * fameScale;
		hearingRange = 160 * fameScale;
		attackRange = 20;
	}

	public function randomizeBehavior():Void
	{
		// Scale difficulty with fame level
		// Fame 1: average ~5 stars (25% of max), Fame 10: average ~15 stars (75% of max)
		var fameLevel:Int = Globals.fameLevel;
		var difficultyScale:Float = 0.25 + ((fameLevel - 1) / 9.0) * 0.50; // 0.25 at level 1, 0.75 at level 10
		var variation:Float = 0.3; // ±30% variation
		var targetDifficulty:Float = difficultyScale + (FlxG.random.float(-variation, variation) * difficultyScale);
		targetDifficulty = Math.max(0.15, Math.min(0.95, targetDifficulty)); // Clamp to 15%-95%

		// Distribute difficulty across stats with some randomization
		// Each stat gets a portion of the total difficulty budget
		var speedPortion:Float = FlxG.random.float(0.15, 0.35);
		var aggrPortion:Float = FlxG.random.float(0.15, 0.35);
		var powerPortion:Float = FlxG.random.float(0.15, 0.35);
		var skittPortion:Float = 1.0 - (speedPortion + aggrPortion + powerPortion);
		skittPortion = Math.max(0.10, Math.min(0.40, skittPortion));

		// Normalize portions to sum to 1.0
		var totalPortions:Float = speedPortion + aggrPortion + powerPortion + skittPortion;
		speedPortion /= totalPortions;
		aggrPortion /= totalPortions;
		powerPortion /= totalPortions;
		skittPortion /= totalPortions;

		// Apply difficulty to each stat
		var speedDifficulty:Float = targetDifficulty * speedPortion;
		var aggrDifficulty:Float = targetDifficulty * aggrPortion;
		var powerDifficulty:Float = targetDifficulty * powerPortion;
		var skittDifficulty:Float = targetDifficulty * skittPortion;

		// Convert to actual values
		// Speed: 20-70 range maps to difficulty
		wanderSpeed = 20 + (speedDifficulty * 4.0) * 50.0; // Multiply by 4 since speedDifficulty is ~25% of target
		wanderSpeed = Math.max(20, Math.min(70, wanderSpeed));

		// Aggression: -1 to 1 range, favor positive aggression at higher difficulties
		var aggrSign:Int = if (FlxG.random.float() < (0.3 + aggrDifficulty * 0.5)) 1 else -1;
		aggression = (aggrDifficulty * 4.0) * aggrSign; // Multiply by 4
		aggression = Math.max(-1.0, Math.min(1.0, aggression));
		aggression = Math.round(aggression * 10.0) / 10.0;

		// Skittishness: 0-1 range
		skittishness = skittDifficulty * 4.0; // Multiply by 4
		skittishness = Math.max(0.0, Math.min(1.0, skittishness));
		skittishness = Math.round(skittishness * 10.0) / 10.0;

		// Power: 1-5 stars (stored as 1-5, not 5-15 damage anymore)
		power = Std.int(Math.max(1, Math.min(5, Math.round((powerDifficulty * 4.0) * 5.0))));

		speed = wanderSpeed;
		aiDecisionInterval = FlxG.random.float(0.3, 1.2);
		// Calculate AI value for damage (5-15 damage range based on power stars)
		var valF:Float = 1.0 + aggression * 3.0 + (wanderSpeed - 20.0) / 30.0 - skittishness * 2.0;
		var valI:Int = Std.int(Math.max(1, Math.round(valF)));
		aiValue = valI;
		// Damage is now based on power stars directly
		var damagePerStar:Int = 3; // 3 damage per power star
		aiValue = Std.int(Math.max(5, Math.min(15, power * damagePerStar)));

		aiTimer = 0.0;
	}

	/**
	 * Get the current target position for pathfinding
	 */
	public function getPathTarget():FlxPoint
	{
		if (FlxG.state != null && Std.isOfType(FlxG.state, PlayState))
		{
			var playState:PlayState = cast FlxG.state;
			if (aiState == FLEE || aiState == CORNERED)
			{
				// Flee away from player
				var playerPos = playState.player.getMidpoint();
				var myPos = getMidpoint();
				var angle = Math.atan2(myPos.y - playerPos.y, myPos.x - playerPos.x);
				var fleeDistance = 200;
				var target = FlxPoint.get(myPos.x + Math.cos(angle) * fleeDistance, myPos.y + Math.sin(angle) * fleeDistance);
				myPos.put();
				playerPos.put();
				return target;
			}
			else
			{
				// Chase player
				return playState.player.getMidpoint();
			}
		}
		return null;
	}

	/**
	 * Get current movement speed based on state and variant
	 */
	public function getCurrentSpeed():Float
	{
		var baseSpeed = speed;
		if (aiState == FLEE || aiState == CORNERED)
			baseSpeed *= 1.5; // Faster when fleeing
		return baseSpeed * variantSpeedMult;
	}

	/**
	 * Handle hearing a sound event
	 */
	public function hearSound(origin:FlxPoint):Void
	{
		// React to sounds if idle (not if already chasing/attacking/alerting)
		if (aiState == IDLE)
		{
			// Interrupt current action and become alert
			stop();
			aiTimer = 0.0;
			changeState(ALERT);
			needsPathUpdate = true;
		}
	}

	/**
	 * Start attack telegraph animation (pullback -> pause -> lunge)
	 */
	public function startAttack(targetPlayer:Player):Void
	{
		if (isAttacking)
			return;

		isAttacking = true;
		attackPhase = 0;
		attackTimer = PULLBACK_TIME;

		// Trigger attack cry (now with cooldown to prevent constant screaming)
		var playState:PlayState = cast FlxG.state;
		if (playState != null)
		{
			ai.EnemyBrain.triggerAttackCry(this, targetPlayer, playState.enemies, playState.tilemap);
		}

		// Store start position
		if (attackStartPos == null)
			attackStartPos = FlxPoint.get();
		attackStartPos.set(x, y);

		// Calculate pullback direction (away from player)
		var angleToPlayer = FlxAngle.angleBetween(this, targetPlayer, true);
		var pullbackAngle = angleToPlayer + 180; // Opposite direction

		if (attackTargetPos == null)
			attackTargetPos = FlxPoint.get();

		// Pullback position
		attackTargetPos.set(x + Math.cos(pullbackAngle * FlxAngle.TO_RAD) * PULLBACK_DISTANCE,
			y + Math.sin(pullbackAngle * FlxAngle.TO_RAD) * PULLBACK_DISTANCE);

		// Stop normal movement
		velocity.set(0, 0);
		acceleration.set(0, 0);
		stop();
	}

	/**
	 * Update attack telegraph animation
	 */
	public function updateAttack(elapsed:Float, targetPlayer:Player):Void
	{
		if (!isAttacking)
			return;

		attackTimer -= elapsed;

		if (attackPhase == 0) // Pullback
		{
			// Move backward smoothly
			var t = 1.0 - (attackTimer / PULLBACK_TIME);
			x = FlxMath.lerp(attackStartPos.x, attackTargetPos.x, t);
			y = FlxMath.lerp(attackStartPos.y, attackTargetPos.y, t);

			if (attackTimer <= 0)
			{
				// Move to pause phase
				attackPhase = 1;
				attackTimer = PAUSE_TIME;
			}
		}
		else if (attackPhase == 1) // Pause
		{
			// Stay still at pullback position
			if (attackTimer <= 0)
			{
				// Move to lunge phase
				attackPhase = 2;
				attackTimer = LUNGE_TIME;

				// Calculate lunge target (toward player)
				var angleToPlayer = FlxAngle.angleBetween(this, targetPlayer, true);
				attackTargetPos.set(x + Math.cos(angleToPlayer * FlxAngle.TO_RAD) * LUNGE_DISTANCE,
					y + Math.sin(angleToPlayer * FlxAngle.TO_RAD) * LUNGE_DISTANCE);
				attackStartPos.set(x, y);
			}
		}
		else if (attackPhase == 2) // Lunge
		{
			// Fast forward movement
			var t = 1.0 - (attackTimer / LUNGE_TIME);
			x = FlxMath.lerp(attackStartPos.x, attackTargetPos.x, t);
			y = FlxMath.lerp(attackStartPos.y, attackTargetPos.y, t);

			// Check for player collision during lunge
			if (overlaps(targetPlayer))
			{
				// Deal damage to player
				targetPlayer.takeDamage(power);
				endAttack();
				return;
			}

			if (attackTimer <= 0)
			{
				// Attack complete, return to normal behavior
				endAttack();
			}
		}
	}

	/**
	 * End attack and return to normal behavior
	 */
	public function endAttack():Void
	{
		isAttacking = false;
		attackPhase = 0;
		attackTimer = 0;

		// Return to CHASE or IDLE
		changeState(CHASE);
	}

	/**
	 * Change AI state and handle transitions
	 */
	public function changeState(newState:EnemyState):Void
	{
		if (aiState == newState)
			return;

		// Unregister from old state
		if (aiState == CHASE || aiState == FLEE || aiState == CORNERED)
			EnemyBrain.unregister(this);

		aiState = newState;

		// Register to new state
		if (aiState == CHASE)
			EnemyBrain.registerChaser(this);
		else if (aiState == FLEE)
			EnemyBrain.registerFleer(this);
		else if (aiState == CORNERED)
			EnemyBrain.registerCornered(this);

		needsPathUpdate = true;

		// Show alert icon when appropriate
		updateAlertIcon();
	}

	/**
	 * Update which alert icon to show based on state
	 * Icons are ONLY shown on state transitions via EnemyBrain, not here
	 * This just hides the icon when timer expires
	 */
	private function updateAlertIcon():Void
	{
		// Simply hide icon when timer expires
		if (alertIconTimer <= 0 && alertIcon != null && alertIcon.visible)
		{
			hideAlertIcon();
		}
	}

	/**
	 * Show alert icon above enemy
	 * @param frame 0 for "!", 1 for "?"
	 */
	public function showAlertIcon(frame:Int):Void
	{
		// Kill existing icon first to ensure fresh display
		if (alertIcon != null && alertIcon.visible)
		{
			hideAlertIcon();
		}

		// Get icon from pool if we don't have one
		if (alertIcon == null)
		{
			var playState = cast(FlxG.state, PlayState);
			if (playState != null && playState.alertIcons != null)
			{
				// Recycle from pool
				alertIcon = playState.alertIcons.recycle();
			}
		}

		if (alertIcon != null)
		{
			alertIcon.animation.frameIndex = frame;
			alertIcon.visible = true;
			alertIconTimer = ALERT_ICON_DURATION;

			// Position above enemy
			updateAlertIconPosition();
		}
	}

	/**
	 * Hide alert icon and return to pool
	 */
	public function hideAlertIcon():Void
	{
		if (alertIcon != null)
		{
			alertIcon.visible = false;
			// Return to pool
			alertIcon = null;
		}
	}

	/**
	 * Update alert icon position to stay above enemy
	 */
	private function updateAlertIconPosition():Void
	{
		if (alertIcon != null && alertIcon.visible)
		{
			alertIcon.x = x + (width - alertIcon.width) / 2;
			alertIcon.y = y - alertIcon.height - 2;
		}
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
		// Handle attack animation
		if (isAttacking)
		{
			var playState = cast(FlxG.state, PlayState);
			if (playState != null && playState.player != null)
			{
				updateAttack(elapsed, playState.player);
			}
			else
			{
				endAttack(); // No player, cancel attack
			}
			return; // Skip normal updates during attack
		}

		// NO ALPHA EFFECTS - keep enemy fully opaque always
		alpha = 1.0;

		// Rainbow hue cycling for Shiny enemies (just update timer, shader handles the rest)
		if (variantType == SHINY && shader != null)
		{
			shinyHueTimer += elapsed * 180; // Cycle through 180 degrees per second (faster)
			if (shinyHueTimer >= 360)
				shinyHueTimer -= 360;

			// Update shader hue parameter
			cast(shader, shaders.OutlineShader).hue.value = [shinyHueTimer / 360.0];
		}

		// Update alert icon timer and position ALWAYS (even off-screen)
		if (alertIconTimer > 0)
		{
			alertIconTimer -= elapsed;
			if (alertIconTimer <= 0)
			{
				hideAlertIcon();
			}
		}

		// Keep alert icon positioned above enemy ALWAYS
		updateAlertIconPosition();

		// Off-screen enemies skip AI updates (optimization)
		if (!this.isOnScreen())
		{
			if (aiState == CHASE || aiState == FLEE || aiState == CORNERED)
				EnemyBrain.unregister(this);
			return;
		}

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
		// Use normal coloring for all enemies
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
		// Apply color cycling shader for Shiny enemies only
		if (variantType == SHINY)
		{
			var outlineShader = new shaders.OutlineShader();
			outlineShader.size.value = [1.0, 1.0];
			outlineShader.hue.value = [0.0]; // Will be updated in update()
			shader = outlineShader;
		}
	}

	public override function destroy():Void
	{
		// Unregister from EnemyBrain
		EnemyBrain.unregister(this);

		// Clean up path target
		if (lastPathTarget != null)
		{
			lastPathTarget.put();
			lastPathTarget = null;
		}

		// Clean up attack positions
		if (attackStartPos != null)
		{
			attackStartPos.put();
			attackStartPos = null;
		}
		if (attackTargetPos != null)
		{
			attackTargetPos.put();
			attackTargetPos = null;
		}

		// Clean up alert icon
		if (alertIcon != null)
		{
			alertIcon.destroy();
			alertIcon = null;
		}

		super.destroy();
	}
}
