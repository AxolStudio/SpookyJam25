package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.math.FlxPoint;
import flixel.math.FlxAngle;
import flixel.util.FlxColor;

using Types.ReticleState;

class Reticle extends FlxSprite
{
	public var reticleAngle:Float = 0;
	public var reticleDistance:Float = 32;
	public var minDistance:Float = 16;
	public var maxDistance:Float = 96;
	public var currentState:ReticleState = NEUTRAL;
	private var player:Player;

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
		player = Parent;
		
		loadGraphic("assets/images/reticle.png", true, Constants.TILE_SIZE, Constants.TILE_SIZE, false, 'reticle');
		animation.add("blink", [0, 1], 12, true);
		animation.play("blink");
		width = height = 14;
		offset.x = offset.y = 1;
		centerOrigin();
		reticleAngle = 0;
		reticleDistance = Math.max(minDistance, Math.min(maxDistance, reticleDistance));
	}

	override function set_cameras(value:Array<FlxCamera>):Array<FlxCamera>
	{
		super.set_cameras(value);
		return value;
	}

	public function updateState(enemies:flixel.group.FlxGroup.FlxTypedGroup<Enemy>):Void
	{
		if (player.film <= 0)
		{
			setState(OUT_OF_FILM);
			return;
		}
		if (player.photoCooldown > 0)
		{
			setState(ON_COOLDOWN);
			return;
		}
		var targetingEnemy:Bool = false;
		if (enemies != null)
		{
			for (enemy in enemies.members)
			{
				if (enemy != null && enemy.alive && enemy.exists)
				{
					if (overlaps(enemy))
					{
						targetingEnemy = true;
						break;
					}
				}
			}
		}
		if (targetingEnemy)
			setState(ENEMY_TARGETED);
		else
			setState(NEUTRAL);
	}

	private function setState(newState:ReticleState):Void
	{
		if (currentState == newState)
			return;

		currentState = newState;

		switch (newState)
		{
			case NEUTRAL:
				color = FlxColor.WHITE;
			case ENEMY_TARGETED:
				color = FlxColor.LIME; // Bright green
			case OUT_OF_FILM:
				color = FlxColor.RED;
			case ON_COOLDOWN:
				color = FlxColor.YELLOW;
		}
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
		var touchActive:Bool = false;
		if (FlxG.touches.list != null && FlxG.touches.list.length > 0)
		{
			var primaryTouch = FlxG.touches.list[0];
			if (primaryTouch != null)
			{
				curViewX = primaryTouch.viewX;
				curViewY = primaryTouch.viewY;
				touchActive = true;
			}
		}
		
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


		if (mouseMoved || touchActive)
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
			var useViewX:Float = FlxG.mouse.viewX;
			var useViewY:Float = FlxG.mouse.viewY;
			if (FlxG.touches.list != null && FlxG.touches.list.length > 0)
			{
				var primaryTouch = FlxG.touches.list[0];
				if (primaryTouch != null)
				{
					useViewX = primaryTouch.viewX;
					useViewY = primaryTouch.viewY;
				}
			}
			var p = null;
			if (FlxG.mouse != null)
			{
				try
				{
					p = FlxG.mouse.getWorldPosition(cam);
					if (FlxG.touches.list != null && FlxG.touches.list.length > 0)
					{
						var primaryTouch = FlxG.touches.list[0];
						if (primaryTouch != null)
						{
							try
							{
								p = primaryTouch.getWorldPosition(cam);
							}
							catch (e:Dynamic)
							{
								p = null;
							}
						}
					}
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

				mx = cam.scroll.x + (useViewX - cam.x) / cam.zoom;
				my = cam.scroll.y + (useViewY - cam.y) / cam.zoom;
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

		// Position so the CENTER of the 16x16 graphic aligns with the target point
		// The graphic is 16x16, so subtract 8 to center it
		x = cx + Math.cos(rad) * reticleDistance - 8;
		y = cy + Math.sin(rad) * reticleDistance - 8;

		if (pm != null)
			pm.put();
		if (pm2 != null)
			pm2.put();
	}
	public override function draw():Void
	{
		super.draw();
	}

	public override function destroy():Void
	{
		player = null;
		super.destroy();
	}
}
