package ai;

import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.FlxG;
import flixel.FlxCamera;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.sound.FlxSound;
import flixel.path.FlxPathfinder;
import flixel.path.FlxPathfinder.FlxDiagonalPathfinder;
import flixel.path.FlxPathfinder.FlxTilemapDiagonalPolicy;
import flixel.path.FlxPathfinder.FlxPathSimplifier;
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

	private static var attackCryCooldown:Float = 0.0;
	private static var MIN_ATTACK_CRY_DELAY:Float = 3.0;

	private static var cryingEnemy:Enemy = null;
	private static var activeChimeraCry:FlxSound = null;
	private static var CRY_MAX_RADIUS:Float = 800.0;

	public static var pathfinder:FlxPathfinder;
	private static var chasingEnemies:Array<Enemy> = [];
	private static var fleeingEnemies:Array<Enemy> = [];
	private static var corneredEnemies:Array<Enemy> = [];
	private static var lastCameraPos:FlxPoint;
	private static var cameraScrollThreshold:Float = Constants.TILE_SIZE * 3;
	private static var pathRecalcDistance:Float = Constants.TILE_SIZE * 2;
	private static var maxPathsPerFrame:Int = 3;

	private static var activeSoundWaves:Array<SoundWave> = [];

	private static inline var TILES_PER_FRAME:Int = 20;

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

		attackCryCooldown -= elapsed;
		if (attackCryCooldown < 0)
			attackCryCooldown = 0;

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

			if (dist2 <= LOS_DISTANCE_SQR)
			{
				if (tilemap != null)
					sees = tilemap.lineOfSight(ex, ey, px, py);
				else
					sees = true;
			}

			if (!e.lastSawPlayer && sees)
			{
				if (!e.seenPlayer)
				{
					e.seenPlayer = true;
					e.showAlertIcon(0);
				}

				e.aiTimer = 0.0;
				e.changeState(CHASE);
				triggerAlertCry(e, player, enemies, tilemap);
			}
			else if (e.lastSawPlayer && !sees && (e.aiState == CHASE || e.aiState == ATTACK))
			{
				if (e.seenPlayer)
				{
					e.seenPlayer = false;
					e.showAlertIcon(1);
				}

				e.changeState(ALERT);
				e.aiTimer = 0.8;
			}

			var dist:Float = Math.sqrt(dist2);
			applyPersonalityBehavior(e, player, tilemap, sees, dist); // Check for attack range (if chasing and close enough)
			if (!e.isAttacking && e.aiState == CHASE && sees && dist < e.attackRange)
			{
				e.changeState(ATTACK);
				e.startAttack(player);
				e.lastSawPlayer = sees;
				eMid.put();
				pMid.put();
				continue;
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
					e.aiState = cast 2;
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
					e.aiState = cast 1;
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
					e.aiState = cast 0;
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
					e.aiState = cast 0;

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
	/**
	 * Apply aggression-type specific behavior modifications
	 * Called from process() to layer personality on top of base AI
	 */
	public static function applyPersonalityBehavior(enemy:Enemy, player:Player, tilemap:GameMap, seesPlayer:Bool, distToPlayer:Float):Void
	{
		switch (enemy.aggressionType)
		{
			case HUNTER:
				// Hunters: Large detection radius, relentless chase
				// Already handled by larger detectionRange in Enemy constructor
				// Increase speed slightly when chasing
				if (seesPlayer && enemy.aiState == CHASE)
				{
					enemy.speed = enemy.wanderSpeed * 1.3;
				}
				else
				{
					enemy.speed = enemy.wanderSpeed;
				}

			case TERRITORIAL:
				// Territorial: Patrol area, only chase if player invades
				// Don't chase too far from spawn point
				// (Spawn point tracking would need to be added to Enemy.hx)
				// For now, just reduce chase range
				if (enemy.aiState == CHASE && distToPlayer > enemy.detectionRange * 1.5)
				{
					// Give up chase, return to patrol
					enemy.changeState(IDLE);
					enemy.speed = enemy.wanderSpeed;
				}

			case SKITTISH:
				// Skittish: Flee immediately when spotted, hard to photograph
				if (seesPlayer && distToPlayer < enemy.detectionRange * 1.2)
				{
					// Flee instead of chase!
					if (enemy.aiState != FLEE)
					{
						enemy.changeState(FLEE);
						enemy.speed = enemy.wanderSpeed * 1.5; // Faster flee
					}
				}
				// Move faster when fleeing
				if (enemy.aiState == FLEE)
				{
					enemy.speed = enemy.wanderSpeed * 1.8;
				}

			case AMBUSHER:
				// Ambusher: Looks idle/slow until player close, then sudden charge
				if (enemy.aiState == IDLE || enemy.aiState == ALERT)
				{
					// Move very slowly or not at all
					enemy.speed = enemy.wanderSpeed * 0.3;

					// If player gets close, sudden burst!
					if (seesPlayer && distToPlayer < enemy.attackRange * 3)
					{
						enemy.changeState(CHASE);
						enemy.speed = enemy.wanderSpeed * 2.0; // Sudden charge!

						// Visual feedback handled by state change
						// TODO: Add visual flash when assets support it
					}
				}
				else if (enemy.aiState == CHASE)
				{
					// Maintain high speed during charge
					enemy.speed = enemy.wanderSpeed * 2.0;
				}
		}
	}

	public static function init(tilemap:GameMap):Void
	{
		// Create shared pathfinder with diagonal movement (WIDE policy counts diagonal as +2 cost)
		pathfinder = new FlxDiagonalPathfinder(FlxTilemapDiagonalPolicy.WIDE);
		chasingEnemies = [];
		fleeingEnemies = [];
		corneredEnemies = [];
		lastCameraPos = FlxPoint.get();
		if (FlxG.camera != null)
			lastCameraPos.copyFrom(FlxG.camera.scroll);
	}

	public static function destroy():Void
	{
		pathfinder = null;
		chasingEnemies = [];
		fleeingEnemies = [];
		corneredEnemies = [];
		if (lastCameraPos != null)
		{
			lastCameraPos.put();
			lastCameraPos = null;
		}
	}

	public static function registerChaser(enemy:Enemy):Void
	{
		if (!chasingEnemies.contains(enemy))
			chasingEnemies.push(enemy);
		fleeingEnemies.remove(enemy);
		corneredEnemies.remove(enemy);
		enemy.needsPathUpdate = true;
	}

	public static function registerFleer(enemy:Enemy):Void
	{
		if (!fleeingEnemies.contains(enemy))
			fleeingEnemies.push(enemy);
		chasingEnemies.remove(enemy);
		corneredEnemies.remove(enemy);
		enemy.needsPathUpdate = true;
	}

	public static function registerCornered(enemy:Enemy):Void
	{
		if (!corneredEnemies.contains(enemy))
			corneredEnemies.push(enemy);
		chasingEnemies.remove(enemy);
		fleeingEnemies.remove(enemy);
		enemy.needsPathUpdate = true;
	}

	public static function unregister(enemy:Enemy):Void
	{
		chasingEnemies.remove(enemy);
		fleeingEnemies.remove(enemy);
		corneredEnemies.remove(enemy);
	}

	public static function updatePaths(elapsed:Float, tilemap:GameMap):Void
	{
		if (pathfinder == null)
			return;

		// Check if camera has scrolled significantly
		var cameraMoved = false;
		if (FlxG.camera != null)
		{
			var currentCameraPos = FlxG.camera.scroll;
			if (lastCameraPos == null)
			{
				lastCameraPos = FlxPoint.get(currentCameraPos.x, currentCameraPos.y);
			}
			else if (Math.abs(currentCameraPos.x - lastCameraPos.x) > cameraScrollThreshold
				|| Math.abs(currentCameraPos.y - lastCameraPos.y) > cameraScrollThreshold)
			{
				cameraMoved = true;
				lastCameraPos.set(currentCameraPos.x, currentCameraPos.y);
			}
		}

		// Update paths for chasing enemies (prioritize on-screen)
		var pathsUpdated = 0;
		for (enemy in chasingEnemies)
		{
			if (pathsUpdated >= maxPathsPerFrame)
				break;

			if (shouldUpdatePath(enemy, cameraMoved))
			{
				updatePath(enemy, tilemap);
				pathsUpdated++;
			}
		}

		// Update paths for fleeing enemies
		for (enemy in fleeingEnemies)
		{
			if (pathsUpdated >= maxPathsPerFrame)
				break;

			if (shouldUpdatePath(enemy, cameraMoved))
			{
				updatePath(enemy, tilemap);
				pathsUpdated++;
			}
		}

		// Update paths for cornered enemies (they might escape)
		for (enemy in corneredEnemies)
		{
			if (pathsUpdated >= maxPathsPerFrame)
				break;

			if (shouldUpdatePath(enemy, cameraMoved))
			{
				updatePath(enemy, tilemap);
				pathsUpdated++;
			}
		}
	}

	private static function shouldUpdatePath(enemy:Enemy, cameraMoved:Bool):Bool
	{
		// Check if enemy explicitly needs path update
		if (enemy.needsPathUpdate)
			return true;

		// Update if camera moved significantly
		if (cameraMoved)
			return true;

		// Check if path doesn't exist
		if (enemy.path == null || enemy.path.nodes == null || enemy.path.nodes.length == 0)
			return true;

		// Check if target has moved significantly
		var currentTarget = enemy.getPathTarget();
		if (enemy.lastPathTarget != null && currentTarget != null)
		{
			var dx = currentTarget.x - enemy.lastPathTarget.x;
			var dy = currentTarget.y - enemy.lastPathTarget.y;
			var dist = Math.sqrt(dx * dx + dy * dy);
			currentTarget.put();
			if (dist > pathRecalcDistance)
				return true;
		}
		else if (currentTarget != null)
		{
			currentTarget.put();
		}

		return false;
	}

	private static function updatePath(enemy:Enemy, tilemap:GameMap):Void
	{
		var target = enemy.getPathTarget();
		if (target == null)
		{
			enemy.needsPathUpdate = false;
			return;
		}

		var startPos = enemy.getMidpoint();

		// Use wallsMap's findPath method for pathfinding
		var path = tilemap.wallsMap.findPath(startPos, target, FlxPathSimplifier.LINE, FlxTilemapDiagonalPolicy.WIDE);
		startPos.put();

		if (path != null && path.length > 0)
		{
			// Apply path to enemy
			if (enemy.path == null)
				enemy.path = new flixel.path.FlxPath();

			enemy.path.start(path, enemy.getCurrentSpeed());
			if (enemy.lastPathTarget == null)
				enemy.lastPathTarget = FlxPoint.get();
			enemy.lastPathTarget.copyFrom(target);
			enemy.needsPathUpdate = false;
		}

		target.put();
	}

	/**
	 * Trigger alert cry when enemy spots player
	 * Propagates to nearby enemies via pathfinding
	 */
	private static function triggerAlertCry(alertedEnemy:Enemy, player:Player, allEnemies:FlxTypedGroup<Enemy>, tilemap:GameMap):Void
	{
		// Cooldown check
		if (cryCooldown > 0)
			return;

		// Play cry sound from this enemy
		var isVisible = alertedEnemy.alpha > 0.5;
		var cry = SoundHelper.playRandomChimeraCry(isVisible);

		if (cry != null)
		{
			var enemyMid = alertedEnemy.getMidpoint();
			cry.proximity(enemyMid.x, enemyMid.y, player, CRY_MAX_RADIUS, true);
			cry.play(true);

			// Propagate alert to nearby enemies via pathfinding
			var enemyArray:Array<Enemy> = [];
			for (e in allEnemies.members)
			{
				if (e != null && e.exists && e.alive && e != alertedEnemy)
					enemyArray.push(e);
			}

			// Use pathfinding-based sound propagation
			propagateSound(enemyMid, alertedEnemy.hearingRange * 1.5, enemyArray, tilemap, alertedEnemy);

			enemyMid.put();
			cryCooldown = MIN_CRY_DELAY;
		}
	}

	/**
	 * Trigger attack cry when enemy starts attacking
	 * Propagates to nearby enemies via pathfinding
	 */
	public static function triggerAttackCry(attackingEnemy:Enemy, player:Player, allEnemies:FlxTypedGroup<Enemy>, tilemap:GameMap):Void
	{
		// Cooldown check - prevent constant screaming
		if (attackCryCooldown > 0)
			return;

		// Play cry sound from this enemy
		var isVisible = attackingEnemy.alpha > 0.5;
		var cry = SoundHelper.playRandomChimeraCry(isVisible);

		if (cry != null)
		{
			var enemyMid = attackingEnemy.getMidpoint();
			cry.proximity(enemyMid.x, enemyMid.y, player, CRY_MAX_RADIUS, true);
			cry.play(true);

			// Set cooldown
			attackCryCooldown = MIN_ATTACK_CRY_DELAY;

			// Propagate attack cry to nearby enemies via pathfinding
			var enemyArray:Array<Enemy> = [];
			for (e in allEnemies.members)
			{
				if (e != null && e.exists && e.alive && e != attackingEnemy)
					enemyArray.push(e);
			}

			// Use pathfinding-based sound propagation (slightly larger radius for attack cries)
			propagateSound(enemyMid, attackingEnemy.hearingRange * 2.0, enemyArray, tilemap, attackingEnemy);

			enemyMid.put();
		}
	}

	/**
	 * Start sound propagation using flood-fill (spreads over multiple frames, no lag!)
	 */
	public static function propagateSound(origin:FlxPoint, loudness:Float, allEnemies:Array<Enemy>, tilemap:GameMap, ?sourceEnemy:Enemy = null):Void
	{
		// Start a new sound wave that will spread incrementally
		startSoundWave(origin.x, origin.y, loudness, sourceEnemy);
	}

	/**
	 * Update active sound waves - spreads flood-fill incrementally
	 * Call this from PlayState.update()
	 */
	public static function updateSoundWaves(tilemap:GameMap, allEnemies:Array<Enemy>):Void
	{
		var i = activeSoundWaves.length - 1;
		while (i >= 0)
		{
			var wave = activeSoundWaves[i];

			// Expand frontier by TILES_PER_FRAME tiles this frame
			var tilesExpanded = 0;
			while (tilesExpanded < TILES_PER_FRAME && wave.frontier.length > 0)
			{
				// Pop next tile from frontier
				var current = wave.frontier.shift();

				// Check if any enemy is at this tile
				for (enemy in allEnemies)
				{
					if (!enemy.exists || !enemy.alive)
						continue;

					var enemyTileX = Std.int(enemy.x / Constants.TILE_SIZE);
					var enemyTileY = Std.int(enemy.y / Constants.TILE_SIZE);

					if (enemyTileX == current.x && enemyTileY == current.y)
					{
						// Enemy found! Alert them based on source
						if (wave.sourceEnemy != null)
						{
							// Responding to another enemy's alert cry
							if (enemy.aggressionType == HUNTER || enemy.aggressionType == TERRITORIAL)
							{
								// Aggressive types move TOWARD the alert location
								if (enemy.aiState == IDLE)
								{
									var soundOrigin = FlxPoint.get(wave.originX, wave.originY);
									enemy.hearSound(soundOrigin);
									soundOrigin.put();
								}
							}
							else if (enemy.aggressionType == SKITTISH)
							{
								// Skittish types flee AWAY from alert
								if (enemy.aiState == IDLE)
								{
									enemy.changeState(FLEE);
									enemy.needsPathUpdate = true;
								}
							}
							// Ambushers stay still (ambush behavior)
						}
						else
						{
							// Generic sound (not from alert cry)
							var soundOrigin = FlxPoint.get(wave.originX, wave.originY);
							enemy.hearSound(soundOrigin);
							soundOrigin.put();
						}
					}
				}

				// Add neighbors to frontier if not visited and not blocked
				var neighbors = [
					{x: current.x + 1, y: current.y},
					{x: current.x - 1, y: current.y},
					{x: current.x, y: current.y + 1},
					{x: current.x, y: current.y - 1}
				];

				for (neighbor in neighbors)
				{
					// Check if already visited
					var key = neighbor.x + "," + neighbor.y;
					if (wave.visited.exists(key))
						continue;

					// Check if tile is walkable
					var tileIndex = tilemap.wallsMap.getTileIndex(neighbor.x, neighbor.y);
					if (tileIndex == 0) // 0 = walkable
					{
						// Calculate distance from origin
						var dx = (neighbor.x * Constants.TILE_SIZE + Constants.TILE_SIZE / 2) - wave.originX;
						var dy = (neighbor.y * Constants.TILE_SIZE + Constants.TILE_SIZE / 2) - wave.originY;
						var dist = Math.sqrt(dx * dx + dy * dy);

						// Only add if within loudness range
						if (dist < wave.loudness)
						{
							wave.frontier.push({x: neighbor.x, y: neighbor.y});
							wave.visited.set(key, true);
						}
					}
					else
					{
						// Mark wall as visited so we don't re-check it
						wave.visited.set(key, true);
					}
				}

				tilesExpanded++;
			}

			// Remove wave if frontier is empty (finished spreading)
			if (wave.frontier.length == 0)
			{
				activeSoundWaves.splice(i, 1);
			}

			i--;
		}
	}

	/**
	 * Start a new sound wave propagation
	 */
	private static function startSoundWave(originX:Float, originY:Float, loudness:Float, ?sourceEnemy:Enemy):Void
	{
		// Create new sound wave starting at origin tile
		var startTileX = Std.int(originX / Constants.TILE_SIZE);
		var startTileY = Std.int(originY / Constants.TILE_SIZE);

		var wave:SoundWave = {
			originX: originX,
			originY: originY,
			loudness: loudness,
			sourceEnemy: sourceEnemy,
			frontier: [{x: startTileX, y: startTileY}],
			visited: new Map<String, Bool>()
		};

		wave.visited.set(startTileX + "," + startTileY, true);
		activeSoundWaves.push(wave);
	}
}

/**
 * Represents a sound wave spreading through the map
 */
typedef SoundWave =
{
	var originX:Float;
	var originY:Float;
	var loudness:Float;
	var sourceEnemy:Null<Enemy>;
	var frontier:Array<{x:Int, y:Int}>;
	var visited:Map<String, Bool>;
}
