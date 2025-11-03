package;

import flixel.util.FlxDestroyUtil;
import Types.Rect;
import Types.TileCoord;
import Types.Vec2;
import flixel.FlxG;
import flixel.addons.tile.FlxCaveGenerator;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets;
import flixel.tile.FlxBaseTilemap.FlxTilemapAutoTiling;
import flixel.tile.FlxTilemap;
import openfl.display.BitmapData;
import util.ColorHelpers;

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
	public var wallGrid:Array<Array<Int>>;

	public var roomsInfo:Array<RoomInfo>;

	private var _floorCsv:String;
	private var _wallsCsv:String;

	public var portalRoomIndex:Int = -1;
	public var portalTileX:Int = -1;
	public var portalTileY:Int = -1;
	public var portalPixelX:Float = -1;
	public var portalPixelY:Float = -1;

	public var width(get, never):Int;
	public var height(get, never):Int;

	override public function destroy():Void
	{
		floorMap = FlxDestroyUtil.destroy(floorMap);
		wallsMap = FlxDestroyUtil.destroy(wallsMap);
		super.destroy();
	}

	private function get_width():Int
	{
		return wallsMap != null ? Std.int(wallsMap.width) : 0;
	}

	public function buildDebugBitmap(playerTileX:Int, playerTileY:Int, enemyTiles:Array<TileCoord>):openfl.display.BitmapData
	{
		if (wallGrid == null || wallGrid.length == 0)
			throw 'wallGrid not generated';
		var h = wallGrid.length;
		var w = wallGrid[0].length;
		var bmp:openfl.display.BitmapData = new openfl.display.BitmapData(w, h, true, 0x00000000);

		for (y in 0...h)
		{
			for (x in 0...w)
			{
				var v:Int = wallGrid[y][x];
				if (v == 1)
					bmp.setPixel32(x, y, 0xFF000000);
				else
					bmp.setPixel32(x, y, 0xFFFFFFFF);
			}
		}

		for (e in enemyTiles)
		{
			if (e == null)
				continue;
			var ex:Int = Std.int(e.x);
			var ey:Int = Std.int(e.y);
			if (ex >= 0 && ex < w && ey >= 0 && ey < h)
				bmp.setPixel32(ex, ey, 0xFFFF0000);
		}

		if (playerTileX >= 0 && playerTileX < w && playerTileY >= 0 && playerTileY < h)
			bmp.setPixel32(playerTileX, playerTileY, 0xFF00FF00);

		return bmp;
	}

	private function get_height():Int
	{
		return wallsMap != null ? Std.int(wallsMap.height) : 0;
	}

	public function lineOfSight(x0:Float, y0:Float, x1:Float, y1:Float):Bool
	{
		var TILE_SIZE:Int = Constants.TILE_SIZE;
		if (wallGrid == null)
			throw 'wallGrid not generated';
		var tx:Int = Std.int(Math.floor(x0 / TILE_SIZE));
		var ty:Int = Std.int(Math.floor(y0 / TILE_SIZE));
		var txEnd:Int = Std.int(Math.floor(x1 / TILE_SIZE));
		var tyEnd:Int = Std.int(Math.floor(y1 / TILE_SIZE));

		var dx:Float = x1 - x0;
		var dy:Float = y1 - y0;

		if (tx == txEnd && ty == tyEnd)
		{
			var gridH0:Int = wallGrid != null ? wallGrid.length : 0;
			if (ty < 0 || ty >= gridH0)
				return false;
			var row0:Array<Int> = wallGrid[ty];
			if (row0 == null)
				return false;
			var gridW0:Int = row0.length;
			if (tx < 0 || tx >= gridW0)
				return false;
			return (row0[tx] == 0);
		}

		var stepX:Int = dx > 0 ? 1 : -1;
		var stepY:Int = dy > 0 ? 1 : -1;

		var tMaxX:Float;
		var tMaxY:Float;
		var tDeltaX:Float;
		var tDeltaY:Float;

		if (dx == 0)
		{
			tMaxX = 1e9;
			tDeltaX = 1e9;
		}
		else
		{
			var nextGridX:Float = (tx + (stepX > 0 ? 1 : 0)) * TILE_SIZE;
			tMaxX = Math.abs((nextGridX - x0) / dx);
			tDeltaX = Math.abs(TILE_SIZE / dx);
		}

		if (dy == 0)
		{
			tMaxY = 1e9;
			tDeltaY = 1e9;
		}
		else
		{
			var nextGridY:Float = (ty + (stepY > 0 ? 1 : 0)) * TILE_SIZE;
			tMaxY = Math.abs((nextGridY - y0) / dy);
			tDeltaY = Math.abs(TILE_SIZE / dy);
		}

		var gridH:Int = wallGrid != null ? wallGrid.length : 0;
		var gridW:Int = (gridH > 0 && wallGrid[0] != null) ? wallGrid[0].length : 0;

		var maxSteps:Int = 1024;
		while (maxSteps-- > 0)
		{
			if (tx < 0 || ty < 0 || ty >= gridH || tx >= gridW)
				return false;

			if (gridH > 0 && gridW > 0 && wallGrid[ty][tx] == 1)
				return false;

			if (tx == txEnd && ty == tyEnd)
				break;

			if (tMaxX < tMaxY)
			{
				tMaxX += tDeltaX;
				tx += stepX;
			}
			else
			{
				tMaxY += tDeltaY;
				ty += stepY;
			}
		}

		return true;
	}

	public function new()
	{
		super();
	}

	private function isSpawnBlocked(enemies:flixel.group.FlxGroup.FlxTypedGroup<Enemy>, tx:Int, ty:Int, avoidRadius:Int, minSpacing:Int, TILE_SIZE:Int,
			?playerTileX:Int = -1, ?playerTileY:Int = -1):Bool
	{

		if (Math.abs(tx - this.portalTileX) <= avoidRadius && Math.abs(ty - this.portalTileY) <= avoidRadius)
			return true;
		// Block spawns that would be visible on the initial screen
		// The camera will be centered on the portal when the player spawns
		// Calculate what will be on-screen based on portal position
		var screenTilesW:Int = Std.int(Math.ceil(FlxG.width / TILE_SIZE));
		var screenTilesH:Int = Std.int(Math.ceil(FlxG.height / TILE_SIZE));
		var halfScreenW:Int = Std.int(screenTilesW / 2) + 2; // +2 tile buffer
		var halfScreenH:Int = Std.int(screenTilesH / 2) + 2; // +2 tile buffer

		// Check if this tile would be on screen when camera is centered on portal
		if (Math.abs(tx - this.portalTileX) <= halfScreenW && Math.abs(ty - this.portalTileY) <= halfScreenH)
			return true;
			
		if (playerTileX >= 0 && playerTileY >= 0)
		{
			var playerAvoidRadius:Int = 25;
			if (Math.abs(tx - playerTileX) <= playerAvoidRadius && Math.abs(ty - playerTileY) <= playerAvoidRadius)
				return true;
		}

		for (existing in enemies.members)
		{
			if (existing == null)
				continue;
			var em:FlxPoint = existing.getMidpoint();
			var ex:Int = Std.int(em.x / TILE_SIZE);
			var ey:Int = Std.int((existing.y + existing.height * 0.5) / TILE_SIZE);
			if (Math.abs(ex - tx) <= minSpacing && Math.abs(ey - ty) <= minSpacing)
				return true;
			em.put();
		}
		return false;
	}

	public function spawnEnemies(enemies:flixel.group.FlxGroup.FlxTypedGroup<Enemy>, atmosphereHue:Int, ?playerTileX:Int = -1, ?playerTileY:Int = -1):Void
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
		var ppx:Int = playerTileX;
		var ppy:Int = playerTileY;
		roomOrder.sort(function(a:Int, b:Int):Int
		{
			var ra:RoomInfo = this.roomsInfo[a];
			var rb:RoomInfo = this.roomsInfo[b];
			if (ra == null || rb == null)
				return 0;

			var da_portal:Float = Math.pow(ra.centroid.x - px, 2) + Math.pow(ra.centroid.y - py, 2);
			var db_portal:Float = Math.pow(rb.centroid.x - px, 2) + Math.pow(rb.centroid.y - py, 2);

			var da_player:Float = (ppx >= 0 && ppy >= 0) ? (Math.pow(ra.centroid.x - ppx, 2) + Math.pow(ra.centroid.y - ppy, 2)) : 0;
			var db_player:Float = (ppx >= 0 && ppy >= 0) ? (Math.pow(rb.centroid.x - ppx, 2) + Math.pow(rb.centroid.y - ppy, 2)) : 0;

			var da:Float = da_portal * 0.7 + da_player * 0.3;
			var db:Float = db_portal * 0.7 + db_player * 0.3;
			return da < db ? -1 : (da > db ? 1 : 0);
		});

		for (i in 0...roomOrder.length)
		{
			var idx = roomOrder[i];
			if (totalSpawned >= globalMax)
				break;
			var room:RoomInfo =  this.roomsInfo[idx];
			if (room == null || room.area <= 0)
				continue;
			if (room.isPortal)
				continue;
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

			if (playerTileX >= 0 && playerTileY >= 0)
			{
				var playerDistTiles:Float = Math.pow(room.centroid.x - playerTileX, 2) + Math.pow(room.centroid.y - playerTileY, 2);
				if (playerDistTiles <= 144.0)
				{
					desired = Std.int(desired * 0.5);
					if (desired < 1)
						desired = 1;
				}
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
				if (isSpawnBlocked(enemies, tx, ty, avoidRadius, minSpacingTiles, TILE_SIZE, playerTileX, playerTileY))
					continue;

				var eObj:Enemy = new Enemy(tx * TILE_SIZE, ty * TILE_SIZE, atmosphereHue);
				enemies.add(eObj);

				placed++;
				totalSpawned++;
			}
		}

		var portalClusterSize:Int = 6;
		var portalRoom:RoomInfo =  this.roomsInfo[this.portalRoomIndex];
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
				if (isSpawnBlocked(enemies, tx, ty, avoidRadiusCluster, minSpacingTiles, TILE_SIZE, playerTileX, playerTileY))
					continue;
				var eObj:Enemy = new Enemy(tx * TILE_SIZE, ty * TILE_SIZE, atmosphereHue);
				enemies.add(eObj);

				clusterPlaced++;
				totalSpawned++;
			}
		}


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
										var eObj:Enemy = new Enemy(xx * TILE_SIZE, yy * TILE_SIZE, atmosphereHue);
										enemies.add(eObj);

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
		catch (e:Dynamic)
		{
			#if (debug)
			trace('GameMap.generate: coverage-pass failure: ' + Std.string(e));
			#end
		}
	}

	public static function carveCrooked(M:Array<Array<Int>>, x1:Int, y1:Int, x2:Int, y2:Int, width:Int, depth:Int):Void
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
						if (nx <= 0 || ny <= 0 || nx >= M[0].length - 1 || ny >= M.length - 1)
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
		GameMap.carveCrooked(M, x1, y1, mxi, myi, width, depth + 1);
		GameMap.carveCrooked(M, mxi, myi, x2, y2, width, depth + 1);

		if (FlxG.random.float() < 0.55 && depth < 7)
		{
			var bx = Std.int(mxi + (FlxG.random.float() - 0.5) * dist * 0.5);
			var by = Std.int(myi + (FlxG.random.float() - 0.5) * dist * 0.5);
			var bw = Std.int(2 + Std.int(FlxG.random.float() * 3));
			GameMap.carveCrooked(M, mxi, myi, bx, by, bw, depth + 1);
		}
	}

	public static function findCenter(node:Dynamic):TileCoord
	{
		if (node == null)
			return null;
		if (node.roomCenter != null)
			return node.roomCenter;
		var l:TileCoord = GameMap.findCenter(node.left);
		if (l != null)
			return l;
		return GameMap.findCenter(node.right);
	}

	public static function connectNode(M:Array<Array<Int>>, node:Dynamic):Void
	{
		if (node == null)
			return;
		if (node.left != null && node.right != null)
		{
			var a:TileCoord = GameMap.findCenter(node.left);
			var b:TileCoord = GameMap.findCenter(node.right);
			if (a != null && b != null)
			{
				var w = Std.int(3 + Std.int(FlxG.random.float() * 6));
				GameMap.carveCrooked(M, a.x, a.y, b.x, b.y, w, 0);
			}
		}
		if (node.left != null)
			GameMap.connectNode(M, node.left);
		if (node.right != null)
			GameMap.connectNode(M, node.right);
	}


	public function generate(hue:Int = -1):Void
	{
		var TILE_SIZE:Int = Constants.TILE_SIZE;
		var tilesWide:Int = Std.int(FlxG.width / TILE_SIZE);
		var tilesHigh:Int = Std.int(FlxG.height / TILE_SIZE);

		var totalW:Int = Std.int(Math.max(96, tilesWide * 8));
		var totalH:Int = Std.int(Math.max(96, tilesHigh * 8));


		var M:Array<Array<Int>> = [];
		for (y in 0...totalH)
		{
			var row:Array<Int> = [];
			for (x in 0...totalW)
				row.push(1);
			M.push(row);
		}

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

		var minLeaf:Int = 7;
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

		roomsInfo = [];
		for (leaf in leaves)
		{
			if (leaf.left != null || leaf.right != null)
				continue;

			var margin = 3;
			var maxRW = Math.max(3, leaf.w - margin * 2);
			var maxRH = Math.max(3, leaf.h - margin * 2);
			if (maxRW < 3 || maxRH < 3)
				continue;

			var roomFracMin:Float = 0.45;
			var roomFracRange:Float = 0.25;
			var rW = Std.int(Math.max(3, Math.min(maxRW - 1, Std.int(maxRW * (roomFracMin + FlxG.random.float() * roomFracRange)))));
			var rH = Std.int(Math.max(3, Math.min(maxRH - 1, Std.int(maxRH * (roomFracMin + FlxG.random.float() * roomFracRange)))));
			var minRoomSeparation:Int = 8;
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

			var circles = 4 + Std.int(FlxG.random.float() * 6);
			for (c in 0...circles)
			{
				var angle = FlxG.random.float() * Math.PI * 2;
				var edgeBias = 0.35 + FlxG.random.float() * 0.55;
				var ox = cx + Std.int((rW / 2) * Math.cos(angle) * edgeBias) + Std.int((FlxG.random.float() - 0.5) * 4);
				var oy = cy + Std.int((rH / 2) * Math.sin(angle) * edgeBias) + Std.int((FlxG.random.float() - 0.5) * 4);
				var maxRad = Math.max(2, Std.int(Math.min(rW, rH) * (0.18 + FlxG.random.float() * 0.50)));

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


			var yy0:Int = Std.int(ry);
			var yy1:Int = Std.int(ry + rH);
			var xx0:Int = Std.int(rx);
			var xx1:Int = Std.int(rx + rW);
			for (yy in yy0...yy1)
				for (xx in xx0...xx1)
					if (xx > 0 && yy > 0 && xx < totalW - 1 && yy < totalH - 1 && FlxG.random.float() < 0.02)
						M[yy][xx] = 0;


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



		GameMap.connectNode(M, root);

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
				var stack:Array<FlxPoint> = [];
				var p0:FlxPoint = FlxPoint.get(xx, yy);
				stack.push(p0);
				comp[yy][xx] = cid;
				var list:Array<TileCoord> = [];
				while (stack.length > 0)
				{
					var curP:FlxPoint = stack.pop();
					var curX:Int = Std.int(curP.x);
					var curY:Int = Std.int(curP.y);
					list.push({x: curX, y: curY});
					curP.put();
					var dxs:Array<Int> = [-1, 1, 0, 0];
					var dys:Array<Int> = [0, 0, -1, 1];
					for (k in 0...4)
					{
						var nx:Int = curX + dxs[k];
						var ny:Int = curY + dys[k];
						if (nx < 0 || ny < 0 || nx >= totalW || ny >= totalH)
							continue;
						if (M[ny][nx] == 0 && comp[ny][nx] == -1)
						{
							comp[ny][nx] = cid;
							var np:FlxPoint = FlxPoint.get(nx, ny);
							stack.push(np);
						}
					}
				}
				comps.push(list);
				cid++;
			}
		}

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

		if (comps.length > 1 && keepId >= 0)
		{
			var compRooms:Array<Array<Int>> = [];
			for (ci in 0...comps.length)
				compRooms.push([]);
			for (ri in 0...roomsInfo.length)
			{
				var r:RoomInfo = roomsInfo[ri];
				if (r == null || r.tiles == null || r.tiles.length == 0)
					continue;
				for (t in r.tiles)
				{
					var tx:Int = Std.int(t.x);
					var ty:Int = Std.int(t.y);
					if (tx >= 0 && ty >= 0 && tx < totalW && ty < totalH)
					{
						var cidVal:Int = comp[ty][tx];
						if (cidVal >= 0 && cidVal < compRooms.length)
						{
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

			for (ci in 0...comps.length)
			{
				if (ci == keepId)
					continue;
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

				var w:Int = 2 + Std.int(FlxG.random.float() * 3);
				GameMap.carveCrooked(M, srcX, srcY, tgtX, tgtY, w, 0);
			}

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
					var stack2:Array<FlxPoint> = [];
					var p02:FlxPoint = FlxPoint.get(xx, yy);
					stack2.push(p02);
					comp2[yy][xx] = cid2;
					var list2:Array<TileCoord> = [];
					while (stack2.length > 0)
					{
						var cur2P:FlxPoint = stack2.pop();
						var cur2X:Int = Std.int(cur2P.x);
						var cur2Y:Int = Std.int(cur2P.y);
						list2.push({x: cur2X, y: cur2Y});
						cur2P.put();
						var dxs2:Array<Int> = [-1, 1, 0, 0];
						var dys2:Array<Int> = [0, 0, -1, 1];
						for (k2 in 0...4)
						{
							var nx2:Int = cur2X + dxs2[k2];
							var ny2:Int = cur2Y + dys2[k2];
							if (nx2 < 0 || ny2 < 0 || nx2 >= totalW || ny2 >= totalH)
								continue;
							if (M[ny2][nx2] == 0 && comp2[ny2][nx2] == -1)
							{
								comp2[ny2][nx2] = cid2;
								var np2:FlxPoint = FlxPoint.get(nx2, ny2);
								stack2.push(np2);
							}
						}
					}
					comps2.push(list2);
					cid2++;
				}
			}

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

			for (i2 in 0...comps2.length)
			{
				if (i2 == keepId2)
					continue;
				for (t in comps2[i2])
					M[t.y][t.x] = 1;
			}
			comp = comp2;
			comps = comps2;
			keepId = keepId2;
		}

		{
			var EXTRA_LOOPS:Int = 4;
			var mainRoomIndices:Array<Int> = [];
			if (keepId >= 0)
			{
				for (ri in 0...roomsInfo.length)
				{
					var r:RoomInfo = roomsInfo[ri];
					if (r == null || r.tiles == null || r.tiles.length == 0)
						continue;
					var t0 = r.tiles[Std.int(r.tiles.length * 0.5)];
					var cx0:Int = Std.int(Math.max(0, Math.min(totalW - 1, Math.round(t0.x))));
					var cy0:Int = Std.int(Math.max(0, Math.min(totalH - 1, Math.round(t0.y))));
					if (comp[cy0][cx0] == keepId)
						mainRoomIndices.push(ri);
				}
			}
			for (l in 0...EXTRA_LOOPS)
			{
				if (mainRoomIndices.length < 2)
					break;
				var aIdx:Int = Std.int(FlxG.random.float() * mainRoomIndices.length);
				if (aIdx < 0)
					aIdx = 0;
				if (aIdx >= mainRoomIndices.length)
					aIdx = mainRoomIndices.length - 1;
				var ra:RoomInfo = roomsInfo[mainRoomIndices[aIdx]];
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
					var score:Float = d2;
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
				var width1:Int = 2 + Std.int(FlxG.random.float() * 3);
				GameMap.carveCrooked(M, sx, sy, tx, ty, width1, 0);
				if (FlxG.random.float() < 0.25)
				{
					var width2:Int = 1 + Std.int(FlxG.random.float() * 3);
					var offAx:Int = Std.int((FlxG.random.float() - 0.5) * 6);
					var offAy:Int = Std.int((FlxG.random.float() - 0.5) * 6);
					var offBx:Int = Std.int((FlxG.random.float() - 0.5) * 6);
					var offBy:Int = Std.int((FlxG.random.float() - 0.5) * 6);
					var ax:Int = Std.int(Math.max(1, sx + offAx));
					var ay:Int = Std.int(Math.max(1, sy + offAy));
					var bx:Int = Std.int(Math.max(1, tx + offBx));
					var by:Int = Std.int(Math.max(1, ty + offBy));
					GameMap.carveCrooked(M, ax, ay, bx, by, width2, 0);
				}
			}
		}

		{
			var POCKET_CHANCE:Float = 0.08;
			for (ri in 0...roomsInfo.length)
			{
				if (FlxG.random.float() > POCKET_CHANCE)
					continue;
				var r:RoomInfo = roomsInfo[ri];
				if (r == null || r.tiles == null || r.tiles.length == 0)
					continue;
				var cx:Int = Std.int(Math.round(r.centroid.x));
				var cy:Int = Std.int(Math.round(r.centroid.y));
				var pocketCircles:Int = 3 + Std.int(FlxG.random.float() * 4);
				for (pc in 0...pocketCircles)
				{
					var angle = FlxG.random.float() * Math.PI * 2;
					var dist = 2 + Std.int(FlxG.random.float() * 6);
					var ox = cx + Std.int(Math.cos(angle) * dist) + Std.int((FlxG.random.float() - 0.5) * 3);
					var oy = cy + Std.int(Math.sin(angle) * dist) + Std.int((FlxG.random.float() - 0.5) * 3);
					var rad = 2 + Std.int(FlxG.random.float() * 4);
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
				if (FlxG.random.float() < 0.9)
					GameMap.carveCrooked(M, cx, cy, cx + Std.int((FlxG.random.float() - 0.5) * 6), cy + Std.int((FlxG.random.float() - 0.5) * 6), 2, 0);
			}
		}

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

		var validRooms:Array<Int> = [];
		for (i in 0...roomsInfo.length)
		{
			var rr:RoomInfo = roomsInfo[i];
			if (rr != null && rr.tiles != null && rr.tiles.length > 0)
				validRooms.push(i);
		}

		if (validRooms.length > 0)
		{
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

			var candidateRooms:Array<Int> = [];
			for (idx in validRooms)
			{
				var rr2:RoomInfo = roomsInfo[idx];
				if (rr2.area <= cutoffArea && rr2.area >= 6)
					candidateRooms.push(idx);
			}

			if (candidateRooms.length == 0)
				candidateRooms = validRooms;

			var bestIdx:Int = -1;
			var bestScore:Float = -1.0;
			for (ci in 0...candidateRooms.length)
			{
				var idxRoom = candidateRooms[ci];
				var rroom:RoomInfo = roomsInfo[idxRoom];
				if (rroom == null)
					continue;
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
					if (d2 <= 144.0)
						neighborCount++;
				}
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
					var ti:Int = Std.int(FlxG.random.float() * room.tiles.length);
					if (ti < 0)
						ti = 0;
					if (ti >= room.tiles.length)
						ti = room.tiles.length - 1;
					pickTile = room.tiles[ti];
				}
				portalTileX = Std.int(pickTile.x);
				portalTileY = Std.int(pickTile.y);
				portalPixelX = portalTileX * TILE_SIZE + TILE_SIZE / 2.0;
				portalPixelY = portalTileY * TILE_SIZE + TILE_SIZE / 2.0;
				room.isPortal = true;
			}
		}

		var csv:String = FlxCaveGenerator.convertMatrixToString(M);
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
				rowArr.push(v);
			}
			wallGrid.push(rowArr);
		}
		var floorCsv:String = generateFloorCSV(totalW, totalH);
		_floorCsv = floorCsv;

		floorMap = new FlxTilemap();
		var floorTileset:BitmapData = (hue >= 0) ? ColorHelpers.getHueColoredBmp("assets/images/floor.png",
			hue) : FlxAssets.getBitmapData("assets/images/floor.png");

		floorMap.loadMapFromCSV(_floorCsv, floorTileset, TILE_SIZE, TILE_SIZE, FlxTilemapAutoTiling.OFF, 0, 0);
		this.add(floorMap);

		wallsMap = new FlxTilemap();
		_wallsCsv = csv;
		wallsMap = new FlxTilemap();
		var wallsTileset:BitmapData = (hue >= 0) ? ColorHelpers.getHueColoredBmp("assets/images/autotiles.png",
			hue) : FlxAssets.getBitmapData("assets/images/autotiles.png");

		wallsMap.loadMapFromCSV(_wallsCsv, wallsTileset, TILE_SIZE, TILE_SIZE, FlxTilemapAutoTiling.FULL);
		this.add(wallsMap);
	}


	private function generateFloorCSV(w:Int, h:Int):String
	{

		var octaves = 4;
		var persistence = 0.62;
		var lacunarity = 1.7;
		var baseFreq:Float = 0.6;

		var maxAmp:Float = 0.0;
		for (o in 0...octaves)
			maxAmp += Math.pow(persistence, o);

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
					var v00:Float = FlxG.random.float();
					var v10:Float = FlxG.random.float();
					var v01:Float = FlxG.random.float();
					var v11:Float = FlxG.random.float();
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
