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
	private static var cryCooldown:Float = 0.0;
	private static var MIN_CRY_DELAY:Float = 1.0;
	private static var CRY_CHECK_INTERVAL:Float = 0.5;
	private static var nextCryCheckTime:Float = 0.0;

	private static var cryingEnemy:Enemy = null;
	private static var activeChimeraCry:FlxSound = null;
	private static var CRY_MAX_RADIUS:Float = 800.0;

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

		updateActiveChimeraCry(player);

		cryCooldown -= elapsed;
		if (cryCooldown < 0)
			cryCooldown = 0;

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

			var scheduled:Bool = false;
			if (sees && dist2 <= LOS_DISTANCE_SQR)
			{
				var roll:Float = FlxG.random.float(-1.0, 1.0);

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
					var sAngle:Float = FlxG.random.float(0, 360);
					var sTime:Float = FlxG.random.float(0.6, 1.8);
					if (sTime < 0.12)
						sTime = 0.12;
					e.startTimedMove(sAngle, sTime);
					e.aiTimer = sTime + 0.05;
					e.aiState = 0;
					scheduled = true;

				}
			}
			else
			{
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
		if (activeChimeraCry == null || cryingEnemy == null)
			return;

		if (!activeChimeraCry.playing || !cryingEnemy.exists || !cryingEnemy.alive)
		{
			cleanupChimeraCry();
			return;
		}

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
		if (cryCooldown > 0 || activeChimeraCry != null)
			return;

		var playerMid = player.getMidpoint();
		var allEnemies:Array<Enemy> = [];
		var visibleEnemies:Array<Enemy> = [];

		for (e in enemies.members)
		{
			if (e == null || !e.exists || !e.alive)
				continue;

			var enemyMid = e.getMidpoint();
			var distance = playerMid.distanceTo(enemyMid);
			enemyMid.put();

			if (distance > CRY_MAX_RADIUS)
				continue;

			allEnemies.push(e);

			if (e.alpha > 0.5)
			{
				visibleEnemies.push(e);
			}
		}

		playerMid.put();

		if (allEnemies.length == 0)
			return;

		if (FlxG.random.float() > 0.5)
			return;

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

		var enemyMid = cryingEnemy.getMidpoint();
		activeChimeraCry.proximity(enemyMid.x, enemyMid.y, player, CRY_MAX_RADIUS, true);

		activeChimeraCry.update(0);

		trace("start cry", enemyMid, player.getMidpoint(), player.getMidpoint()
			.distanceTo(enemyMid), activeChimeraCry.pan, activeChimeraCry.getActualVolume());
		enemyMid.put();

		activeChimeraCry.play(true);

		cryCooldown = MIN_CRY_DELAY + FlxG.random.float(0, 1.5);
	}
}
