package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.ui.FlxButton.FlxTypedButton;
import flixel.util.FlxColor;
import ui.GameText;
import ui.NineSliceButton;
import util.ColorHelpers;

class GameResults extends FlxState
{
	private var bg:FlxSprite;
	private var player:Player; // not used but handy
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

	// Persistent text objects for star ratings
	private var speedLabel:GameText;
	private var speedStars:Array<FlxSprite> = [];
	private var aggrLabel:GameText;
	private var aggrStars:Array<FlxSprite> = [];
	private var powerLabel:GameText;
	private var powerStars:Array<FlxSprite> = [];
	private var rewardLabel:GameText;
	private var rewardAmount:GameText;
	private var photoSprite:FlxSprite;

	private var currentUIIndex:Int = 0;
	private var uiObjects:Array<FlxSprite> = [];
	private var highlightSprite:AnimatedReticle;
	private var lastMouseX:Int = 0;
	private var lastMouseY:Int = 0;

	// Virtual Keyboard
	private var virtualKeyboard:VirtualKeyboard;
	private var currentCreatureName:String = "";

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

		// UI: show first captured enemy if any
		if (items.length > 0)
		{
			updateSelected(0);
		}
		else
		{
			// No creatures captured - show message and OK button in a dialog box
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

			// Change submit button to "OK" and make it return to office
			var okLabel = new GameText(0, 0, "OK");
			okLabel.updateHitbox(); // Force graphic creation

			submitBtn = new NineSliceButton<GameText>(dialogX + (dialogWidth - 40) / 2, dialogY + dialogHeight - 26, 40, 16, returnToOffice);
			submitBtn.label = okLabel;
			submitBtn.positionLabel();
			add(submitBtn); // Create virtual keyboard and reticle (needed for input handling)
			virtualKeyboard = new VirtualKeyboard();
			virtualKeyboard.onSubmit = onKeyboardSubmit;
			virtualKeyboard.onCancel = onKeyboardCancel;
			add(virtualKeyboard);

			highlightSprite = new AnimatedReticle();
			add(highlightSprite);
			virtualKeyboard.sharedReticle = highlightSprite; // Setup simple UI navigation for OK button
			uiObjects = [submitBtn];
			currentUIIndex = 0;

			// Skip the rest of the UI setup
			setupBlackOutAndMusic();
			super.create();
			return;
		}

		// Create submit button at bottom right
		var saveLabel = new GameText(0, 0, "Save");
		saveLabel.updateHitbox(); // Force graphic creation

		submitBtn = new NineSliceButton<GameText>(FlxG.width - 50, FlxG.height - 26, 40, 16, activateSubmitAction);
		submitBtn.label = saveLabel;
		submitBtn.positionLabel();
		add(submitBtn); // Add date text to bottom left (pocket area)
		// Position it on top of the folder, same x as "Reward:" label
		dateText = new GameText(14 + 18, FlxG.height - 66, "10/27/2025");
		add(dateText); // Add photo counter centered above folder
		if (items.length > 0)
		{
			var counterStr = "Photo "
				+ StringTools.lpad(Std.string(selectedIndex + 1), "0", 2)
				+ "/"
				+ StringTools.lpad(Std.string(items.length), "0", 2);
			photoCounterText = new GameText(0, 16, counterStr);
			photoCounterText.x = Std.int((FlxG.width - photoCounterText.width) / 2);
			add(photoCounterText);
		}

		// Setup UI objects for navigation
		setupUINavigation();

		setupBlackOutAndMusic();

		// Create virtual keyboard and reticle LAST so they're on top of everything
		virtualKeyboard = new VirtualKeyboard();
		virtualKeyboard.onSubmit = onKeyboardSubmit;
		virtualKeyboard.onCancel = onKeyboardCancel;
		add(virtualKeyboard);

		highlightSprite = new AnimatedReticle();
		add(highlightSprite);
		virtualKeyboard.sharedReticle = highlightSprite;
		
