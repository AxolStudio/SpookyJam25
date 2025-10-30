package;

import axollib.AxolAPI;
import flixel.FlxG;
import flixel.util.FlxSave;
import util.SoundHelper;

class Globals
{
	private static var _initialized:Bool = false;

	public static var usingMouse:Bool = false;
	public static var gameSave:FlxSave;
	public static var savedCreatures:Array<SavedCreature> = [];
	public static var playerMoney:Int = 0;

	public static var playerID:String = "";

	// Fame system
	public static var fameLevel:Int = 1; // 1-10 (shown as 'A' at 10)
	public static var currentFame:Int = 0;

	public static function init():Void
	{
		if (_initialized)
			return;
		_initialized = true;

		FlxG.autoPause = false;

		Actions.init();
		SoundHelper.initSounds();

		// Preload commonly used graphics to prevent lag spikes
		preloadAssets();

		if (Constants.Mouse == null)
		{
			Constants.Mouse = new MouseHandler();
		}
		Constants.Mouse.init();

		// Start with mouse cursor hidden
		FlxG.mouse.visible = false;

		// Initialize save system
		initSave();
		AxolAPI.initSave(playerID, gameSave);
		AxolAPI.initialize("7F2F79A96ED8A86D115894216E9EB", playerID);
		AxolAPI.sendEvent("GAME_START");
	}
	private static function preloadAssets():Void
	{
		// Preload all commonly used graphics
		FlxG.bitmap.add("assets/images/reticle.png");
		FlxG.bitmap.add("assets/images/small-font.png");
		FlxG.bitmap.add("assets/ui/ui_box_16x16.png");
		FlxG.bitmap.add("assets/ui/button.png");
		FlxG.bitmap.add("assets/ui/mainmenu_bg.png");
		FlxG.bitmap.add("assets/ui/mainmenu_logo.png");
		FlxG.bitmap.add("assets/ui/bg.png");
		FlxG.bitmap.add("assets/ui/board.png");
		FlxG.bitmap.add("assets/ui/desk.png");
		FlxG.bitmap.add("assets/ui/hover_desk.png");
		FlxG.bitmap.add("assets/ui/phone.png");
		FlxG.bitmap.add("assets/ui/hover_phone.png");
		FlxG.bitmap.add("assets/ui/office_portal.png");
		FlxG.bitmap.add("assets/ui/hover_portal.png");
		FlxG.bitmap.add("assets/ui/trash.png");
		FlxG.bitmap.add("assets/ui/hover_trash.png");
		FlxG.bitmap.add("assets/images/player.png");
		FlxG.bitmap.add("assets/images/enemies.png");
		FlxG.bitmap.add("assets/images/portal.png");
		FlxG.bitmap.add("assets/images/floor.png");
		FlxG.bitmap.add("assets/images/autotiles.png");
		FlxG.bitmap.add("assets/images/hud_film.png");
		FlxG.bitmap.add("assets/images/hud_o2.png");
		FlxG.bitmap.add("assets/images/hud_bulb.png");
		FlxG.bitmap.add("assets/ui/room_report.png");
		FlxG.bitmap.add("assets/ui/paperclip.png");
		FlxG.bitmap.add("assets/ui/star_pip.png");
		FlxG.bitmap.add("assets/ui/fame_level_lg.png");
		FlxG.bitmap.add("assets/images/photos.png");
	}

	public static function initSave():Void
	{
		gameSave = new FlxSave();
		gameSave.bind("SpookyJam25Save");

		// Load saved creatures if they exist
		if (gameSave.data.creatures != null)
		{
			savedCreatures = gameSave.data.creatures;
		}
		else
		{
			savedCreatures = [];
		}

		// Load player money
		if (gameSave.data.money != null)
		{
			playerMoney = gameSave.data.money;
		}
		else
		{
			playerMoney = 0;
		}

		// Load fame data
		if (gameSave.data.fameLevel != null)
		{
			fameLevel = gameSave.data.fameLevel;
		}
		else
		{
			fameLevel = 1;
		}

		if (gameSave.data.currentFame != null)
		{
			currentFame = gameSave.data.currentFame;
		}
		else
		{
			currentFame = 0;
		}

		if (gameSave.data.playerID != null)
		{
			playerID = gameSave.data.playerID;
		}
		else
		{
			playerID = AxolAPI.generateGUID();
			gameSave.data.playerID = playerID;
			gameSave.flush();
		}
	}

	public static function saveCreature(creature:SavedCreature, rewardAmount:Int):Void
	{
		savedCreatures.push(creature);
		playerMoney += rewardAmount;
		gameSave.data.creatures = savedCreatures;
		gameSave.data.money = playerMoney;
		gameSave.flush();
	}

	public static function addFame(amount:Int):Void
	{
		currentFame += amount;
		gameSave.data.currentFame = currentFame;
		gameSave.data.fameLevel = fameLevel;
		gameSave.flush();
	}

	public static function getFameNeededForLevel(level:Int):Int
	{
		return 50 * level; // 50, 100, 150, 200...
	}

	public static function getFameNeededForNextLevel():Int
	{
		if (fameLevel >= 10)
			return 0; // Max level
		return getFameNeededForLevel(fameLevel);
	}

	public static function getFameLevelDisplay():String
	{
		return fameLevel >= 10 ? "A" : Std.string(fameLevel);
	}

	public static function clearAllData():Void
	{
		if (gameSave != null)
		{
			gameSave.erase();
		}
		savedCreatures = [];
		playerMoney = 0;
		fameLevel = 1;
		currentFame = 0;
		initSave();
	}
}
