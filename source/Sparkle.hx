package;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.util.FlxColor;

class Sparkle extends FlxSprite
{
	private var timer:Float = 0;
	private var duration:Float = 1.0;
	private var delay:Float = 0;
	private var direction:Int = 1;
	private var cameraWidth:Float;
	private var cameraHeight:Float;
	private var repositionTimer:Float = 0;
	private var repositionDelay:Float = 5.0;
	private var maxAlpha:Float = 0.66;

	public function new(camWidth:Float, camHeight:Float)
	{
		super();
		cameraWidth = camWidth;
		cameraHeight = camHeight;
		var color:FlxColor = FlxG.random.bool() ? 0xFF999999 : 0xFF666666;
		makeGraphic(1, 1, color);
		resetSparkle(FlxG.random.float(0, camWidth), FlxG.random.float(0, camHeight));
	}

	public function resetSparkle(?newX:Float, ?newY:Float):Void
	{
		if (newX != null && newY != null)
		{
			x = newX;
			y = newY;
		}
		else
		{
			x = FlxG.random.float(0, cameraWidth);
			y = FlxG.random.float(0, cameraHeight);
		}
		delay = FlxG.random.float(0, 3.5);
		duration = FlxG.random.float(1.5, 3.5);
		timer = -delay;
		alpha = 0;
		direction = 1;
		repositionTimer = FlxG.random.float(5, 10);
		maxAlpha = FlxG.random.float() < 0.2 ? 1.0 : 0.66;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (timer < 0)
		{
			timer += elapsed;
			return;
		}
		timer += elapsed;
		var progress = timer / duration;
		if (progress >= 1.0)
		{
			direction *= -1;
			timer = 0;
		}
		var t = timer / duration;
		alpha = Math.sin(t * Math.PI) * maxAlpha;
		repositionTimer -= elapsed;
		if (repositionTimer <= 0)
		{
			var cam = FlxG.cameras.list[0];
			if (cam != null)
			{
				x = cam.scroll.x + FlxG.random.float(0, cameraWidth);
				y = cam.scroll.y + FlxG.random.float(0, cameraHeight);
				repositionTimer = FlxG.random.float(5, 10);
			}
		}
	}
}
