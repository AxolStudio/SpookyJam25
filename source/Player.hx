package;

import flixel.util.FlxColor;

class Player extends GameObject
{
	public static inline var SPEED:Float = 80;

	public function new(X:Float, Y:Float)
	{
		super(X, Y);
		this.speed = SPEED;
		// accel will be derived as DEFAULT_ACCEL_MULT * speed by GameObject if unset
		makeGraphic(16, 16, FlxColor.WHITE);
	}
}
