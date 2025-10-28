package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;
import flixel.ui.FlxButton.FlxTypedButton;
import ui.GameText;
import ui.NineSliceButton;

class OfficeState extends FlxState
{
	private var blackOut:BlackOut;
	private var isTransitioning:Bool = false;

	// Interactive objects
	private var desk:FlxSprite;
	private var deskHover:FlxSprite;
	private var phone:FlxSprite;
	private var phoneHover:FlxSprite;
	private var portal:FlxSprite;
	private var portalHover:FlxSprite;
	private var trash:FlxSprite;
	private var trashHover:FlxSprite;

	// Confirmation dialog
	private var confirmDialog:NineSliceSprite;
	private var confirmText:GameText;
	private var yesButton:NineSliceButton<GameText>;
	private var noButton:NineSliceButton<GameText>;
	private var showingConfirmDialog:Bool = false;

	// UI navigation
	private var interactiveObjects:Array<InteractiveObject> = [];
	private var currentIndex:Int = 0;
	private var lastMouseX:Int = 0;
	private var lastMouseY:Int = 0;
	private var selectionText:GameText;
	private var moneyText:GameText;

	private var ready:Bool = false;

	override public function create():Void
	{
		super.create();

		Globals.init();
		Actions.switchSet(Actions.menuIndex);

		// Layer 1: Background
		var bg = new FlxSprite(0, 0, "assets/ui/bg.png");
		add(bg);

		// Layer 2: Board (non-interactive)
		var board = new FlxSprite(0, 0, "assets/ui/board.png");
		add(board);

		// Layer 3: Trash (interactive) - behind desk
		trash = new FlxSprite(0, 0, "assets/ui/trash.png");
		add(trash);
		trashHover = new FlxSprite(0, 0, "assets/ui/hover_trash.png");
		trashHover.visible = false;
		add(trashHover);

		// Layer 4: Desk goes on top of trash
		desk = new FlxSprite(0, 0, "assets/ui/desk.png");
		add(desk);
		deskHover = new FlxSprite(0, 0, "assets/ui/hover_desk.png");
		deskHover.visible = false;
		add(deskHover);

		// Layer 5: Phone (interactive)
		phone = new FlxSprite(0, 0, "assets/ui/phone.png");
		add(phone);
		phoneHover = new FlxSprite(0, 0, "assets/ui/hover_phone.png");
		phoneHover.visible = false;
		add(phoneHover);

		// Layer 6: Portal (interactive)
		portal = new FlxSprite(0, 0, "assets/ui/office_portal.png");
		add(portal);
		portalHover = new FlxSprite(0, 0, "assets/ui/hover_portal.png");
		portalHover.visible = false;
		add(portalHover);

		// Money display - yellow zone on board (top left area)
		moneyText = new GameText(34, 47, "$" + Globals.playerMoney);
		add(moneyText);

		// Selection label at bottom center
		selectionText = new GameText(0, FlxG.height - 22, "");
		selectionText.x = Std.int((FlxG.width - selectionText.width) / 2);
		add(selectionText); // Setup interactive objects
		setupInteractiveObjects();

		// BlackOut for fade in from black
		var overCam = new flixel.FlxCamera(0, 0, FlxG.width, FlxG.height);
		overCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(overCam, false);

		blackOut = new BlackOut(overCam);
		add(blackOut);

		// Fade in from black
		blackOut.fade(() ->
		{
			// Start with cursor visible (mouse mode by default)
			FlxG.mouse.visible = true;
			Globals.usingMouse = true;
			ready = true;
		}, false, 1.0, FlxColor.BLACK);

		// Start playing office music (if not already playing)
		util.SoundHelper.playMusic("office");
	}

