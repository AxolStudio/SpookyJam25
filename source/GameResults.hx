package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.graphics.frames.FlxAtlasFrames;
import ui.GameText;
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
	private var submitBtn:FlxSprite;
	private var keyboardActive:Bool = false;

	// UI Navigation
	private var currentUIIndex:Int = 0;
	private var uiObjects:Array<FlxSprite> = [];
	private var highlightSprite:FlxSprite;

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
		// Initialize Actions and switch to menu controls
		Actions.init();
		Actions.switchSet(Actions.menuIndex);
		
		// background report image
		bg = new FlxSprite(0, 0, "assets/ui/room_report.png");
		add(bg);

		// UI: show first captured enemy if any
		if (items.length > 0)
		{
			updateSelected(0);
		}
		else
		{
			// center the no-creatures message
			nameText = new GameText(0, 80, "No creatures captured.");
			add(nameText);
			nameText.x = Std.int((FlxG.width - nameText.width) / 2);
		}

		// Create submit button at bottom right
		submitBtn = new FlxSprite();
		submitBtn.makeGraphic(60, 20, 0xFF444444); // Temporary gray placeholder
		submitBtn.x = FlxG.width - submitBtn.width - 10;
		submitBtn.y = FlxG.height - submitBtn.height - 10;
		add(submitBtn);
		
		// Create highlight sprite
		highlightSprite = new FlxSprite();
		highlightSprite.makeGraphic(1, 1, 0xFFFFFF00); // Yellow highlight
		highlightSprite.alpha = 0.3;
		add(highlightSprite);

		// Create virtual keyboard
		virtualKeyboard = new VirtualKeyboard();
		virtualKeyboard.onSubmit = onKeyboardSubmit;
		virtualKeyboard.onCancel = onKeyboardCancel;
		add(virtualKeyboard);

		// Setup UI objects for navigation
		setupUINavigation();

		super.create();
	}

	private function updateSelected(idx:Int):Void
	{
		selectedIndex = idx;
		var ci:CapturedInfo = items[idx];

		// clear previous
		if (nameText != null)
			nameText.kill();
		if (infoText != null)
			infoText.kill();
		if (rewardText != null)
			rewardText.kill();

		// compute layout bases (center split between two pages)
		var centerX:Int = Std.int(FlxG.width / 2);
		var pageMargin:Int = 14;
		var baseRightX:Int = centerX + pageMargin;
		var leftInnerRight:Int = centerX - pageMargin;

		// Name label higher up on the right side
		if (nameLabel != null)
			nameLabel.kill();
		nameLabel = new GameText(baseRightX, 40, "Name:");
		add(nameLabel);
		// Clickable name field just underneath the label
		nameText = new GameText(baseRightX, 56, "[EDIT]");
		nameText.autoSize = false;
		nameText.fieldWidth = 120;
		add(nameText);

		// Speed stars (normalize speed 20..70 -> 1..5)
		var minSpeed:Float = 20.0;
		var maxSpeed:Float = 70.0;
		var t:Float = (ci.speed - minSpeed) / (maxSpeed - minSpeed);
		if (t < 0)
			t = 0;
		if (t > 1)
			t = 1;
		var speedStars:Int = Std.int(Math.floor(t * 4.0)) + 1;
		var speedStarsStr:String = "";
		for (i in 0...speedStars)
			speedStarsStr += "*";
		var speedText = new GameText(baseRightX, 88, "Speed: " + speedStarsStr);
		add(speedText);

		// Aggression stars (map -1..1 -> 1..5)
		var a:Float = ci.aggression;
		if (a < -1)
			a = -1;
		if (a > 1)
			a = 1;
		// normalize to 0..1
		var an:Float = (a + 1.0) / 2.0;
		var aggrStars:Int = Std.int(Math.floor(an * 4.0)) + 1;
		var aggrStarsStr:String = "";
		for (i in 0...aggrStars)
			aggrStarsStr += "*";
		var aggrText = new GameText(baseRightX, 108, "Aggression: " + aggrStarsStr);
		add(aggrText);

		// reward = sum of stars * 10
		var reward:Int = (speedStars + aggrStars) * 10;
		// reward label and right-aligned amount on left page
		var leftLabelX:Int = pageMargin + 18;
		var rewardLabel = new GameText(leftLabelX, 140, "Reward:");
		add(rewardLabel);
		var rewardAmount = new GameText(0, 140, "$" + Std.string(reward));
		rewardAmount.x = leftInnerRight - Std.int(rewardAmount.width);
		add(rewardAmount);
		var photo:FlxSprite = new FlxSprite();
		photo.frames = FlxAtlasFrames.fromSparrow(ColorHelpers.getHueColoredBmp("assets/images/photos.png", ci.hue), "assets/images/photos.xml");

		// get all the frames that start with the variant name
		var framesForVariant = photo.frames.getAllByPrefix(ci.variant);
		// pick one at random
		var frameIndex = FlxG.random.int(0, framesForVariant.length - 1);
		photo.animation.frameName = framesForVariant[frameIndex].name;
		photo.x = 45;
		photo.y = 40;
		add(photo);

		add(new FlxSprite(0, 0, "assets/ui/paperclip.png"));
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (virtualKeyboard.isVisible)
		{
			// Handle virtual keyboard input
			virtualKeyboard.handleInput();
		}
		else
		{
			// Handle normal UI navigation
			handleUINavigation();
			handleMouseInput();
			updateHighlight();
		}
	}

	private function openKeyboardFor(idx:Int):Void
	{
		// TODO: implement keyboard opening
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
		if (uiObjects.length > 0 && currentUIIndex < uiObjects.length)
		{
			var currentObj = uiObjects[currentUIIndex];
			highlightSprite.setGraphicSize(Std.int(currentObj.width + 4), Std.int(currentObj.height + 4));
			highlightSprite.updateHitbox();
			highlightSprite.x = currentObj.x - 2;
			highlightSprite.y = currentObj.y - 2;
			highlightSprite.visible = true;
		}
		else
		{
			highlightSprite.visible = false;
		}
	}

	private function activateCurrentUIObject():Void
	{
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
		virtualKeyboard.show(currentCreatureName);
	}

	private function activateSubmitAction():Void
	{
		// TODO: placeholder submit action
		trace("Submit action triggered");
	}
	private function onKeyboardSubmit(newName:String):Void
	{
		currentCreatureName = newName;
		keyboardActive = false;

		// Update the name display
		if (nameText != null)
		{
			nameText.text = newName.length > 0 ? newName : "[EDIT]";
		}
	}

	private function onKeyboardCancel():Void
	{
		keyboardActive = false;
		// Don't change the current name
	}
}
