package;

import flixel.util.FlxColor;

class Player extends GameObject
{
	public static inline var SPEED:Float = 50;

	public function new(tileX:Int, tileY:Int)
	{
		super(tileX, tileY);
		speed = SPEED;
		moveAngle = 90;
	}
	public override function buildGraphics():Void
	{
		makeGraphic(Constants.TILE_SIZE, Constants.TILE_SIZE, FlxColor.WHITE);
	}
}
