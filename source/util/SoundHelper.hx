package util;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;

class SoundHelper
{
	private static var soundsInitialized:Bool = false;
	private static var soundLibrary:Map<String, String>;
	private static var musicLibrary:Map<String, String>;

	private static var currentMusicName:String = null;

	public static function initSounds():Void
	{
		if (soundsInitialized)
			return;
		soundsInitialized = true;

		soundLibrary = new Map<String, String>();
		musicLibrary = new Map<String, String>();

		soundLibrary.set("camera", "assets/sounds/camera_shutter.ogg");
		soundLibrary.set("portal", "assets/sounds/portal_enter.ogg");

		soundLibrary.set("chimera_gruntly", "assets/sounds/chimera_cry_gruntly.ogg");
		soundLibrary.set("chimera_roar", "assets/sounds/chimera_cry_roar.ogg");
		soundLibrary.set("chimera_squeakly", "assets/sounds/chimera_cry_squeakly.ogg");
		soundLibrary.set("chimera_whimpy", "assets/sounds/chimera_cry_whimpy.ogg");

		musicLibrary.set("office", "assets/music/office_music.ogg");
		musicLibrary.set("title", "assets/music/title.ogg");
		musicLibrary.set("bgm", "assets/music/bgm.ogg");

		FlxG.sound.cacheAll();
	}

	public static function playSound(name:String, ?SourceMP:FlxPoint, ?Player:FlxObject):Void
	{
		if (!soundsInitialized)
			initSounds();

		var assetPath:String = soundLibrary.get(name);
		if (assetPath == null)
		{
			trace("Sound not found: " + name);
			return;
		}

		var sound:FlxSound = FlxG.sound.play(assetPath, 0.5);

		if (sound != null && Player != null && SourceMP != null)
		{
			sound.proximity(SourceMP.x, SourceMP.y, Player, FlxG.width * 1.5, true);
		}
	}

	private static var chimeraSounds:Array<String> = ["chimera_gruntly", "chimera_roar", "chimera_squeakly", "chimera_whimpy"];

	public static function playRandomChimeraCry(isVisible:Bool = false):FlxSound
	{
		if (!soundsInitialized)
			initSounds();

		var soundName:String = chimeraSounds[FlxG.random.int(0, chimeraSounds.length - 1)];
		var assetPath:String = soundLibrary.get(soundName);

		if (assetPath == null)
		{
			trace("Chimera sound not found: " + soundName);
			return null;
		}

		var baseVolume:Float = isVisible ? 0.5 : 0.15;

		var sound:FlxSound = FlxG.sound.load(assetPath, baseVolume, false, FlxG.sound.defaultSoundGroup, false, false);
		
		return sound;
	}

	public static function playMusic(name:String):Void
	{
		if (!soundsInitialized)
			initSounds();
		var assetPath:String = musicLibrary.get(name);
		if (assetPath == null)
		{
			trace("Music not found: " + name);
			return;
		}

		if (currentMusicName == name && FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			return;
		}

		if (currentMusicName != name && FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
		}
		FlxG.sound.playMusic(assetPath, 0.5, true);
		currentMusicName = name;
	}

	public static function stopMusic(name:String):Void
	{
		if (!soundsInitialized)
			return;

		if (currentMusicName == name && FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
			currentMusicName = null;
		}
	}

	public static function fadeOutMusic(name:String, duration:Float = 1.0):Void
	{
		if (!soundsInitialized)
			return;

		if (currentMusicName == name && FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			FlxG.sound.music.fadeOut(duration, 0.0, function(_)
			{
				FlxG.sound.music.stop();
				currentMusicName = null;
			});
		}
	}
}
