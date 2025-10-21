package;

import flixel.FlxG;
import flixel.system.FlxAssets;
import openfl.display.BitmapData;
// no explicit Reflect import needed
import flixel.addons.tile.FlxCaveGenerator;
import flixel.group.FlxGroup;
import flixel.tile.FlxBaseTilemap.FlxTilemapAutoTiling;
import flixel.tile.FlxTilemap;

class GameMap extends FlxGroup
{
	public var walkableTiles:Array<Int> = [];
	public var roomsInfo:Array<RoomInfo> = [];

	public var floorMap:FlxTilemap;
	public var wallsMap:FlxTilemap;
	// parsed wall grid (0 = floor, 1 = wall) for CPU-side visibility tests
	public var wallGrid:Array<Array<Int>>;

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

	private function get_height():Int
	{
		return wallsMap != null ? Std.int(wallsMap.height) : 0;
	}

	public function new()
	{
		super();
	}

	// Apply a hue shift to floor and walls bitmaps in memory and reload tilemaps
	public function applyHue(hue:Int):Void
	{
		try
		{
			var h:Float = (hue % 360) / 360.0;
			// floor
			var floorBmp:BitmapData = FlxAssets.getBitmapData("assets/images/floor.png");
			if (floorBmp != null && _floorCsv != null)
			{
				var newFloor:BitmapData = new BitmapData(floorBmp.width, floorBmp.height, true, 0x00000000);
				newFloor.lock();
				for (y in 0...floorBmp.height)
				{
					for (x in 0...floorBmp.width)
					{
						var px:Int = floorBmp.getPixel32(x, y);
						var a = (px >> 24) & 0xFF;
						if (a == 0)
						{
							newFloor.setPixel32(x, y, px);
							continue;
						}
						// extract RG
						var r = ((px >> 16) & 0xFF) / 255.0;
						var g = ((px >> 8) & 0xFF) / 255.0;
						var b = (px & 0xFF) / 255.0;
						// convert to HSV-like (we'll use H from hue param, keep S and V)
						var maxc = Math.max(r, Math.max(g, b));
						var minc = Math.min(r, Math.min(g, b));
						var v = maxc;
						var s = (maxc == 0.0) ? 0.0 : (maxc - minc) / maxc;
						// convert hsv back to rgb with new hue h
						var hh = h * 6.0;
						var i = Std.int(Math.floor(hh)) % 6;
						var f = hh - Math.floor(hh);
						var p = v * (1.0 - s);
						var q = v * (1.0 - f * s);
						var t = v * (1.0 - (1.0 - f) * s);
						var nr:Float = 0.0;
						var ng:Float = 0.0;
						var nb:Float = 0.0;
						switch (i)
						{
							case 0:
								nr = v;
								ng = t;
								nb = p;
								break;
							case 1:
								nr = q;
								ng = v;
								nb = p;
								break;
							case 2:
								nr = p;
								ng = v;
								nb = t;
								break;
							case 3:
								nr = p;
								ng = q;
								nb = v;
								break;
							case 4:
								nr = t;
								ng = p;
								nb = v;
								break;
							case 5:
								nr = v;
								ng = p;
								nb = q;
								break;
						}
						var orgb:Int = ((Std.int(nr * 255) & 0xFF) << 16) | ((Std.int(ng * 255) & 0xFF) << 8) | (Std.int(nb * 255) & 0xFF);
						newFloor.setPixel32(x, y, (a << 24) | orgb);
					}
				}
				newFloor.unlock();
				// reload floorMap from CSV using newFloor bitmap
				floorMap.loadMapFromCSV(_floorCsv, newFloor, Constants.TILE_SIZE, Constants.TILE_SIZE, FlxTilemapAutoTiling.OFF);
			}
			// walls/autotiles
			var wallsBmp:BitmapData = FlxAssets.getBitmapData("assets/images/autotiles.png");
			if (wallsBmp != null && _wallsCsv != null)
			{
				var newWalls:BitmapData = new BitmapData(wallsBmp.width, wallsBmp.height, true, 0x00000000);
				newWalls.lock();
				for (y in 0...wallsBmp.height)
				{
					for (x in 0...wallsBmp.width)
					{
						var px:Int = wallsBmp.getPixel32(x, y);
						var a = (px >> 24) & 0xFF;
						if (a == 0)
						{
							newWalls.setPixel32(x, y, px);
							continue;
						}
						var r = ((px >> 16) & 0xFF) / 255.0;
						var g = ((px >> 8) & 0xFF) / 255.0;
						var b = (px & 0xFF) / 255.0;
						var maxc = Math.max(r, Math.max(g, b));
						var minc = Math.min(r, Math.min(g, b));
						var v = maxc;
						var s = (maxc == 0.0) ? 0.0 : (maxc - minc) / maxc;
						var hh = h * 6.0;
						var i = Std.int(Math.floor(hh)) % 6;
						var f = hh - Math.floor(hh);
						var p = v * (1.0 - s);
						var q = v * (1.0 - f * s);
						var t = v * (1.0 - (1.0 - f) * s);
						var nr:Float = 0.0;
						var ng:Float = 0.0;
						var nb:Float = 0.0;
						switch (i)
						{
							case 0:
								nr = v;
								ng = t;
								nb = p;
								break;
							case 1:
								nr = q;
								ng = v;
								nb = p;
								break;
							case 2:
								nr = p;
								ng = v;
								nb = t;
								break;
							case 3:
								nr = p;
								ng = q;
								nb = v;
								break;
							case 4:
								nr = t;
								ng = p;
								nb = v;
								break;
							case 5:
								nr = v;
								ng = p;
								nb = q;
								break;
						}
						var orgb:Int = ((Std.int(nr * 255) & 0xFF) << 16) | ((Std.int(ng * 255) & 0xFF) << 8) | (Std.int(nb * 255) & 0xFF);
						newWalls.setPixel32(x, y, (a << 24) | orgb);
					}
				}
				newWalls.unlock();
				wallsMap.loadMapFromCSV(_wallsCsv, newWalls, Constants.TILE_SIZE, Constants.TILE_SIZE, FlxTilemapAutoTiling.FULL);
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
		var totalW:Int = Std.int(Math.max(48, tilesWide * 4));
		var totalH:Int = Std.int(Math.max(48, tilesHigh * 4));

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
		var targetLeaves:Int = Std.int((totalW * totalH) / 2500);
		if (targetLeaves < 12)
			targetLeaves = 12;

		var leaves:Array<Dynamic> = [];
		var root:Dynamic = {
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

		var minLeaf:Int = 12;
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
				var newL:Array<Dynamic> = [];
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
				var newL2:Array<Dynamic> = [];
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

			// increase room fraction so rooms are larger (65% - 90% of partition)
			var rW = Std.int(Math.max(3, maxRW * (0.65 + FlxG.random.float() * 0.25)));
			var rH = Std.int(Math.max(3, maxRH * (0.65 + FlxG.random.float() * 0.25)));
			// Try to pick a room position that keeps some separation from existing rooms
			var minRoomSeparation:Int = 6; // tiles
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
			var circles = 6 + Std.int(FlxG.random.float() * 7); // 6..12
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

			var tilesList:Array<Dynamic> = [];
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

			if (FlxG.random.float() < 0.35 && depth < 6)
			{
				var bx = Std.int(mxi + (FlxG.random.float() - 0.5) * dist * 0.5);
				var by = Std.int(myi + (FlxG.random.float() - 0.5) * dist * 0.5);
				var bw = Std.int(3 + Std.int(FlxG.random.float() * 9));
				carveCrooked(mxi, myi, bx, by, bw, depth + 1);
			}
		}

		// traverse tree and connect child rooms
		function connectNode(node:Dynamic):Void
		{
			if (node == null)
				return;
			if (node.left != null && node.right != null)
			{
				// find nearest room center in left subtree and right subtree
				function findCenter(n:Dynamic):Dynamic
				{
					if (n == null)
						return null;
					if (n.roomCenter != null)
						return n.roomCenter;
					var l:Dynamic = findCenter(n.left);
					if (l != null)
						return l;
					return findCenter(n.right);
				}
				var a = findCenter(node.left);
				var b = findCenter(node.right);
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

		var comps:Array<Array<Dynamic>> = [];
		var cid:Int = 0;
		for (yy in 0...totalH)
		{
			for (xx in 0...totalW)
			{
				if (M[yy][xx] != 0 || comp[yy][xx] != -1)
					continue;
				// flood-fill / BFS stack
				var stack:Array<Dynamic> = [];
				stack.push({x: xx, y: yy});
				comp[yy][xx] = cid;
				var list:Array<Dynamic> = [];
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

		// fill (turn to wall) any component that is not the main one
		for (i in 0...comps.length)
		{
			if (i == keepId)
				continue;
			for (t in comps[i])
				M[t.y][t.x] = 1;
		}

		// Recompute each room's tile list based on final map (roomsInfo built earlier may be stale)
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

			var ri:Int = Std.int(FlxG.random.float() * candidateRooms.length);
			if (ri < 0)
				ri = 0;
			if (ri >= candidateRooms.length)
				ri = candidateRooms.length - 1;
			portalRoomIndex = candidateRooms[ri];
			var room:RoomInfo = roomsInfo[portalRoomIndex];
			if (room.tiles.length > 0)
			{
				// prefer tiles with 1-tile clearance (all 8 neighbors are floor)
				var clearance:Array<Dynamic> = [];
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
				var pickTile:Dynamic = null;
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
		// create floor tilemap (full-extent mockup) and add it below walls
		var floorCsv:String = generateFloorCSV(totalW, totalH);
		_floorCsv = floorCsv;
		floorMap = new FlxTilemap();
		// recolor tileset bitmap BEFORE loading tilemap if a hue was provided
		var floorTileset:Dynamic = "assets/images/floor.png";
		if (hue >= 0)
		{
			var srcFloor:BitmapData = FlxAssets.getBitmapData("assets/images/floor.png");
			if (srcFloor != null)
			{
				var newFloorBmp:BitmapData = new BitmapData(srcFloor.width, srcFloor.height, true, 0x00000000);
				newFloorBmp.lock();
				// helper: convert RGB -> HSL and back with new hue
				for (fy in 0...srcFloor.height)
				{
					for (fx in 0...srcFloor.width)
					{
						var px:Int = srcFloor.getPixel32(fx, fy);
						var a = (px >> 24) & 0xFF;
						if (a == 0)
						{
							newFloorBmp.setPixel32(fx, fy, px);
							continue;
						}
						var r = ((px >> 16) & 0xFF) / 255.0;
						var g = ((px >> 8) & 0xFF) / 255.0;
						var b = (px & 0xFF) / 255.0;
						// RGB -> HSL
						var maxc = Math.max(r, Math.max(g, b));
						var minc = Math.min(r, Math.min(g, b));
						var l = (maxc + minc) / 2.0;
						var s:Float = 0.0;
						if (maxc != minc)
						{
							s = (l < 0.5) ? ((maxc - minc) / (maxc + minc)) : ((maxc - minc) / (2.0 - maxc - minc));
						}
						var H:Float = (hue % 360) / 360.0;
						// HSL -> RGB
						var rnew:Float;
						var gnew:Float;
						var bnew:Float;
						if (s == 0.0)
						{
							rnew = gnew = bnew = l;
						}
						else
						{
							// hue2rgb helper
							function hue2rgb(p:Float, q:Float, t:Float):Float
							{
								if (t < 0.0)
									t += 1.0;
								if (t > 1.0)
									t -= 1.0;
								if (t < 1.0 / 6.0)
									return p + (q - p) * 6.0 * t;
								if (t < 1.0 / 2.0)
									return q;
								if (t < 2.0 / 3.0)
									return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
								return p;
							}
							var q = (l < 0.5) ? (l * (1.0 + s)) : (l + s - l * s);
							var p = 2.0 * l - q;
							rnew = hue2rgb(p, q, H + 1.0 / 3.0);
							gnew = hue2rgb(p, q, H);
							bnew = hue2rgb(p, q, H - 1.0 / 3.0);
						}
						var orgb:Int = ((Std.int(rnew * 255) & 0xFF) << 16) | ((Std.int(gnew * 255) & 0xFF) << 8) | (Std.int(bnew * 255) & 0xFF);
						newFloorBmp.setPixel32(fx, fy, (a << 24) | orgb);
					}
				}
				newFloorBmp.unlock();
				floorTileset = newFloorBmp;
			}
		}
		// use OFF autotiling for the simple floor tileset (4 tiles in floor.png)
		floorMap.loadMapFromCSV(floorCsv, floorTileset, TILE_SIZE, TILE_SIZE, FlxTilemapAutoTiling.OFF);
		// runtime hue shift shader (applied to floor)
		try
		{
			var sh = new shaders.HueShift();
			floorMap.shader = sh;
			// expose as a dynamic field so PlayState can access if needed
			(cast floorMap : Dynamic).hueShader = sh;
			// pass initial hue to shader (generate was called with hue)
			try
			{
				sh.hue = hue;
			}
			catch (e:Dynamic) {}
		}
		catch (e:Dynamic) {}
		this.add(floorMap);

		// create walls tilemap and add on top of floor
		wallsMap = new FlxTilemap();
		_wallsCsv = csv;
		var wallsTileset:Dynamic = "assets/images/autotiles.png";
		if (hue >= 0)
		{
			var srcWalls:BitmapData = FlxAssets.getBitmapData("assets/images/autotiles.png");
			if (srcWalls != null)
			{
				var newWallsBmp:BitmapData = new BitmapData(srcWalls.width, srcWalls.height, true, 0x00000000);
				newWallsBmp.lock();
				for (wy in 0...srcWalls.height)
				{
					for (wx in 0...srcWalls.width)
					{
						var px2:Int = srcWalls.getPixel32(wx, wy);
						var a2 = (px2 >> 24) & 0xFF;
						if (a2 == 0)
						{
							newWallsBmp.setPixel32(wx, wy, px2);
							continue;
						}
						var rr = ((px2 >> 16) & 0xFF) / 255.0;
						var gg = ((px2 >> 8) & 0xFF) / 255.0;
						var bb = (px2 & 0xFF) / 255.0;
						var maxc2 = Math.max(rr, Math.max(gg, bb));
						var minc2 = Math.min(rr, Math.min(gg, bb));
						var ll = (maxc2 + minc2) / 2.0;
						var ss:Float = 0.0;
						if (maxc2 != minc2)
						{
							ss = (ll < 0.5) ? ((maxc2 - minc2) / (maxc2 + minc2)) : ((maxc2 - minc2) / (2.0 - maxc2 - minc2));
						}
						var H2:Float = (hue % 360) / 360.0;
						var rnew2:Float;
						var gnew2:Float;
						var bnew2:Float;
						if (ss == 0.0)
						{
							rnew2 = gnew2 = bnew2 = ll;
						}
						else
						{
							function hue2rgb2(p:Float, q:Float, t:Float):Float
							{
								if (t < 0.0)
									t += 1.0;
								if (t > 1.0)
									t -= 1.0;
								if (t < 1.0 / 6.0)
									return p + (q - p) * 6.0 * t;
								if (t < 1.0 / 2.0)
									return q;
								if (t < 2.0 / 3.0)
									return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
								return p;
							}
							var q2 = (ll < 0.5) ? (ll * (1.0 + ss)) : (ll + ss - ll * ss);
							var p2 = 2.0 * ll - q2;
							rnew2 = hue2rgb2(p2, q2, H2 + 1.0 / 3.0);
							gnew2 = hue2rgb2(p2, q2, H2);
							bnew2 = hue2rgb2(p2, q2, H2 - 1.0 / 3.0);
						}
						var orgb2:Int = ((Std.int(rnew2 * 255) & 0xFF) << 16) | ((Std.int(gnew2 * 255) & 0xFF) << 8) | (Std.int(bnew2 * 255) & 0xFF);
						newWallsBmp.setPixel32(wx, wy, (a2 << 24) | orgb2);
					}
				}
				newWallsBmp.unlock();
				wallsTileset = newWallsBmp;
			}
		}
		wallsMap.loadMapFromCSV(csv, wallsTileset, TILE_SIZE, TILE_SIZE, FlxTilemapAutoTiling.FULL);
		try
		{
			var sh2 = new shaders.HueShift();
			wallsMap.shader = sh2;
			(cast wallsMap : Dynamic).hueShader = sh2;
			// if a hue was provided at generate time (we recolored tilesets), ensure shader receives same hue
			try
			{
				sh2.hue = hue;
			}
			catch (e:Dynamic) {}
		}
		catch (e:Dynamic) {}
		this.add(wallsMap);
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
	public var tiles:Array<Dynamic>;
	public var area:Int;
	public var centroid:Dynamic;
	public var bbox:Dynamic;
	public var isCorridor:Bool;
	public var isPortal:Bool;

	public function new(tiles:Array<Dynamic>, area:Int, centroid:Dynamic, bbox:Dynamic, isCorridor:Bool)
	{
		this.tiles = tiles;
		this.area = area;
		this.centroid = centroid;
		this.bbox = bbox;
		this.isCorridor = isCorridor;
		this.isPortal = false;
	}
}
