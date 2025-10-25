package;

import shaders.AlphaDither;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

class BlackOut extends FlxSprite
{
	public var dither:AlphaDither;

	private var thisColor:FlxColor;

	public function new(cam:FlxCamera)
	{
		super(0, 0);
		makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		scrollFactor.set(0, 0);
		cameras = [cam];

		dither = new AlphaDither();
		shader = dither;
		dither.globalAlpha = 1.0;
	}


	public function fade(callback:Void->Void, ?fadeIn:Bool = false, ?duration:Float = 1.0, ?NewColor:FlxColor = FlxColor.BLACK):Void
	{
		FlxTween.cancelTweensOf(dither);

		if (NewColor != null && NewColor != thisColor)
		{
			makeGraphic(FlxG.width, FlxG.height, NewColor);
			thisColor = NewColor;
		}

		revive();

		var start:Float = fadeIn ? 0.0 : 1.0;
		var target:Float = fadeIn ? 1.0 : 0.0;

		if (dither != null)
			dither.globalAlpha = start;

		FlxTween.tween(dither, {globalAlpha: target}, duration, {
			onComplete: (_) ->
			{
				if (!fadeIn)
					kill();
				if (callback != null)
					callback();
			}
		});
	}
}
