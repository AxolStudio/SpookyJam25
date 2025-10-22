package;

import Types.TileCoord;
import Types.Vec2;
import Types.Rect;

import openfl.geom.Point;
import openfl.filters.ColorMatrixFilter;
import flixel.FlxG;
import flixel.system.FlxAssets;
import openfl.display.BitmapData;
// no explicit Reflect import needed
import flixel.addons.tile.FlxCaveGenerator;
import flixel.group.FlxGroup;
import flixel.tile.FlxBaseTilemap.FlxTilemapAutoTiling;
import flixel.tile.FlxTilemap;

// TreeNode uses shared typedefs from Types.hx (TileCoord, Vec2, Rect)
// Local typedef for BSP node structure (recursive)
typedef TreeNode =
{
	x:Int,
	y:Int,
	w:Int,
	h:Int,
	left:TreeNode,
	right:TreeNode,
	roomCenter:TileCoord,
	roomRect:Rect
};

class GameMap extends FlxGroup
{
	public var walkableTiles:Array<Int> = [];

	public var floorMap:FlxTilemap;
	public var wallsMap:FlxTilemap;
	// parsed wall grid (0 = floor, 1 = wall) for CPU-side visibility tests
	public var wallGrid:Array<Array<Int>>;

	// generated room information after map creation
	public var roomsInfo:Array<RoomInfo>;

	// store generated CSVs so we can reload tilemaps with recolored bitmaps at runtime
	private var _floorCsv:String;
	private var _wallsCsv:String;

	// portal info
	public var portalRoomIndex:Int = -1;
	public var portalTileX:Int = -1;
	public var portalTileY:Int = -1;
	public var portalPixelX:Float = -1;
	public var portalPixelY:Float = -1;

	public var width(get, never):Int;
	public var height(get, never):Int;

	private function get_width():Int
	{
		return wallsMap != null ? Std.int(wallsMap.width) : 0;
	}

	// Build a debug bitmap where 1px == 1 tile. Colors: black=wall, white=floor, red=enemies, green=player spawn.
	// Caller should supply player coords (tile) and list of enemy tile coords.
	public function buildDebugBitmap(playerTileX:Int, playerTileY:Int, enemyTiles:Array<TileCoord>):openfl.display.BitmapData
	{
		if (wallGrid == null || wallGrid.length == 0)
			throw 'wallGrid not generated';
		var h = wallGrid.length;
		var w = wallGrid[0].length;
		var bmp:openfl.display.BitmapData = new openfl.display.BitmapData(w, h, true, 0x00000000);
		// draw base: walls=black, floor=white
		for (y in 0...h)
		{
			for (x in 0...w)
			{
				var v:Int = wallGrid[y][x];
				if (v == 1)
					bmp.setPixel32(x, y, 0xFF000000); // black
				else
					bmp.setPixel32(x, y, 0xFFFFFFFF); // white
			}
		}

		// draw enemies (red)
		for (e in enemyTiles)
		{
			if (e == null)
				continue;
			var ex:Int = Std.int(e.x);
			var ey:Int = Std.int(e.y);
			if (ex >= 0 && ex < w && ey >= 0 && ey < h)
				bmp.setPixel32(ex, ey, 0xFFFF0000);
		}

		// draw player spawn (green)
		if (playerTileX >= 0 && playerTileX < w && playerTileY >= 0 && playerTileY < h)
			bmp.setPixel32(playerTileX, playerTileY, 0xFF00FF00);

		return bmp;
	}

	private function get_height():Int
	{
		return wallsMap != null ? Std.int(wallsMap.height) : 0;
	}

	public function new()
	{
		super();
	}

	// Helper: check if a candidate spawn tile is blocked by portal buffer or nearby enemies
	private function isSpawnBlocked(enemies:flixel.group.FlxGroup.FlxTypedGroup<Enemy>, tx:Int, ty:Int, avoidRadius:Int, minSpacing:Int, TILE_SIZE:Int):Bool
	{
		// avoid portal buffer
		if (Math.abs(tx - this.portalTileX) <= avoidRadius && Math.abs(ty - this.portalTileY) <= avoidRadius)
			return true;
		// ensure spacing from existing enemies
		for (existing in enemies.members)
		{
			if (existing == null)
				continue;
			var ex:Int = Std.int((existing.x + existing.width * 0.5) / TILE_SIZE);
			var ey:Int = Std.int((existing.y + existing.height * 0.5) / TILE_SIZE);
			if (Math.abs(ex - tx) <= minSpacing && Math.abs(ey - ty) <= minSpacing)
				return true;
		}
		return false;
	}

