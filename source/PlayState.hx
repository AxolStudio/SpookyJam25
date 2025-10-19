package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;
import ui.Hud;

class PlayState extends FlxState
{
	public var tilemap:GameMap;
	public var player:Player;
	public var reticle:Reticle;

	// enemies group (rendered above player, below reticle)
	public var enemies:FlxTypedGroup<Enemy>;

	// HUD
	public var hud:Hud;

	override public function create():Void
	{
		Actions.init();
		Actions.switchSet(Actions.gameplayIndex);

		tilemap = new GameMap();
		tilemap.generate();
		add(tilemap);

		player = new Player(tilemap.portalTileX * Constants.TILE_SIZE, tilemap.portalTileY * Constants.TILE_SIZE);
		add(player);

		// create enemies group and spawn
		enemies = new FlxTypedGroup<Enemy>();
		add(enemies);
		spawnEnemies();

		reticle = new Reticle(player);
		add(reticle);

		// HUD group (separate class)
		hud = new Hud(player);
		add(hud);

		FlxG.camera.setScrollBoundsRect(0, 0, Std.int(tilemap.width), Std.int(tilemap.height), true);
		FlxG.camera.follow(player);
		super.create();
	}

	// ...existing code...

	override public function update(elapsed:Float):Void
	{
		playerMovement(elapsed);
		if (reticle != null)
			reticle.updateFromPlayer(player);
		// HUD updates handled by Hud.update()
		super.update(elapsed);
		FlxG.collide(player, tilemap.wallsMap);
	}

	private function playerMovement(elapsed:Float):Void
	{
		var left:Bool = Actions.left.check();
		var right:Bool = Actions.right.check();
		var up:Bool = Actions.up.check();
		var down:Bool = Actions.down.check();
		if (left && right)
			left = right = false;
		if (up && down)
			up = down = false;
		var any:Bool = left || right || up || down;

		var moveAngle:Float = 0;
		var move:FlxPoint = FlxPoint.get();

		if (Actions.leftStick.check() && (Math.abs(Actions.leftStick.x) > 0.1 || Math.abs(Actions.leftStick.y) > 0.1))
		{
			move.x = Actions.leftStick.x;
			move.y = Actions.leftStick.y;
			moveAngle = Math.atan2(move.y, move.x);
			any = true;
		}
		else if (any)
		{
			if (left)
				moveAngle = Math.PI;
			else if (right)
				moveAngle = 0;
			else if (up)
				moveAngle = -Math.PI / 2;
			else if (down)
				moveAngle = Math.PI / 2;

			if (left && up)
				moveAngle = -3 * Math.PI / 4;
			else if (right && up)
				moveAngle = -Math.PI / 4;
			else if (left && down)
				moveAngle = 3 * Math.PI / 4;
			else if (right && down)
				moveAngle = Math.PI / 4;

			move.x = Math.cos(moveAngle);
			move.y = Math.sin(moveAngle);
		}

		if (any)
		{
			var deg:Float = moveAngle * 180.0 / Math.PI;
			player.move(deg);
		}
		else
		{
			player.stop();
		}
		move.put();
		// handle attack/photo input
		if (Actions.attack.check())
		{
			if (player.tryTakePhoto())
			{
				// use FlxG.overlap to leverage HaxeFlixel collision logic (handles groups,
				// origin offsets and any custom overlap callbacks). We'll capture the first
				// enemy we find under the reticle and call capture on it.
				var hits:Array<Enemy> = [];
				FlxG.overlap(reticle, enemies, function(a:Dynamic, b:Dynamic):Void
				{
					if (b != null)
						hits.push(cast(b, Enemy));
				});
				// capture all hits found (rare case). We capture after collecting
				// to avoid mutating the group while FlxG.overlap is iterating.
				for (h in hits)
				{
					if (h != null)
						h.capture(player);
				}
			}
		}
	}
	// spawn enemies into rooms (skip portal room and corridors)
	private function spawnEnemies():Void
	{
		if (tilemap == null || tilemap.roomsInfo == null)
			return;
		var TILE_SIZE:Int = Constants.TILE_SIZE;
		var tilesPerEnemy:Int = 14; // was 18, reduced to increase density (~+20%)
		var maxPerRoom:Int = 7; // was 6
		var globalMax:Int = 36; // was 30
		var totalSpawned:Int = 0;

		// screen-based density cap: no more than 1 enemy per quarter-screen area
		var screenTilesW:Int = Std.int(FlxG.width / TILE_SIZE);
		var screenTilesH:Int = Std.int(FlxG.height / TILE_SIZE);
		var quarterScreenTiles:Int = Std.int(Math.max(1, (screenTilesW * screenTilesH) / 4));

		for (i in 0...tilemap.roomsInfo.length)
		{
			if (totalSpawned >= globalMax)
				break;
			var room:Dynamic = tilemap.roomsInfo[i];
			if (room == null || room.area <= 0)
				continue;
			if (room.isPortal)
				continue;
			if (room.isCorridor)
				continue;

			// explicit per-area mapping requested:
			// area < 5 -> 0
			// 5..14 -> 1
			// 15..29 -> 2
			// 30..44 -> 3
			// >=45 -> scale by area but still respect maxPerRoom and screen cap
			var desired:Int = 0;
			if (room.area < 5)
				desired = 0;
			else if (room.area < 15)
				desired = 1;
			else if (room.area < 30)
				desired = 2;
			else if (room.area < 45)
				desired = 3;
			else
				desired = Std.int(room.area / tilesPerEnemy);

			if (desired > maxPerRoom)
				desired = maxPerRoom;

			// Enforce screen-density cap: at most one enemy per quarter-screen area
			var screenCap:Int = 0;
			if (quarterScreenTiles > 0)
				screenCap = Std.int(room.area / quarterScreenTiles);
			if (screenCap < desired)
				desired = screenCap;

			var attempts:Int = 0;
			var placed:Int = 0;
			while (placed < desired && attempts < desired * 8 && totalSpawned < globalMax)
			{
				attempts++;
				var tlen:Int = Std.int(room.tiles.length);
				if (tlen <= 0)
					continue;
				var ti:Int = Std.int(FlxG.random.float() * tlen);
				if (ti < 0)
					ti = 0;
				if (ti >= tlen)
					ti = tlen - 1;
				var t = room.tiles[ti];
				if (t == null)
					continue;
				var tx:Int = Std.int(t.x);
				var ty:Int = Std.int(t.y);
				// avoid portal tile
				if (tx == tilemap.portalTileX && ty == tilemap.portalTileY)
					continue;
				// avoid spawning too close to existing enemies (tile distance < 2)
				var ok:Bool = true;
				for (existing in enemies.members)
				{
					if (existing == null)
						continue;
					var ex:Int = Std.int((existing.x + existing.width / 2) / TILE_SIZE);
					var ey:Int = Std.int((existing.y + existing.height / 2) / TILE_SIZE);
					if (Math.abs(ex - tx) <= 1 && Math.abs(ey - ty) <= 1)
					{
						ok = false;
						break;
					}
				}
				if (!ok)
					continue;

				var variant:String = Enemy.pickVariant();
				var e:Enemy = enemies.add(new Enemy(tx * TILE_SIZE, ty * TILE_SIZE, variant));
				placed++;
				totalSpawned++;
			}
		}
	}
}
