package ai;

import flixel.math.FlxPoint;
import flixel.FlxG;
import flixel.FlxCamera;
import flixel.group.FlxGroup.FlxTypedGroup;
import Player;
import Enemy;
import GameMap;
import flixel.math.FlxAngle;

class EnemyBrain
{
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
					#if (debug)
					trace('EnemyBrain: ' + Std.string(e.variant) + ' flee (roll=' + Std.string(roll) + ',aggr=' + Std.string(e.aggression) + ')');
					#end
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
					#if (debug)
					trace('EnemyBrain: ' + Std.string(e.variant) + ' attack (roll=' + Std.string(roll) + ',aggr=' + Std.string(e.aggression) + ')');
					#end
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
					#if (debug)
					trace('EnemyBrain: '
						+ Std.string(e.variant)
						+ ' seen-wander (roll='
						+ Std.string(roll)
						+ ',aggr='
						+ Std.string(e.aggression)
						+ ')');
					#end
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
					#if (debug)
					trace('EnemyBrain: ' + Std.string(e.variant) + ' wander (not seen)');
					#end
				}
				else
				{
					e.stop();
					e.aiState = 0;
					#if (debug)
					trace('EnemyBrain: ' + Std.string(e.variant) + ' stopped (not seen)');
					#end
				}
			}

			if (!scheduled)
				e.aiTimer = e.aiDecisionInterval * FlxG.random.float(0.8, 1.6);
			e.lastSawPlayer = sees;

			eMid.put();
			pMid.put();
		}
	}
}
