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
	private var prevBtn:NineSliceButton<GameText>;
	private var nextBtn:NineSliceButton<GameText>;
	private var shareBtn:NineSliceButton<GameText>;

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

		var shareLabel = new GameText(0, 0, "Share");
		shareLabel.updateHitbox();

		shareBtn = new NineSliceButton<GameText>(10, FlxG.height - 26, 40, 16, onShareClick);
		shareBtn.label = shareLabel;
		shareBtn.positionLabel();
		shareBtn.visible = (creatures.length > 0);
		add(shareBtn);

		var closeLabel = new GameText(0, 0, "Close");
		closeLabel.updateHitbox();

		closeBtn = new NineSliceButton<GameText>(FlxG.width - 50, FlxG.height - 26, 40, 16, returnToOffice);
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

		var leftArrow = new GameText(0, 0, "<");
		prevBtn = new NineSliceButton<GameText>(10, arrowY, 24, 24, navigatePrev);
		prevBtn.label = leftArrow;
		prevBtn.positionLabel();
		add(prevBtn);

		var rightArrow = new GameText(0, 0, ">");
		nextBtn = new NineSliceButton<GameText>(FlxG.width - 34, arrowY, 24, 24, navigateNext);
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

		blackOut.fade(null, false, 1.0, FlxColor.BLACK);

		util.SoundHelper.playMusic("office");
	}

	private function returnToOffice():Void
	{
		axollib.AxolAPI.sendEvent("ARCHIVE_CLOSED");
		blackOut.fade(() -> FlxG.switchState(() -> new OfficeState()), true, 1.0, FlxColor.BLACK);
	}

	private function onShareClick():Void
	{
		hideUIForScreenshot();

		new flixel.util.FlxTimer().start(0.1, (_) ->
		{
			var timestamp = Date.now().getTime();
			var filename = "creature_" + timestamp + ".png";

			#if html5
			try
			{
				var canvas:js.html.CanvasElement = cast js.Browser.document.querySelector("canvas");
				if (canvas != null)
				{
					var dataURL = canvas.toDataURL("image/png");
					var link = js.Browser.document.createAnchorElement();
					link.download = filename;
					link.href = dataURL;
					link.style.display = "none";
					js.Browser.document.body.appendChild(link);
					link.click();
					js.Browser.document.body.removeChild(link);
					trace("Screenshot download triggered: " + filename);
				}
			}
			catch (e:Dynamic)
			{
				trace("Screenshot failed: " + e);
			}
			#elseif (sys || nodejs)
			var success = FlxG.stage.window.application.window.readPixels().image.encode(openfl.display.PNGEncoderOptions.DEFAULT).saveToFile(filename);
			if (success)
			{
				trace("Screenshot saved: " + filename);
			}
			#else
			trace("Screenshot not supported on this platform");
			#end

			showUIAfterScreenshot();
		});
	}

	private function hideUIForScreenshot():Void
	{
		if (prevBtn != null)
			prevBtn.visible = false;
		if (nextBtn != null)
			nextBtn.visible = false;
		if (closeBtn != null)
			closeBtn.visible = false;
		if (shareBtn != null)
			shareBtn.visible = false;
		if (highlightSprite != null)
			highlightSprite.visible = false;
		if (photoCounterText != null)
			photoCounterText.visible = false;
		if (dateText != null)
			dateText.visible = false;
		if (blackOut != null)
			blackOut.visible = false;
	}

	private function showUIAfterScreenshot():Void
	{
		if (prevBtn != null && selectedIndex > 0)
			prevBtn.visible = true;
		if (nextBtn != null && selectedIndex < creatures.length - 1)
			nextBtn.visible = true;
		if (closeBtn != null)
			closeBtn.visible = true;
		if (shareBtn != null)
			shareBtn.visible = true;
		if (highlightSprite != null)
			highlightSprite.visible = !Globals.usingMouse;
		if (photoCounterText != null)
			photoCounterText.visible = true;
		if (dateText != null)
			dateText.visible = true;
		if (blackOut != null)
			blackOut.visible = true;
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

		var pn:Float = creature.power;
		if (pn < 0)
			pn = 0;
		if (pn > 1)
			pn = 1;
		var powerStarsCount:Int = Std.int(Math.floor(pn * 4.0)) + 1;

		if (powerLabel == null)
		{
			powerLabel = new GameText(baseRightX, 128, "Power:");
			add(powerLabel);

			for (i in 0...5)
			{
				var star = new FlxSprite(baseRightX + powerLabel.width + 4 + (i * 10), 130, "assets/ui/star_pip.png");
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
			rewardLabel = new GameText(leftLabelX, 140, "Reward:");
			add(rewardLabel);
		}

		var calculatedReward:Int = calculateReward(creature);
		if (rewardAmount == null)
		{
			rewardAmount = new GameText(0, 140, "$" + calculatedReward);
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
			fameLabel = new GameText(leftLabelX, 152, "Fame:");
			add(fameLabel);
		}

		var calculatedFame:Int = creature.power;
		if (fameAmount == null)
		{
			fameAmount = new GameText(0, 152, "+" + calculatedFame);
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

		var baseReward:Int = (speedStarsCount + aggrStarsCount + powerStarsCount) * 5;
		return baseReward * Globals.fameLevel;
	}

	private function setupUINavigation():Void
	{
		uiObjects = [];
		if (shareBtn != null)
			uiObjects.push(shareBtn);
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
		if (FlxG.mouse.justPressed)
		{
			var mousePos = FlxG.mouse.getWorldPosition();

			if (shareBtn != null && shareBtn.overlapsPoint(mousePos))
			{
				onShareClick();
			}
			else if (prevBtn != null && prevBtn.visible && prevBtn.overlapsPoint(mousePos))
			{
				navigatePrev();
			}
			else if (nextBtn != null && nextBtn.visible && nextBtn.overlapsPoint(mousePos))
			{
				navigateNext();
			}
			else if (closeBtn != null && closeBtn.overlapsPoint(mousePos))
			{
				returnToOffice();
			}

			mousePos.put();
		}
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
		shareBtn = flixel.util.FlxDestroyUtil.destroy(shareBtn);
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

		uiObjects = null;
		creatures = null;

		super.destroy();
	}
}
