package ai;

import flixel.FlxG;
import flixel.FlxCamera;
import Enemy;

class EnemyAI
{
	// Simple helper: return true if the enemy is offscreen by a margin (we should skip AI updates)
	public static function isOffscreen(e:Enemy, margin:Float = 32.0):Bool
	{
		var cam:FlxCamera = FlxG.camera;
		if (cam == null || e == null)
			return false;
		var screenX:Float = (e.x + e.width * 0.5) - cam.scroll.x;
		var screenY:Float = (e.y + e.height * 0.5) - cam.scroll.y;
		if (screenX < -margin || screenY < -margin || screenX > cam.width + margin || screenY > cam.height + margin)
			return true;
		return false;
	}
}
