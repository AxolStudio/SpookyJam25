package ai;

import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.FlxG;
import flixel.FlxCamera;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.sound.FlxSound;
import util.SoundHelper;
import Player;
import Enemy;
import GameMap;
import flixel.math.FlxAngle;

class EnemyBrain
{
	// Chimera cry tracking
	private static var cryCooldown:Float = 0.0;
	private static var MIN_CRY_DELAY:Float = 1.0; // Minimum seconds between cries (reduced from 2.0)
	private static var CRY_CHECK_INTERVAL:Float = 0.5; // How often to check if we should cry
	private static var nextCryCheckTime:Float = 0.0;

	// Active cry tracking - for updating proximity as enemy/player move
	private static var cryingEnemy:Enemy = null;
	private static var activeChimeraCry:FlxSound = null;
	private static var CRY_MAX_RADIUS:Float = 800.0; // Larger radius for better audio range
	// try the given angle and small offsets to avoid walking directly into walls
	private static function findClearAngle(tilemap:GameMap, fromX:Float, fromY:Float, baseAngleDeg:Float, stepPx:Float = 8):Float
	{
		var testBlocked = function(angleDeg:Float):Bool
		{
			var rad = angleDeg * FlxAngle.TO_RAD;
			var tx = fromX + Math.cos(rad) * stepPx;
			var ty = fromY + Math.sin(rad) * stepPx;
			return !tilemap.lineOfSight(fromX, fromY, tx, ty);
		};

		if (!testBlocked(baseAngleDeg))
			return baseAngleDeg;

		var offsets = [15, -15, 30, -30];
		for (o in offsets)
		{
			var a = baseAngleDeg + o;
			if (!testBlocked(a))
				return a;
		}

		return baseAngleDeg;
	}

	public static var LOS_DISTANCE:Float = 0.0;
	private static var LOS_DISTANCE_SQR:Float = 0.0;

	public static function process(player:Player, enemies:FlxTypedGroup<Enemy>, tilemap:GameMap, elapsed:Float, ?cam:FlxCamera):Void
	{
		if (player == null || enemies == null || tilemap == null)
			return;

		if (LOS_DISTANCE <= 0.0)
		{
			LOS_DISTANCE = FlxG.width * 0.66;
			LOS_DISTANCE_SQR = LOS_DISTANCE * LOS_DISTANCE;
		}

		// if (CRY_MAX_RADIUS <= 0.0)
		// {
		// 	CRY_MAX_RADIUS = FlxG.width * 0.75;
		// }

		// Update active chimera cry proximity if one is playing
		updateActiveChimeraCry(player);

		// Update cry cooldown
		cryCooldown -= elapsed;
		if (cryCooldown < 0)
			cryCooldown = 0;

		// Check if it's time to potentially trigger a cry
		nextCryCheckTime -= elapsed;
		var shouldCheckForCry = nextCryCheckTime <= 0;
		if (shouldCheckForCry)
		{
			nextCryCheckTime = CRY_CHECK_INTERVAL;
			tryTriggerChimeraCry(player, enemies, cam);
		}

		for (e in enemies.members)
		{
			if (e == null || !e.exists || !e.alive)
				continue;

			if (cam != null && !e.isOnScreen(cam))
			{
				e.stop();
				continue;
			}

			e.aiTimer -= elapsed;

			var eMid:FlxPoint = e.getMidpoint();
			var pMid:FlxPoint = player.getMidpoint();
			var ex:Float = eMid.x;
			var ey:Float = eMid.y;
			var px:Float = pMid.x;
			var py:Float = pMid.y;
			var dx:Float = px - ex;
			var dy:Float = py - ey;
			var dist2:Float = dx * dx + dy * dy;

			var sees:Bool = false;
			if (dist2 <= LOS_DISTANCE_SQR || e.aiTimer <= 0)
			{
				if (tilemap != null)
					sees = tilemap.lineOfSight(ex, ey, px, py);
				else
					sees = dist2 <= LOS_DISTANCE_SQR;
			}

			if (!e.lastSawPlayer && sees)
			{
				// interrupt any ongoing motion
				e.stop();
				e.aiTimer = 0.0;
			}

			if (e.aiTimer > 0)
			{
				e.lastSawPlayer = sees;
				eMid.put();
				pMid.put();
				continue;
			}

			// Main decision rules
			var scheduled:Bool = false;
			if (sees && dist2 <= LOS_DISTANCE_SQR)
			{
				var roll:Float = FlxG.random.float(-1.0, 1.0);

				// Flee
				if (roll < 0 && roll >= e.aggression)
				{
					var mAngle:Float = FlxAngle.degreesBetween(player, e) + FlxG.random.float(-2.0, 2.0);
					mAngle = findClearAngle(tilemap, ex, ey, mAngle, 12);
					var mDist:Float = FlxG.random.float(16.0, 40.0);
					var mTime:Float = mDist * e.speed;
					if (mTime < 0.12)
						mTime = 0.12;
					e.startTimedMove(mAngle, mTime);
					e.aiTimer = mTime + 0.05;
					e.aiState = 2;
					scheduled = true;
				}
				// Attack
				else if (roll > 0 && roll <= e.aggression)
				{
					var aAngle:Float = FlxAngle.degreesBetween(e, player);
					aAngle = findClearAngle(tilemap, ex, ey, aAngle, 12);
					var aDist:Float = FlxG.random.float(48.0, 72.0);
					var aTime:Float = aDist * e.speed;
					if (aTime < 0.12)
						aTime = 0.12;
					e.startTimedMove(aAngle, aTime);
					e.aiTimer = aTime + 0.05;
					e.aiState = 1;
					scheduled = true;
				}
				else
				{
					// Didn't choose to flee or attack: perform a short seen-wander
					var sAngle:Float = FlxG.random.float(0, 360);
					var sTime:Float = FlxG.random.float(0.6, 1.8);
					if (sTime < 0.12)
						sTime = 0.12;
					e.startTimedMove(sAngle, sTime);
					e.aiTimer = sTime + 0.05;
					e.aiState = 0; // wandering
					scheduled = true;

				}
			}
			else
			{
				// Not seeing the player: wander or stop
				if (FlxG.random.float() < 0.25)
				{
					var wAngle:Float = FlxG.random.float(0, 360);
					var wTime:Float = FlxG.random.float(1.0, 3.0);
					if (wTime < 0.12)
						wTime = 0.12;
					e.aiTimer = wTime + 0.05;
					e.startTimedMove(wAngle, wTime);
					scheduled = true;

				}
				else
				{
					e.stop();
					e.aiState = 0;

				}
			}

			if (!scheduled)
				e.aiTimer = e.aiDecisionInterval * FlxG.random.float(0.8, 1.6);
			e.lastSawPlayer = sees;

			eMid.put();
			pMid.put();
		}
	}
	/**
	 * Updates the active chimera cry's proximity audio based on current enemy/player positions.
	 * Called every frame from process().
	 */
	private static function updateActiveChimeraCry(player:Player):Void
	{
		// Check if we have an active cry
		if (activeChimeraCry == null || cryingEnemy == null)
			return;

		// Check if sound is done or enemy is gone
		if (!activeChimeraCry.playing || !cryingEnemy.exists || !cryingEnemy.alive)
		{
			cleanupChimeraCry();
			return;
		}

		// Update proximity every frame as positions change
		var enemyMid = cryingEnemy.getMidpoint();
		activeChimeraCry.proximity(enemyMid.x, enemyMid.y, player, CRY_MAX_RADIUS, true);
		enemyMid.put();
	}