	// Spawn enemies into the provided group. This was previously in PlayState; moved
	// here so the map can control spawn distribution and room/corridor coverage.
	public function spawnEnemies(enemies:flixel.group.FlxGroup.FlxTypedGroup<Enemy>, atmosphereHue:Int):Void
	{
		if (this.roomsInfo == null)
			return;
		var TILE_SIZE:Int = Constants.TILE_SIZE;
		var tilesPerEnemy:Int = 5;
		var maxPerRoom:Int = 15;
		var globalMax:Int = 300;
		var totalSpawned:Int = 0;

		var screenTilesW:Int = Std.int(FlxG.width / TILE_SIZE);
		var screenTilesH:Int = Std.int(FlxG.height / TILE_SIZE);
		var quarterScreenTiles:Int = Std.int(Math.max(1, (screenTilesW * screenTilesH) / 4));

		var roomOrder:Array<Int> = [];
		for (ri in 0...this.roomsInfo.length)
			roomOrder.push(ri);
		var px:Int = this.portalTileX;
		var py:Int = this.portalTileY;
		roomOrder.sort(function(a:Int, b:Int):Int
		{
			var ra:RoomInfo = cast this.roomsInfo[a];
			var rb:RoomInfo = cast this.roomsInfo[b];
			if (ra == null || rb == null)
				return 0;
			var da:Float = Math.pow(ra.centroid.x - px, 2) + Math.pow(ra.centroid.y - px, 2);
			var db:Float = Math.pow(rb.centroid.x - px, 2) + Math.pow(rb.centroid.y - px, 2);
			return da < db ? -1 : (da > db ? 1 : 0);
		});

		for (i in 0...roomOrder.length)
		{
			var idx = roomOrder[i];
			if (totalSpawned >= globalMax)
				break;
			var room:RoomInfo = cast this.roomsInfo[idx];
			if (room == null || room.area <= 0)
				continue;
			if (room.isPortal)
				continue;
			// allow corridor spawns
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

			var portalDistTiles:Float = Math.pow(room.centroid.x - this.portalTileX, 2) + Math.pow(room.centroid.y - this.portalTileY, 2);
			if (portalDistTiles <= 144.0)
			{
				desired += 2;
				if (desired > maxPerRoom)
					desired = maxPerRoom;
			}

			var screenCap:Int = 0;
			if (quarterScreenTiles > 0)
				screenCap = Std.int(room.area / quarterScreenTiles);
			if (screenCap < desired)
				desired = screenCap;

			if (room.isCorridor)
			{
				var tmpDesired:Int = Std.int(room.area / (tilesPerEnemy * 2));
				if (tmpDesired < 1)
					tmpDesired = 1;
				desired = tmpDesired;
				if (desired > 3)
					desired = 3;
			}

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
				var t = room.tiles[ti];
				if (t == null)
					continue;
				var tx:Int = Std.int(t.x);
				var ty:Int = Std.int(t.y);
				var avoidRadius:Int = 6;
				var minSpacingTiles:Int = 4;
				if (isSpawnBlocked(enemies, tx, ty, avoidRadius, minSpacingTiles, TILE_SIZE))
					continue;

				var variant:String = Enemy.pickVariant();
				var eObj:Enemy = new Enemy(tx * TILE_SIZE, ty * TILE_SIZE, variant);
				enemies.add(eObj);
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

		var portalClusterSize:Int = 6;
		var portalRoom:RoomInfo = cast this.roomsInfo[this.portalRoomIndex];
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
				var t = portalRoom.tiles[ti];
				if (t == null)
					continue;
				var tx:Int = Std.int(t.x);
				var ty:Int = Std.int(t.y);
				var avoidRadiusCluster:Int = 6;
				var minSpacingTiles:Int = 4;
				if (isSpawnBlocked(enemies, tx, ty, avoidRadiusCluster, minSpacingTiles, TILE_SIZE))
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

		// Coverage pass
		try
		{
			var grid:Array<Array<Int>> = this.wallGrid;
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
						var cxTile = startX + Std.int(cellSize / 2);
						var cyTile = startY + Std.int(cellSize / 2);
						if (Math.abs(cxTile - this.portalTileX) <= 6 && Math.abs(cyTile - this.portalTileY) <= 6)
							continue;
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
						var placedInCell:Bool = false;
						for (yy in startY...Std.int(Math.min(startY + cellSize, gridH)))
						{
							for (xx in startX...Std.int(Math.min(startX + cellSize, gridW)))
							{
								if (grid[yy][xx] == 0)
								{
									var tooClose:Bool = false;
									if (Math.abs(xx - this.portalTileX) <= 6 && Math.abs(yy - this.portalTileY) <= 6)
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
	}

	// generate map; optional hue parameter (0..359). If hue >= 0, recolor floor/autotile bitmaps
	// before creating tilemaps so the tilesets themselves are tinted at load time.
	public function generate(hue:Int = -1):Void
	{
		var TILE_SIZE:Int = Constants.TILE_SIZE;
		var tilesWide:Int = Std.int(FlxG.width / TILE_SIZE);
		var tilesHigh:Int = Std.int(FlxG.height / TILE_SIZE);
		// increase overall map size: make map larger so rooms can be smaller and more spread out
		var totalW:Int = Std.int(Math.max(96, tilesWide * 8));
		var totalH:Int = Std.int(Math.max(96, tilesHigh * 8));

		// init matrix (1 = wall)
		var M:Array<Array<Int>> = [];
		for (y in 0...totalH)
		{
			var row:Array<Int> = [];
			for (x in 0...totalW)
				row.push(1);
			M.push(row);
		}

		// BSP: many partitions
		// increase the number of BSP leaves so we get more partitions -> more rooms
		// reduce divisor to create more leaves for denser partitioning
		var targetLeaves:Int = Std.int((totalW * totalH) / 900);
		if (targetLeaves < 20)
			targetLeaves = 24;

		var leaves:Array<TreeNode> = [];
		var root:TreeNode = {
			x: 2,
			y: 2,
			w: totalW - 4,
			h: totalH - 4,
			left: null,
			right: null,
			roomCenter: null,
			roomRect: null
		};
		leaves.push(root);

		var minLeaf:Int = 7; // allow slightly smaller leaves so more splits occur
		var attempts:Int = 0;
		while (leaves.length < targetLeaves && attempts < targetLeaves * 8)
		{
			attempts++;
			var pick = -1;
			var bestA = 0;
			for (i in 0...leaves.length)
			{
				var n = leaves[i];
				if (n.left != null || n.right != null)
					continue;
				var a = n.w * n.h;
				if (a > bestA)
				{
					bestA = a;
					pick = i;
				}
			}
			if (pick == -1)
				break;
			var node = leaves[pick];
			if (node.w < minLeaf * 2 && node.h < minLeaf * 2)
				continue;

			var splitHoriz:Bool = (node.w < node.h) ? true : (node.h < node.w ? false : (FlxG.random.float() < 0.5));
			if (splitHoriz && node.h >= minLeaf * 2)
			{
				var at = minLeaf + Std.int(FlxG.random.float() * (node.h - minLeaf * 2));
				var a = {
					x: node.x,
					y: node.y,
					w: node.w,
					h: at,
					left: null,
					right: null,
					roomCenter: null,
					roomRect: null
				};
				var b = {
					x: node.x,
					y: node.y + at,
					w: node.w,
					h: node.h - at,
					left: null,
					right: null,
					roomCenter: null,
					roomRect: null
				};
				node.left = a;
				node.right = b;
				var newL:Array<TreeNode> = [];
				for (j in 0...pick)
					newL.push(leaves[j]);
				newL.push(a);
				newL.push(b);
				for (j in pick + 1...leaves.length)
					newL.push(leaves[j]);
				leaves = newL;
			}
			else if (!splitHoriz && node.w >= minLeaf * 2)
			{
				var at2 = minLeaf + Std.int(FlxG.random.float() * (node.w - minLeaf * 2));
				var a2 = {
					x: node.x,
					y: node.y,
					w: at2,
					h: node.h,
					left: null,
					right: null,
					roomCenter: null,
					roomRect: null
				};
				var b2 = {
					x: node.x + at2,
					y: node.y,
					w: node.w - at2,
					h: node.h,
					left: null,
					right: null,
					roomCenter: null,
					roomRect: null
				};
				node.left = a2;
				node.right = b2;
				var newL2:Array<TreeNode> = [];
				for (j in 0...pick)
					newL2.push(leaves[j]);
				newL2.push(a2);
				newL2.push(b2);
				for (j in pick + 1...leaves.length)
					newL2.push(leaves[j]);
				leaves = newL2;
			}
		}

		// carve blobby rooms inside each leaf (rooms take most of the partition)
		roomsInfo = [];
		for (leaf in leaves)
		{
			if (leaf.left != null || leaf.right != null)
				continue;
			// increase margin so rooms stay away from partition edges
			var margin = 3;
			var maxRW = Math.max(3, leaf.w - margin * 2);
			var maxRH = Math.max(3, leaf.h - margin * 2);
			if (maxRW < 3 || maxRH < 3)
				continue;

			// make rooms a bit smaller fraction of partition (45% - 70%) so more rooms fit in
			// also cap room size to be at most leaf size - 1 so rooms never fully fill a leaf
			var roomFracMin:Float = 0.45;
			var roomFracRange:Float = 0.25; // up to 0.45 + 0.25 = 0.70
			var rW = Std.int(Math.max(3, Math.min(maxRW - 1, Std.int(maxRW * (roomFracMin + FlxG.random.float() * roomFracRange)))));
			var rH = Std.int(Math.max(3, Math.min(maxRH - 1, Std.int(maxRH * (roomFracMin + FlxG.random.float() * roomFracRange)))));
			// Try to pick a room position that keeps some separation from existing rooms
			var minRoomSeparation:Int = 8; // increase separation so rooms spread out more
			var attemptsPos:Int = 0;
			var rx:Int = 0;
			var ry:Int = 0;
			var maxPosAttempts:Int = 12;
			while (attemptsPos < maxPosAttempts)
			{
				attemptsPos++;
				rx = leaf.x + margin + Std.int(FlxG.random.float() * Math.max(0, leaf.w - rW - margin * 2));
				ry = leaf.y + margin + Std.int(FlxG.random.float() * Math.max(0, leaf.h - rH - margin * 2));
				var cxTry = rx + Std.int(rW / 2);
				var cyTry = ry + Std.int(rH / 2);
				var okPos:Bool = true;
				// check against already placed rooms' centroids
				for (existingRoom in roomsInfo)
				{
					if (existingRoom == null)
						continue;
					var exC:Int = Std.int(existingRoom.centroid.x);
					var eyC:Int = Std.int(existingRoom.centroid.y);
					if (Math.abs(exC - cxTry) <= minRoomSeparation && Math.abs(eyC - cyTry) <= minRoomSeparation)
					{
						okPos = false;
						break;
					}
				}
				if (okPos)
					break;
			}

			var cx = rx + Std.int(rW / 2);
			var cy = ry + Std.int(rH / 2);

			// more circles and slightly larger radii for richer blobs
			// slightly fewer circles but keep variety
			var circles = 4 + Std.int(FlxG.random.float() * 6); // 4..9
			for (c in 0...circles)
			{
				var angle = FlxG.random.float() * Math.PI * 2;
				var edgeBias = 0.35 + FlxG.random.float() * 0.55; // push toward edge moderately
				var ox = cx + Std.int((rW / 2) * Math.cos(angle) * edgeBias) + Std.int((FlxG.random.float() - 0.5) * 4);
				var oy = cy + Std.int((rH / 2) * Math.sin(angle) * edgeBias) + Std.int((FlxG.random.float() - 0.5) * 4);
				var maxRad = Math.max(2, Std.int(Math.min(rW, rH) * (0.18 + FlxG.random.float() * 0.50))); // larger circles

				var minx:Int = Std.int(Math.max(1, ox - maxRad - 1));
				var maxx:Int = Std.int(Math.min(totalW - 2, ox + maxRad + 1));
				var miny:Int = Std.int(Math.max(1, oy - maxRad - 1));
				var maxy:Int = Std.int(Math.min(totalH - 2, oy + maxRad + 1));
				for (yy in miny...maxy)
					for (xx in minx...maxx)
					{
						var dx = xx - ox;
						var dy = yy - oy;
						var d2 = dx * dx + dy * dy;
						if (d2 <= maxRad * maxRad && FlxG.random.float() < 0.92)
							M[yy][xx] = 0;
					}
			}

			// optional small noise fill
			var yy0:Int = Std.int(ry);
			var yy1:Int = Std.int(ry + rH);
			var xx0:Int = Std.int(rx);
			var xx1:Int = Std.int(rx + rW);
			for (yy in yy0...yy1)
				for (xx in xx0...xx1)
					if (xx > 0 && yy > 0 && xx < totalW - 1 && yy < totalH - 1 && FlxG.random.float() < 0.02)
						M[yy][xx] = 0;

			// central guarantee
			for (yy in cy - 1...cy + 2)
				for (xx in cx - 1...cx + 2)
					if (xx > 0 && yy > 0 && xx < totalW - 1 && yy < totalH - 1)
						M[yy][xx] = 0;

			leaf.roomCenter = {x: cx, y: cy};
			leaf.roomRect = {
				x: rx,
				y: ry,
				w: rW,
				h: rH
			};

			var tilesList:Array<TileCoord> = [];
			var by0:Int = Std.int(Math.max(0, ry - 1));
			var by1:Int = Std.int(Math.min(totalH, ry + rH + 1));
			var bx0:Int = Std.int(Math.max(0, rx - 1));
			var bx1:Int = Std.int(Math.min(totalW, rx + rW + 1));
			for (yy in by0...by1)
				for (xx in bx0...bx1)
					if (M[yy][xx] == 0)
						tilesList.push({x: xx, y: yy});

			roomsInfo.push(new RoomInfo(tilesList, tilesList.length, {x: cx, y: cy}, {
				x: rx,
				y: ry,
				w: rW,
				h: rH
			}, false));
		}

		// keep borders as walls
		for (x in 0...totalW)
		{
			M[0][x] = 1;
			M[totalH - 1][x] = 1;
		}
		for (y in 0...totalH)
		{
			M[y][0] = 1;
			M[y][totalW - 1] = 1;
		}

		// crooked corridor drawer
		function carveCrooked(x1:Int, y1:Int, x2:Int, y2:Int, width:Int, depth:Int):Void
		{
			if (depth > 8)
				return;
			var dx = x2 - x1;
			var dy = y2 - y1;
			var dist = Math.sqrt(dx * dx + dy * dy);
			if (dist < 1)
				return;
			if (dist <= 6)
			{
				var steps = Std.int(Math.max(1, dist));
				for (s in 0...steps + 1)
				{
					var t:Float = s / Math.max(1, steps);
					var fx = Std.int(x1 + dx * t);
					var fy = Std.int(y1 + dy * t);
					var r = Std.int(Math.max(1, Std.int(width / 2)));
					for (oy in -r...r + 1)
						for (ox in -r...r + 1)
						{
							var nx = fx + ox;
							var ny = fy + oy;
							if (nx <= 0 || ny <= 0 || nx >= totalW - 1 || ny >= totalH - 1)
								continue;
							if (ox * ox + oy * oy <= r * r)
								M[ny][nx] = 0;
						}
				}
				return;
			}

			var mx = (x1 + x2) / 2.0 + (FlxG.random.float() - 0.5) * dist * 0.6;
			var my = (y1 + y2) / 2.0 + (FlxG.random.float() - 0.5) * dist * 0.6;
			var mxi = Std.int(mx);
			var myi = Std.int(my);
			carveCrooked(x1, y1, mxi, myi, width, depth + 1);
			carveCrooked(mxi, myi, x2, y2, width, depth + 1);

			// increase chance of branching corridors for a more connected, curvy network
			if (FlxG.random.float() < 0.55 && depth < 7)
			{
				var bx = Std.int(mxi + (FlxG.random.float() - 0.5) * dist * 0.5);
				var by = Std.int(myi + (FlxG.random.float() - 0.5) * dist * 0.5);
				var bw = Std.int(2 + Std.int(FlxG.random.float() * 3));
				carveCrooked(mxi, myi, bx, by, bw, depth + 1);
			}
		}

		// traverse tree and connect child rooms
		function connectNode(node:TreeNode):Void
		{
			if (node == null)
				return;
			if (node.left != null && node.right != null)
			{
				// find nearest room center in left subtree and right subtree
				function findCenter(n:TreeNode):TileCoord
				{
					if (n == null)
						return null;
					if (n.roomCenter != null)
						return n.roomCenter;
					var l:TileCoord = findCenter(n.left);
					if (l != null)
						return l;
					return findCenter(n.right);
				}
				var a:TileCoord = findCenter(node.left);
				var b:TileCoord = findCenter(node.right);
				if (a != null && b != null)
				{
					var w = Std.int(3 + Std.int(FlxG.random.float() * 6));
					carveCrooked(a.x, a.y, b.x, b.y, w, 0);
				}
			}
			if (node.left != null)
				connectNode(node.left);
			if (node.right != null)
				connectNode(node.right);
		}

		connectNode(root);

		// smoothing
		for (iter in 0...2)
		{
			var buf:Array<Array<Int>> = [];
			for (y in 0...totalH)
			{
				var row:Array<Int> = [];
				for (x in 0...totalW)
				{
					var n = 0;
					for (oy in -1...2)
						for (ox in -1...2)
						{
							var nx = x + ox;
							var ny = y + oy;
							if (nx < 0 || ny < 0 || nx >= totalW || ny >= totalH)
								continue;
							if (M[ny][nx] == 0)
								n++;
						}
					if (n >= 4)
						row.push(0);
					else
						row.push(1);
				}
				buf.push(row);
			}
			M = buf;
		}

		// finalize borders
		for (x in 0...totalW)
		{
			M[0][x] = 1;
			M[totalH - 1][x] = 1;
		}
		for (y in 0...totalH)
		{
			M[y][0] = 1;
			M[y][totalW - 1] = 1;
		}

		// --- Remove orphan (disconnected) floor regions, keeping the largest connected area ---
		// Build component id grid initialized to -1
		var comp:Array<Array<Int>> = [];
		for (yy in 0...totalH)
		{
			var crow:Array<Int> = [];
			for (xx in 0...totalW)
				crow.push(-1);
			comp.push(crow);
		}

		var comps:Array<Array<TileCoord>> = [];
		var cid:Int = 0;
		for (yy in 0...totalH)
		{
			for (xx in 0...totalW)
			{
				if (M[yy][xx] != 0 || comp[yy][xx] != -1)
					continue;
				// flood-fill / BFS stack
				var stack:Array<TileCoord> = [];
				stack.push({x: xx, y: yy});
				comp[yy][xx] = cid;
				var list:Array<TileCoord> = [];
				while (stack.length > 0)
				{
					var cur = stack.pop();
					list.push(cur);
					var dxs:Array<Int> = [-1, 1, 0, 0];
					var dys:Array<Int> = [0, 0, -1, 1];
					for (k in 0...4)
					{
						var nx:Int = cur.x + dxs[k];
						var ny:Int = cur.y + dys[k];
						if (nx < 0 || ny < 0 || nx >= totalW || ny >= totalH)
							continue;
						if (M[ny][nx] == 0 && comp[ny][nx] == -1)
						{
							comp[ny][nx] = cid;
							stack.push({x: nx, y: ny});
						}
					}
				}
				comps.push(list);
				cid++;
			}
		}

		// find largest component
		var keepId:Int = -1;
		var bestSize:Int = -1;
		for (i in 0...comps.length)
		{
			if (comps[i].length > bestSize)
			{
				bestSize = comps[i].length;
				keepId = i;
			}
		}

		// Attempt to repair (connect) pruned components back to the main component
		// Strategy: for each component that would be pruned, pick a room that lies
		// inside that component (if any) and connect its centroid to a room in the
		// main component using a small crooked tunnel. This helps keep interesting
		// rooms from being destroyed while preserving pruning for tiny isolated blobs.
		if (comps.length > 1 && keepId >= 0)
		{
			// build mapping from comp id -> list of room indices that intersect it
			var compRooms:Array<Array<Int>> = [];
			for (ci in 0...comps.length)
				compRooms.push([]);
			for (ri in 0...roomsInfo.length)
			{
				var r:RoomInfo = roomsInfo[ri];
				if (r == null || r.tiles == null || r.tiles.length == 0)
					continue;
				// find any tile of the room and get its component id
				for (t in r.tiles)
				{
					var tx:Int = Std.int(t.x);
					var ty:Int = Std.int(t.y);
					if (tx >= 0 && ty >= 0 && tx < totalW && ty < totalH)
					{
						var cidVal:Int = comp[ty][tx];
						if (cidVal >= 0 && cidVal < compRooms.length)
						{
							// add if not already present
							var present:Bool = false;
							for (ei in 0...compRooms[cidVal].length)
								if (compRooms[cidVal][ei] == ri)
								{
									present = true;
									break;
								}
							if (!present)
								compRooms[cidVal].push(ri);
							break;
						}
					}
				}
			}

			// for each pruned component, try to connect to the main component
			for (ci in 0...comps.length)
			{
				if (ci == keepId)
					continue;
				// pick a source coordinate: prefer a room centroid inside this comp
				var srcX:Int = -1;
				var srcY:Int = -1;
				if (compRooms[ci].length > 0)
				{
					var rindex:Int = Std.int(FlxG.random.float() * compRooms[ci].length);
					if (rindex < 0)
						rindex = 0;
					if (rindex >= compRooms[ci].length)
						rindex = compRooms[ci].length - 1;
					var sRoom:RoomInfo = roomsInfo[compRooms[ci][rindex]];
					srcX = Std.int(Math.max(1, Math.min(totalW - 2, Math.round(sRoom.centroid.x))));
					srcY = Std.int(Math.max(1, Math.min(totalH - 2, Math.round(sRoom.centroid.y))));
				}
				else
				{
					// fallback: pick a random tile from the component
					var compTiles = comps[ci];
					if (compTiles.length > 0)
					{
						var tt:Int = Std.int(FlxG.random.float() * compTiles.length);
						if (tt < 0)
							tt = 0;
						if (tt >= compTiles.length)
							tt = compTiles.length - 1;
						srcX = compTiles[tt].x;
						srcY = compTiles[tt].y;
					}
				}
				if (srcX < 0 || srcY < 0)
					continue;

				// pick target: choose nearest room in the keepId component if possible
				var tgtX:Int = -1;
				var tgtY:Int = -1;
				if (compRooms[keepId].length > 0)
				{
					var bestR:Int = -1;
					var bestD:Float = 1e12;
					for (ri2 in 0...compRooms[keepId].length)
					{
						var cand:RoomInfo = roomsInfo[compRooms[keepId][ri2]];
						var dx = cand.centroid.x - srcX;
						var dy = cand.centroid.y - srcY;
						var d2 = dx * dx + dy * dy;
						if (d2 < bestD)
						{
							bestD = d2;
							bestR = compRooms[keepId][ri2];
						}
					}
					if (bestR >= 0)
					{
						var bestRoom:RoomInfo = roomsInfo[bestR];
						tgtX = Std.int(Math.max(1, Math.min(totalW - 2, Math.round(bestRoom.centroid.x))));
						tgtY = Std.int(Math.max(1, Math.min(totalH - 2, Math.round(bestRoom.centroid.y))));
					}
				}
				// fallback: pick any tile from main comp
				if (tgtX < 0 || tgtY < 0)
				{
					var mainTiles = comps[keepId];
					if (mainTiles.length > 0)
					{
						var mt:Int = Std.int(FlxG.random.float() * mainTiles.length);
						if (mt < 0)
							mt = 0;
						if (mt >= mainTiles.length)
							mt = mainTiles.length - 1;
						tgtX = mainTiles[mt].x;
						tgtY = mainTiles[mt].y;
					}
				}
				if (tgtX < 0 || tgtY < 0)
					continue;

				// carve a small crooked tunnel between src and tgt
				var w:Int = 2 + Std.int(FlxG.random.float() * 3); // width 2..4
				carveCrooked(srcX, srcY, tgtX, tgtY, w, 0);
			}

			// After attempting repairs, recompute components so we can fill any remaining orphans
			// Build component id grid initialized to -1 (again)
			var comp2:Array<Array<Int>> = [];
			for (yy in 0...totalH)
			{
				var crow2:Array<Int> = [];
				for (xx in 0...totalW)
					crow2.push(-1);
				comp2.push(crow2);
			}
			var comps2:Array<Array<TileCoord>> = [];
			var cid2:Int = 0;
			for (yy in 0...totalH)
			{
				for (xx in 0...totalW)
				{
					if (M[yy][xx] != 0 || comp2[yy][xx] != -1)
						continue;
					var stack2:Array<TileCoord> = [];
					stack2.push({x: xx, y: yy});
					comp2[yy][xx] = cid2;
					var list2:Array<TileCoord> = [];
					while (stack2.length > 0)
					{
						var cur2 = stack2.pop();
						list2.push(cur2);
						var dxs2:Array<Int> = [-1, 1, 0, 0];
						var dys2:Array<Int> = [0, 0, -1, 1];
						for (k2 in 0...4)
						{
							var nx2:Int = cur2.x + dxs2[k2];
							var ny2:Int = cur2.y + dys2[k2];
							if (nx2 < 0 || ny2 < 0 || nx2 >= totalW || ny2 >= totalH)
								continue;
							if (M[ny2][nx2] == 0 && comp2[ny2][nx2] == -1)
							{
								comp2[ny2][nx2] = cid2;
								stack2.push({x: nx2, y: ny2});
							}
						}
					}
					comps2.push(list2);
					cid2++;
				}
			}

			// find new largest component id
			var keepId2:Int = -1;
			var bestSize2:Int = -1;
			for (i2 in 0...comps2.length)
			{
				if (comps2[i2].length > bestSize2)
				{
					bestSize2 = comps2[i2].length;
					keepId2 = i2;
				}
			}

			// fill (turn to wall) any component that is not the main one (after repairs)
			for (i2 in 0...comps2.length)
			{
				if (i2 == keepId2)
					continue;
				for (t in comps2[i2])
					M[t.y][t.x] = 1;
			}
			// swap comp2/comps2 into comp/comps so downstream code uses the updated values
			comp = comp2;
			comps = comps2;
			keepId = keepId2;
		}

		// --- Extra connectivity: add additional loops between rooms in the main component ---
		// This reduces strict bifurcation by creating alternate paths (loops) between rooms.
		{
			var EXTRA_LOOPS:Int = 4; // try 3..6 for moderate loops
			var mainRoomIndices:Array<Int> = [];
			if (keepId >= 0)
			{
				// collect rooms that are part of the main component
				for (ri in 0...roomsInfo.length)
				{
					var r:RoomInfo = roomsInfo[ri];
					if (r == null || r.tiles == null || r.tiles.length == 0)
						continue;
					// pick a tile of the room and check its comp id
					var t0 = r.tiles[Std.int(r.tiles.length * 0.5)];
					var cx0:Int = Std.int(Math.max(0, Math.min(totalW - 1, Math.round(t0.x))));
					var cy0:Int = Std.int(Math.max(0, Math.min(totalH - 1, Math.round(t0.y))));
					if (comp[cy0][cx0] == keepId)
						mainRoomIndices.push(ri);
				}
			}
			// create some loops by connecting nearby or random pairs of main rooms
			for (l in 0...EXTRA_LOOPS)
			{
				if (mainRoomIndices.length < 2)
					break;
				// pick two rooms biased toward being not already adjacent: pick random then nearest among some sample
				var aIdx:Int = Std.int(FlxG.random.float() * mainRoomIndices.length);
				if (aIdx < 0)
					aIdx = 0;
				if (aIdx >= mainRoomIndices.length)
					aIdx = mainRoomIndices.length - 1;
				var ra:RoomInfo = roomsInfo[mainRoomIndices[aIdx]];
				// find a candidate b by sampling a subset and choosing one with mid-range distance
				var bestB:Int = -1;
				var bestScore:Float = -1;
				var sampleCount:Int = Std.int(Math.min(8, mainRoomIndices.length));
				for (s in 0...sampleCount)
				{
					var j:Int = Std.int(FlxG.random.float() * mainRoomIndices.length);
					if (j < 0)
						j = 0;
					if (j >= mainRoomIndices.length)
						j = mainRoomIndices.length - 1;
					if (j == aIdx)
						continue;
					var rb:RoomInfo = roomsInfo[mainRoomIndices[j]];
					var dx = rb.centroid.x - ra.centroid.x;
					var dy = rb.centroid.y - ra.centroid.y;
					var d2 = dx * dx + dy * dy;
					// prefer not-too-close and not-too-far (mid-range): score = d2 / (1 + abs(d2 - median))
					var score:Float = d2; // simple prefer larger separation for interesting loops
					if (score > bestScore)
					{
						bestScore = score;
						bestB = mainRoomIndices[j];
					}
				}
				if (bestB < 0)
					continue;
				var rb2:RoomInfo = roomsInfo[bestB];
				var sx:Int = Std.int(Math.max(1, Math.min(totalW - 2, Math.round(ra.centroid.x))));
				var sy:Int = Std.int(Math.max(1, Math.min(totalH - 2, Math.round(ra.centroid.y))));
				var tx:Int = Std.int(Math.max(1, Math.min(totalW - 2, Math.round(rb2.centroid.x))));
				var ty:Int = Std.int(Math.max(1, Math.min(totalH - 2, Math.round(rb2.centroid.y))));
				// carve a crooked tunnel; occasionally carve two parallel tunnels for redundancy
				var width1:Int = 2 + Std.int(FlxG.random.float() * 3);
				carveCrooked(sx, sy, tx, ty, width1, 0);
				if (FlxG.random.float() < 0.25)
				{
					var width2:Int = 1 + Std.int(FlxG.random.float() * 3);
					// offset endpoints slightly for a second path
					var offAx:Int = Std.int((FlxG.random.float() - 0.5) * 6);
					var offAy:Int = Std.int((FlxG.random.float() - 0.5) * 6);
					var offBx:Int = Std.int((FlxG.random.float() - 0.5) * 6);
					var offBy:Int = Std.int((FlxG.random.float() - 0.5) * 6);
					var ax:Int = Std.int(Math.max(1, sx + offAx));
					var ay:Int = Std.int(Math.max(1, sy + offAy));
					var bx:Int = Std.int(Math.max(1, tx + offBx));
					var by:Int = Std.int(Math.max(1, ty + offBy));
					carveCrooked(ax, ay, bx, by, width2, 0);
				}
			}
		}

		// --- Gnarly pockets: for a random subset of rooms carve small twisted clusters nearby ---
		{
			var POCKET_CHANCE:Float = 0.08; // ~8% of rooms get a gnarly pocket
			for (ri in 0...roomsInfo.length)
			{
				if (FlxG.random.float() > POCKET_CHANCE)
					continue;
				var r:RoomInfo = roomsInfo[ri];
				if (r == null || r.tiles == null || r.tiles.length == 0)
					continue;
				var cx:Int = Std.int(Math.round(r.centroid.x));
				var cy:Int = Std.int(Math.round(r.centroid.y));
				// carve a small cluster of overlapping circles around the room centroid
				var pocketCircles:Int = 3 + Std.int(FlxG.random.float() * 4); // 3..6
				for (pc in 0...pocketCircles)
				{
					var angle = FlxG.random.float() * Math.PI * 2;
					var dist = 2 + Std.int(FlxG.random.float() * 6); // distance from centroid
					var ox = cx + Std.int(Math.cos(angle) * dist) + Std.int((FlxG.random.float() - 0.5) * 3);
					var oy = cy + Std.int(Math.sin(angle) * dist) + Std.int((FlxG.random.float() - 0.5) * 3);
					var rad = 2 + Std.int(FlxG.random.float() * 4); // 2..6 small radii
					var minx:Int = Std.int(Math.max(1, ox - rad - 1));
					var maxx:Int = Std.int(Math.min(totalW - 2, ox + rad + 1));
					var miny:Int = Std.int(Math.max(1, oy - rad - 1));
					var maxy:Int = Std.int(Math.min(totalH - 2, oy + rad + 1));
					for (yy in miny...maxy)
						for (xx in minx...maxx)
						{
							var dx = xx - ox;
							var dy = yy - oy;
							if (dx * dx + dy * dy <= rad * rad && FlxG.random.float() < 0.9)
								M[yy][xx] = 0;
						}
				}
				// optionally, connect the pocket back to the room centroid with a short crooked path
				if (FlxG.random.float() < 0.9)
					carveCrooked(cx, cy, cx + Std.int((FlxG.random.float() - 0.5) * 6), cy + Std.int((FlxG.random.float() - 0.5) * 6), 2, 0);
			}
		}

		// Recompute each room's tile list based on final map (roomsInfo built earlier may be stale)
		// Filter out rooms that were destroyed by the pruning step and recompute centroids/areas
		var newRooms:Array<RoomInfo> = [];
		for (ri in 0...roomsInfo.length)
		{
			var r:RoomInfo = roomsInfo[ri];
			if (r == null)
				continue;
			var newTiles:Array<TileCoord> = [];
			for (t in r.tiles)
			{
				if (t == null)
					continue;
				var tx:Int = Std.int(t.x);
				var ty:Int = Std.int(t.y);
				if (tx >= 0 && ty >= 0 && tx < totalW && ty < totalH && M[ty][tx] == 0)
					newTiles.push({x: tx, y: ty});
			}
			if (newTiles.length == 0)
				continue;
			// recompute centroid
			var sx:Int = 0;
			var sy:Int = 0;
			for (nt in newTiles)
			{
				sx += Std.int(nt.x);
				sy += Std.int(nt.y);
			}
			var cx:Float = sx / Math.max(1, newTiles.length);
			var cy:Float = sy / Math.max(1, newTiles.length);
			newRooms.push(new RoomInfo(newTiles, newTiles.length, {x: cx, y: cy}, r.bbox, r.isCorridor));
		}
		roomsInfo = newRooms;

		// build a list of valid room indices (non-empty rooms)
		var validRooms:Array<Int> = [];
		for (i in 0...roomsInfo.length)
		{
			var rr:RoomInfo = roomsInfo[i];
			if (rr != null && rr.tiles != null && rr.tiles.length > 0)
				validRooms.push(i);
		}

		if (validRooms.length > 0)
		{
			// Compute a size cutoff around the 60th percentile to prefer small/medium rooms
			var areas:Array<Int> = [];
			for (idx in validRooms)
				areas.push(roomsInfo[idx].area);
			areas.sort(function(a:Int, b:Int):Int
			{
				return a - b;
			});
			var cutoffIndex:Int = Std.int(Math.floor(validRooms.length * 0.6));
			if (cutoffIndex < 0)
				cutoffIndex = 0;
			if (cutoffIndex >= areas.length)
				cutoffIndex = areas.length - 1;
			var cutoffArea:Int = areas[cutoffIndex];

			// Choose candidate rooms that are <= cutoffArea but not trivially small
			var candidateRooms:Array<Int> = [];
			for (idx in validRooms)
			{
				var rr2:RoomInfo = roomsInfo[idx];
				if (rr2.area <= cutoffArea && rr2.area >= 6)
					candidateRooms.push(idx);
			}

			// Fallback: if none match the heuristic, use all valid rooms
			if (candidateRooms.length == 0)
				candidateRooms = validRooms;

			// Prefer candidate rooms that sit near other small rooms (small-room clusters)
			var bestIdx:Int = -1;
			var bestScore:Float = -1.0;
			for (ci in 0...candidateRooms.length)
			{
				var idxRoom = candidateRooms[ci];
				var rroom:RoomInfo = roomsInfo[idxRoom];
				if (rroom == null)
					continue;
				// count nearby small rooms within a radius (tiles)
				var neighborCount:Int = 0;
				for (oj in 0...candidateRooms.length)
				{
					if (oj == ci)
						continue;
					var otherIdx = candidateRooms[oj];
					var oroom:RoomInfo = roomsInfo[otherIdx];
					if (oroom == null)
						continue;
					var dx = oroom.centroid.x - rroom.centroid.x;
					var dy = oroom.centroid.y - rroom.centroid.y;
					var d2 = dx * dx + dy * dy;
					if (d2 <= 144.0) // within ~12 tiles
						neighborCount++;
				}
				// score = neighborCount + small random to add variance
				var score:Float = neighborCount + FlxG.random.float() * 0.8;
				if (score > bestScore)
				{
					bestScore = score;
					bestIdx = idxRoom;
				}
			}
			if (bestIdx >= 0)
				portalRoomIndex = bestIdx;
			else
			{
				var ri:Int = Std.int(FlxG.random.float() * candidateRooms.length);
				if (ri < 0)
					ri = 0;
				if (ri >= candidateRooms.length)
					ri = candidateRooms.length - 1;
				portalRoomIndex = candidateRooms[ri];
			}
			var room:RoomInfo = roomsInfo[portalRoomIndex];
			if (room.tiles.length > 0)
			{
				// prefer tiles with 1-tile clearance (all 8 neighbors are floor)
				var clearance:Array<TileCoord> = [];
				for (t in room.tiles)
				{
					var x0:Int = Std.int(t.x);
					var y0:Int = Std.int(t.y);
					var ok:Bool = true;
					for (oy in -1...2)
						for (ox in -1...2)
						{
							var nx:Int = x0 + ox;
							var ny:Int = y0 + oy;
							if (nx < 0 || ny < 0 || nx >= totalW || ny >= totalH)
							{
								ok = false;
								break;
							}
							if (M[ny][nx] != 0)
							{
								ok = false;
								break;
							}
						}
					if (ok)
						clearance.push({x: x0, y: y0});
				}
				var pickTile:TileCoord = null;
				if (clearance.length > 0)
				{
					var ci:Int = Std.int(FlxG.random.float() * clearance.length);
					if (ci < 0)
						ci = 0;
					if (ci >= clearance.length)
						ci = clearance.length - 1;
					pickTile = clearance[ci];
				}
				else
				{
					// fallback: pick any tile in the room
					var ti:Int = Std.int(FlxG.random.float() * room.tiles.length);
					if (ti < 0)
						ti = 0;
					if (ti >= room.tiles.length)
						ti = room.tiles.length - 1;
					pickTile = room.tiles[ti];
				}
				portalTileX = Std.int(pickTile.x);
				portalTileY = Std.int(pickTile.y);
				portalPixelX = portalTileX * TILE_SIZE + TILE_SIZE / 2.0; // center of tile
				portalPixelY = portalTileY * TILE_SIZE + TILE_SIZE / 2.0;
				// mark room as portal room
				room.isPortal = true;
			}
		}

		var csv:String = FlxCaveGenerator.convertMatrixToString(M);
		// parse CSV into wallGrid for fast CPU queries (rows = totalH, cols = totalW)
		wallGrid = [];
		var csvRows = csv.split("\n");
		for (ry in 0...csvRows.length)
		{
			var parts = csvRows[ry].split(",");
			var rowArr:Array<Int> = [];
			for (pxi in 0...parts.length)
			{
				var v:Int = 1;
				try
				{
					v = Std.int(Std.parseInt(parts[pxi]));
				}
				catch (e:Dynamic)
				{
					v = 1;
				}
				// in our M generation 0=floor, 1=wall; keep same semantics
				rowArr.push(v);
			}
			wallGrid.push(rowArr);
		}
		var floorCsv:String = generateFloorCSV(totalW, totalH);
		_floorCsv = floorCsv;

		floorMap = new FlxTilemap();
		var floorTileset:BitmapData = (hue >= 0) ? getHueColoredBmp("assets/images/floor.png", hue) : FlxAssets.getBitmapData("assets/images/floor.png");
		FlxG.bitmapLog.add(floorTileset);
		floorMap.loadMapFromCSV(_floorCsv, floorTileset, TILE_SIZE, TILE_SIZE, FlxTilemapAutoTiling.OFF, 0, 0);
		this.add(floorMap);

		wallsMap = new FlxTilemap();
		_wallsCsv = csv;
		wallsMap = new FlxTilemap();
		var wallsTileset:BitmapData = (hue >= 0) ? getHueColoredBmp("assets/images/autotiles.png",
			hue) : FlxAssets.getBitmapData("assets/images/autotiles.png");
		FlxG.bitmapLog.add(wallsTileset);
		wallsMap.loadMapFromCSV(_wallsCsv, wallsTileset, TILE_SIZE, TILE_SIZE, FlxTilemapAutoTiling.FULL);
		this.add(wallsMap);
	}

	private function getHueColoredBmp(path:String, hue:Int):BitmapData
	{
		var src:BitmapData = FlxAssets.getBitmapData(path);
		if (src == null)
			throw 'Missing asset: ' + path;

		var result:BitmapData = new BitmapData(src.width, src.height, true, 0x00000000);
		// copy original pixels to result as base
		result.copyPixels(src, src.rect, new Point(0, 0));

		// Parameters chosen to match shader defaults in PlayState (tweak there if needed)
		var sat:Float = 0.7; // shader sat
		var vLight:Float = 0.60; // shader vLight
		var vDark:Float = 0.18; // shader vDark
		var hn:Float = (hue % 360) / 360.0;

		for (yy in 0...result.height)
		{
			for (xx in 0...result.width)
			{
				var px:Int = src.getPixel32(xx, yy);
				var a:Int = (px >> 24) & 0xFF;
				if (a == 0)
					continue; // preserve transparency
				var r:Int = (px >> 16) & 0xFF;
				var g:Int = (px >> 8) & 0xFF;
				var b:Int = px & 0xFF;
				// value = max(r,g,b)
				var vf:Float = Math.max(r / 255.0, Math.max(g / 255.0, b / 255.0));
				var v:Float = vDark + vf * (vLight - vDark);

				var h:Float = hn;
				var s:Float = sat;
				if (s <= 0.0)
				{
					var gray:Int = Std.int(Math.round(v * 255.0));
					var outCol:Int = (a << 24) | (gray << 16) | (gray << 8) | gray;
					result.setPixel32(xx, yy, outCol);
					continue;
				}
				var hh:Float = (h - Math.floor(h)) * 6.0;
				var i:Int = Std.int(Math.floor(hh));
				var f:Float = hh - i;
				var p:Float = v * (1.0 - s);
				var q:Float = v * (1.0 - s * f);
				var t:Float = v * (1.0 - s * (1.0 - f));
				var rf:Float = 0.0;
				var gf:Float = 0.0;
				var bf:Float = 0.0;
				if (i == 0)
				{
					rf = v;
					gf = t;
					bf = p;
				}
				else if (i == 1)
				{
					rf = q;
					gf = v;
					bf = p;
				}
				else if (i == 2)
				{
					rf = p;
					gf = v;
					bf = t;
				}
				else if (i == 3)
				{
					rf = p;
					gf = q;
					bf = v;
				}
				else if (i == 4)
				{
					rf = t;
					gf = p;
					bf = v;
				}
				else
				{
					rf = v;
					gf = p;
					bf = q;
				}
				var ri:Int = Std.int(Math.max(0, Math.min(255, Std.int(Math.round(rf * 255.0)))));
				var gi:Int = Std.int(Math.max(0, Math.min(255, Std.int(Math.round(gf * 255.0)))));
				var bi:Int = Std.int(Math.max(0, Math.min(255, Std.int(Math.round(bf * 255.0)))));
				var out:Int = (a << 24) | (ri << 16) | (gi << 8) | bi;
				result.setPixel32(xx, yy, out);
			}
		}
		return result;
	}

	// --- helper: generate a floor CSV using multi-octave value-noise (Perlin-like) ---
	private function generateFloorCSV(w:Int, h:Int):String
	{
		// simple value-noise: grid of random values sampled with bilinear interpolation

		// sample with multiple octaves (tuned for more coherence)
		var octaves = 4;
		var persistence = 0.62; // stronger low-frequency contribution
		var lacunarity = 1.7; // slower frequency increase -> bigger features
		var baseFreq:Float = 0.6; // start at a lower base frequency for larger patches

		var maxAmp:Float = 0.0;
		for (o in 0...octaves)
			maxAmp += Math.pow(persistence, o);

		// first build a float grid of values
		var vals:Array<Array<Float>> = [];
		for (j in 0...h)
		{
			var crow:Array<Float> = [];
			for (i in 0...w)
				crow.push(0.0);
			vals.push(crow);
		}

		for (j in 0...h)
		{
			for (i in 0...w)
			{
				var amplitude:Float = 1.0;
				var freq:Float = baseFreq;
				var val:Float = 0.0;
				for (o in 0...octaves)
				{
					var sx:Float = i / Math.max(1, w) * freq;
					var sy:Float = j / Math.max(1, h) * freq;
					var ix:Int = Std.int(Math.floor(sx));
					var iy:Int = Std.int(Math.floor(sy));
					var fx:Float = sx - ix;
					var fy:Float = sy - iy;
					// four corner values (value noise)
					var v00:Float = FlxG.random.float();
					var v10:Float = FlxG.random.float();
					var v01:Float = FlxG.random.float();
					var v11:Float = FlxG.random.float();
					// bilinear interpolation
					var a:Float = v00 * (1 - fx) + v10 * fx;
					var b:Float = v01 * (1 - fx) + v11 * fx;
					var s:Float = a * (1 - fy) + b * fy;
					val += s * amplitude;
					amplitude *= persistence;
					freq *= lacunarity;
				}
				vals[j][i] = val / maxAmp;
			}
		}

		// apply a couple of light smoothing passes (3x3 box blur) to increase coherence
		for (p in 0...2)
		{
			var buf:Array<Array<Float>> = [];
			for (y in 0...h)
			{
				var brow:Array<Float> = [];
				for (x in 0...w)
				{
					var sum:Float = 0.0;
					var cnt:Int = 0;
					for (oy in -1...2)
						for (ox in -1...2)
						{
							var nx:Int = x + ox;
							var ny:Int = y + oy;
							if (nx < 0 || ny < 0 || nx >= w || ny >= h)
								continue;
							sum += vals[ny][nx];
							cnt++;
						}
					brow.push(sum / Math.max(1, cnt));
				}
				buf.push(brow);
			}
			vals = buf;
		}

		// quantize to 0..3 and build CSV
		var rows:Array<String> = [];
		for (j in 0...h)
		{
			var cols:Array<String> = [];
			for (i in 0...w)
			{
				var v:Float = vals[j][i];
				var idx = Std.int(Math.floor(v * 4));
				if (idx < 0)
					idx = 0;
				if (idx > 3)
					idx = 3;
				cols.push(Std.string(idx));
			}
			rows.push(cols.join(","));
		}
		return rows.join("\n");
	}
}

class RoomInfo
{
	public var tiles:Array<TileCoord>;
	public var area:Int;
	public var centroid:Vec2;
	public var bbox:Rect;
	public var isCorridor:Bool;
	public var isPortal:Bool;

	public function new(tiles:Array<TileCoord>, area:Int, centroid:Vec2, bbox:Rect, isCorridor:Bool)
	{
		this.tiles = tiles;
		this.area = area;
		this.centroid = centroid;
		this.bbox = bbox;
		this.isCorridor = isCorridor;
		this.isPortal = false;
	}
}
