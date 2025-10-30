package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxColor;
import ui.GameText;
import ui.NineSliceButton;
import util.ColorHelpers;

class ArchiveState extends FlxState
{
	private var bg:FlxSprite;
	private var creatures:Array<SavedCreature>;
	private var selectedIndex:Int = 0;
	private var nameText:GameText;
	private var nameLabel:GameText;
	private var speedLabel:GameText;
	private var speedStars:Array<FlxSprite> = [];
	private var aggrLabel:GameText;
	private var aggrStars:Array<FlxSprite> = [];
	private var powerLabel:GameText;
	private var powerStars:Array<FlxSprite> = [];
	private var skittLabel:GameText;
	private var skittStars:Array<FlxSprite> = [];
	private var rewardLabel:GameText;
	private var rewardAmount:GameText;
	private var fameLabel:GameText;
	private var fameAmount:GameText;
	private var photoSprite:FlxSprite;
	private var dateText:GameText;
	private var photoCounterText:GameText;
	private var blackOut:BlackOut;
	private var isTransitioning:Bool = false;
	private var closeBtn:NineSliceButton<GameText>;
	private var prevBtn:NineSliceButton<FlxSprite>;
	private var nextBtn:NineSliceButton<FlxSprite>;

	private var currentUIIndex:Int = 0;
	private var uiObjects:Array<FlxSprite> = [];
	private var highlightSprite:AnimatedReticle;
	private var lastMouseX:Int = 0;
	private var lastMouseY:Int = 0;

	override public function create():Void
	{
		Globals.init();
		Actions.switchSet(Actions.menuIndex);

		FlxG.mouse.visible = false;

		creatures = Globals.savedCreatures.copy();

		bg = new FlxSprite(0, 0, "assets/ui/room_report.png");
		add(bg);

		if (creatures.length == 0)
		{
			showEmptyDialog();
		}
		else
		{
			updateSelected(0);
			setupNavigationButtons();
		}



		var closeLabel = new GameText(0, 0, "Close");
		closeLabel.updateHitbox();

		closeBtn = new NineSliceButton<GameText>(FlxG.width - 50, FlxG.height - 26, 40, 16, returnToOffice);
		closeBtn.isCancelButton = true;
		closeBtn.label = closeLabel;
		closeBtn.positionLabel();
		add(closeBtn);

		if (creatures.length > 0)
		{
			var counterStr = "File "
				+ StringTools.lpad(Std.string(selectedIndex + 1), "0", 2)
				+ "/"
				+ StringTools.lpad(Std.string(creatures.length), "0", 2);
			photoCounterText = new GameText(14 + 18, FlxG.height - 54, counterStr);
			add(photoCounterText);
		}

		setupBlackOutAndMusic();

		highlightSprite = new AnimatedReticle();
		add(highlightSprite);

		setupUINavigation();

		super.create();
	}

	private function showEmptyDialog():Void
	{
		var dialogWidth:Float = 200;
		var dialogHeight:Float = 80;
		var dialogX:Float = (FlxG.width - dialogWidth) / 2;
		var dialogY:Float = (FlxG.height - dialogHeight) / 2;

		var dialog = new NineSliceSprite(dialogX, dialogY, dialogWidth, dialogHeight);
		add(dialog);

		var emptyText = new GameText(0, 0, "No files archived.");
		add(emptyText);
		emptyText.x = dialogX + (dialogWidth - emptyText.width) / 2;
		emptyText.y = dialogY + 10;
	}

	private function setupNavigationButtons():Void
	{
		var arrowY = Std.int(FlxG.height / 2 - 8);

		var leftArrow = new FlxSprite(0, 0, "assets/ui/back.png");
		prevBtn = new NineSliceButton<FlxSprite>(10, arrowY, 24, 24, navigatePrev);
		prevBtn.label = leftArrow;
		prevBtn.positionLabel();
		add(prevBtn);

		var rightArrow = new FlxSprite(0, 0, "assets/ui/next.png");
		nextBtn = new NineSliceButton<FlxSprite>(FlxG.width - 34, arrowY, 24, 24, navigateNext);
		nextBtn.label = rightArrow;
		nextBtn.positionLabel();
		add(nextBtn);

		updateNavigationButtons();
	}

