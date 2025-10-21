package;

import flixel.util.FlxColor;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
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

	public var mainCam:FlxCamera;
	public var overCam:FlxCamera;
	public var hudCam:FlxCamera;

	public var atmosphereHue:Int;

	// ...existing imports...

	// HUD
	public var hud:Hud;

	// fog overlay
	public var fog:FlxSprite;
	public var fogShader:shaders.Fog;

	// cache last hue applied to tilemaps to detect changes
	private var _lastTileHue:Int = -1;

	override public function create():Void
	{
		Actions.init();
		Actions.switchSet(Actions.gameplayIndex);

		atmosphereHue = FlxG.random.int(0, 359);

		createCameras();

		tilemap = new GameMap();
		tilemap.generate(atmosphereHue);
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

		// set cameras for world objects BEFORE creating the fog so draw order is correct
		tilemap.cameras = player.cameras = enemies.cameras = [mainCam];
		reticle.cameras = [overCam];
		hud.cameras = [hudCam];

		// now create fog sprite so it renders above world objects on mainCam
		try
		{
			fog = new FlxSprite(0, 0);
			fog.makeGraphic(Std.int(mainCam.width), Std.int(mainCam.height), FlxColor.TRANSPARENT);
			fogShader = new shaders.Fog();
			fog.shader = fogShader;
			// set static hue once (atmosphereHue never changes after start)
			try
			{
				fogShader.hue = (cast atmosphereHue : Int);
				// tune saturation/value to better match tile recolor (HSV)
				try
				{
					fogShader.sat = 0.7;
				}
				catch (e:Dynamic) {}
				try
				{
					fogShader.vDark = 0.18;
				}
				catch (e:Dynamic) {}
				try
				{
					fogShader.vLight = 0.60;
				}
				catch (e:Dynamic) {}
			}
			catch (e:Dynamic) {}
			fog.cameras = [mainCam];
			fog.scrollFactor.set(0, 0);
			add(fog);
		}
		catch (e:Dynamic) {}

		mainCam.setScrollBoundsRect(0, 0, Std.int(tilemap.width), Std.int(tilemap.height), true);
		mainCam.follow(player);
		overCam.setScrollBoundsRect(0, 0, Std.int(tilemap.width), Std.int(tilemap.height), true);
		overCam.follow(player);
		super.create();
		// Hue is static and tiles were recolored above; no runtime tilemap hue shader to set.
	}

	// ...existing code...

	override public function update(elapsed:Float):Void
	{
		playerMovement(elapsed);
		if (reticle != null)
			reticle.updateFromPlayer(player, overCam);
		// HUD updates handled by Hud.update()
		super.update(elapsed);
		FlxG.collide(player, tilemap.wallsMap);
		// update fog shader uniforms
		try
		{
			if (fogShader != null && player != null)
			{
				// increment time
				fogShader.time += elapsed;
				// convert player world position to normalized screen UV (0..1)
				var cam = mainCam;
				var screenX = (player.x + player.width * 0.5) - cam.scroll.x;
				var screenY = (player.y + player.height * 0.5) - cam.scroll.y;
				// convert to 0..1 in camera viewport
				var px = screenX / cam.width;
				var py = screenY / cam.height;
				fogShader.playerX = FlxMath.bound(px, 0.0, 1.0);
				fogShader.playerY = FlxMath.bound(py, 0.0, 1.0);
				// ensure circular hole by setting scale to compensate for aspect
				var camMin:Float = Math.min(cam.width, cam.height);
				fogShader.scaleX = cam.width / camMin;
				fogShader.scaleY = cam.height / camMin;
				// radii: 1/3 camera height -> in normalized space relative to min(width,height)
				var radiusPixels = Std.int(cam.height / 3.0);
				var rInner = (radiusPixels * 0.66) / camMin; // 2/3 fully transparent
				var rOuter = (radiusPixels) / camMin;
				fogShader.innerRadius = rInner;
				fogShader.outerRadius = rOuter;
				// Build CPU visibility mask and apply to fog sprite to allow walls to occlude vision
				try
				{
					if (tilemap != null && (cast tilemap : GameMap) != null && (cast tilemap : GameMap).wallGrid != null)
					{
						// lazy create mask helper on fog shader object for lifetime
						var existingMask = Reflect.getProperty(fog, "__visibilityMask");
						if (existingMask == null)
							Reflect.setProperty(fog, "__visibilityMask",
								new VisibilityMask((cast tilemap : GameMap).wallGrid, Constants.TILE_SIZE, 1.0, false));
						var mask:VisibilityMask = Reflect.getProperty(fog, "__visibilityMask");
						var worldPlayerX = player.x + player.width * 0.5;
						var worldPlayerY = player.y + player.height * 0.5;
						var bmp = mask.buildMask(cam, worldPlayerX, worldPlayerY);
						// assign mask pixels to fog sprite (scaled back to full resolution if needed)
						// If mask is scaled, stretch to camera size by drawing into a full-res BitmapData
						if (bmp.width != Std.int(cam.width) || bmp.height != Std.int(cam.height))
						{
							var full:openfl.display.BitmapData = new openfl.display.BitmapData(Std.int(cam.width), Std.int(cam.height), true, 0x00000000);
							// draw scaled mask without smoothing (nearest-neighbor) to avoid
							// bilinear filtering leaking opaque pixels into transparent areas
							full.draw(bmp, new openfl.geom.Matrix(1 / mask.maskScale, 0, 0, 1 / mask.maskScale), null, null, null, false);
							try
							{
								fog.pixels = full;
							}
							catch (e:Dynamic) {}
						}
						else
						{
							try
							{
								fog.pixels = bmp;
							}
							catch (e:Dynamic) {}
						}
						try
						{
							fog.dirty = true;
						}
						catch (e:Dynamic) {}
					}
				}
				catch (e:Dynamic) {}
				// hue is static; tilemap hue shaders were set at generate()/create() time
			}
		}
		catch (e:Dynamic) {}
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
		// increase enemy density: fewer tiles per enemy and higher caps
		var tilesPerEnemy:Int = 6; // was 14
		var maxPerRoom:Int = 12; // was 7
		var globalMax:Int = 240; // increased from 120
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

			// apply a screen-based cap so we don't overcrowd the visible area
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
				var tlen:Int = room.tiles.length;
				if (tlen <= 0)
					continue;
				var ti:Int = Std.int(FlxG.random.float() * tlen);
				if (ti < 0)
					ti = 0;
				if (ti >= tlen)
					ti = tlen - 1;
				var t:Dynamic = room.tiles[ti];
				if (t == null)
					continue;
				var tx:Int = Std.int(t.x);
				var ty:Int = Std.int(t.y);
				if (tx == tilemap.portalTileX && ty == tilemap.portalTileY)
					continue;

				var ok:Bool = true;
				for (existing in enemies.members)
				{
					if (existing == null)
						continue;
					var ex:Int = Std.int((existing.x + existing.width * 0.5) / TILE_SIZE);
					var ey:Int = Std.int((existing.y + existing.height * 0.5) / TILE_SIZE);
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
	private function createCameras():Void
	{
		mainCam = new FlxCamera(0, 18, FlxG.width, FlxG.height - 18);
		overCam = new FlxCamera(0, 18, FlxG.width, FlxG.height - 18);
		hudCam = new FlxCamera(0, 0, FlxG.width, 18);
		FlxG.cameras.add(mainCam);
		FlxG.cameras.add(overCam);
		FlxG.cameras.add(hudCam);
		FlxG.camera = mainCam;
		hudCam.bgColor = FlxColor.TRANSPARENT;
		overCam.bgColor = FlxColor.TRANSPARENT;
		mainCam.pixelPerfectRender = true;
		hudCam.pixelPerfectRender = true;
		overCam.pixelPerfectRender = true;
	}
}
