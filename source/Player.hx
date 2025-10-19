package;

import flixel.FlxG;
import flixel.util.FlxColor;

class Player extends GameObject
{
	public static inline var SPEED:Float = 50;

	// Photo mechanic state
	public var film:Int = Constants.PHOTO_START_FILM;

	public var photoCooldown(default, null):Float = 0;

	public var captured:Array<String> = [];

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
	public override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (photoCooldown > 0)
			photoCooldown -= elapsed;
	}

	// Called by PlayState when attack input is pressed. Returns true if a photo
	// was taken (film consumed and cooldown started).
	public function tryTakePhoto():Bool
	{
		if (film <= 0)
			return false;
		if (photoCooldown > 0)
			return false;
		film -= 1;
		photoCooldown = Constants.PHOTO_COOLDOWN;
		// camera flash
		FlxG.camera.flash(0xFFFFFFFF, Constants.PHOTO_FLASH_TIME, false);
		return true;
	}
}