	private function updateNavigationButtons():Void
	{
		if (prevBtn != null)
			prevBtn.visible = (selectedIndex > 0);
		if (nextBtn != null)
			nextBtn.visible = (selectedIndex < creatures.length - 1);
	}

	private function navigatePrev():Void
	{
		if (selectedIndex > 0)
		{
			util.SoundHelper.playRandomPageTurn();
			selectedIndex--;
			updateSelected(selectedIndex);
			updateNavigationButtons();
			updatePhotoCounter();
		}
	}

	private function navigateNext():Void
	{
		if (selectedIndex < creatures.length - 1)
		{
			util.SoundHelper.playRandomPageTurn();
			selectedIndex++;
			updateSelected(selectedIndex);
			updateNavigationButtons();
			updatePhotoCounter();
		}
	}

	private function updatePhotoCounter():Void
	{
		if (photoCounterText != null)
		{
			var counterStr = "File "
				+ StringTools.lpad(Std.string(selectedIndex + 1), "0", 2)
				+ "/"
				+ StringTools.lpad(Std.string(creatures.length), "0", 2);
			photoCounterText.text = counterStr;
		}
	}

	private function setupBlackOutAndMusic():Void
	{
		var overCam = new flixel.FlxCamera(0, 0, FlxG.width, FlxG.height);
		overCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(overCam, false);

		blackOut = new BlackOut(overCam);
		add(blackOut);

		blackOut.fade(null, false, 0.33, FlxColor.BLACK);

		util.SoundHelper.playMusic("office");
	}

	private function returnToOffice():Void
	{
		axollib.AxolAPI.sendEvent("ARCHIVE_CLOSED");
		blackOut.fade(() -> FlxG.switchState(() -> new OfficeState()), true, 0.33, FlxColor.BLACK);
	}



