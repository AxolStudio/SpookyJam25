package;

import flixel.FlxG;
import flixel.FlxSprite;

class Reticle extends FlxSprite
{
	// relative angle from player's facing (degrees)
	public var reticleAngle:Float = 0;
	// radial distance from the player's center
	public var reticleDistance:Float = 32;
	public var minDistance:Float = 16;
	public var maxDistance:Float = 96;

	// right-stick distance control params
	public var stickDeadzone:Float = 0.25;
	public var maxRadialSpeed:Float = 60; // pixels per second when increasing/decreasing
	public var angleTolerance:Float = 45; // degrees tolerance for considering "same" or "opposite"
	public var maxAngularSpeed:Float = 60; // degrees per second when adjusting angle
	public var perpendicularTolerance:Float = 30; // degrees tolerance to consider "perpendicular"
	public var minRelativeAngle:Float = -45;
	public var maxRelativeAngle:Float = 45;

	public function new(Parent:Player)
	{
		super();
		loadGraphic("assets/images/reticle.png", true, Constants.TILE_SIZE, Constants.TILE_SIZE, false, 'reticle');
		animation.add("blink", [0, 1], 12, true);
		animation.play("blink");

		// defaults
		reticleAngle = 0;
		reticleDistance = Math.max(minDistance, Math.min(maxDistance, reticleDistance));
	}

	public function updateFromPlayer(player:Player):Void
	{
		// clamp distance
		if (reticleDistance < minDistance)
			reticleDistance = minDistance;
		if (reticleDistance > maxDistance)
			reticleDistance = maxDistance;

		// normalize helper (degrees -> [-180,180])
		var normalize = function(a:Float):Float
		{
			var v = a % 360;
			if (v > 180)
				v -= 360;
			if (v <= -180)
				v += 360;
			return v;
		}

		// check right stick and adjust distance if player is pointing toward/away
		Actions.rightStick.check();
		var rs = Actions.rightStick;
		var rsActive:Bool = Math.abs(rs.x) > stickDeadzone || Math.abs(rs.y) > stickDeadzone;
		if (rsActive)
		{
			// stick angle in degrees
			var stickDeg:Float = Math.atan2(rs.y, rs.x) * 180.0 / Math.PI;

			var diff:Float = Math.abs(normalize(stickDeg - player.moveAngle));
			// if stick points roughly the same direction as player -> increase distance
			if (diff <= angleTolerance)
			{
				reticleDistance += maxRadialSpeed * FlxG.elapsed;
			}
			// if stick points roughly opposite -> decrease distance
			else if (diff >= 180 - angleTolerance)
			{
				reticleDistance -= maxRadialSpeed * FlxG.elapsed;
			}

			// ANGLE control: if stick is roughly perpendicular to player facing, nudge relative angle
			var perpDiff = Math.abs(normalize(Math.abs(normalize(stickDeg - player.moveAngle)) - 90));
			if (perpDiff <= perpendicularTolerance)
			{
				// determine side: if stick is to the left of facing, increase angle; if right, decrease
				var signed = normalize(stickDeg - player.moveAngle);
				// signed > 0 means stick is rotated clockwise from facing (toward down/right depending)
				// We'll treat positive signed as moving angle positive
				var dir = (signed > 0) ? 1 : -1;
				reticleAngle += dir * maxAngularSpeed * FlxG.elapsed;
			}
		}
		else
		{
			// mouse handling: set angle and distance directly from mouse world position
			var mx:Float = FlxG.mouse.viewX + FlxG.camera.scroll.x;
			var my:Float = FlxG.mouse.viewY + FlxG.camera.scroll.y;
			var cx:Float = player.x + player.width / 2;
			var cy:Float = player.y + player.height / 2;
			var dx:Float = mx - cx;
			var dy:Float = my - cy;
			if (dx != 0 || dy != 0)
			{
				var worldDeg2:Float = Math.atan2(dy, dx) * 180.0 / Math.PI;
				var desiredRel:Float = normalize(worldDeg2 - player.moveAngle);
				// clamp relative angle
				if (desiredRel < minRelativeAngle)
					desiredRel = minRelativeAngle;
				if (desiredRel > maxRelativeAngle)
					desiredRel = maxRelativeAngle;
				reticleAngle = desiredRel;
				// distance
				var mDist:Float = Math.sqrt(dx * dx + dy * dy);
				reticleDistance = Math.max(minDistance, Math.min(maxDistance, mDist));
			}
		}

		// clamp relative angle
		if (reticleAngle < minRelativeAngle)
			reticleAngle = minRelativeAngle;
		if (reticleAngle > maxRelativeAngle)
			reticleAngle = maxRelativeAngle;

		// compute world angle in degrees
		var worldAngleDeg:Float = player.moveAngle + reticleAngle;

		// convert to radians for trig
		var rad:Float = worldAngleDeg * Math.PI / 180.0;

		// player's center (use width/height to compute midpoint)
		var cx:Float = player.x + player.width / 2;
		var cy:Float = player.y + player.height / 2;

		// world position
		x = cx + Math.cos(rad) * reticleDistance - width / 2;
		y = cy + Math.sin(rad) * reticleDistance - height / 2;
	}
}
