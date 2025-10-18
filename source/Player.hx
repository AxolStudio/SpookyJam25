package;

import flixel.util.FlxColor;

class Player extends GameObject
{
	public static inline var SPEED:Float = 80;

	public function new(X:Float, Y:Float)
	{
		super(X, Y);
		this.speed = SPEED;
		makeGraphic(16, 16, FlxColor.WHITE);
	}
}