	private function updateSelected(idx:Int):Void
	{
		selectedIndex = idx;
		var creature:SavedCreature = creatures[idx];

		var centerX:Int = Std.int(FlxG.width / 2);
		var pageMargin:Int = 14;
		var baseRightX:Int = centerX + pageMargin;
		var leftInnerRight:Int = centerX - pageMargin;

		if (nameLabel == null)
		{
			nameLabel = new GameText(baseRightX, 40, "Name:");
			add(nameLabel);
		}

		if (nameText == null)
		{
			nameText = new GameText(baseRightX, 56, creature.name);
			nameText.autoSize = false;
			nameText.fieldWidth = 120;
			add(nameText);
		}
		else
		{
			nameText.text = creature.name;
		}

		var minSpeed:Float = 20.0;
		var maxSpeed:Float = 70.0;
		var t:Float = (creature.speed - minSpeed) / (maxSpeed - minSpeed);
		if (t < 0)
			t = 0;
		if (t > 1)
			t = 1;
		var speedStarsCount:Int = Std.int(Math.floor(t * 4.0)) + 1;

		if (speedLabel == null)
		{
			speedLabel = new GameText(baseRightX, 88, "Speed:");
			add(speedLabel);

			for (i in 0...5)
			{
				var star = new FlxSprite(baseRightX + speedLabel.width + 4 + (i * 10), 90, "assets/ui/star_pip.png");
				star.color = FlxColor.BLUE;
				speedStars.push(star);
				add(star);
			}
		}

		for (i in 0...5)
		{
			speedStars[i].visible = (i < speedStarsCount);
		}

		var a:Float = creature.aggression;
		if (a < -1)
			a = -1;
		if (a > 1)
			a = 1;
		var an:Float = (a + 1.0) / 2.0;
		var aggrStarsCount:Int = Std.int(Math.floor(an * 4.0)) + 1;

		if (aggrLabel == null)
		{
			aggrLabel = new GameText(baseRightX, 108, "Aggression:");
			add(aggrLabel);

			for (i in 0...5)
			{
				var star = new FlxSprite(baseRightX + aggrLabel.width + 4 + (i * 10), 110, "assets/ui/star_pip.png");
				star.color = FlxColor.RED;
				aggrStars.push(star);
				add(star);
			}
		}

		for (i in 0...5)
		{
			aggrStars[i].visible = (i < aggrStarsCount);
		}

		// Skittishness stars - show before power
		var skitt:Float = creature.skittishness;
		if (skitt < 0)
			skitt = 0;
		if (skitt > 1)
			skitt = 1;
		var skittStarsCount:Int = Std.int(Math.floor(skitt * 4.0)) + 1;

		if (skittLabel == null)
		{
			skittLabel = new GameText(baseRightX, 128, "Skittish:");
			add(skittLabel);

			for (i in 0...5)
			{
				var star = new FlxSprite(baseRightX + skittLabel.width + 4 + (i * 10), 130, "assets/ui/star_pip.png");
				star.color = FlxColor.YELLOW;
				skittStars.push(star);
				add(star);
			}
		}

		for (i in 0...5)
		{
			skittStars[i].visible = (i < skittStarsCount);
		}

		var pn:Float = creature.power;
		if (pn < 0)
			pn = 0;
		if (pn > 1)
			pn = 1;
		var powerStarsCount:Int = Std.int(Math.floor(pn * 4.0)) + 1;

		if (powerLabel == null)
		{
			powerLabel = new GameText(baseRightX, 148, "Power:");
			add(powerLabel);

			for (i in 0...5)
			{
				var star = new FlxSprite(baseRightX + powerLabel.width + 4 + (i * 10), 150, "assets/ui/star_pip.png");
				star.color = FlxColor.GREEN;
				powerStars.push(star);
				add(star);
			}
		}

		for (i in 0...5)
		{
			powerStars[i].visible = (i < powerStarsCount);
		}

		var leftLabelX:Int = pageMargin + 18;
		if (rewardLabel == null)
		{
			rewardLabel = new GameText(leftLabelX, 128, "Reward:");
			add(rewardLabel);
		}

		var calculatedReward:Int = calculateReward(creature);
		if (rewardAmount == null)
		{
			rewardAmount = new GameText(0, 128, "$" + calculatedReward);
			rewardAmount.x = leftInnerRight - Std.int(rewardAmount.width);
			add(rewardAmount);
		}
		else
		{
			rewardAmount.text = "$" + calculatedReward;
			rewardAmount.x = leftInnerRight - Std.int(rewardAmount.width);
		}

		if (fameLabel == null)
		{
			fameLabel = new GameText(leftLabelX, 148, "Fame:");
			add(fameLabel);
		}

		var calculatedFame:Int = calculateFame(creature);
		if (fameAmount == null)
		{
			fameAmount = new GameText(0, 148, "+" + calculatedFame);
			fameAmount.x = leftInnerRight - Std.int(fameAmount.width);
			add(fameAmount);
		}
		else
		{
			fameAmount.text = "+" + calculatedFame;
			fameAmount.x = leftInnerRight - Std.int(fameAmount.width);
		}

		if (dateText == null)
		{
			dateText = new GameText(14 + 18, FlxG.height - 66, creature.date);
			add(dateText);
		}
		else
		{
			dateText.text = creature.date;
		}

		if (photoSprite == null)
		{
			photoSprite = new FlxSprite(45, 45);
			add(photoSprite);
			add(new FlxSprite(0, 0, "assets/ui/paperclip.png"));
		}

		photoSprite.visible = false;

		photoSprite.frames = FlxAtlasFrames.fromSparrow(ColorHelpers.getHueColoredBmp("assets/images/photos.png", Std.int(creature.hue)),
			"assets/images/photos.xml");

		if (creature.frameName != null && creature.frameName.length > 0)
		{
			photoSprite.animation.frameName = creature.frameName;
		}
		else
		{
			var framesForVariant = photoSprite.frames.getAllByPrefix(creature.enemyType);
			if (framesForVariant.length > 0)
			{
				photoSprite.animation.frameName = framesForVariant[0].name;
			}
		}

		photoSprite.visible = true;
	}

