package ui;

import flixel.text.FlxBitmapFont;
import flixel.text.FlxBitmapText;

class GameText extends FlxBitmapText
{
	public static var FONT:FlxBitmapFont;

	public function new(X:Float, Y:Float, ?Text:String = "")
	{
		if (FONT == null)
		{
			FONT = FlxBitmapFont.fromAngelCode("assets/images/font.png", "assets/images/font.xml");
		}
		super(X, Y, Text, FONT);
	}
}
