package;

import flixel.FlxSprite;

class GameObject extends FlxSprite
{
	public var speed:Float = 80;
	public var moveAngle:Float = 0;

	public function new(X:Float = 0, Y:Float = 0)
	{
		super(X, Y);
		maxVelocity.set(speed, speed);
	}

	public function move(angleDegrees:Float):Void
	{
		moveAngle = angleDegrees;
		var rad:Float = angleDegrees * Math.PI / 180.0;
		velocity.set(Math.cos(rad) * speed, Math.sin(rad) * speed);
	}

	public function stop():Void
	{
		velocity.set(0, 0);
		acceleration.set(0, 0);
	}
}
