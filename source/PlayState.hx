package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.tile.FlxBaseTilemap.FlxTilemapAutoTiling;
import flixel.tile.FlxTilemap;

class PlayState extends FlxState
{
	public var tilemap:GameMap;

	override public function create():Void
	{
		super.create();
		tilemap = new GameMap();
		tilemap.generate();
		add(tilemap);

		FlxG.camera.setScrollBoundsRect(0, 0, Std.int(tilemap.width), Std.int(tilemap.height), true);
	}

	override public function update(elapsed:Float):Void
	{


		super.update(elapsed);
	}
}
