package;

import util.SoundHelper;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import shaders.AlphaDither;
import shaders.TitleFog;
import ui.GameText;

class TitleState extends FlxState
{
	private var bg:FlxSprite;
	private var bgShader:TitleFog;
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

		bg = new FlxSprite(0, 0);
		bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bgShader = new TitleFog();
		bgShader.hue = FlxG.random.float(0, 360);
		bgShader.sat = 0.85;
		bgShader.vDark = 0.10;
		bgShader.vLight = 0.50;
		bgShader.contrast = 0.5;
		bg.shader = bgShader;
		add(bg);

		logo = new FlxSprite(0, 0);
		logo.loadGraphic("assets/ui/mainmenu_logo.png", true, 320, 240);
		logo.animation.add("idle", [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5], 12, true);
		logo.animation.play("idle");
		logoShader = new AlphaDither();
		logoShader.globalAlpha = 0.0;
		logo.shader = logoShader;
		add(logo);

		promptText = new GameText(0, FlxG.height + 20, "Press [Action] to Play");
		promptText.x = Std.int((FlxG.width - promptText.width) / 2);
		add(promptText);
		var overCam = new flixel.FlxCamera(0, 0, FlxG.width, FlxG.height);
		overCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(overCam, false);

		blackOut = new BlackOut(overCam);
		add(blackOut);

		blackOut.fade(() ->
		{
			FlxTween.tween(logoShader, {globalAlpha: 1.0}, 1.5, {
				ease: FlxEase.quadInOut,
				onComplete: (_) ->
				{
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

		// Only update input manager if the state is ready to prevent issues
		if (ready)
			util.InputManager.update();

		if (bgShader != null)
			bgShader.time += elapsed;

		if (!ready)
			return;

		// Check for user interaction to unlock audio (HTML5 requirement)
		var userInteracted = (Actions.pressUI != null && Actions.pressUI.triggered) || FlxG.mouse.justPressed;

		#if web
		// On first interaction, unlock audio and start music, but don't proceed to next state
		if (userInteracted && !util.SoundHelper.isAudioUnlocked())
		{
			util.SoundHelper.unlockAudio();
			util.SoundHelper.playMusic("title"); // Now it will actually play
			return; // Don't process the click as a "start game" action
		}
		#end

		// Null-check Actions to prevent crash when window loses focus for extended period
		if (userInteracted)
		{
			ready = false;

			axollib.AxolAPI.sendEvent("TITLE_TO_OFFICE");

			SoundHelper.fadeOutMusic("title", 0.66);
			blackOut.fade(() ->
			{
				FlxG.switchState(() -> new OfficeState());
			}, true, 1.0, FlxColor.BLACK);
		}
	}
	override public function destroy():Void
	{
		bg = flixel.util.FlxDestroyUtil.destroy(bg);
		bgShader = null;
		logo = flixel.util.FlxDestroyUtil.destroy(logo);
		logoShader = null;
		promptText = flixel.util.FlxDestroyUtil.destroy(promptText);
		blackOut = flixel.util.FlxDestroyUtil.destroy(blackOut);

		super.destroy();
	}
}
