package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import ui.GameText;
import ui.NineSliceButton;

class FameResultsState extends FlxState
{
	private var bg:FlxSprite;
	private var panel:NineSliceSprite;
	private var fameBar:FlxBar;
	private var fameCounterText:GameText;
	private var levelText:GameText;
	private var levelSprite:FlxSprite;
	private var titleText:GameText;
	private var continueBtn:NineSliceButton<GameText>;
	private var blackOut:BlackOut;

	private var totalFameToAdd:Int;
	private var fameRemaining:Int;
	private var isProcessing:Bool = false;
	private var processingComplete:Bool = false;
	private var isTransitioning:Bool = false;

	private var startingLevel:Int;
	private var startingFame:Int;

	public function new(fameToAdd:Int)
	{
		super();
		totalFameToAdd = fameToAdd;
		fameRemaining = fameToAdd;
		startingLevel = Globals.fameLevel;
		startingFame = Globals.currentFame;
	}

	override public function create():Void
	{
		super.create();

		Actions.switchSet(Actions.menuIndex);

		bg = new FlxSprite(0, 0, "assets/ui/bg.png");
		add(bg);

		panel = new NineSliceSprite(Std.int(FlxG.width * 0.15), Std.int(FlxG.height * 0.2), Std.int(FlxG.width * 0.7), Std.int(FlxG.height * 0.6),
			"assets/ui/ui_box_16x16.png");
		add(panel);

		// Level icon at the very top
		levelSprite = new FlxSprite(0, Std.int(panel.y + 20));
		levelSprite.loadGraphic("assets/ui/fame_level_lg.png", true, 42, 42);
		levelSprite.x = Std.int((FlxG.width - 42) / 2);
		setupLevelAnimation();
		add(levelSprite);

		// New fame amount below the icon
		fameCounterText = new GameText(0, Std.int(levelSprite.y + 42 + 16), "+" + totalFameToAdd);
		fameCounterText.x = Std.int((FlxG.width - fameCounterText.width) / 2);
		add(fameCounterText);

		// "FAME GAINED" label
		titleText = new GameText(0, Std.int(fameCounterText.y + 20), "FAME GAINED");
		titleText.x = Std.int((FlxG.width - titleText.width) / 2);
		add(titleText);

		// Fame bar below the label
		fameBar = new FlxBar(Std.int(panel.x + 40), Std.int(titleText.y + 16), LEFT_TO_RIGHT, Std.int(panel.width - 80), 24);
		fameBar.createFilledBar(0xFF3D2B2B, 0xFF00FF00, true, FlxColor.BLACK);

		var maxFame = Globals.getFameNeededForNextLevel();
		if (maxFame == 0)
			maxFame = 1;
		fameBar.setRange(0, maxFame);
		fameBar.value = Globals.currentFame;
		add(fameBar);

		// Continue button below the bar, inside the panel, initially invisible
		var buttonLabel = new GameText(0, 0, "Continue");
		continueBtn = new NineSliceButton<GameText>(Std.int((FlxG.width - 160) / 2), Std.int(panel.y + panel.height - 60), 160, 40, onContinue);
		continueBtn.label = buttonLabel;
		continueBtn.positionLabel();
		continueBtn.visible = false;
		add(continueBtn);

		var overCam = new flixel.FlxCamera(0, 0, FlxG.width, FlxG.height);
		overCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(overCam, false);

		blackOut = new BlackOut(overCam);
		add(blackOut);

		blackOut.fade(null, false, 1.0, FlxColor.BLACK);

		FlxG.sound.playMusic("assets/music/office_music.ogg", 0.5, true);

		// Delay before starting fame processing
		new FlxTimer().start(0.75, (_) ->
		{
			if (!isProcessing && !processingComplete)
			{
				isProcessing = true;
				processFame();
			}
		});
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
	}

	private function processFame():Void
	{
		if (fameRemaining <= 0 || Globals.fameLevel >= 10)
		{
			onProcessingComplete();
			return;
		}

		var maxFame = Globals.getFameNeededForNextLevel();
		var fameToNextLevel = maxFame - Globals.currentFame;

		if (fameRemaining >= fameToNextLevel)
		{
			var addAmount = fameToNextLevel;
			fameRemaining -= addAmount;

			FlxTween.num(Globals.currentFame, maxFame, 0.5, {ease: FlxEase.quadOut}, (v:Float) ->
			{
				Globals.currentFame = Std.int(v);
				fameBar.value = v;
				updateFameCounter();
			}).onComplete = (_) ->
				{
					new FlxTimer().start(0.2, (_) ->
					{
						levelUp();
					});
				};
		}
		else
		{
			var targetFame = Globals.currentFame + fameRemaining;
			fameRemaining = 0;

			FlxTween.num(Globals.currentFame, targetFame, 0.5, {ease: FlxEase.quadOut}, (v:Float) ->
			{
				Globals.currentFame = Std.int(v);
				fameBar.value = v;
				updateFameCounter();
			}).onComplete = (_) ->
				{
					Globals.addFame(0);
					new FlxTimer().start(0.2, (_) ->
					{
						onProcessingComplete();
					});
				};
		}
	}

	private function setupLevelAnimation():Void
	{
		var currentLevel = Globals.fameLevel - 1;
		var baseFrame = currentLevel * 7;

		var frames:Array<Int> = [
			baseFrame + 1,
			baseFrame + 2,
			baseFrame + 3,
			baseFrame + 4,
			baseFrame + 5,
			baseFrame + 6,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame,
			baseFrame
		];

		levelSprite.animation.add("shine", frames, 12, true);
		levelSprite.animation.play("shine");
	}

	private function levelUp():Void
	{
		Globals.fameLevel++;
		Globals.currentFame = 0;

		var maxFame = Globals.getFameNeededForNextLevel();
		if (maxFame == 0)
			maxFame = 1;
		fameBar.setRange(0, maxFame);
		fameBar.value = 0;

		setupLevelAnimation();

		FlxTween.tween(levelSprite.scale, {x: 1.5, y: 1.5}, 0.15, {
			ease: FlxEase.backOut,
			onComplete: (_) ->
			{
				FlxTween.tween(levelSprite.scale, {x: 1.0, y: 1.0}, 0.15, {
					ease: FlxEase.backIn,
					onComplete: (_) ->
					{
						Globals.addFame(0);
						processFame();
					}
				});
			}
		});
	}

	private function updateFameCounter():Void
	{
		fameCounterText.text = "+" + fameRemaining;
		fameCounterText.x = Std.int((FlxG.width - fameCounterText.width) / 2);
	}

	private function onProcessingComplete():Void
	{
		processingComplete = true;

		fameCounterText.text = "+0";
		fameCounterText.x = Std.int((FlxG.width - fameCounterText.width) / 2);
		// Wait a moment, then show the continue button
		new FlxTimer().start(0.5, (_) ->
		{
			continueBtn.visible = true;
		});
	}

	private function onContinue():Void
	{
		if (isTransitioning)
			return;
		isTransitioning = true;

		blackOut.fade(() -> FlxG.switchState(() -> new OfficeState()), true, 1.0, FlxColor.BLACK);
	}
}