	private function calculateReward(creature:SavedCreature):Int
	{
		var minSpeed:Float = 20.0;
		var maxSpeed:Float = 70.0;
		var t:Float = (creature.speed - minSpeed) / (maxSpeed - minSpeed);
		if (t < 0)
			t = 0;
		if (t > 1)
			t = 1;
		var speedStarsCount:Int = Std.int(Math.floor(t * 4.0)) + 1;

		var a:Float = creature.aggression;
		if (a < -1)
			a = -1;
		if (a > 1)
			a = 1;
		var an:Float = (a + 1.0) / 2.0;
		var aggrStarsCount:Int = Std.int(Math.floor(an * 4.0)) + 1;

		var powerStarsCount:Int = creature.power;

		var skitt:Float = creature.skittishness;
		if (skitt < 0)
			skitt = 0;
		if (skitt > 1)
			skitt = 1;
		var skittStarsCount:Int = Std.int(Math.floor(skitt * 4.0)) + 1;

		// New system: ~$2 per star * level
		var totalStars:Int = speedStarsCount + aggrStarsCount + powerStarsCount + skittStarsCount;
		var maxStars:Int = 20;
		var difficultyMultiplier:Float = totalStars / maxStars;
		var baseMoneyPerStar:Int = 2;
		var moneyMultiplier:Float = 0.8 + (difficultyMultiplier * 0.4);
		return Std.int(Math.max(5, totalStars * baseMoneyPerStar * Globals.fameLevel * moneyMultiplier));
	}

	private function calculateFame(creature:SavedCreature):Int
	{
		var minSpeed:Float = 20.0;
		var maxSpeed:Float = 70.0;
		var t:Float = (creature.speed - minSpeed) / (maxSpeed - minSpeed);
		if (t < 0)
			t = 0;
		if (t > 1)
			t = 1;
		var speedStarsCount:Int = Std.int(Math.floor(t * 4.0)) + 1;

		var a:Float = creature.aggression;
		if (a < -1)
			a = -1;
		if (a > 1)
			a = 1;
		var an:Float = (a + 1.0) / 2.0;
		var aggrStarsCount:Int = Std.int(Math.floor(an * 4.0)) + 1;

		var powerStarsCount:Int = creature.power;

		var skitt:Float = creature.skittishness;
		if (skitt < 0)
			skitt = 0;
		if (skitt > 1)
			skitt = 1;
		var skittStarsCount:Int = Std.int(Math.floor(skitt * 4.0)) + 1;

		// New system: ~20% of fame needed per creature
		var totalStars:Int = speedStarsCount + aggrStarsCount + powerStarsCount + skittStarsCount;
		var maxStars:Int = 20;
		var fameNeeded:Int = Globals.getFameNeededForNextLevel();
		var baseFame:Float = fameNeeded * 0.20;
		var difficultyMultiplier:Float = totalStars / maxStars;
		return Std.int(Math.max(3, Math.round(baseFame * difficultyMultiplier)));
	}

