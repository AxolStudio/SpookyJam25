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

	/**
	 * Track if we've had user interaction (for HTML5 audio unlock)
	 */
	private static var audioUnlocked:Bool = false;

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

		soundLibrary.set("player_hurt_1", "assets/sounds/player_hurt_1.ogg");
		soundLibrary.set("player_hurt_2", "assets/sounds/player_hurt_2.ogg");
		soundLibrary.set("player_hurt_3", "assets/sounds/player_hurt_3.ogg");
		soundLibrary.set("player_hurt_4", "assets/sounds/player_hurt_4.ogg");
		soundLibrary.set("player_hurt_5", "assets/sounds/player_hurt_5.ogg");

		soundLibrary.set("ui_hover", "assets/sounds/ui_hover.ogg");
		soundLibrary.set("ui_select", "assets/sounds/ui_select.ogg");
		soundLibrary.set("ui_cancel", "assets/sounds/ui_cancel.ogg");

		soundLibrary.set("drawer_open", "assets/sounds/drawer_open.ogg");
		soundLibrary.set("drawer_close", "assets/sounds/drawer_close.ogg");
		soundLibrary.set("phone_pickup", "assets/sounds/phone_pickup.ogg");
		soundLibrary.set("trashcan_rustle", "assets/sounds/trashcan_rustle.ogg");
		soundLibrary.set("upgrade_buy", "assets/sounds/upgrade_buy.ogg");
		soundLibrary.set("trashcan_throw_away", "assets/sounds/trashcan_throw_away.ogg");
		soundLibrary.set("out_of_oxygen", "assets/sounds/out_of_oxygen.ogg");
		soundLibrary.set("low_air", "assets/sounds/low_air.ogg");

		soundLibrary.set("page_turn_1", "assets/sounds/page_turn_1.ogg");
		soundLibrary.set("page_turn_2", "assets/sounds/page_turn_2.ogg");
		soundLibrary.set("page_turn_3", "assets/sounds/page_turn_3.ogg");
		soundLibrary.set("page_turn_4", "assets/sounds/page_turn_4.ogg");

		musicLibrary.set("office", "assets/music/office_music.ogg");
		musicLibrary.set("title", "assets/music/title.ogg");
		musicLibrary.set("bgm", "assets/music/bgm.ogg");

		FlxG.sound.cacheAll();
	}

	public static function playSound(name:String, ?SourceMP:FlxPoint, ?Player:FlxObject, ?volume:Float):Void
	{
		if (!soundsInitialized)
			initSounds();
		// Don't play sounds if audio hasn't been unlocked yet (HTML5 audio context restriction)
		#if web
		if (!audioUnlocked)
			return;
		#end

		var assetPath:String = soundLibrary.get(name);
		if (assetPath == null)
		{
			trace("Sound not found: " + name);
			return;
		}

		// Custom volumes for specific sounds
		var soundVolume:Float = volume != null ? volume : 0.5;
		if (volume == null)
		{
			if (name == "low_air")
				soundVolume = 0.25; // Reduce low_air by 50%
		}

		var sound:FlxSound = FlxG.sound.play(assetPath, soundVolume);

		if (sound != null && Player != null && SourceMP != null)
		{
			sound.proximity(SourceMP.x, SourceMP.y, Player, FlxG.width * 1.5, true);
		}
	}

	private static var chimeraSounds:Array<String> = ["chimera_gruntly", "chimera_roar", "chimera_squeakly", "chimera_whimpy"];
	private static var playerHurtSounds:Array<String> = [
		"player_hurt_1",
		"player_hurt_2",
		"player_hurt_3",
		"player_hurt_4",
		"player_hurt_5"
	];
	private static var pageTurnSounds:Array<String> = ["page_turn_1", "page_turn_2", "page_turn_3", "page_turn_4"];
	private static var lastHurtSound:String = "";
	private static var lastPageTurnSound:String = "";

	public static function playRandomChimeraCry(isVisible:Bool = false):FlxSound
	{
		if (!soundsInitialized)
			initSounds();

		// Don't play sounds if audio hasn't been unlocked yet (HTML5 audio context restriction)
		#if web
		if (!audioUnlocked)
			return null;
		#end

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

	public static function playRandomHurtSound():Void
	{
		if (!soundsInitialized)
			initSounds();

		// Don't play sounds if audio hasn't been unlocked yet (HTML5 audio context restriction)
		#if web
		if (!audioUnlocked)
			return;
		#end

		// Filter out the last played sound
		var availableSounds:Array<String> = playerHurtSounds.filter(function(s:String):Bool
		{
			return s != lastHurtSound;
		});

		// Pick a random sound from the available ones
		var soundName:String = availableSounds[FlxG.random.int(0, availableSounds.length - 1)];
		lastHurtSound = soundName;

		var assetPath:String = soundLibrary.get(soundName);
		if (assetPath == null)
		{
			trace("Hurt sound not found: " + soundName);
			return;
		}

		FlxG.sound.play(assetPath, 0.75); // Increased from 0.5 to 0.75
	}

	public static function playRandomPageTurn():Void
	{
		if (!soundsInitialized)
			initSounds();
		// Don't play sounds if audio hasn't been unlocked yet (HTML5 audio context restriction)
		#if web
		if (!audioUnlocked)
			return;
		#end

		// Filter out the last played sound
		var availableSounds:Array<String> = pageTurnSounds.filter(function(s:String):Bool
		{
			return s != lastPageTurnSound;
		});

		// Pick a random sound from the available ones
		var soundName:String = availableSounds[FlxG.random.int(0, availableSounds.length - 1)];
		lastPageTurnSound = soundName;

		var assetPath:String = soundLibrary.get(soundName);
		if (assetPath == null)
		{
			trace("Page turn sound not found: " + soundName);
			return;
		}

		FlxG.sound.play(assetPath, 0.5);
	}

	public static function playMusic(name:String):Void
	{
		if (!soundsInitialized)
			initSounds();
		// Don't play music if audio hasn't been unlocked yet (HTML5 audio context restriction)
		#if web
		if (!audioUnlocked)
			return;
		#end
			
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
	/**
	 * Call this on first user interaction to unlock audio on HTML5
	 * Returns true if audio was just unlocked, false if already unlocked
	 */
	public static function unlockAudio():Bool
	{
		#if web
		if (!audioUnlocked)
		{
			audioUnlocked = true;
			trace("Audio unlocked - user interaction detected");
			return true;
		}
		#else
		// On non-web platforms, audio is always "unlocked"
		audioUnlocked = true;
		#end
		return false;
	}

	/**
	 * Check if audio has been unlocked yet
	 */
	public static function isAudioUnlocked():Bool
	{
		#if !web
		return true; // Always unlocked on non-web platforms
		#end
		return audioUnlocked;
	}
}
