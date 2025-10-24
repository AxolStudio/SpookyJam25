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

	private static var mAngle:Float = -1;
	private static var mDist:Float = -1;
	private static var mTime:Float = -1;

	private static var eMid:FlxPoint;
	private static var pMid:FlxPoint;
	private static var ex:Float = -1;
	private static var ey:Float = -1;
	private static var px:Float = -1;
	private static var py:Float = -1;
	private static var dx:Float = -1;
	private static var dy:Float = -1;
	private static var dist2:Float = -1;
	private static var sees:Bool = false;
	private static var bold:Float = -1;
	private static var roll:Float = -1;

	public static function process(player:Player, enemies:FlxTypedGroup<Enemy>, tilemap:GameMap, elapsed:Float, ?cam:FlxCamera):Void
	{
		if (player == null || enemies == null || tilemap == null || cam == null)
			return;
		if (LOS_DISTANCE <= 0.0)
		{
			LOS_DISTANCE = FlxG.width * 0.66;
			LOS_DISTANCE_SQR = LOS_DISTANCE * LOS_DISTANCE;
		}

		for (e in enemies.members.filter((e) -> e != null && e.exists && e.alive))
		{
			if (!e.isOnScreen(cam))
			{
				e.stop();
				continue;
			}

			e.aiTimer -= elapsed;

			eMid = e.getMidpoint();
			pMid = player.getMidpoint();
			ex = eMid.x;
			ey = eMid.y;
			px = pMid.x;
			py = pMid.y;
			dx = px - ex;
			dy = py - ey;
			dist2 = dx * dx + dy * dy;

			sees = false;
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
				continue;
			}

			bold = e.aggression - e.skittishness;
			roll = FlxG.random.float();

			if (sees && dist2 <= LOS_DISTANCE_SQR)
			{
				if (bold > 0 && roll < Math.min(1.0, bold + 0.25))
				{
					// get degrees and ensure the short-step isn't immediately blocked
					mAngle = FlxAngle.degreesBetween(e, player);
					mAngle = findClearAngle(tilemap, ex, ey, mAngle, 12);
					mDist = FlxG.random.float(16.0, 40.0);
					mTime = mDist * e.speed;
					// clamp to a minimum duration to avoid jittery tiny moves
					if (mTime < 0.12)
						mTime = 0.12;
					e.startTimedMove(mAngle, mTime);
					// prevent the AI from re-evaluating while the timed move is in progress
					e.aiTimer = mTime + 0.05;
					e.aiState = 1;
					#if (debug)
					trace('EnemyBrain: ' + Std.string(e.variant) + ' attack-pursuit (bold=' + Std.string(bold) + ',roll=' + Std.string(roll) + ')');
					#end
				}
				else if (bold < 0 && roll < Math.min(1.0, -bold + 0.25))
				{
					mAngle = FlxAngle.degreesBetween(player, e) + FlxG.random.float(-2.0, 2.0);
					mAngle = findClearAngle(tilemap, ex, ey, mAngle, 12);
					mDist = FlxG.random.float(16.0, 40.0);
					mTime = mDist * e.speed;
					if (mTime < 0.12)
						mTime = 0.12;
					e.startTimedMove(mAngle, mTime);
					e.aiTimer = mTime + 0.05;
					e.aiState = 2;
					#if (debug)
					trace('EnemyBrain: ' + Std.string(e.variant) + ' flee-pursuit (bold=' + Std.string(bold) + ',roll=' + Std.string(roll) + ')');
					#end
				}
				else
				{
					mAngle = FlxG.random.float(0, 360);
					mTime = FlxG.random.float(1.0, 3.0);
					if (mTime < 0.12)
						mTime = 0.12;
					// avoid re-evaluation during wander burst
					e.aiTimer = mTime + 0.05;
					e.startTimedMove(mAngle, mTime);
					#if (debug)
					trace('EnemyBrain: ' + Std.string(e.variant) + ' wander (seen)');
					#end
				}
			}
			else
			{
				if (FlxG.random.float() < 0.25)
				{
					mAngle = FlxG.random.float(0, 360);
					mTime = FlxG.random.float(1.0, 3.0);
					if (mTime < 0.12)
						mTime = 0.12;
					// avoid re-evaluation during wander burst
					e.aiTimer = mTime + 0.05;
					e.startTimedMove(mAngle, mTime);
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

			e.aiTimer = e.aiDecisionInterval * FlxG.random.float(0.8, 1.6);

			e.lastSawPlayer = sees;
		}
		if (eMid != null)
			eMid.put();
		if (pMid != null)
			pMid.put();
	}
}
