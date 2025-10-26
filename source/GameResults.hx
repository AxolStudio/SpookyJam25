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

	public function new(items:Array<CapturedInfo>)
	{
		super();
		this.items = items != null ? items : [];
	}

	override public function create():Void
	{
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

		// TODO: Submit button bottom-right
		// I don't have an image for any buttons at the moment

		// TODO: add visuals/text to the button; we'll keep it simple

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
		nameText = new GameText(baseRightX, 56, "<Click to rename>");
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
		// input: click on nameText to open keyboard
		if (!keyboardActive && nameText != null && FlxG.mouse.justPressed)
		{
			var p = FlxG.mouse.getWorldPosition();
			if (nameText.overlapsPoint(p))
			{
				openKeyboardFor(selectedIndex);
			}
		}
		// submit button
		if (FlxG.mouse.justPressed && submitBtn != null)
		{
			var p2 = FlxG.mouse.getWorldPosition();
			if (submitBtn.overlapsPoint(p2))
			{
				// TODO: submit logic
				FlxG.switchState(() -> new PlayState());
			}
		}
	}

	private function openKeyboardFor(idx:Int):Void
	{
		// TODO: implement keyboard opening
	}
}
