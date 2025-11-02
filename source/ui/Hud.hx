package ui;

import flixel.util.FlxDestroyUtil;
import Player;
import Std;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;

class Hud extends FlxGroup
{
	public var player:Player;
	public var filmIcon:FlxSprite;
	public var filmText:GameText;
	public var flashIcon:FlxSprite;
	public var cooldownBarYellow:FlxBar;
	public var cooldownBarWhite:FlxBar;
	public var o2Icon:FlxSprite;
	public var o2Bar:FlxBar;


	private var cooldownTarget:Float = 0;
	private var cooldownTweenActive:Bool = false;
	private var o2FlashTimer:Float = 0;
	private var o2FlashState:Bool = false;
	private var lowAirSoundTimer:Float = 0;

	public var isLowAirSoundActive:Bool = false;

	public function new(P:Player)
	{
		super();
		player = P;

		var hudBack:FlxSprite = new FlxSprite(0, 0);
		hudBack.makeGraphic(FlxG.width, 18, FlxColor.GRAY);
		hudBack.scrollFactor.set(0, 0);
		add(hudBack);


		var iconX = 8;
		var iconY = 2;
		filmIcon = new FlxSprite(iconX, iconY);
		filmIcon.loadGraphic("assets/images/hud_film.png");
		filmIcon.scrollFactor.set(0, 0);
		add(filmIcon);


		filmText = new GameText(filmIcon.x + filmIcon.width + 2, 0, Std.string(player.film));
		filmText.y = filmIcon.y + (filmIcon.height / 2) - (filmText.height / 2);
		filmText.scrollFactor.set(0, 0);
		add(filmText);


		flashIcon = new FlxSprite(filmText.x + 32 + 48, iconY);
		flashIcon.loadGraphic("assets/images/hud_bulb.png");
		flashIcon.scrollFactor.set(0, 0);

		add(flashIcon);


		var fillW = 48;
		var fillH = 8;
		var barX = flashIcon.x + 18;
		var barY = flashIcon.y + 2;

		cooldownBarYellow = new FlxBar(barX, barY, null, fillW, fillH, null, "", 0, Constants.PHOTO_COOLDOWN);
		cooldownBarYellow.createFilledBar(0xFF000000, 0xFFFFFF00, true, 0xFF000000, 1);
		cooldownBarYellow.fixedPosition = true;
		cooldownBarYellow.scrollFactor.set(0, 0);
		add(cooldownBarYellow);

		cooldownBarWhite = new FlxBar(barX, barY, null, fillW, fillH, null, "", 0, Constants.PHOTO_COOLDOWN);
		cooldownBarWhite.createFilledBar(0xFF000000, 0xFFFFFFFF, true, 0xFF000000, 1);
		cooldownBarWhite.fixedPosition = true;
		cooldownBarWhite.scrollFactor.set(0, 0);
		cooldownBarWhite.value = Constants.PHOTO_COOLDOWN;
		add(cooldownBarWhite);
		o2Bar = new FlxBar(FlxG.width - 8 - fillW, barY, null, fillW, fillH, null, "", 0, player.o2);
		o2Bar.createFilledBar(0xFF000000, 0xFF00FFFF, true, 0xFF000000, 1);
		o2Bar.fixedPosition = true;
		o2Bar.scrollFactor.set(0, 0);
		o2Bar.value = player.o2;
		add(o2Bar);

		o2Icon = new FlxSprite(o2Bar.x - 18, iconY);
		o2Icon.loadGraphic("assets/images/hud_o2.png");
		o2Icon.scrollFactor.set(0, 0);
		add(o2Icon);

		
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (filmText != null && player != null)
			filmText.text = Std.string(player.film);
		if (player != null)
		{
			var val:Float = Constants.PHOTO_COOLDOWN - player.photoCooldown;
			if (val < 0)
				val = 0;
			if (val > Constants.PHOTO_COOLDOWN)
				val = Constants.PHOTO_COOLDOWN;

			if (cooldownBarYellow != null)
			{
				if (Math.abs(cooldownTarget - val) > 0.01)
				{
					cooldownTarget = val;
					FlxTween.tween(cooldownBarYellow, {value: cooldownTarget}, 0.18, {ease: FlxEase.quadOut});
				}
			}
			if (cooldownBarWhite != null)
				cooldownBarWhite.visible = (val >= Constants.PHOTO_COOLDOWN);
			o2Bar.value = player.o2;
			var maxO2:Float = o2Bar.max;
			var o2Percentage:Float = (player.o2 / maxO2);
			if (o2Percentage <= 0.2)
			{
				o2FlashTimer += elapsed;
				if (o2FlashTimer >= 0.25)
				{
					o2FlashTimer = 0;
					o2FlashState = !o2FlashState;

					if (o2FlashState)
						o2Bar.createFilledBar(0xFF000000, 0xFFFF0000, true, 0xFF000000, 1);
					else
						o2Bar.createFilledBar(0xFF000000, 0xFF00FFFF, true, 0xFF000000, 1);
				}
				lowAirSoundTimer += elapsed;
				if (lowAirSoundTimer >= 0.5)
				{
					lowAirSoundTimer = 0;
					util.SoundHelper.playSound("low_air", 0.5);
					isLowAirSoundActive = true;
				}
			}
			else
			{
				if (o2FlashState)
				{
					o2Bar.createFilledBar(0xFF000000, 0xFF00FFFF, true, 0xFF000000, 1);
					o2FlashState = false;
					o2FlashTimer = 0;
				}

				if (isLowAirSoundActive)
				{
					isLowAirSoundActive = false;
					lowAirSoundTimer = 0;
				}
			}
		}
	}

	public function stopLowAirSound():Void
	{
		isLowAirSoundActive = false;
		lowAirSoundTimer = 0;
	}

	override public function destroy():Void
	{
		player = null;
		FlxDestroyUtil.destroyArray([
			filmIcon,
			filmText,
			flashIcon,
			cooldownBarYellow,
			cooldownBarWhite,
			o2Icon,
			o2Bar
		]);
		super.destroy();
	}
}
