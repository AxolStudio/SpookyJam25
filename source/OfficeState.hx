package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxColor;
import ui.GameText;
import ui.NineSliceButton;

class OfficeState extends FlxState
{
	private var blackOut:BlackOut;
	private var isTransitioning:Bool = false;
	private var fromDeath:Bool = false;

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
	private var lastHoveredIndex:Int = -1;
	private var selectionText:GameText;
	private var moneyText:GameText;
	private var fameLevelSprite:FlxSprite;

	private var ready:Bool = false;

	public function new(?fromDeath:Bool = false)
	{
		super();
		this.fromDeath = fromDeath;
	}

	override public function create():Void
	{
		super.create();

		Globals.init();
		Actions.switchSet(Actions.menuIndex);

		var bg = new FlxSprite(0, 0, "assets/ui/bg.png");
		add(bg);

		var board = new FlxSprite(0, 0, "assets/ui/board.png");
		add(board);

		trash = new FlxSprite(0, 0, "assets/ui/trash.png");
		add(trash);
		trashHover = new FlxSprite(0, 0, "assets/ui/hover_trash.png");
		trashHover.visible = false;
		add(trashHover);

		desk = new FlxSprite(0, 0, "assets/ui/desk.png");
		add(desk);
		deskHover = new FlxSprite(0, 0, "assets/ui/hover_desk.png");
		deskHover.visible = false;
		add(deskHover);

		phone = new FlxSprite(0, 0, "assets/ui/phone.png");
		add(phone);
		phoneHover = new FlxSprite(0, 0, "assets/ui/hover_phone.png");
		phoneHover.visible = false;
		add(phoneHover);

		portal = new FlxSprite(0, 0, "assets/ui/office_portal.png");
		add(portal);
		portalHover = new FlxSprite(0, 0, "assets/ui/hover_portal.png");
		portalHover.visible = false;
		add(portalHover);

		moneyText = new GameText(42, 47, "$" + Globals.playerMoney);
		add(moneyText);

		fameLevelSprite = new FlxSprite(0, 62);
		fameLevelSprite.loadGraphic("assets/ui/fame_level_sm.png", true, 16, 16);
		setupFameLevelAnimation();
		fameLevelSprite.x = Std.int(moneyText.x + (moneyText.width / 2) - (fameLevelSprite.width / 2));
		add(fameLevelSprite);

		selectionText = new GameText(0, FlxG.height - 22, "");
		selectionText.x = Std.int((FlxG.width - selectionText.width) / 2);
		add(selectionText);
		setupInteractiveObjects();
		var overCam = new flixel.FlxCamera(0, 0, FlxG.width, FlxG.height);
		overCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(overCam, false);

		blackOut = new BlackOut(overCam);
		add(blackOut);

		if (fromDeath)
			blackOut.fade(() -> showDeathDialog(), false, 1.0, FlxColor.WHITE);
		else
		{
			blackOut.fade(() ->
			{
				FlxG.mouse.visible = true;
				Globals.usingMouse = true;
				ready = true;
			}, false, 1.0, FlxColor.BLACK);
		}

		util.SoundHelper.playMusic("office");
	}

	private function setupFameLevelAnimation():Void
	{
		var currentLevel = Globals.fameLevel - 1;
		var baseFrame = currentLevel * 7;

		var frames:Array<Int> = [
			baseFrame + 1,
			baseFrame + 2,
			baseFrame + 3,
			baseFrame + 4,
			baseFrame + 5,
			baseFrame + 6
		];

		for (i in 0...40)
			frames.push(baseFrame);

		fameLevelSprite.animation.add("shine", frames, 12, true);
		fameLevelSprite.animation.play("shine");
	}

	private function setupInteractiveObjects():Void
	{
		interactiveObjects.push({
			name: "phone",
			normalSprite: phone,
			hoverSprite: phoneHover,
			bounds: new flixel.math.FlxRect(151, 36, 72, 90),
			callback: onPhoneClick
		});

		interactiveObjects.push({
			name: "trash",
			normalSprite: trash,
			hoverSprite: trashHover,
			bounds: new flixel.math.FlxRect(151, 159, 46, 58),
			callback: onTrashClick
		});

		interactiveObjects.push({
			name: "portal",
			normalSprite: portal,
			hoverSprite: portalHover,
			bounds: new flixel.math.FlxRect(234, 0, 86, 240),
			callback: onPortalClick
		});

		interactiveObjects.push({
			name: "desk",
			normalSprite: desk,
			hoverSprite: deskHover,
			bounds: new flixel.math.FlxRect(0, 121, 148, 119),
			callback: onDeskClick
		});

		currentIndex = 0;
		updateHighlights();
		updateSelectionText();
	}

