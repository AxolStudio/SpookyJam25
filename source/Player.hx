package;

import flixel.FlxG;
import util.SoundHelper;

class Player extends GameObject
{
	public static inline var BASE_SPEED:Float = 50;
	public static inline var BASE_O2:Float = 50; // Halved from 100
	public static inline var BASE_ARMOR:Int = 0; // Flat damage reduction

	public var film:Int = Constants.PHOTO_START_FILM;
	public var o2:Float = 50;
	public var armor:Int = 0;

	public var photoCooldown(default, null):Float = 0;

	// Invincibility system for taking damage
	public var invincibilityTimer:Float = 0;

	public var flickerTimer:Float = 0;

	private static inline var FLICKER_INTERVAL:Float = 0.1;

	public var captured:Array<CapturedInfo> = [];

	public function getCaptured():Array<CapturedInfo>
	{
		return captured;
	}

	public function clearCaptured():Void
	{
		captured = [];
	}

	public function new(tileX:Int, tileY:Int)
	{
		super(tileX, tileY);
		// Apply upgrades
		applyUpgrades();
		
		moveAngle = 90;
		width = height = 12;
		offset.x = 2;
		offset.y = 7;
		x += 2;
		y -= height;
	}
	private function applyUpgrades():Void
	{
		// Get upgrade levels from Globals
		var o2Level = getUpgradeLevel("o2");
		var speedLevel = getUpgradeLevel("speed");
		var armorLevel = getUpgradeLevel("armor");
		var filmLevel = getUpgradeLevel("film");

		// Apply speed upgrade: +10% per level
		speed = BASE_SPEED * (1.0 + speedLevel * 0.1);

		// Apply O2 upgrade: base * level (50, 100, 150, 200, 250)
		o2 = BASE_O2 * (o2Level > 0 ? o2Level : 1);

		// Apply armor upgrade: -1 damage per level
		armor = armorLevel;

		// Apply film upgrade: base film + (5 + (level - 1)) per level
		// Level 0: 5, Level 1: 10 (5+5), Level 2: 16 (5+5+6), Level 3: 23 (5+5+6+7), Level 4: 31 (5+5+6+7+8), Level 5: 40 (5+5+6+7+8+9)
		film = Constants.PHOTO_START_FILM;
		for (i in 0...filmLevel)
		{
			film += 5 + i;
		}

		trace("Player upgrades applied - Speed: " + speed + ", O2: " + o2 + ", Armor: " + armor + ", Film: " + film);
	}

	private function getUpgradeLevel(key:String):Int
	{
		if (Globals.gameSave.data.upgrades == null)
			return 0;

		var level = Reflect.field(Globals.gameSave.data.upgrades, key);
		return level != null ? level : 0;
	}

	public override function buildGraphics():Void
	{
		loadGraphic("assets/images/player.png", true, 16, 19, false, "player");

		var names = ["up_left", "up", "up_right", "left", "right", "down_left", "down", "down_right"];
		for (i in 0...names.length)
		{
			var base = i * 4;

			animation.add("walk_" + names[i], [base + 1, base + 2, base + 3, base + 0], 10, true);

			animation.add("idle_" + names[i], [base + 0], 0, true);
		}
		currentDir = 6;
		animation.play("idle_down");
	}

	private var currentDir:Int = 6;

	private function angleToDirIndex(angle:Float):Int
	{
		var a = angle % 360.0;
		if (a < 0)
			a += 360.0;

		if (a >= 337.5 || a < 22.5)
			return 4;
		if (a >= 22.5 && a < 67.5)
			return 7;
		if (a >= 67.5 && a < 112.5)
			return 6;
		if (a >= 112.5 && a < 157.5)
			return 5;
		if (a >= 157.5 && a < 202.5)
			return 3;
		if (a >= 202.5 && a < 247.5)
			return 0;
		if (a >= 247.5 && a < 292.5)
			return 1;
		return 2;
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

		if (animation != null)
			animation.stop();

		var idleName = "idle_" + ["up_left", "up", "up_right", "left", "right", "down_left", "down", "down_right"][currentDir];
		if (animation != null)
			animation.play(idleName);
	}
	public var canDepleteo2:Bool = false;
	
	public override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (photoCooldown > 0)
			photoCooldown -= elapsed;
		if (canDepleteo2)
			o2 -= elapsed;
		if (invincibilityTimer > 0)
		{
			invincibilityTimer -= elapsed;
			flickerTimer -= elapsed;

			if (flickerTimer <= 0)
			{
				visible = !visible;
				flickerTimer = FLICKER_INTERVAL;
			}

			if (invincibilityTimer <= 0)
			{
				visible = true;
			}
		}
	}

	public function tryTakePhoto():Bool
	{
		if (film <= 0)
		{
			axollib.AxolAPI.sendEvent("OUT_OF_FILM");
			return false;
		}
		if (photoCooldown > 0)
			return false;
		film -= 1;
		if (film == 0)
		{
			axollib.AxolAPI.sendEvent("FILM_DEPLETED");
		}
		
		photoCooldown = Constants.PHOTO_COOLDOWN;

		SoundHelper.playSound("camera");
		FlxG.camera.flash(0xFFFFFFFF, Constants.PHOTO_FLASH_TIME, false);

		return true;
	}
}