	private function setupInteractiveObjects():Void
	{
		// Define clickable regions based on mockup zones
		// NOTE: Order matters! Smaller/overlapping regions should come first

		interactiveObjects.push({
			name: "phone",
			normalSprite: phone,
			hoverSprite: phoneHover,
			bounds: new flixel.math.FlxRect(151, 36, 72, 90), // Purple zone - phone on desk
			callback: onPhoneClick
		});

		interactiveObjects.push({
			name: "trash",
			normalSprite: trash,
			hoverSprite: trashHover,
			bounds: new flixel.math.FlxRect(151, 159, 46, 58), // Blue zone - trash can bottom left
			callback: onTrashClick
		});

		interactiveObjects.push({
			name: "portal",
			normalSprite: portal,
			hoverSprite: portalHover,
			bounds: new flixel.math.FlxRect(234, 0, 86, 240), // Red zone - right side portal
			callback: onPortalClick
		});

		interactiveObjects.push({
			name: "desk",
			normalSprite: desk,
			hoverSprite: deskHover,
			bounds: new flixel.math.FlxRect(0, 121, 148, 119), // Green zone - desk filing area
			callback: onDeskClick
		});

		// Start with first object selected (for keyboard navigation)
		currentIndex = 0;
		updateHighlights();
		updateSelectionText();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		Constants.Mouse.update(elapsed);

		if (isTransitioning || !ready)
			return;

		// If showing confirmation dialog, handle dialog input only
		if (showingConfirmDialog)
			return;

		checkInputMode();

		if (Globals.usingMouse)
		{
			handleMouseInput();
		}
		else
		{
			handleKeyboardInput();
		}

		updateHighlights();
	}

	private function checkInputMode():Void
	{
		// Check if mouse moved
		if (FlxG.mouse.viewX != lastMouseX || FlxG.mouse.viewY != lastMouseY)
		{
			lastMouseX = FlxG.mouse.viewX;
			lastMouseY = FlxG.mouse.viewY;
			Globals.usingMouse = true;
			FlxG.mouse.visible = true;
		}
		// Check if keyboard/gamepad input used
		else if (Actions.leftUI.triggered || Actions.rightUI.triggered || Actions.upUI.triggered || Actions.downUI.triggered)
		{
			Globals.usingMouse = false;
			FlxG.mouse.visible = false;
		}
	}

	private function handleMouseInput():Void
	{
		var mousePos = FlxG.mouse.getPosition();

		// Check which object mouse is over
		for (i in 0...interactiveObjects.length)
		{
			var obj = interactiveObjects[i];
			if (obj.bounds.containsPoint(mousePos))
			{
				currentIndex = i;
				if (FlxG.mouse.justPressed)
				{
					obj.callback();
				}
				break;
			}
		}

		mousePos.put();
	}

	private function handleKeyboardInput():Void
	{
		if (Actions.leftUI.triggered)
		{
			currentIndex--;
			if (currentIndex < 0)
				currentIndex = interactiveObjects.length - 1;
		}
		else if (Actions.rightUI.triggered)
		{
			currentIndex++;
			if (currentIndex >= interactiveObjects.length)
				currentIndex = 0;
		}

		if (Actions.pressUI.triggered)
		{
			interactiveObjects[currentIndex].callback();
		}

		// Update selection label after keyboard navigation
		updateSelectionText();
	}

	private function updateHighlights():Void
	{
		if (Globals.usingMouse)
		{
			// Mouse mode - check hover
			var mousePos = FlxG.mouse.getPosition();
			for (obj in interactiveObjects)
			{
				var isHovered = obj.bounds.containsPoint(mousePos);
				obj.normalSprite.visible = !isHovered;
				obj.hoverSprite.visible = isHovered;
			}
			mousePos.put();
		}
		else
		{
			// Keyboard mode - show selected
			for (i in 0...interactiveObjects.length)
			{
				var obj = interactiveObjects[i];
				var isSelected = (i == currentIndex);
				obj.normalSprite.visible = !isSelected;
				obj.hoverSprite.visible = isSelected;
			}
		}

		// Refresh selection text
		updateSelectionText();
	}

	private function getDisplayLabelFor(name:String):String
	{
		switch (name)
		{
			case "desk":
				return "Review Files";
			case "portal":
				return "Enter the Portal";
			case "phone":
				return "Peruse Catalog";
			case "trash":
				return "Delete Saved Data";
			default:
				return "";
		}
	}

	private function updateSelectionText():Void
	{
		if (selectionText == null)
			return;
		var label = "";
		if (Globals.usingMouse)
		{
			// find hovered
			var mousePos = FlxG.mouse.getPosition();
			for (i in 0...interactiveObjects.length)
			{
				var obj = interactiveObjects[i];
				if (obj.bounds.containsPoint(mousePos))
				{
					label = getDisplayLabelFor(obj.name);
					break;
				}
			}
			mousePos.put();
		}
		else
		{
			label = getDisplayLabelFor(interactiveObjects[currentIndex].name);
		}
		selectionText.text = label;
		selectionText.x = Std.int((FlxG.width - selectionText.width) / 2);
	}

