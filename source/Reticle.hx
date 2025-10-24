package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.math.FlxPoint;
import flixel.math.FlxAngle;

class Reticle extends FlxSprite
{
	public var reticleAngle:Float = 0;
	public var reticleDistance:Float = 32;
	public var minDistance:Float = 16;
	public var maxDistance:Float = 96;

	public var stickDeadzone:Float = 0.25;
	public var maxRadialSpeed:Float = 60;
	public var angleTolerance:Float = 45;
	public var maxAngularSpeed:Float = 60;
	public var perpendicularTolerance:Float = 30;
	public var minRelativeAngle:Float = -45;
	public var maxRelativeAngle:Float = 45;
	public var stickCursorSpeed:Float = 240;

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

		reticleAngle = 0;
		reticleDistance = Math.max(minDistance, Math.min(maxDistance, reticleDistance));
	}

	public function updateFromPlayer(player:Player, cam:FlxCamera):Void
	{

		if (reticleDistance < minDistance)
			reticleDistance = minDistance;
		if (reticleDistance > maxDistance)
			reticleDistance = maxDistance;


		var normalize = function(a:Float):Float
		{
			var v = a % 360;
			if (v > 180)
				v -= 360;
			if (v <= -180)
				v += 360;
			return v;
		}


		Actions.rightStick.check();
		var rs = Actions.rightStick;
		var rsActive:Bool = Math.abs(rs.x) > stickDeadzone || Math.abs(rs.y) > stickDeadzone;

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


		if (mouseMoved)
			Actions.usingGamepad = false;
		else if (rsActive)
			Actions.usingGamepad = true;


		var pm:FlxPoint = null;
		var pm2:FlxPoint = null;
		if (Actions.usingGamepad && rsActive)
		{

			pm = player.getMidpoint();
			var pcx:Float = pm.x;
			var pcy:Float = pm.y;

			var radCur:Float = (player.moveAngle + reticleAngle) * FlxAngle.TO_RAD;
			var rx:Float = pcx + Math.cos(radCur) * reticleDistance;
			var ry:Float = pcy + Math.sin(radCur) * reticleDistance;


			var dxScreen:Float = rs.x * stickCursorSpeed * FlxG.elapsed;
			var dyScreen:Float = rs.y * stickCursorSpeed * FlxG.elapsed;


			var dxWorld:Float = dxScreen / cam.zoom;
			var dyWorld:Float = dyScreen / cam.zoom;


			rx += dxWorld;
			ry += dyWorld;


			var ndx:Float = rx - pcx;
			var ndy:Float = ry - pcy;
			var newDist:Float = Math.sqrt(ndx * ndx + ndy * ndy);
			if (newDist < 0.001)
				newDist = 0.001;
			var newDeg:Float = Math.atan2(ndy, ndx) * FlxAngle.TO_DEG;
			var desiredRel2:Float = normalize(newDeg - player.moveAngle);

			if (desiredRel2 < minRelativeAngle)
				desiredRel2 = minRelativeAngle;
			if (desiredRel2 > maxRelativeAngle)
				desiredRel2 = maxRelativeAngle;
			reticleAngle = desiredRel2;
			reticleDistance = Math.max(minDistance, Math.min(maxDistance, newDist));
		}
		else if (!Actions.usingGamepad)
		{

			var mx:Float;
			var my:Float;

			var p = null;
			if (FlxG.mouse != null)
			{
				try
				{
					p = FlxG.mouse.getWorldPosition(cam);
				}
				catch (e:Dynamic)
				{
					p = null;
				}
			}
			if (p != null)
			{
				mx = p.x;
				my = p.y;
			}
			else
			{

				mx = cam.scroll.x + (FlxG.mouse.viewX - cam.x) / cam.zoom;
				my = cam.scroll.y + (FlxG.mouse.viewY - cam.y) / cam.zoom;
			}
			var pm_mouse:FlxPoint = player.getMidpoint();
			var cx:Float = pm_mouse.x;
			var cy:Float = pm_mouse.y;
			var dx:Float = mx - cx;
			var dy:Float = my - cy;
			if (dx != 0 || dy != 0)
			{
				var worldDeg2:Float = Math.atan2(dy, dx) * FlxAngle.TO_DEG;
				var desiredRel:Float = normalize(worldDeg2 - player.moveAngle);

				if (desiredRel < minRelativeAngle)
					desiredRel = minRelativeAngle;
				if (desiredRel > maxRelativeAngle)
					desiredRel = maxRelativeAngle;
				reticleAngle = desiredRel;

				var mDist:Float = Math.sqrt(dx * dx + dy * dy);
				reticleDistance = Math.max(minDistance, Math.min(maxDistance, mDist));
				pm_mouse.put();
			}
		}


		if (reticleAngle < minRelativeAngle)
			reticleAngle = minRelativeAngle;
		if (reticleAngle > maxRelativeAngle)
			reticleAngle = maxRelativeAngle;


		var worldAngleDeg:Float = player.moveAngle + reticleAngle;


		var rad:Float = worldAngleDeg * FlxAngle.TO_RAD;


		if (pm == null)
			pm = player.getMidpoint();
		pm2 = player.getMidpoint();
		var cx:Float = pm2.x;
		var cy:Float = pm2.y;

		x = cx + Math.cos(rad) * reticleDistance - width / 2;
		y = cy + Math.sin(rad) * reticleDistance - height / 2;
		if (pm != null)
			pm.put();
		if (pm2 != null)
			pm2.put();
	}
}
