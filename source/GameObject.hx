package;

import flixel.FlxSprite;

/**
 * Minimal GameObject base used by Player and enemies.
 * Only provides velocity-based movement (move/stop).
 */
class GameObject extends FlxSprite
{
	// public max speed in pixels/second (simple field — easy to change)
	public var speed:Float = 80;

	public function new(X:Float = 0, Y:Float = 0)
	{
		super(X, Y);
		this.maxVelocity.set(speed, speed);
	}

	// immediate velocity set in heading (degrees)
	public function move(angleDegrees:Float):Void
	{
		var rad:Float = angleDegrees * Math.PI / 180.0;
		this.velocity.set(Math.cos(rad) * speed, Math.sin(rad) * speed);
	}

	// instant stop
	public function stop():Void
	{
		this.velocity.set(0, 0);
		this.acceleration.set(0, 0);
	}
}