	private function onPortalClick():Void
	{
		trace("Portal clicked - transition to PlayState");
		isTransitioning = true;

		// Track portal entry with current money
		axollib.AxolAPI.sendEvent("PORTAL_ENTER", Globals.playerMoney);

		// Fade out office music
		util.SoundHelper.fadeOutMusic("office", 0.66);

		// Play portal sound
		util.SoundHelper.playSound("portal");

		// Start fade immediately but add delay before state switch to let sound finish
		blackOut.fade(() ->
		{
			// Wait an extra second after fade completes for sound to finish
			haxe.Timer.delay(() ->
			{
				FlxG.switchState(() -> new PlayState());
			}, 1000);
		}, true, 1.5, FlxColor.BLACK); // Slower fade (1.5s instead of 1s)
	}

	private function onDeskClick():Void
	{
		trace("Desk clicked - view saved files (TODO)");
		// Track desk/catalog interaction
		axollib.AxolAPI.sendEvent("DESK_CLICKED");
		// TODO: Create FilesState to view saved creatures
		// For now, just trace
	}

	private function onPhoneClick():Void
	{
		trace("Phone clicked - open shop (TODO)");
		// Track phone interaction
		axollib.AxolAPI.sendEvent("PHONE_CLICKED");
		// TODO: Create ShopState
		// For now, just trace
	}

	private function onTrashClick():Void
	{
		trace("Trash clicked - show confirmation dialog");
		// Track trash can interaction
		axollib.AxolAPI.sendEvent("TRASH_CLICKED");
		showConfirmationDialog();
	}

	private function showConfirmationDialog():Void
	{
		showingConfirmDialog = true;
		ready = false;

		// Create dialog box (centered)
		var dialogWidth:Float = 200;
		var dialogHeight:Float = 80;
		var dialogX:Float = (FlxG.width - dialogWidth) / 2;
		var dialogY:Float = (FlxG.height - dialogHeight) / 2;

		confirmDialog = new NineSliceSprite(dialogX, dialogY, dialogWidth, dialogHeight);
		add(confirmDialog);

		// Add confirmation message
		confirmText = new GameText(0, 0, "Are you sure you want to\nclear all saved data?");
		add(confirmText);
		confirmText.x = dialogX + (dialogWidth - confirmText.width) / 2;
		confirmText.y = dialogY + 10;

		// Add YES button
		var yesLabel = new GameText(0, 0, "YES");
		yesLabel.updateHitbox(); // Force graphic creation

		yesButton = new NineSliceButton<GameText>(dialogX + 20, dialogY + dialogHeight - 26, 40, 16, onYesClick);
		yesButton.label = yesLabel;
		yesButton.positionLabel();
		add(yesButton);

		// Add NO button
		var noLabel = new GameText(0, 0, "NO");
		noLabel.updateHitbox(); // Force graphic creation

		noButton = new NineSliceButton<GameText>(dialogX + dialogWidth - 60, dialogY + dialogHeight - 26, 40, 16, onNoClick);
		noButton.label = noLabel;
		noButton.positionLabel();
		add(noButton);
	}

	private function hideConfirmationDialog():Void
	{
		showingConfirmDialog = false;
		ready = true;

		if (confirmDialog != null)
		{
			remove(confirmDialog);
			confirmDialog.destroy();
			confirmDialog = null;
		}
		if (confirmText != null)
		{
			remove(confirmText);
			confirmText.destroy();
			confirmText = null;
		}
		if (yesButton != null)
		{
			remove(yesButton);
			yesButton.destroy();
			yesButton = null;
		}
		if (noButton != null)
		{
			remove(noButton);
			noButton.destroy();
			noButton = null;
		}
	}

	private function onYesClick():Void
	{
		trace("YES clicked - clearing save data");
		// Track save data clear with how many creatures and how much money was lost
		axollib.AxolAPI.sendEvent("DATA_CLEARED_CREATURES", Globals.savedCreatures.length);
		axollib.AxolAPI.sendEvent("DATA_CLEARED_MONEY", Globals.playerMoney);
		hideConfirmationDialog();
		clearSaveData();
	}

	private function onNoClick():Void
	{
		trace("NO clicked - canceling");
		hideConfirmationDialog();
	}

	private function clearSaveData():Void
	{
		Globals.clearAllData();
		moneyText.text = "$" + Globals.playerMoney;
	}
}

typedef InteractiveObject =
{
	var name:String;
	var normalSprite:FlxSprite;
	var hoverSprite:FlxSprite;
	var bounds:flixel.math.FlxRect;
	var callback:Void->Void;
}