	/**
	 * Cleans up the active chimera cry sound and references.
	 */
	private static function cleanupChimeraCry():Void
	{
		if (activeChimeraCry != null)
		{
			activeChimeraCry.stop();
			activeChimeraCry.destroy();
			activeChimeraCry = null;
		}
		cryingEnemy = null;
	}

	private static function tryTriggerChimeraCry(player:Player, enemies:FlxTypedGroup<Enemy>, ?cam:FlxCamera):Void
	{
		// Don't trigger if cooldown is active or a cry is already playing
		if (cryCooldown > 0 || activeChimeraCry != null)
			return;

		// Collect enemies within hearing range
		var playerMid = player.getMidpoint();
		var allEnemies:Array<Enemy> = [];
		var visibleEnemies:Array<Enemy> = [];

		for (e in enemies.members)
		{
			if (e == null || !e.exists || !e.alive)
				continue;

			// Check if enemy is within hearing range
			var enemyMid = e.getMidpoint();
			var distance = playerMid.distanceTo(enemyMid);
			enemyMid.put();

			// Skip enemies too far away to be heard
			if (distance > CRY_MAX_RADIUS)
				continue;

			allEnemies.push(e);

			// Check if enemy is visible to player (alpha > 0.5 means visible through fog)
			if (e.alpha > 0.5)
			{
				visibleEnemies.push(e);
			}
		}

		playerMid.put();

		// No enemies within range? Don't cry
		if (allEnemies.length == 0)
			return;

		// Increased chance to cry (50% per check, up from 20%)
		if (FlxG.random.float() > 0.5)
			return;

		// Prefer visible enemies, but allow non-visible enemies to cry too
		// 70% chance to pick from visible if any exist, 30% chance for any enemy
		if (visibleEnemies.length > 0 && FlxG.random.float() < 0.7)
		{
			cryingEnemy = visibleEnemies[FlxG.random.int(0, visibleEnemies.length - 1)];
		}
		else
		{
			cryingEnemy = allEnemies[FlxG.random.int(0, allEnemies.length - 1)];
		}

		var isVisible = cryingEnemy.alpha > 0.5;

		// Get the sound (doesn't play yet)
		activeChimeraCry = SoundHelper.playRandomChimeraCry(isVisible);

		if (activeChimeraCry == null)
		{
			cryingEnemy = null;
			return;
		}

		// Set up initial proximity BEFORE playing
		var enemyMid = cryingEnemy.getMidpoint();
		activeChimeraCry.proximity(enemyMid.x, enemyMid.y, player, CRY_MAX_RADIUS, true);

		// CRITICAL: Call update() manually BEFORE play() to set initial volume/pan
		// This prevents the "pop" at base volume before first frame update
		activeChimeraCry.update(0);

		trace("start cry", enemyMid, player.getMidpoint(), player.getMidpoint()
			.distanceTo(enemyMid), activeChimeraCry.pan, activeChimeraCry.getActualVolume());
		enemyMid.put();

		// NOW play the sound - volume/pan are already correct
		activeChimeraCry.play(true);

		// Shorter cooldown for more frequent cries (1-2.5 seconds, down from 2-4)
		cryCooldown = MIN_CRY_DELAY + FlxG.random.float(0, 1.5);
	}
}
