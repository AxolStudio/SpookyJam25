package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import ui.GameText;
import ui.NineSliceButton;
import util.ColorHelpers;

class GameResults extends FlxState
{
	private var bg:FlxSprite;
	private var player:Player;
	private var items:Array<CapturedInfo>;
	private var selectedIndex:Int = 0;
	private var nameText:GameText;
	private var nameLabel:GameText;
	private var infoText:GameText;
	private var rewardText:GameText;
	private var submitBtn:NineSliceButton<GameText>;
	private var keyboardActive:Bool = false;
	private var dateText:GameText;
	private var photoCounterText:GameText;
	private var currentReward:Int = 0;
	private var blackOut:BlackOut;
	private var isTransitioning:Bool = false;
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

	private var currentUIIndex:Int = 0;
	private var uiObjects:Array<FlxSprite> = [];
	private var highlightSprite:AnimatedReticle;
	private var lastMouseX:Int = 0;
	private var lastMouseY:Int = 0;

	private var virtualKeyboard:VirtualKeyboard;
	private var currentCreatureName:String = "";
	private var totalFameEarned:Int = 0;
	private var totalMoneyEarned:Int = 0;
	private var currentFame:Int = 0;
	private var currentFrameName:String = "";
	private var nameTextPulseTween:FlxTween = null;

	public function new(items:Array<CapturedInfo>)
	{
		super();
		this.items = items != null ? items : [];
	}

	override public function create():Void
	{
		Globals.init();
		Actions.switchSet(Actions.menuIndex);

		FlxG.mouse.visible = false;
		
		bg = new FlxSprite(0, 0, "assets/ui/room_report.png");
		add(bg);

		if (items.length > 0)
		{
			updateSelected(0);
		}
		else
		{
			var dialogWidth:Float = 200;
			var dialogHeight:Float = 80;
			var dialogX:Float = (FlxG.width - dialogWidth) / 2;
			var dialogY:Float = (FlxG.height - dialogHeight) / 2;

			var noPhotosDialog = new NineSliceSprite(dialogX, dialogY, dialogWidth, dialogHeight);
			add(noPhotosDialog);

			nameText = new GameText(0, 0, "No creatures captured.");
			add(nameText);
			nameText.x = dialogX + (dialogWidth - nameText.width) / 2;
			nameText.y = dialogY + 10;

			var okLabel = new GameText(0, 0, "OK");
			okLabel.updateHitbox();

			submitBtn = new NineSliceButton<GameText>(dialogX + (dialogWidth - 40) / 2, dialogY + dialogHeight - 26, 40, 16, returnToOffice);
			submitBtn.label = okLabel;
			submitBtn.positionLabel();
			add(submitBtn);

			virtualKeyboard = new VirtualKeyboard();
			virtualKeyboard.onSubmit = onKeyboardSubmit;
			virtualKeyboard.onCancel = onKeyboardCancel;
			add(virtualKeyboard);

			highlightSprite = new AnimatedReticle();
			add(highlightSprite);
			virtualKeyboard.sharedReticle = highlightSprite;

			uiObjects = [submitBtn];
			currentUIIndex = 0;
			highlightSprite.setTarget(Std.int(submitBtn.x), Std.int(submitBtn.y), Std.int(submitBtn.width), Std.int(submitBtn.height));
			highlightSprite.visible = !Globals.usingMouse;

			setupBlackOutAndMusic();
			super.create();
			return;
		}

		var saveLabel = new GameText(0, 0, "Save");
		saveLabel.updateHitbox();

		submitBtn = new NineSliceButton<GameText>(FlxG.width - 50, FlxG.height - 26, 40, 16, activateSubmitAction);
		submitBtn.label = saveLabel;
		submitBtn.positionLabel();
		submitBtn.visible = false; // Hide until name is entered
		add(submitBtn);
		dateText = new GameText(14 + 18, FlxG.height - 66, "10/27/2025");
		add(dateText);
		if (items.length > 0)
		{
			var counterStr = "Photo "
				+ StringTools.lpad(Std.string(selectedIndex + 1), "0", 2)
				+ "/"
				+ StringTools.lpad(Std.string(items.length), "0", 2);
			photoCounterText = new GameText(14 + 18, FlxG.height - 54, counterStr);
			add(photoCounterText);
		}

		setupBlackOutAndMusic();

		virtualKeyboard = new VirtualKeyboard();
		virtualKeyboard.onSubmit = onKeyboardSubmit;
		virtualKeyboard.onCancel = onKeyboardCancel;
		add(virtualKeyboard);

		highlightSprite = new AnimatedReticle();
		add(highlightSprite);
		virtualKeyboard.sharedReticle = highlightSprite;

		setupUINavigation();
		
		super.create();
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
		axollib.AxolAPI.sendEvent("OFFICE_RETURN_NO_SAVES");
		blackOut.fade(() -> FlxG.switchState(() -> new OfficeState()), true, 0.33, FlxColor.BLACK);
	}

