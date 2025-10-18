package;

import flixel.util.FlxColor;

class Player extends GameObject
{
	public static inline var SPEED:Float = 50;

	public function new(X:Float, Y:Float)
	{
		super(X, Y);
		speed = SPEED;
		makeGraphic(16, 16, FlxColor.WHITE);
		moveAngle = 90;
	}
}
