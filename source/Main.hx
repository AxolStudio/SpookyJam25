package;

import axollib.AxolAPI;
import axollib.SpookyAxolversaryState;
import flixel.FlxGame;
import openfl.display.Sprite;

class Main extends Sprite
{
	public function new()
	{
		super();
		AxolAPI.firstState = TitleState;
		AxolAPI.init = Globals.init;
		addChild(new FlxGame(320, 240, SpookyAxolversaryState, 60, 60, true, false));
	}
}
