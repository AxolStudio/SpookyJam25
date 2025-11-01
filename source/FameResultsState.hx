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
	private var totalMoneyToAdd:Int;
	private var isProcessing:Bool = false;
	private var processingComplete:Bool = false;
	private var isTransitioning:Bool = false;

	private var moneyEarnedLabel:GameText;
	private var moneyEarnedAmount:GameText;
	private var totalFundsLabel:GameText;
	private var totalFundsAmount:GameText;
	private var moneyAnimating:Bool = false;

	private var activeTweens:Array<FlxTween> = [];
	private var activeTimers:Array<FlxTimer> = [];

	private var startingLevel:Int;
	private var startingFame:Int;

	public function new(fameToAdd:Int, moneyToAdd:Int)
	{
		super();
		totalFameToAdd = fameToAdd;
		fameRemaining = fameToAdd;
		totalMoneyToAdd = moneyToAdd;
		startingLevel = Globals.fameLevel;
		startingFame = Globals.currentFame;
	}

	override public function create():Void
	{
		super.create();

		Actions.switchSet(Actions.menuIndex);

		bg = new FlxSprite(0, 0, "assets/ui/bg.png");
		add(bg);

		// Make panel moderately sized - 65% of screen height
		var panelHeight = Std.int(FlxG.height * 0.65);
		var panelY = Std.int((FlxG.height - panelHeight) / 2);
		panel = new NineSliceSprite(Std.int(FlxG.width * 0.15), panelY, Std.int(FlxG.width * 0.7), panelHeight,
			"assets/ui/ui_box_16x16.png");
		add(panel);

		var topMargin = 18;

		// Level icon at the top
		levelSprite = new FlxSprite(0, Std.int(panel.y + topMargin));
		levelSprite.loadGraphic("assets/ui/fame_level_lg.png", true, 42, 42);
		levelSprite.x = Std.int((FlxG.width - 42) / 2);
		setupLevelAnimation();
		add(levelSprite);

		// Fame bar directly below the level sprite
		var barY = Std.int(levelSprite.y + levelSprite.height + 12);
		fameBar = new FlxBar(Std.int(panel.x + 40), barY, LEFT_TO_RIGHT, Std.int(panel.width - 80), 24);
		fameBar.createFilledBar(0xFF3D2B2B, 0xFF00FF00, true, FlxColor.BLACK);

		var maxFame = Globals.getFameNeededForNextLevel();
		if (maxFame == 0)
			maxFame = 1;
		fameBar.setRange(0, maxFame);
		fameBar.value = Globals.currentFame;
		add(fameBar);

		// "Fame Gained" text on LEFT side of bar, vertically centered
		titleText = new GameText(0, 0, "Fame Gained");
		titleText.setPosition(fameBar.x + 4, fameBar.y + (fameBar.height - titleText.height) / 2);
		add(titleText);

		// "+X" counter on RIGHT side of bar, right-aligned, vertically centered
		fameCounterText = new GameText(0, 0, "+" + totalFameToAdd);
		fameCounterText.setPosition(fameBar.x + fameBar.width - fameCounterText.width - 4, fameBar.y + (fameBar.height - fameCounterText.height) / 2);
		add(fameCounterText);

		// Money display elements (initially hidden) - below the bar
		var moneyBaseY = Std.int(fameBar.y + fameBar.height + 20);

		// "Money Earned:" on left, "$X x Level" on right (same line)
		moneyEarnedLabel = new GameText(fameBar.x + 4, moneyBaseY, "Money Earned:");
		moneyEarnedLabel.visible = false;
		add(moneyEarnedLabel);

		moneyEarnedAmount = new GameText(0, moneyBaseY, "$" + totalMoneyToAdd + " x " + Globals.fameLevel);
		moneyEarnedAmount.x = fameBar.x + fameBar.width - moneyEarnedAmount.width - 4;
		moneyEarnedAmount.visible = false;
		add(moneyEarnedAmount);

		// "Total Funds:" on left, "$XXX" on right (same line) - close below money earned
		var totalFundsY = moneyBaseY + 16; // Just 16 pixels below money earned
		totalFundsLabel = new GameText(fameBar.x + 4, totalFundsY, "Total Funds:");
		totalFundsLabel.visible = false;
		add(totalFundsLabel);

		totalFundsAmount = new GameText(0, totalFundsY, "$" + Globals.playerMoney);
		totalFundsAmount.x = fameBar.x + fameBar.width - totalFundsAmount.width - 4;
		totalFundsAmount.visible = false;
		add(totalFundsAmount);

		// Continue button below the panel - shorter height
		var buttonLabel = new GameText(0, 0, "Continue");
		var buttonHeight = Std.int(buttonLabel.height + 6); // Just a bit taller than text
		continueBtn = new NineSliceButton<GameText>(Std.int((FlxG.width - 160) / 2), Std.int(panel.y + panel.height + 10), 160, buttonHeight, onContinue);
		continueBtn.label = buttonLabel;
		continueBtn.positionLabel();
		continueBtn.visible = false;
		add(continueBtn);

		var overCam = new flixel.FlxCamera(0, 0, FlxG.width, FlxG.height);
		overCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(overCam, false);

		blackOut = new BlackOut(overCam);
		add(blackOut);

		blackOut.fade(null, false, 0.33, FlxColor.BLACK);

		FlxG.sound.playMusic("assets/music/office_music.ogg", 0.5, true);

		// Delay before starting fame processing - longer wait after fade in
		var timer = new FlxTimer().start(1.25, (_) ->
		{
			if (!isProcessing && !processingComplete)
			{
				isProcessing = true;
				processFame();
			}
		});
		activeTimers.push(timer);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		// Update input manager
		util.InputManager.update();
		
		// Skip animations if user presses action and continue button is not visible
		if (!continueBtn.visible && !isTransitioning)
		{
			var skipPressed = false;

			if (FlxG.mouse.justPressed)
				skipPressed = true;

			if (Actions.pressUI.triggered)
				skipPressed = true;

			if (skipPressed)
			{
				skipToEnd();
			}
		}
	}

	private function skipToEnd():Void
	{
		// Cancel all active tweens and timers
		for (tween in activeTweens)
		{
			if (tween != null)
				tween.cancel();
		}
		activeTweens = [];

		for (timer in activeTimers)
		{
			if (timer != null)
				timer.cancel();
		}
		activeTimers = [];

		// Instantly complete fame processing
		if (!processingComplete)
		{
			// Add all remaining fame immediately
			if (fameRemaining > 0)
			{
				Globals.currentFame += fameRemaining;
				while (Globals.currentFame >= Globals.getFameNeededForNextLevel() && Globals.fameLevel < 10)
				{
					var maxFame = Globals.getFameNeededForNextLevel();
					Globals.currentFame -= maxFame;
					Globals.fameLevel++;
					levelSprite.animation.frameIndex = (Globals.fameLevel - 1);
				}
				Globals.addFame(0); // Save
				fameRemaining = 0;
			}

			// Update UI
			var maxFame = Globals.getFameNeededForNextLevel();
			if (maxFame == 0)
				maxFame = 1;
			fameBar.setRange(0, maxFame);
			fameBar.value = Globals.currentFame;
			fameCounterText.text = "+0";
			// Right-align on the bar
			fameCounterText.x = fameBar.x + fameBar.width - fameCounterText.width - 4;

			processingComplete = true;
		}

		// Show and complete money animation instantly
		if (!moneyEarnedLabel.visible)
		{
			moneyEarnedLabel.visible = true;
			moneyEarnedAmount.visible = true;
			totalFundsLabel.visible = true;
			totalFundsAmount.visible = true;
		}

		// Calculate and add money immediately
		var actualMoneyToAdd = totalMoneyToAdd * Globals.fameLevel;
		Globals.addMoney(actualMoneyToAdd);

		moneyEarnedAmount.text = "$0 x " + Globals.fameLevel;
		// Right-align on the bar
		moneyEarnedAmount.x = fameBar.x + fameBar.width - moneyEarnedAmount.width - 4;

		totalFundsAmount.text = "$" + Globals.playerMoney;
		// Right-align on the bar
		totalFundsAmount.x = fameBar.x + fameBar.width - totalFundsAmount.width - 4;
		moneyAnimating = false;

		// Show continue button
		continueBtn.visible = true;
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

			var tween = FlxTween.num(Globals.currentFame, maxFame, 0.5, {ease: FlxEase.quadOut}, (v:Float) ->
			{
				Globals.currentFame = Std.int(v);
				fameBar.value = v;
				updateFameCounter();
			});
			activeTweens.push(tween);
			tween.onComplete = (_) ->
			{
				var timer = new FlxTimer().start(0.2, (_) ->
				{
					levelUp();
				});
				activeTimers.push(timer);
			};
		}
		else
		{
			var targetFame = Globals.currentFame + fameRemaining;
			fameRemaining = 0;

			var tween = FlxTween.num(Globals.currentFame, targetFame, 0.5, {ease: FlxEase.quadOut}, (v:Float) ->
			{
				Globals.currentFame = Std.int(v);
				fameBar.value = v;
				updateFameCounter();
			});
			activeTweens.push(tween);
			tween.onComplete = (_) ->
			{
				Globals.addFame(0);
				var timer = new FlxTimer().start(0.2, (_) ->
				{
					onProcessingComplete();
				});
				activeTimers.push(timer);
			};
		}
	}

	private function setupLevelAnimation():Void
	{
		var currentLevel = Globals.fameLevel - 1;
		var baseFrame = currentLevel * 7;

		// Longer delay between shines - hold on frame 0 for 40 frames instead of 20
		var frames:Array<Int> = [
			baseFrame + 1,
			baseFrame + 2,
			baseFrame + 3,
			baseFrame + 4,
			baseFrame + 5,
			baseFrame + 6
		];
		// Add 40 frames of baseFrame (longer hold)
		for (i in 0...40)
		{
			frames.push(baseFrame);
		}

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

		var tween1 = FlxTween.tween(levelSprite.scale, {x: 1.5, y: 1.5}, 0.15, {
			ease: FlxEase.backOut,
			onComplete: (_) ->
			{
				var tween2 = FlxTween.tween(levelSprite.scale, {x: 1.0, y: 1.0}, 0.15, {
					ease: FlxEase.backIn,
					onComplete: (_) ->
					{
						Globals.addFame(0);
						processFame();
					}
				});
				activeTweens.push(tween2);
			}
		});
		activeTweens.push(tween1);
	}

	private function updateFameCounter():Void
	{
		fameCounterText.text = "+" + fameRemaining;
		// Right-align on the bar
		fameCounterText.x = fameBar.x + fameBar.width - fameCounterText.width - 4;
	}

	private function onProcessingComplete():Void
	{
		processingComplete = true;

		fameCounterText.text = "+0";
		// Right-align on the bar
		fameCounterText.x = fameBar.x + fameBar.width - fameCounterText.width - 4;
		// Show money display after a brief pause
		var timer = new FlxTimer().start(0.3, (_) ->
		{
			showMoneyDisplay();
		});
		activeTimers.push(timer);
	}

	private function showMoneyDisplay():Void
	{
		// Show the money earned labels
		moneyEarnedLabel.visible = true;
		moneyEarnedAmount.visible = true;
		totalFundsLabel.visible = true;
		totalFundsAmount.visible = true;

		// Calculate total money (base reward * fame level multiplier)
		var actualMoneyToAdd = totalMoneyToAdd * Globals.fameLevel;
		var startingMoney = Globals.playerMoney;
		var endingMoney = startingMoney + actualMoneyToAdd;

		// Pause for 0.75 seconds so player can read the amounts before they start draining
		var pauseTimer = new FlxTimer().start(0.75, (_) ->
		{
			// Animate the money draining from earned to total
			moneyAnimating = true;
			var tween = FlxTween.num(actualMoneyToAdd, 0, 1.0, {ease: FlxEase.quadOut}, (v:Float) ->
			{
				var remaining = Std.int(v);
				var addedSoFar = actualMoneyToAdd - remaining;

				moneyEarnedAmount.text = "$" + remaining + " x " + Globals.fameLevel;
				// Right-align on the bar
				moneyEarnedAmount.x = fameBar.x + fameBar.width - moneyEarnedAmount.width - 4;

				totalFundsAmount.text = "$" + (startingMoney + addedSoFar);
				// Right-align on the bar
				totalFundsAmount.x = fameBar.x + fameBar.width - totalFundsAmount.width - 4;
			});
			activeTweens.push(tween);
			tween.onComplete = (_) ->
			{
				moneyAnimating = false;

				// Add money to globals after animation completes
				Globals.addMoney(actualMoneyToAdd);
				trace("Added $" + actualMoneyToAdd + " to player funds. New total: $" + Globals.playerMoney);

				// Wait a moment, then show the continue button
				var timer = new FlxTimer().start(0.5, (_) ->
				{
					continueBtn.visible = true;
				});
				activeTimers.push(timer);
			};
		});
		activeTimers.push(pauseTimer);
	}

	private function onContinue():Void
	{
		if (isTransitioning)
			return;
		isTransitioning = true;

		blackOut.fade(() -> FlxG.switchState(() -> new OfficeState()), true, 0.33, FlxColor.BLACK);
	}
}
