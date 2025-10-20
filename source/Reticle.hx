package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;

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
	// when using the right stick in "mouse mode", this is the cursor speed in screen pixels/sec
	public var stickCursorSpeed:Float = 240;

	// track last mouse view position to detect mouse movement
	private var lastMouseViewX:Float = -1;
	private var lastMouseViewY:Float = -1;

	public function new(Parent:Player)
	{
		super();
		loadGraphic("assets/images/reticle.png", true, Constants.TILE_SIZE, Constants.TILE_SIZE, false, 'reticle');
		animation.add("blink", [0, 1], 12, true);
		animation.play("blink");
		width = height = 14;
		offset.x = offset.y = 1;
		

		// defaults
		reticleAngle = 0;
		reticleDistance = Math.max(minDistance, Math.min(maxDistance, reticleDistance));
	}

	public function updateFromPlayer(player:Player, cam:FlxCamera):Void
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

		// check right stick and mouse to decide control source
		Actions.rightStick.check();
		var rs = Actions.rightStick;
		var rsActive:Bool = Math.abs(rs.x) > stickDeadzone || Math.abs(rs.y) > stickDeadzone;
		// detect mouse movement in view coords
		var mouseMoved:Bool = false;
		var curViewX:Float = FlxG.mouse.viewX;
		var curViewY:Float = FlxG.mouse.viewY;
		if (lastMouseViewX < 0 || lastMouseViewY < 0)
		{
			lastMouseViewX = curViewX;
			lastMouseViewY = curViewY;
		}
		else
		{
			if (curViewX != lastMouseViewX || curViewY != lastMouseViewY)
				mouseMoved = true;
			lastMouseViewX = curViewX;
			lastMouseViewY = curViewY;
		}

		// If the player moved the mouse, switch to mouse control. If the right stick is active, switch to gamepad.
		if (mouseMoved)
			Actions.usingGamepad = false;
		else if (rsActive)
			Actions.usingGamepad = true;

		// If usingGamepad is true, process only gamepad input. Otherwise only mouse controls the reticle.
		if (Actions.usingGamepad && rsActive)
		{
			// Move the reticle like a mouse: treat stick input as a screen-space delta and
			// convert that to world-space (accounting for camera zoom), then update the
			// reticle's polar coordinates relative to the player.
			// compute player's center
			var pcx:Float = player.x + player.width / 2;
			var pcy:Float = player.y + player.height / 2;

			// current reticle world position
			var radCur:Float = (player.moveAngle + reticleAngle) * Math.PI / 180.0;
			var rx:Float = pcx + Math.cos(radCur) * reticleDistance;
			var ry:Float = pcy + Math.sin(radCur) * reticleDistance;

			// stick gives direction in [-1,1]; convert to screen pixels delta
			var dxScreen:Float = rs.x * stickCursorSpeed * FlxG.elapsed;
			var dyScreen:Float = rs.y * stickCursorSpeed * FlxG.elapsed;

			// convert screen delta to world delta (account for camera zoom)
			var dxWorld:Float = dxScreen / cam.zoom;
			var dyWorld:Float = dyScreen / cam.zoom;

			// apply delta to reticle world position
			rx += dxWorld;
			ry += dyWorld;

			// recompute polar coords relative to player center
			var ndx:Float = rx - pcx;
			var ndy:Float = ry - pcy;
			var newDist:Float = Math.sqrt(ndx * ndx + ndy * ndy);
			if (newDist < 0.001)
				newDist = 0.001;
			var newDeg:Float = Math.atan2(ndy, ndx) * 180.0 / Math.PI;
			var desiredRel2:Float = normalize(newDeg - player.moveAngle);
			// clamp relative angle and distance
			if (desiredRel2 < minRelativeAngle)
				desiredRel2 = minRelativeAngle;
			if (desiredRel2 > maxRelativeAngle)
				desiredRel2 = maxRelativeAngle;
			reticleAngle = desiredRel2;
			reticleDistance = Math.max(minDistance, Math.min(maxDistance, newDist));
		}
		else if (!Actions.usingGamepad)
		{
			// mouse handling: set angle and distance directly from mouse world position
			// Prefer FlxG.mouse.getWorldPosition(cam) if available (handles viewport & zoom)
			var mx:Float;
			var my:Float;
			try
			{
				var p = FlxG.mouse.getWorldPosition(cam);
				mx = p.x;
				my = p.y;
			}
			catch (e:Dynamic)
			{
				// fallback: manually convert view coords for the provided camera
				mx = cam.scroll.x + (FlxG.mouse.viewX - cam.x) / cam.zoom;
				my = cam.scroll.y + (FlxG.mouse.viewY - cam.y) / cam.zoom;
			}
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