	private function setupUINavigation():Void
	{
		uiObjects = [];
		if (prevBtn != null)
			uiObjects.push(prevBtn);
		if (nextBtn != null)
			uiObjects.push(nextBtn);
		if (closeBtn != null)
			uiObjects.push(closeBtn);

		currentUIIndex = 0;
		if (uiObjects.length > 0 && highlightSprite != null)
		{
			updateHighlight();
			highlightSprite.visible = !Globals.usingMouse;
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		Constants.Mouse.update(elapsed);

		if (isTransitioning)
			return;

		checkInputMode();
		handleUINavigation();
		handleMouseInput();
		updateHighlight();
	}

	private function checkInputMode():Void
	{
		if (FlxG.mouse.viewX != lastMouseX || FlxG.mouse.viewY != lastMouseY)
		{
			lastMouseX = FlxG.mouse.viewX;
			lastMouseY = FlxG.mouse.viewY;
			Globals.usingMouse = true;
			FlxG.mouse.visible = true;
			highlightSprite.visible = false;
		}
		else if (Actions.upUI.triggered || Actions.downUI.triggered || Actions.leftUI.triggered || Actions.rightUI.triggered)
		{
			Globals.usingMouse = false;
			FlxG.mouse.visible = false;
			highlightSprite.visible = true;
		}
	}

	private function handleUINavigation():Void
	{
		if (Actions.rightUI.triggered || Actions.downUI.triggered)
		{
			currentUIIndex = (currentUIIndex + 1) % uiObjects.length;
		}
		else if (Actions.leftUI.triggered || Actions.upUI.triggered)
		{
			currentUIIndex = currentUIIndex > 0 ? currentUIIndex - 1 : uiObjects.length - 1;
		}

		if (Actions.pressUI.triggered)
		{
			activateCurrentUIObject();
		}
	}

	private function activateCurrentUIObject():Void
	{
		if (currentUIIndex >= 0 && currentUIIndex < uiObjects.length)
		{
			var obj = uiObjects[currentUIIndex];
			if (Std.isOfType(obj, NineSliceButton))
			{
				var btn:NineSliceButton<Dynamic> = cast obj;
				if (btn.visible)
				{
					btn.onUp.fire();
				}
			}
		}
	}

	private function handleMouseInput():Void
	{
		// Let FlxButton handle mouse input properly (on justReleased, not justPressed)
		// This prevents double-click issues where a single click fires twice
	}

	private function updateHighlight():Void
	{
		if (currentUIIndex >= 0 && currentUIIndex < uiObjects.length)
		{
			var obj = uiObjects[currentUIIndex];
			highlightSprite.setTarget(Std.int(obj.x), Std.int(obj.y), Std.int(obj.width), Std.int(obj.height));
		}
	}

	override public function destroy():Void
	{
		bg = flixel.util.FlxDestroyUtil.destroy(bg);
		nameLabel = flixel.util.FlxDestroyUtil.destroy(nameLabel);
		nameText = flixel.util.FlxDestroyUtil.destroy(nameText);
		speedLabel = flixel.util.FlxDestroyUtil.destroy(speedLabel);
		aggrLabel = flixel.util.FlxDestroyUtil.destroy(aggrLabel);
		powerLabel = flixel.util.FlxDestroyUtil.destroy(powerLabel);
		rewardLabel = flixel.util.FlxDestroyUtil.destroy(rewardLabel);
		rewardAmount = flixel.util.FlxDestroyUtil.destroy(rewardAmount);
		fameLabel = flixel.util.FlxDestroyUtil.destroy(fameLabel);
		fameAmount = flixel.util.FlxDestroyUtil.destroy(fameAmount);
		photoSprite = flixel.util.FlxDestroyUtil.destroy(photoSprite);
		dateText = flixel.util.FlxDestroyUtil.destroy(dateText);
		photoCounterText = flixel.util.FlxDestroyUtil.destroy(photoCounterText);
		closeBtn = flixel.util.FlxDestroyUtil.destroy(closeBtn);
		prevBtn = flixel.util.FlxDestroyUtil.destroy(prevBtn);
		nextBtn = flixel.util.FlxDestroyUtil.destroy(nextBtn);
		highlightSprite = flixel.util.FlxDestroyUtil.destroy(highlightSprite);
		blackOut = flixel.util.FlxDestroyUtil.destroy(blackOut);

		if (speedStars != null)
		{
			for (star in speedStars)
			{
				star = flixel.util.FlxDestroyUtil.destroy(star);
			}
			speedStars = null;
		}

		if (aggrStars != null)
		{
			for (star in aggrStars)
			{
				star = flixel.util.FlxDestroyUtil.destroy(star);
			}
			aggrStars = null;
		}

		if (powerStars != null)
		{
			for (star in powerStars)
			{
				star = flixel.util.FlxDestroyUtil.destroy(star);
			}
			powerStars = null;
		}

		if (skittStars != null)
		{
			for (star in skittStars)
			{
				star = flixel.util.FlxDestroyUtil.destroy(star);
			}
			skittStars = null;
		}

		uiObjects = null;
		creatures = null;

		super.destroy();
	}
}
