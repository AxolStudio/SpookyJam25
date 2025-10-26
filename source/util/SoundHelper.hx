package util;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;

@:access(flixel.sound.FlxSound)
class SoundHelper
{
	private static var soundsInitialized:Bool = false;
	private static var soundLibrary:Map<String, FlxSound>;
	private static var musicLibrary:Map<String, FlxSound>;

	public static function initSounds():Void
	{
		if (soundsInitialized)
			return;
		soundsInitialized = true;

		soundLibrary = new Map<String, FlxSound>();
		musicLibrary = new Map<String, FlxSound>();

		var s:FlxSound = loadSound("assets/sounds/camera_shutter.ogg");
		soundLibrary.set("camera", s);

		soundLibrary.set("portal", loadSound("assets/sounds/portal_enter.ogg"));

		s = loadSound("assets/music/office_music.ogg");
		s.looped = true;
		musicLibrary.set("office", s);
	}

	private static function loadSound(AssetPath:String):FlxSound
	{
		var sound:FlxSound = new FlxSound().loadEmbedded(AssetPath);

		sound.persist = true;
		sound.autoDestroy = false;
		return sound;
	}

	public static function playSound(name:String, ?SourceMP:FlxPoint, ?Player:FlxObject):Void
	{
		if (!soundsInitialized)
		{
			initSounds();
		}
		var sound:FlxSound = soundLibrary.get(name);
		if (Player != null && SourceMP != null)
		{
			sound.proximity(SourceMP.x, SourceMP.y, Player, FlxG.width * 1.33, true);
		}
		else
		{
			sound._target = null;
		}
		sound.play();
	}
}