		super.create();
	}

	private function setupBlackOutAndMusic():Void
	{
		// BlackOut for fade in from black
		var overCam = new flixel.FlxCamera(0, 0, FlxG.width, FlxG.height);
		overCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(overCam, false);

		blackOut = new BlackOut(overCam);
		add(blackOut);

		// Fade in from black
		blackOut.fade(null, false, 1.0, FlxColor.BLACK);

		// Continue playing office music (if not already playing)
		util.SoundHelper.playMusic("office");
	}

	private function returnToOffice():Void
	{
		// Track returning to office with no photos saved
		axollib.AxolAPI.sendEvent("OFFICE_RETURN_NO_SAVES");
		// Fade to black and return to office
		blackOut.fade(() -> FlxG.switchState(() -> new OfficeState()), true, 1.0, FlxColor.BLACK);
	}

	private function updateSelected(idx:Int):Void
	{
		selectedIndex = idx;
		var ci:CapturedInfo = items[idx];

		// compute layout bases (center split between two pages)
		var centerX:Int = Std.int(FlxG.width / 2);
		var pageMargin:Int = 14;
		var baseRightX:Int = centerX + pageMargin;
		var leftInnerRight:Int = centerX - pageMargin;

		// Create or update Name label on first call
		if (nameLabel == null)
		{
			nameLabel = new GameText(baseRightX, 40, "Name:");
			add(nameLabel);
		}

		// Create or update name field
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

		// Speed stars (normalize speed 20..70 -> 1..5)
		var minSpeed:Float = 20.0;
		var maxSpeed:Float = 70.0;
		var t:Float = (ci.speed - minSpeed) / (maxSpeed - minSpeed);
		if (t < 0)
			t = 0;
		if (t > 1)
			t = 1;
		var speedStarsCount:Int = Std.int(Math.floor(t * 4.0)) + 1;
		
		// Create or update speed label and stars
		if (speedLabel == null)
		{
			speedLabel = new GameText(baseRightX, 88, "Speed:");
			add(speedLabel);

			// Create 5 star sprites (blue colored)
			for (i in 0...5)
			{
				var star = new FlxSprite(baseRightX + speedLabel.width + 4 + (i * 10), 90, "assets/ui/star_pip.png");
				star.color = FlxColor.BLUE;
				speedStars.push(star);
				add(star);
			}
		}

		// Update star visibility
		for (i in 0...5)
		{
			speedStars[i].visible = (i < speedStarsCount);
		}
		// Aggression stars (map -1..1 -> 1..5)
		var a:Float = ci.aggression;
		if (a < -1)
			a = -1;
		if (a > 1)
			a = 1;
		var an:Float = (a + 1.0) / 2.0;
		var aggrStarsCount:Int = Std.int(Math.floor(an * 4.0)) + 1;

		// Create or update aggression label and stars
		if (aggrLabel == null)
		{
			aggrLabel = new GameText(baseRightX, 108, "Aggression:");
			add(aggrLabel);

			// Create 5 star sprites (red colored)
			for (i in 0...5)
			{
				var star = new FlxSprite(baseRightX + aggrLabel.width + 4 + (i * 10), 110, "assets/ui/star_pip.png");
				star.color = FlxColor.RED;
				aggrStars.push(star);
				add(star);
			}
		}

		// Update star visibility
		for (i in 0...5)
		{
			aggrStars[i].visible = (i < aggrStarsCount);
		} // Power stars (1-5, directly from ci.power)
		var powerStarsCount:Int = ci.power;
		if (powerStarsCount < 1)
			powerStarsCount = 1;
		if (powerStarsCount > 5)
			powerStarsCount = 5;

		// Create or update power label and stars
		if (powerLabel == null)
		{
			powerLabel = new GameText(baseRightX, 128, "Power:");
			add(powerLabel);

			// Create 5 star sprites (green colored)
			for (i in 0...5)
			{
				var star = new FlxSprite(baseRightX + powerLabel.width + 4 + (i * 10), 130, "assets/ui/star_pip.png");
				star.color = FlxColor.GREEN;
				powerStars.push(star);
				add(star);
			}
		}

		// Update star visibility
		for (i in 0...5)
		{
			powerStars[i].visible = (i < powerStarsCount);
		}

		// reward = (speed stars + aggression stars + power stars) * $5
		var reward:Int = (speedStarsCount + aggrStarsCount + powerStarsCount) * 5;
		currentReward = reward; // Store for later use when saving

		// Create or update reward label and amount on left page
		var leftLabelX:Int = pageMargin + 18;
		if (rewardLabel == null)
		{
			rewardLabel = new GameText(leftLabelX, 140, "Reward:");
			add(rewardLabel);
		}

		if (rewardAmount == null)
		{
			rewardAmount = new GameText(0, 140, "$" + Std.string(reward));
			rewardAmount.x = leftInnerRight - Std.int(rewardAmount.width);
			add(rewardAmount);
		}
		else
		{
			rewardAmount.text = "$" + Std.string(reward);
			rewardAmount.x = leftInnerRight - Std.int(rewardAmount.width);
		}
		
		// Create or update photo sprite
		if (photoSprite == null)
		{
			photoSprite = new FlxSprite();
			photoSprite.x = 45;
			photoSprite.y = 45;
			add(photoSprite);
			
			// Add paperclip on top
			add(new FlxSprite(0, 0, "assets/ui/paperclip.png"));
		}

		// Update photo frame
		photoSprite.frames = FlxAtlasFrames.fromSparrow(ColorHelpers.getHueColoredBmp("assets/images/photos.png", ci.hue), "assets/images/photos.xml");
		var framesForVariant = photoSprite.frames.getAllByPrefix(ci.variant);
		var frameIndex = FlxG.random.int(0, framesForVariant.length - 1);
		photoSprite.animation.frameName = framesForVariant[frameIndex].name;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		Constants.Mouse.update(elapsed);

		// Don't process input during transitions
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
	}
	private function handleUINavigation():Void
	{
		if (keyboardActive)
			return;

		// Navigate between UI objects
		if (Actions.rightUI.triggered || Actions.downUI.triggered)
		{
			currentUIIndex = (currentUIIndex + 1) % uiObjects.length;
		}
		else if (Actions.leftUI.triggered || Actions.upUI.triggered)
		{
			currentUIIndex = currentUIIndex > 0 ? currentUIIndex - 1 : uiObjects.length - 1;
		}

		// Activate current UI object
		if (Actions.pressUI.triggered)
		{
			activateCurrentUIObject();
		}
	}

	private function handleMouseInput():Void
	{
		if (keyboardActive)
			return;

		if (FlxG.mouse.justPressed)
		{
			var mousePos = FlxG.mouse.getWorldPosition();

			// Check nameText click
			if (nameText != null && nameText.overlapsPoint(mousePos))
			{
				currentUIIndex = 0;
				activateRenameAction();
			}
			// Check submit button click
			else if (submitBtn != null && submitBtn.overlapsPoint(mousePos))
			{
				currentUIIndex = 1;
				activateSubmitAction();
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

		// Hide the save button while keyboard is active
		if (submitBtn != null)
			submitBtn.visible = false;
		
		virtualKeyboard.show(currentCreatureName);
	}

	private function activateSubmitAction():Void
	{
		// Prevent multiple submissions during transition
		if (isTransitioning)
			return;

		// Only allow save if name is non-empty
		if (currentCreatureName == null || currentCreatureName.length == 0)
		{
			trace("Cannot save: name is empty");
			return;
		}

		// Get current creature data
		if (items.length > 0 && selectedIndex < items.length)
		{
			var ci = items[selectedIndex];
			var savedCreature:SavedCreature = {
				enemyType: ci.variant,
				photoIndex: ci.photoIndex,
				hue: ci.hue,
				speed: ci.speed,
				aggression: ci.aggression,
				power: ci.power,
				name: currentCreatureName,
				date: "10/27/2025"
			};

			Globals.saveCreature(savedCreature, currentReward);
			trace("Saved creature: " + currentCreatureName + " for $" + currentReward);
			trace("Total money: $" + Globals.playerMoney);

			// Track creature save with reward amount
			axollib.AxolAPI.sendEvent("CREATURE_SAVED", currentReward);

			// Move to next creature or transition to OfficeState
			if (selectedIndex < items.length - 1)
			{
				// More creatures to process - move to next
				isTransitioning = true;
				currentCreatureName = ""; // Reset name for next creature
				selectedIndex++;
				updateSelected(selectedIndex);

				// Update photo counter
				if (photoCounterText != null)
				{
					var counterStr = "Photo " + StringTools.lpad(Std.string(selectedIndex + 1), "0", 2) + "/"
						+ StringTools.lpad(Std.string(items.length), "0", 2);
					photoCounterText.text = counterStr;
					photoCounterText.x = Std.int((FlxG.width - photoCounterText.width) / 2);
				}

				isTransitioning = false;
			}
			else
			{
				// Last creature - transition to OfficeState
				isTransitioning = true;

				// Track returning to office after saving all creatures
				axollib.AxolAPI.sendEvent("OFFICE_RETURN_ALL_SAVED", items.length);

				blackOut.fade(() ->
				{
					FlxG.switchState(() -> new OfficeState());
				}, true, 1.0, FlxColor.BLACK);
			}
		}
	}
	private function onKeyboardSubmit(newName:String):Void
	{
		currentCreatureName = newName;
		keyboardActive = false;

		// Show the save button again
		if (submitBtn != null)
			submitBtn.visible = true;

		if (nameText != null)
		{
			nameText.text = newName.length > 0 ? newName : "[EDIT]";
		}
		// Target back to the [EDIT] field
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
		// Show the save button again
		if (submitBtn != null)
			submitBtn.visible = true;
		
		// Don't change the current name
		// Target back to the [EDIT] field
		if (uiObjects.length > 0)
		{
			var editField = uiObjects[0];
			highlightSprite.setTarget(Std.int(editField.x), Std.int(editField.y), Std.int(editField.width), Std.int(editField.height));
			highlightSprite.visible = !Globals.usingMouse;
		}
	}
}
