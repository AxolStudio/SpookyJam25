package ui;

import flixel.text.FlxBitmapFont;
import flixel.text.FlxBitmapText;

class GameText extends FlxBitmapText
{
	public static var SMALL_FONT:FlxBitmapFont;

	public function new(X:Float, Y:Float, ?Text:String = "", ?Font:FlxBitmapFont)
	{

		if (SMALL_FONT == null)
		{
			SMALL_FONT = FlxBitmapFont.fromAngelCode("assets/images/small-font.png", "assets/images/small-font.xml");
		}
		super(X, Y, Text, Font != null ? Font : SMALL_FONT);
	}
}