	private function updateSelected(idx:Int):Void
	{
		selectedIndex = idx;
		var ci:CapturedInfo = items[idx];

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
			nameText = new GameText(baseRightX, 56, "[EDIT]");
			nameText.autoSize = false;
			nameText.fieldWidth = 120;
			add(nameText);
		}
		else
		{
			nameText.text = "[EDIT]";
		}
		// Start pulsing animation for [EDIT] text
		if (nameTextPulseTween != null)
		{
			nameTextPulseTween.cancel();
		}
		nameTextPulseTween = FlxTween.tween(nameText, {alpha: 0.25}, 0.5, {
			type: FlxTweenType.PINGPONG,
			startDelay: 0,
			loopDelay: 0
		});

		var minSpeed:Float = 20.0;
		var maxSpeed:Float = 70.0;
		var t:Float = (ci.speed - minSpeed) / (maxSpeed - minSpeed);
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
		var a:Float = ci.aggression;
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
		// Skittishness stars (how hard to catch - flee behavior) - show before power
		var skitt:Float = ci.skittishness;
		if (skitt < 0)
			skitt = 0;
		if (skitt > 1)
			skitt = 1;
		var skittStarsCount:Int = Std.int(Math.floor(skitt * 4.0)) + 1; // 1-5 stars

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
		
		var powerStarsCount:Int = ci.power;
		if (powerStarsCount < 1)
			powerStarsCount = 1;
		if (powerStarsCount > 5)
			powerStarsCount = 5;

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

		// New reward system based on total difficulty (star count)
		// Fame: ~20% of what's needed for next level, scaled by total stars
		// Money: ~$2 per star * level, with some variation

		var totalStars:Int = speedStarsCount + aggrStarsCount + powerStarsCount + skittStarsCount;
		var maxStars:Int = 20; // 5+5+5+5

		// Fame calculation: Base is 20% of fame needed, scaled by difficulty
		var fameNeeded:Int = Globals.getFameNeededForNextLevel();
		var baseFame:Float = fameNeeded * 0.20; // Target 20% per creature
		var difficultyMultiplier:Float = totalStars / maxStars; // 0.2 to 1.0 for 3-15 stars
		currentFame = Std.int(Math.max(3, Math.round(baseFame * difficultyMultiplier)));

		// Money calculation: ~$2 per star * level
		var baseMoneyPerStar:Int = 2;
		var moneyMultiplier:Float = 0.8 + (difficultyMultiplier * 0.4); // 0.8-1.2 variation
		var reward:Int = Std.int(Math.max(5, totalStars * baseMoneyPerStar * Globals.fameLevel * moneyMultiplier));
		currentReward = reward;

		var leftLabelX:Int = pageMargin + 18;
		if (rewardLabel == null)
		{
			rewardLabel = new GameText(leftLabelX, 160, "Reward:");
			add(rewardLabel);
		}

		if (rewardAmount == null)
		{
			rewardAmount = new GameText(0, 160, "$" + Std.string(reward));
			rewardAmount.x = leftInnerRight - Std.int(rewardAmount.width);
			add(rewardAmount);
		}
		else
		{
			rewardAmount.text = "$" + Std.string(reward);
			rewardAmount.x = leftInnerRight - Std.int(rewardAmount.width);
		}

		// Fame display
		if (fameLabel == null)
		{
			fameLabel = new GameText(leftLabelX, 172, "Fame:");
			add(fameLabel);
		}

		if (fameAmount == null)
		{
			fameAmount = new GameText(0, 172, "+" + Std.string(currentFame));
			fameAmount.x = leftInnerRight - Std.int(fameAmount.width);
			add(fameAmount);
		}
		else
		{
			fameAmount.text = "+" + Std.string(currentFame);
			fameAmount.x = leftInnerRight - Std.int(fameAmount.width);
		}

		if (photoSprite == null)
		{
			photoSprite = new FlxSprite();
			photoSprite.x = 45;
			photoSprite.y = 45;
			add(photoSprite);

			add(new FlxSprite(0, 0, "assets/ui/paperclip.png"));
		}

		photoSprite.frames = FlxAtlasFrames.fromSparrow(ColorHelpers.getHueColoredBmp("assets/images/photos.png", ci.hue), "assets/images/photos.xml");
		var framesForVariant = photoSprite.frames.getAllByPrefix(ci.variant);
		var frameIndex = FlxG.random.int(0, framesForVariant.length - 1);
		currentFrameName = framesForVariant[frameIndex].name;
		photoSprite.animation.frameName = currentFrameName;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		Constants.Mouse.update(elapsed);

