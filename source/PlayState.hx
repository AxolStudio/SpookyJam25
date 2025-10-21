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
		// generate map using global RNG (no explicit seed)
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
		// After spawning enemies, build a debug bitmap (1px = 1 tile) and add to bitmap log
		try
		{
			var TILE:Int = Constants.TILE_SIZE;
			var enemyTiles:Array<Dynamic> = [];
			for (member in enemies.members)
			{
				var ent:Enemy = cast(member, Enemy);
				if (ent == null)
					continue;
				var etx:Int = Std.int((ent.x + ent.width * 0.5) / TILE);
				var ety:Int = Std.int((ent.y + ent.height * 0.5) / TILE);
				enemyTiles.push({x: etx, y: ety});
			}
			var px:Int = tilemap.portalTileX;
			var py:Int = tilemap.portalTileY;
			var dbg:openfl.display.BitmapData = tilemap.buildDebugBitmap(px, py, enemyTiles);
			FlxG.bitmapLog.add(dbg);
		}
		catch (err:Dynamic) {}

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
		// ensure enemies also collide with walls so they don't pass through geometry
		FlxG.collide(enemies, tilemap.wallsMap);
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
						// Implement a small mask-age cache to avoid rebuilding mask every frame
						var __lastMaskBmp:openfl.display.BitmapData = Reflect.getProperty(fog, "__lastMaskBmp");
						var __maskAge:Int = Reflect.getProperty(fog, "__maskAge") == null ? 0 : Reflect.getProperty(fog, "__maskAge");
						var __maskMaxAge:Int = Reflect.getProperty(fog, "__maskMaxAge") == null ? 3 : Reflect.getProperty(fog, "__maskMaxAge");
						var __lastPlayerX:Float = Reflect.getProperty(fog, "__lastPlayerX") == null ? -1 : Reflect.getProperty(fog, "__lastPlayerX");
						var __lastPlayerY:Float = Reflect.getProperty(fog, "__lastPlayerY") == null ? -1 : Reflect.getProperty(fog, "__lastPlayerY");
						var __moveThreshold:Float = 1.0; // in pixels: small movement allowed before rebuild

						var needRebuild:Bool = true;
						if (__lastMaskBmp != null)
						{
							// if player hasn't moved much and mask age is below max, reuse
							var dx = Math.abs(__lastPlayerX - worldPlayerX);
							var dy = Math.abs(__lastPlayerY - worldPlayerY);
							if ((__maskAge < __maskMaxAge) && dx <= __moveThreshold && dy <= __moveThreshold)
								needRebuild = false;
						}

						var bmp:openfl.display.BitmapData;
						if (!needRebuild)
						{
							bmp = __lastMaskBmp;
							__maskAge++;
							Reflect.setProperty(fog, "__maskAge", __maskAge);
						}
						else
						{
							bmp = mask.buildMask(cam, worldPlayerX, worldPlayerY);
							// store cache
							Reflect.setProperty(fog, "__lastMaskBmp", bmp);
							Reflect.setProperty(fog, "__maskAge", 0);
							Reflect.setProperty(fog, "__lastPlayerX", worldPlayerX);
							Reflect.setProperty(fog, "__lastPlayerY", worldPlayerY);
						}
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
							// set mask texel size for shader dither
							try
							{
								if (fogShader != null)
								{
									fogShader.maskTexelX = 1.0 / full.width;
									fogShader.maskTexelY = 1.0 / full.height;
								}
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
						// if we assigned the bmp directly, set texel size from bmp
						try
						{
							if (fogShader != null)
							{
								fogShader.maskTexelX = 1.0 / bmp.width;
								fogShader.maskTexelY = 1.0 / bmp.height;
							}
						}
						catch (e:Dynamic) {}
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
		// increase enemy density: fewer tiles per enemy and higher caps (~25% more density)
		var tilesPerEnemy:Int = 5; // lower => more enemies per room (was 6)
		var maxPerRoom:Int = 15; // allow slightly more per room (was 12)
		var globalMax:Int = 300; // raise overall cap (was 240)
		var totalSpawned:Int = 0;

		// screen-based density cap: no more than 1 enemy per quarter-screen area
		var screenTilesW:Int = Std.int(FlxG.width / TILE_SIZE);
		var screenTilesH:Int = Std.int(FlxG.height / TILE_SIZE);
		var quarterScreenTiles:Int = Std.int(Math.max(1, (screenTilesW * screenTilesH) / 4));

		// Prefer filling rooms closer to the portal/player spawn first so player finds enemies sooner
		var roomOrder:Array<Int> = [];
		for (ri in 0...tilemap.roomsInfo.length)
			roomOrder.push(ri);
		// compute distances to portal
		var px:Int = tilemap.portalTileX;
		var py:Int = tilemap.portalTileY;
		roomOrder.sort(function(a:Int, b:Int):Int
		{
			var ra:Dynamic = tilemap.roomsInfo[a];
			var rb:Dynamic = tilemap.roomsInfo[b];
			if (ra == null || rb == null)
				return 0;
			var da:Float = Math.pow(ra.centroid.x - px, 2) + Math.pow(ra.centroid.y - py, 2);
			var db:Float = Math.pow(rb.centroid.x - px, 2) + Math.pow(rb.centroid.y - py, 2);
			return da < db ? -1 : (da > db ? 1 : 0);
		});
		for (i in 0...roomOrder.length)
		{
			var idx = roomOrder[i];
			if (totalSpawned >= globalMax)
				break;
			var room:Dynamic = tilemap.roomsInfo[idx];
			if (room == null || room.area <= 0)
				continue;
			if (room.isPortal)
				continue;
			// allow spawning in corridors too so enemies are distributed along paths
			// but give corridors a small target so they don't get overloaded

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

			// special-case corridors: ensure at least one spawn in longer corridors
			if (room.isCorridor)
			{
				// corridors have small area but we want some coverage
				var tmpDesired:Int = Std.int(room.area / (tilesPerEnemy * 2));
				if (tmpDesired < 1)
					tmpDesired = 1;
				desired = tmpDesired;
				if (desired > 3)
					desired = 3;
			}

			// Bias: if room is near the portal, increase desired density so player sees more enemies nearby
			var portalDistTiles:Float = Math.pow(room.centroid.x - tilemap.portalTileX, 2) + Math.pow(room.centroid.y - tilemap.portalTileY, 2);
			if (portalDistTiles <= 144.0) // within ~12 tiles
			{
				// small rooms near the portal get a bonus
				desired += 2;
				if (desired > maxPerRoom)
					desired = maxPerRoom;
			}

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
				// avoid spawning directly on or too close to the portal tile/player spawn
				var avoidRadius:Int = 6; // tiles (reduced buffer so player sees enemies sooner)
				if (Math.abs(tx - tilemap.portalTileX) <= avoidRadius && Math.abs(ty - tilemap.portalTileY) <= avoidRadius)
					continue;

				// ensure enemies are not spawned too close to each other (min spacing)
				var minSpacingTiles:Int = 4;
				var ok:Bool = true;
				for (existing in enemies.members)
				{
					if (existing == null)
						continue;
					var ex:Int = Std.int((existing.x + existing.width * 0.5) / TILE_SIZE);
					var ey:Int = Std.int((existing.y + existing.height * 0.5) / TILE_SIZE);
					if (Math.abs(ex - tx) <= minSpacingTiles && Math.abs(ey - ty) <= minSpacingTiles)
					{
						ok = false;
						break;
					}
				}
				if (!ok)
					continue;

				var variant:String = Enemy.pickVariant();
				var eObj:Enemy = new Enemy(tx * TILE_SIZE, ty * TILE_SIZE, variant);
				enemies.add(eObj);
				// randomize enemy behavior and tint to avoid atmosphere hue
				try
				{
					if (eObj != null)
						eObj.randomizeBehavior(atmosphereHue);
				}
				catch (eDyn:Dynamic) {}
				placed++;
				totalSpawned++;
			}
		}
		// Coverage pass: ensure roughly one enemy per 10x10 tile cell across the map
		// so there are no very large empty regions. This will also place enemies in
		// corridors if missing.
		try
		{
			var grid:Dynamic = tilemap.wallGrid;
			if (grid != null && grid.length > 0)
			{
				var gridH:Int = grid.length;
				var gridW:Int = grid[0].length;
				var cellSize:Int = 10;
				for (gy in 0...Std.int((gridH + cellSize - 1) / cellSize))
				{
					for (gx in 0...Std.int((gridW + cellSize - 1) / cellSize))
					{
						var startY = gy * cellSize;
						var startX = gx * cellSize;
						// skip if portal is in or near this cell
						var cxTile = startX + Std.int(cellSize / 2);
						var cyTile = startY + Std.int(cellSize / 2);
						if (Math.abs(cxTile - tilemap.portalTileX) <= 6 && Math.abs(cyTile - tilemap.portalTileY) <= 6)
							continue;
						// check if any enemy exists within this cell or nearby
						var hasEnemy:Bool = false;
						for (existing in enemies.members)
						{
							if (existing == null)
								continue;
							var ex:Int = Std.int((existing.x + existing.width * 0.5) / TILE_SIZE);
							var ey:Int = Std.int((existing.y + existing.height * 0.5) / TILE_SIZE);
							if (ex >= startX && ex < startX + cellSize && ey >= startY && ey < startY + cellSize)
							{
								hasEnemy = true;
								break;
							}
						}
						if (hasEnemy)
							continue;
						// find a walkable tile in this cell to spawn
						var placedInCell:Bool = false;
						for (yy in startY...Std.int(Math.min(startY + cellSize, gridH)))
						{
							for (xx in startX...Std.int(Math.min(startX + cellSize, gridW)))
							{
								if (grid[yy][xx] == 0)
								{
									// ensure spacing and avoid portal buffer
									var tooClose:Bool = false;
									if (Math.abs(xx - tilemap.portalTileX) <= 10 && Math.abs(yy - tilemap.portalTileY) <= 10)
										tooClose = true;
									for (existing in enemies.members)
									{
										if (existing == null)
											continue;
										var ex:Int = Std.int((existing.x + existing.width * 0.5) / TILE_SIZE);
										var ey:Int = Std.int((existing.y + existing.height * 0.5) / TILE_SIZE);
										if (Math.abs(ex - xx) <= 4 && Math.abs(ey - yy) <= 4)
										{
											tooClose = true;
											break;
										}
									}
									if (!tooClose && totalSpawned < globalMax)
									{
										var variant:String = Enemy.pickVariant();
										var eObj:Enemy = new Enemy(xx * TILE_SIZE, yy * TILE_SIZE, variant);
										enemies.add(eObj);
										try
										{
											if (eObj != null)
												eObj.randomizeBehavior(atmosphereHue);
										}
										catch (d:Dynamic) {}
										placedInCell = true;
										totalSpawned++;
										break;
									}
								}
							}
							if (placedInCell)
								break;
						}
					}
				}
			}
		}
		catch (e:Dynamic) {}
		// Additionally spawn a small dense cluster around the portal so the player sees immediate threats
		var portalClusterSize:Int = 6;
		var portalRoom:Dynamic = tilemap.roomsInfo[tilemap.portalRoomIndex];
		if (portalRoom != null)
		{
			var clusterPlaced = 0;
			var tries = 0;
			while (clusterPlaced < portalClusterSize && tries < portalClusterSize * 8 && totalSpawned < globalMax)
			{
				tries++;
				var ti:Int = Std.int(FlxG.random.float() * Std.int(portalRoom.tiles.length));
				if (ti < 0)
					ti = 0;
				var prLen:Int = Std.int(portalRoom.tiles.length);
				if (ti >= prLen)
					ti = prLen - 1;
				var t:Dynamic = portalRoom.tiles[ti];
				if (t == null)
					continue;
				var tx:Int = Std.int(t.x);
				var ty:Int = Std.int(t.y);
				// avoid exact portal tile and immediate surrounding area so player isn't swarmed
				var avoidRadiusCluster:Int = 6; // keep consistent with main spawn buffer
				if (Math.abs(tx - tilemap.portalTileX) <= avoidRadiusCluster && Math.abs(ty - tilemap.portalTileY) <= avoidRadiusCluster)
					continue;
				// ensure enemies are not spawned too close to each other (min spacing)
				var minSpacingTiles:Int = 4;
				var ok:Bool = true;
				for (existing in enemies.members)
				{
					if (existing == null)
						continue;
					var ex:Int = Std.int((existing.x + existing.width * 0.5) / TILE_SIZE);
					var ey:Int = Std.int((existing.y + existing.height * 0.5) / TILE_SIZE);
					if (Math.abs(ex - tx) <= minSpacingTiles && Math.abs(ey - ty) <= minSpacingTiles)
					{
						ok = false;
						break;
					}
				}
				if (!ok)
					continue;
				var variant:String = Enemy.pickVariant();
				var eObj:Enemy = new Enemy(tx * TILE_SIZE, ty * TILE_SIZE, variant);
				enemies.add(eObj);
				try
				{
					if (eObj != null)
						eObj.randomizeBehavior(atmosphereHue);
				}
				catch (d:Dynamic) {}
				clusterPlaced++;
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