	private function showDeathDialog():Void
	{
		FlxG.mouse.visible = true;
		Globals.usingMouse = true;
		
		var dialogWidth = 240;
		var dialogHeight = 100;
		var dialogX = Std.int((FlxG.width - dialogWidth) / 2);
		var dialogY = Std.int((FlxG.height - dialogHeight) / 2);

		var dialog = new NineSliceSprite(dialogX, dialogY, dialogWidth, dialogHeight, "assets/ui/ui_box_16x16.png");
		add(dialog);

		var message = new GameText(0, 0, "You fell unconscious and\nwere dragged back through\nthe portal by your assistant.\nHowever you lost your photos.");
		message.x = Std.int(dialogX + (dialogWidth - message.width) / 2);
		message.y = Std.int(dialogY + 12);
		add(message);

		var okBtn:NineSliceButton<GameText> = null;
		var onOkClick = () ->
		{
			remove(dialog);
			remove(message);
			if (okBtn != null)
				remove(okBtn);
			ready = true;
		};
		okBtn = new NineSliceButton<GameText>(Std.int(dialogX + (dialogWidth - 60) / 2), Std.int(dialogY + dialogHeight - 34), 60, 24, onOkClick);
		var okLabel = new GameText(0, 0, "OK");
		okBtn.label = okLabel;
		okBtn.positionLabel();
		add(okBtn);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		Constants.Mouse.update(elapsed);

		if (isTransitioning || !ready)
			return;

		if (showingConfirmDialog)
			return;

		util.InputManager.update();

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

	private function handleMouseInput():Void
	{
		var mousePos = FlxG.mouse.getPosition();

		for (i in 0...interactiveObjects.length)
		{
			var obj = interactiveObjects[i];
			if (obj.bounds.containsPoint(mousePos))
			{
				currentIndex = i;
				if (FlxG.mouse.justPressed)
				{
					util.SoundHelper.playSound("ui_select");
					obj.callback();
				}
				break;
			}
		}

		mousePos.put();
	}

	private function handleKeyboardInput():Void
	{
		var oldIndex = currentIndex;
		
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

		if (oldIndex != currentIndex)
			util.SoundHelper.playSound("ui_hover");

		if (Actions.pressUI.triggered)
		{
			util.SoundHelper.playSound("ui_select");
			interactiveObjects[currentIndex].callback();
		}

		updateSelectionText();
	}

	private function updateHighlights():Void
	{
		if (Globals.usingMouse)
		{
			var mousePos = FlxG.mouse.getPosition();
			var hoveredIndex:Int = -1;

			for (i in 0...interactiveObjects.length)
			{
				var obj = interactiveObjects[i];
				var isHovered = obj.bounds.containsPoint(mousePos);
				obj.normalSprite.visible = !isHovered;
				obj.hoverSprite.visible = isHovered;
				if (isHovered)
				{
					hoveredIndex = i;
				}
			}
			if (hoveredIndex != lastHoveredIndex)
			{
				if (lastHoveredIndex != -1)
				{
					var lastObj = interactiveObjects[lastHoveredIndex];
					if (lastObj.name == "desk")
						util.SoundHelper.playSound("drawer_close");
				}

				if (hoveredIndex != -1)
				{
					var newObj = interactiveObjects[hoveredIndex];
					if (newObj.name == "desk")
						util.SoundHelper.playSound("drawer_open");
					else
						util.SoundHelper.playSound("ui_hover");
				}
			}
			lastHoveredIndex = hoveredIndex;
			
			mousePos.put();
		}
		else
		{
			for (i in 0...interactiveObjects.length)
			{
				var obj = interactiveObjects[i];
				var isSelected = (i == currentIndex);
				obj.normalSprite.visible = !isSelected;
				obj.hoverSprite.visible = isSelected;
			}
		}

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
		FlxG.mouse.visible = false;

		axollib.AxolAPI.sendEvent("PORTAL_ENTER", Globals.playerMoney);
		util.SoundHelper.fadeOutMusic("office", 0.66);
		util.SoundHelper.playSound("portal");

		blackOut.fade(() ->
		{
			haxe.Timer.delay(() -> FlxG.switchState(() -> new PlayState()), 1000);
		}, true, 1.5, FlxColor.BLACK);
	}

	private function onDeskClick():Void
	{
		trace("Desk clicked - opening archive");
		axollib.AxolAPI.sendEvent("DESK_CLICKED");
		blackOut.fade(() -> FlxG.switchState(() -> new ArchiveState()), true, 0.33, FlxColor.BLACK);
	}

	private function onPhoneClick():Void
	{
		trace("Phone clicked - opening catalog");
		axollib.AxolAPI.sendEvent("PHONE_CLICKED");
		util.SoundHelper.playSound("phone_pickup");
		blackOut.fade(() -> FlxG.switchState(() -> new CatalogState()), true, 0.33, FlxColor.BLACK);
	}

	private function onTrashClick():Void
	{
		trace("Trash clicked - show confirmation dialog");
		axollib.AxolAPI.sendEvent("TRASH_CLICKED");
		util.SoundHelper.playSound("trashcan_rustle");
		showConfirmationDialog();
	}

	private function showConfirmationDialog():Void
	{
		showingConfirmDialog = true;
		ready = false;

		var dialogWidth:Float = 200;
		var dialogHeight:Float = 80;
		var dialogX:Float = (FlxG.width - dialogWidth) / 2;
		var dialogY:Float = (FlxG.height - dialogHeight) / 2;

		confirmDialog = new NineSliceSprite(dialogX, dialogY, dialogWidth, dialogHeight);
		add(confirmDialog);
		confirmText = new GameText(0, 0, "Are you sure you want to\nclear all saved data?");
		add(confirmText);
		confirmText.x = dialogX + (dialogWidth - confirmText.width) / 2;
		confirmText.y = dialogY + 10;

		var yesLabel = new GameText(0, 0, "YES");
		yesLabel.updateHitbox();

		yesButton = new NineSliceButton<GameText>(dialogX + 20, dialogY + dialogHeight - 26, 40, 16, onYesClick);
		yesButton.label = yesLabel;
		yesButton.positionLabel();
		add(yesButton);

		var noLabel = new GameText(0, 0, "NO");
		noLabel.updateHitbox();

		noButton = new NineSliceButton<GameText>(dialogX + dialogWidth - 60, dialogY + dialogHeight - 26, 40, 16, onNoClick);
		noButton.isCancelButton = true;
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
		axollib.AxolAPI.sendEvent("DATA_CLEARED_CREATURES", Globals.savedCreatures.length);
		axollib.AxolAPI.sendEvent("DATA_CLEARED_MONEY", Globals.playerMoney);
		util.SoundHelper.playSound("trashcan_throw_away");
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
		setupFameLevelAnimation();
	}

	override public function destroy():Void
	{
		blackOut = flixel.util.FlxDestroyUtil.destroy(blackOut);

		desk = flixel.util.FlxDestroyUtil.destroy(desk);
		deskHover = flixel.util.FlxDestroyUtil.destroy(deskHover);
		phone = flixel.util.FlxDestroyUtil.destroy(phone);
		phoneHover = flixel.util.FlxDestroyUtil.destroy(phoneHover);
		portal = flixel.util.FlxDestroyUtil.destroy(portal);
		portalHover = flixel.util.FlxDestroyUtil.destroy(portalHover);
		trash = flixel.util.FlxDestroyUtil.destroy(trash);
		trashHover = flixel.util.FlxDestroyUtil.destroy(trashHover);

		confirmDialog = flixel.util.FlxDestroyUtil.destroy(confirmDialog);
		confirmText = flixel.util.FlxDestroyUtil.destroy(confirmText);
		yesButton = flixel.util.FlxDestroyUtil.destroy(yesButton);
		noButton = flixel.util.FlxDestroyUtil.destroy(noButton);

		if (interactiveObjects != null)
		{
			for (obj in interactiveObjects)
			{
				if (obj.bounds != null)
					obj.bounds.put();
			}
			interactiveObjects = null;
		}

		selectionText = flixel.util.FlxDestroyUtil.destroy(selectionText);
		moneyText = flixel.util.FlxDestroyUtil.destroy(moneyText);
		fameLevelSprite = flixel.util.FlxDestroyUtil.destroy(fameLevelSprite);

		super.destroy();
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