		if (isTransitioning)
			return;

		checkInputMode();
		if (virtualKeyboard.isVisible)
		{
			virtualKeyboard.handleInput();
		}
		else
		{
			handleUINavigation();
			handleMouseInput();
			updateHighlight();
		}
	}

	private function checkInputMode():Void
	{
		if (FlxG.mouse.viewX != lastMouseX || FlxG.mouse.viewY != lastMouseY)
		{
			lastMouseX = FlxG.mouse.viewX;
			lastMouseY = FlxG.mouse.viewY;
			Globals.usingMouse = true;
			FlxG.mouse.visible = true;
			if (!virtualKeyboard.isVisible)
			{
				highlightSprite.visible = false;
			}
		}
		else if (Actions.upUI.triggered || Actions.downUI.triggered || Actions.leftUI.triggered || Actions.rightUI.triggered)
		{
			Globals.usingMouse = false;
			FlxG.mouse.visible = false;
			if (!virtualKeyboard.isVisible)
			{
				highlightSprite.visible = true;
			}
		}
	}


	private function setupUINavigation():Void
	{
		uiObjects = [];
		if (nameText != null)
			uiObjects.push(cast nameText);
		if (submitBtn != null)
			uiObjects.push(submitBtn);

		currentUIIndex = 0;
		if (uiObjects.length > 0 && highlightSprite != null)
		{
			var firstObj = uiObjects[0];
			highlightSprite.setTarget(Std.int(firstObj.x), Std.int(firstObj.y), Std.int(firstObj.width), Std.int(firstObj.height));
			highlightSprite.visible = !Globals.usingMouse;
		}
	}
	private function handleUINavigation():Void
	{
		if (keyboardActive)
			return;

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

	private function handleMouseInput():Void
	{
		if (keyboardActive)
			return;

		// Let FlxButton handle mouse input properly (on justReleased, not justPressed)
		// Check for clicks on the name text field to activate rename
		if (FlxG.mouse.justPressed)
		{
			var mousePos = FlxG.mouse.getWorldPosition();

			if (nameText != null && nameText.overlapsPoint(mousePos))
			{
				currentUIIndex = 0;
				activateRenameAction();
			}

			mousePos.put();
		}
	}

	private function updateHighlight():Void
	{
		if (!Globals.usingMouse && uiObjects.length > 0 && currentUIIndex < uiObjects.length)
		{
			var currentObj = uiObjects[currentUIIndex];
			highlightSprite.changeTarget(Std.int(currentObj.x), Std.int(currentObj.y), Std.int(currentObj.width), Std.int(currentObj.height));
			highlightSprite.visible = true;
		}
		else
		{
			highlightSprite.visible = false;
		}
	}

	private function activateCurrentUIObject():Void
	{
		// If no items, the only UI object is the OK button
		if (items.length == 0)
		{
			returnToOffice();
			return;
		}

		if (currentUIIndex == 0)
		{
			activateRenameAction();
		}
		else if (currentUIIndex == 1)
		{
			activateSubmitAction();
		}
	}

	private function activateRenameAction():Void
	{
		keyboardActive = true;
		highlightSprite.visible = false;

		if (submitBtn != null)
			submitBtn.visible = false;
		
		virtualKeyboard.show(currentCreatureName);
	}

	private function activateSubmitAction():Void
	{
		if (isTransitioning)
			return;

		if (currentCreatureName == null || currentCreatureName.length == 0)
		{
			trace("Cannot save: name is empty");
			return;
		}

		if (items.length > 0 && selectedIndex < items.length)
		{
			var ci = items[selectedIndex];
			var savedCreature:SavedCreature = {
				enemyType: ci.variant,
				photoIndex: ci.photoIndex,
				hue: ci.hue,
				speed: ci.speed,
				aggression: ci.aggression,
				skittishness: ci.skittishness,
				power: ci.power,
				name: currentCreatureName,
				date: "10/27/2025",
				frameName: currentFrameName
			};

			Globals.saveCreature(savedCreature);
			totalFameEarned += currentFame;
			totalMoneyEarned += currentReward;
			trace("Saved creature: " + currentCreatureName + " for $" + currentReward + " and +" + currentFame + " fame");
			trace("Total money to earn: $" + totalMoneyEarned);

			axollib.AxolAPI.sendEvent("CREATURE_SAVED", currentReward);

			if (selectedIndex < items.length - 1)
			{
				isTransitioning = true;
				currentCreatureName = "";
				selectedIndex++;
				updateSelected(selectedIndex);

				if (photoCounterText != null)
				{
					var counterStr = "Photo " + StringTools.lpad(Std.string(selectedIndex + 1), "0", 2) + "/"
						+ StringTools.lpad(Std.string(items.length), "0", 2);
					photoCounterText.text = counterStr;
				}

				// Hide save button since name is reset
				if (submitBtn != null)
					submitBtn.visible = false;

				isTransitioning = false;
			}
			else
			{
				isTransitioning = true;

				axollib.AxolAPI.sendEvent("OFFICE_RETURN_ALL_SAVED", items.length);

				blackOut.fade(() ->
				{
					FlxG.switchState(() -> new FameResultsState(totalFameEarned, totalMoneyEarned));
				}, true, 1.0, FlxColor.BLACK);
			}
		}
	}
	private function onKeyboardSubmit(newName:String):Void
	{
		currentCreatureName = newName;
		keyboardActive = false;

		// Only show save button if a name was actually entered
		if (submitBtn != null)
			submitBtn.visible = (newName != null && newName.length > 0);

		if (nameText != null)
		{
			nameText.text = newName.length > 0 ? newName : "[EDIT]";
			// Stop pulsing and restore full alpha when name is changed
			if (nameTextPulseTween != null)
			{
				nameTextPulseTween.cancel();
				nameTextPulseTween = null;
			}
			nameText.alpha = 1.0;
			// If name is still "[EDIT]", start pulsing again
			if (nameText.text == "[EDIT]")
			{
				nameTextPulseTween = FlxTween.tween(nameText, {alpha: 0.25}, 0.5, {
					type: FlxTweenType.PINGPONG,
					startDelay: 0,
					loopDelay: 0
				});
			}
		}
		if (uiObjects.length > 0)
		{
			var editField = uiObjects[0];
			highlightSprite.setTarget(Std.int(editField.x), Std.int(editField.y), Std.int(editField.width), Std.int(editField.height));
			highlightSprite.visible = !Globals.usingMouse;
		}
	}

	private function onKeyboardCancel():Void
	{
		keyboardActive = false;
		if (submitBtn != null)
			submitBtn.visible = true;

		if (uiObjects.length > 0)
		{
			var editField = uiObjects[0];
			highlightSprite.setTarget(Std.int(editField.x), Std.int(editField.y), Std.int(editField.width), Std.int(editField.height));
			highlightSprite.visible = !Globals.usingMouse;
		}
	}
	override public function destroy():Void
	{
		bg = flixel.util.FlxDestroyUtil.destroy(bg);
		nameText = flixel.util.FlxDestroyUtil.destroy(nameText);
		nameLabel = flixel.util.FlxDestroyUtil.destroy(nameLabel);
		infoText = flixel.util.FlxDestroyUtil.destroy(infoText);
		rewardText = flixel.util.FlxDestroyUtil.destroy(rewardText);
		submitBtn = flixel.util.FlxDestroyUtil.destroy(submitBtn);
		dateText = flixel.util.FlxDestroyUtil.destroy(dateText);
		photoCounterText = flixel.util.FlxDestroyUtil.destroy(photoCounterText);
		blackOut = flixel.util.FlxDestroyUtil.destroy(blackOut);

		speedLabel = flixel.util.FlxDestroyUtil.destroy(speedLabel);
		if (speedStars != null)
		{
			for (star in speedStars)
				flixel.util.FlxDestroyUtil.destroy(star);
			speedStars = null;
		}

		aggrLabel = flixel.util.FlxDestroyUtil.destroy(aggrLabel);
		if (aggrStars != null)
		{
			for (star in aggrStars)
				flixel.util.FlxDestroyUtil.destroy(star);
			aggrStars = null;
		}

		powerLabel = flixel.util.FlxDestroyUtil.destroy(powerLabel);
		if (powerStars != null)
		{
			for (star in powerStars)
				flixel.util.FlxDestroyUtil.destroy(star);
			powerStars = null;
		}

		skittLabel = flixel.util.FlxDestroyUtil.destroy(skittLabel);
		if (skittStars != null)
		{
			for (star in skittStars)
				flixel.util.FlxDestroyUtil.destroy(star);
			skittStars = null;
		}

		rewardLabel = flixel.util.FlxDestroyUtil.destroy(rewardLabel);
		rewardAmount = flixel.util.FlxDestroyUtil.destroy(rewardAmount);
		photoSprite = flixel.util.FlxDestroyUtil.destroy(photoSprite);

		highlightSprite = flixel.util.FlxDestroyUtil.destroy(highlightSprite);
		virtualKeyboard = flixel.util.FlxDestroyUtil.destroy(virtualKeyboard);

		if (uiObjects != null)
		{
			uiObjects = null;
		}
		if (items != null)
		{
			items = null;
		}

		player = null;

		super.destroy();
	}
}
