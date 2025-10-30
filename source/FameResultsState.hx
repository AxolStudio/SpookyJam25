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
			"assets/ui/button.png");
		add(panel);

		titleText = new GameText(0, Std.int(panel.y + 30), "FAME GAINED");
		titleText.x = Std.int((FlxG.width - titleText.width) / 2);
		add(titleText);

		levelText = new GameText(0, Std.int(titleText.y + 40), "LEVEL " + Globals.getFameLevelDisplay());
		levelText.x = Std.int((FlxG.width - levelText.width) / 2);
		add(levelText);

		fameBar = new FlxBar(Std.int(panel.x + 40), Std.int(levelText.y + 50), LEFT_TO_RIGHT, Std.int(panel.width - 80), 30);
		fameBar.createFilledBar(0xFF3D2B2B, 0xFF00FF00, true, FlxColor.BLACK);

		var maxFame = Globals.getFameNeededForNextLevel();
		if (maxFame == 0)
			maxFame = 1;
		fameBar.setRange(0, maxFame);
		fameBar.value = Globals.currentFame;
		add(fameBar);

		fameCounterText = new GameText(0, Std.int(fameBar.y + 50), "+" + totalFameToAdd + " Fame");
		fameCounterText.x = Std.int((FlxG.width - fameCounterText.width) / 2);
		add(fameCounterText);

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

		FlxG.sound.playMusic("assets/music/office.ogg", 0.5, true);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!isProcessing && !processingComplete)
		{
			isProcessing = true;
			processFame();
		}
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

	private function levelUp():Void
	{
		Globals.fameLevel++;
		Globals.currentFame = 0;

		var maxFame = Globals.getFameNeededForNextLevel();
		if (maxFame == 0)
			maxFame = 1;
		fameBar.setRange(0, maxFame);
		fameBar.value = 0;

		levelText.text = "LEVEL " + Globals.getFameLevelDisplay();
		levelText.x = Std.int((FlxG.width - levelText.width) / 2);

		FlxTween.tween(levelText.scale, {x: 1.5, y: 1.5}, 0.15, {
			ease: FlxEase.backOut,
			onComplete: (_) ->
			{
				FlxTween.tween(levelText.scale, {x: 1.0, y: 1.0}, 0.15, {
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
		fameCounterText.text = "+" + fameRemaining + " Fame";
		fameCounterText.x = Std.int((FlxG.width - fameCounterText.width) / 2);
	}

	private function onProcessingComplete():Void
	{
		processingComplete = true;
		continueBtn.visible = true;

		fameCounterText.text = "Total: +" + totalFameToAdd + " Fame";
		fameCounterText.x = Std.int((FlxG.width - fameCounterText.width) / 2);
	}

	private function onContinue():Void
	{
		if (isTransitioning)
			return;
		isTransitioning = true;

		blackOut.fade(() -> FlxG.switchState(() -> new OfficeState()), true, 1.0, FlxColor.BLACK);
	}
}
