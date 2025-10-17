package;

import flixel.FlxG;
import flixel.addons.tile.FlxCaveGenerator;
import flixel.tile.FlxBaseTilemap.FlxTilemapAutoTiling;
import flixel.tile.FlxTilemap;

class GameMap extends FlxTilemap
{
	public var walkableTiles:Array<Int> = [];
	public var roomsInfo:Array<RoomInfo> = [];

	public function new()
	{
		super();
	}

	public function generate():Void
	{
		var TILE_SIZE:Int = 8;
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
			var margin = 2;
			var maxRW = Math.max(3, leaf.w - margin * 2);
			var maxRH = Math.max(3, leaf.h - margin * 2);
			if (maxRW < 3 || maxRH < 3)
				continue;

			var rW = Math.max(3, maxRW - Std.int(FlxG.random.float() * Std.int(maxRW * 0.12)));
			var rH = Math.max(3, maxRH - Std.int(FlxG.random.float() * Std.int(maxRH * 0.12)));
			var rx = leaf.x + margin + Std.int(FlxG.random.float() * Math.max(0, leaf.w - rW - margin * 2));
			var ry = leaf.y + margin + Std.int(FlxG.random.float() * Math.max(0, leaf.h - rH - margin * 2));

			var cx = rx + Std.int(rW / 2);
			var cy = ry + Std.int(rH / 2);

			var circles = 5 + Std.int(FlxG.random.float() * 8); // 5..12
			for (c in 0...circles)
			{
				var angle = FlxG.random.float() * Math.PI * 2;
				var edgeBias = 0.35 + FlxG.random.float() * 0.65;
				var ox = cx + Std.int((rW / 2) * Math.cos(angle) * edgeBias) + Std.int((FlxG.random.float() - 0.5) * 4);
				var oy = cy + Std.int((rH / 2) * Math.sin(angle) * edgeBias) + Std.int((FlxG.random.float() - 0.5) * 4);
				var maxRad = Math.max(2, Std.int(Math.min(rW, rH) * (0.20 + FlxG.random.float() * 0.55)));

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

			if (FlxG.random.float() < 0.18 && depth < 4)
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
				var a = node.left.roomCenter;
				var b = node.right.roomCenter;
				if (a != null && b != null)
				{
					var w = Std.int(3 + Std.int(FlxG.random.float() * 9));
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

		walkableTiles = [];
		for (yy in 0...totalH)
			for (xx in 0...totalW)
				if (M[yy][xx] == 0)
					walkableTiles.push(yy * totalW + xx);

		var csv:String = FlxCaveGenerator.convertMatrixToString(M);
		this.loadMapFromCSV(csv, "assets/images/autotiles.png", TILE_SIZE, TILE_SIZE, FlxTilemapAutoTiling.AUTO);
	}
}

class RoomInfo
{
	public var tiles:Array<Dynamic>;
	public var area:Int;
	public var centroid:Dynamic;
	public var bbox:Dynamic;
	public var isCorridor:Bool;

	public function new(tiles:Array<Dynamic>, area:Int, centroid:Dynamic, bbox:Dynamic, isCorridor:Bool)
	{
		this.tiles = tiles;
		this.area = area;
		this.centroid = centroid;
		this.bbox = bbox;
		this.isCorridor = isCorridor;
	}
}
