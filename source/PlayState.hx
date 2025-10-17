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
		// GameMap now produces both floor and walls layers
		tilemap = new GameMap();
		tilemap.generate();
		add(tilemap);

		FlxG.camera.zoom = 1.0;
	}

	override public function update(elapsed:Float):Void
	{
		// camera controls: WASD or Arrow keys to pan, + / - to zoom
		var panSpeed:Float = 200.0;
		if (FlxG.keys.pressed.A || FlxG.keys.pressed.LEFT)
			FlxG.camera.scroll.x -= panSpeed * elapsed;
		if (FlxG.keys.pressed.D || FlxG.keys.pressed.RIGHT)
			FlxG.camera.scroll.x += panSpeed * elapsed;
		if (FlxG.keys.pressed.W || FlxG.keys.pressed.UP)
			FlxG.camera.scroll.y -= panSpeed * elapsed;
		if (FlxG.keys.pressed.S || FlxG.keys.pressed.DOWN)
			FlxG.camera.scroll.y += panSpeed * elapsed;

		// zoom controls
		if (FlxG.keys.justPressed.PLUS)
			FlxG.camera.zoom += 0.1;
		if (FlxG.keys.justPressed.MINUS)
			FlxG.camera.zoom = Math.max(0.25, FlxG.camera.zoom - 0.1);

		super.update(elapsed);
	}
}
