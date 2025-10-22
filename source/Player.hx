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
		// load 4x8 sprite sheet: 4 frames per direction, 8 directions (rows)
		loadGraphic("assets/images/player.png", true, 16, 19, false, "player");

		// animation order in the sheet (row-major): UP_LEFT, UP, UP_RIGHT, LEFT, RIGHT, DOWN_LEFT, DOWN, DOWN_RIGHT
		var names = ["up_left", "up", "up_right", "left", "right", "down_left", "down", "down_right"];
		for (i in 0...names.length)
		{
			var base = i * 4;
			// frame 0 of each direction is the stopped frame; walk uses 1,2,3,0
			animation.add("walk_" + names[i], [base + 1, base + 2, base + 3, base + 0], 10, true);
			// idle shows the stopped frame (base + 0)
			animation.add("idle_" + names[i], [base + 0], 0, true);
		}
		// default facing down
		currentDir = 6; // DOWN
		animation.play("idle_down");
	}

	// current facing direction index (0..7 matches names array)
	private var currentDir:Int = 6;

	// map an angle in degrees to sheet direction index
	private function angleToDirIndex(angle:Float):Int
	{
		var a = angle % 360.0;
		if (a < 0)
			a += 360.0;
		// sectors centered on: 0=right, 45=down-right, 90=down, 135=down-left, 180=left, 225=up-left, 270=up, 315=up-right
		if (a >= 337.5 || a < 22.5)
			return 4; // RIGHT
		if (a >= 22.5 && a < 67.5)
			return 7; // DOWN_RIGHT
		if (a >= 67.5 && a < 112.5)
			return 6; // DOWN
		if (a >= 112.5 && a < 157.5)
			return 5; // DOWN_LEFT
		if (a >= 157.5 && a < 202.5)
			return 3; // LEFT
		if (a >= 202.5 && a < 247.5)
			return 0; // UP_LEFT
		if (a >= 247.5 && a < 292.5)
			return 1; // UP
		return 2; // UP_RIGHT (292.5..337.5)
	}

	public override function move(angleDegrees:Float):Void
	{
		super.move(angleDegrees);
		var dir = angleToDirIndex(angleDegrees);
		var dirNames = ["up_left", "up", "up_right", "left", "right", "down_left", "down", "down_right"];
		var animName = "walk_" + dirNames[dir];
		var curName:String = "";
		if (animation != null && animation.curAnim != null)
		{
			curName = animation.curAnim.name;
		}
		if (curName != animName)
		{
			animation.play(animName);
		}
		currentDir = dir;
	}

	public override function stop():Void
	{
		super.stop();
		// stop animation and show the stopped frame for current direction
		if (animation != null)
			animation.stop();
		// play the idle animation for currentDir so the correct stopped frame shows
		var idleName = "idle_" + ["up_left", "up", "up_right", "left", "right", "down_left", "down", "down_right"][currentDir];
		if (animation != null)
			animation.play(idleName);
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
