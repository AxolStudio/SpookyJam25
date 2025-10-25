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

		var s:FlxSound = new FlxSound().loadEmbedded("assets/sounds/camera_shutter.ogg");
		soundLibrary.set("camera", s);
		s.persist = true;
		s.autoDestroy = false;

		s = new FlxSound().loadEmbedded("assets/music/office_music.ogg");
		musicLibrary.set("office", s);
		s.persist = true;
		s.autoDestroy = false;
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
