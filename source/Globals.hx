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

	public static function init():Void
	{
		if (_initialized)
			return;
		_initialized = true;

		FlxG.autoPause = false;

		FlxG.scaleMode = new flixel.system.scaleModes.PixelPerfectScaleMode();

		Actions.init();
		SoundHelper.initSounds();

		if (Constants.Mouse == null)
		{
			Constants.Mouse = new MouseHandler();
		}
		Constants.Mouse.init();

		// Start with mouse cursor hidden
		FlxG.mouse.visible = false;

		// Initialize save system
		initSave();

		AxolAPI.initialize("7F2F79A96ED8A86D115894216E9EB", playerID);
		AxolAPI.sendEvent("GAME_START");
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

	public static function clearAllData():Void
	{
		if (gameSave != null)
		{
			gameSave.erase();
		}
		savedCreatures = [];
		playerMoney = 0;
		initSave();
	}
}
