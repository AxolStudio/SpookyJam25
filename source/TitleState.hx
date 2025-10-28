package;

import util.SoundHelper;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import shaders.AlphaDither;
import ui.GameText;

class TitleState extends FlxState
{
	private var bg:FlxSprite;
	private var logo:FlxSprite;
	private var logoShader:AlphaDither;
	private var promptText:GameText;
	private var blackOut:BlackOut;
	private var ready:Bool = false;

	override public function create():Void
	{
		super.create();

		Globals.init();
		Actions.switchSet(Actions.menuIndex);

		// Background
		bg = new FlxSprite(0, 0, "assets/ui/mainmenu_bg.png");
		add(bg);

		// Logo with alpha dither shader
		logo = new FlxSprite(0, 0, "assets/ui/mainmenu_logo.png");
		logoShader = new AlphaDither();
		logoShader.globalAlpha = 0.0;
		logo.shader = logoShader;
		add(logo);

		// Prompt text (start off-screen below)
		promptText = new GameText(0, FlxG.height + 20, "Press [Action] to Play");
		promptText.x = Std.int((FlxG.width - promptText.width) / 2);
		add(promptText); // BlackOut for fade in
		var overCam = new flixel.FlxCamera(0, 0, FlxG.width, FlxG.height);
		overCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(overCam, false);

		blackOut = new BlackOut(overCam);
		add(blackOut);

		// Start sequence: fade in from black
		blackOut.fade(() ->
		{
			// Fade in the logo with alpha dither
			FlxTween.tween(logoShader, {globalAlpha: 1.0}, 1.5, {
				ease: FlxEase.quadInOut,
				onComplete: (_) ->
				{
					// Slide prompt text up from bottom
					FlxTween.tween(promptText, {y: FlxG.height - 30}, 0.5, {
						ease: FlxEase.backOut,
						onComplete: (_) ->
						{
							ready = true;
						}
					});
				}
			});
		}, false, 1.0, FlxColor.BLACK);

		util.SoundHelper.playMusic("title");
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!ready)
			return;

		// Check for action input
		if (Actions.pressUI.triggered || FlxG.mouse.justPressed)
		{
			ready = false;

			// Track title screen exit
			axollib.AxolAPI.sendEvent("TITLE_TO_OFFICE");

			// Fade to black and switch to OfficeState
			SoundHelper.fadeOutMusic("title", 0.66);
			blackOut.fade(() ->
			{
				FlxG.switchState(() -> new OfficeState());
			}, true, 1.0, FlxColor.BLACK);
		}
	}
}
