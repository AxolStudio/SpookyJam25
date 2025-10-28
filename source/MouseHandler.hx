package;

import flixel.FlxG;
import flixel.FlxSprite;
import openfl.display.PixelSnapping;
import openfl.events.Event;

class MouseHandler extends FlxSprite
{
	public var cursor(get, set):MouseCursor;

	private var currentCursor:MouseCursor;

	public var loaded:Bool = false;
	public var mScale:Float = 1.0;

	public function new():Void
	{
		super();

		loadGraphic("assets/ui/cursors.png", true, 32, 32, false, "cursors");
		animation.add("finger", [0], 0, false);
		animation.add("finger-down", [1], 0, false);
		pixelPerfectPosition = pixelPerfectRender = true;
		antialiasing = false;

		currentCursor = MouseCursor.FINGER;
		cursor = MouseCursor.FINGER;
	}

	public function init():Void
	{
		if (loaded)
			return;

		loadMouse();

		FlxG.stage.addEventListener(Event.RESIZE, (e) ->
		{
			loadMouse();
		});

		FlxG.stage.addEventListener(Event.FULLSCREEN, (e) ->
		{
			loadMouse();
		});
	}

	public function loadMouse():Void
	{
		if (FlxG.mouse == null)
			return;

		loaded = true;
		mScale = FlxG.stage.stageHeight / FlxG.height;

		// Set stage quality to LOW to prevent smoothing on scaled graphics
		#if flash
		FlxG.stage.quality = flash.display.StageQuality.LOW;
		#end

		FlxG.mouse.load(null, 2.0, -10, -6);
		FlxG.mouse.cursor.smoothing = false;
		FlxG.mouse.cursor.pixelSnapping = PixelSnapping.ALWAYS;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (!FlxG.mouse.visible || !loaded)
		{
			return;
		}

		if (cursor == MouseCursor.FINGER && FlxG.mouse.pressed)
		{
			cursor = MouseCursor.FINGER_DOWN;
		}
		else if (cursor == MouseCursor.FINGER_DOWN && FlxG.mouse.justReleased)
		{
			cursor = MouseCursor.FINGER;
		}
		drawFrame();
		var cursorData = framePixels.clone();
		FlxG.mouse.cursor.bitmapData = cursorData;
		// Ensure the cursor display object does not smooth or antialias the bitmap
		if (FlxG.mouse.cursor != null)
		{
			FlxG.mouse.cursor.smoothing = false;
			// pixelSnapping is a property on the DisplayObject; set it if available
			try
			{
				FlxG.mouse.cursor.pixelSnapping = PixelSnapping.ALWAYS;
			}
			catch (e:Dynamic) {}
		}
	}

	private function set_cursor(Value:MouseCursor):MouseCursor
	{
		switch (Value)
		{
			case FINGER:
				animation.play("finger");
			case FINGER_DOWN:
				animation.play("finger-down");
		}
		return currentCursor = Value;
	}

	private function get_cursor():MouseCursor
	{
		return currentCursor;
	}
}

enum abstract MouseCursor(String) from String to String
{
	var FINGER = "finger";
	var FINGER_DOWN = "finger-down";
}
