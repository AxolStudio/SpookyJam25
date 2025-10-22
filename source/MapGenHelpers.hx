package;

import flixel.FlxG;
import Types.TileCoord;

class MapGenHelpers
{
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
		MapGenHelpers.carveCrooked(M, x1, y1, mxi, myi, width, depth + 1);
		MapGenHelpers.carveCrooked(M, mxi, myi, x2, y2, width, depth + 1);

		if (FlxG.random.float() < 0.55 && depth < 7)
		{
			var bx = Std.int(mxi + (FlxG.random.float() - 0.5) * dist * 0.5);
			var by = Std.int(myi + (FlxG.random.float() - 0.5) * dist * 0.5);
			var bw = Std.int(2 + Std.int(FlxG.random.float() * 3));
			MapGenHelpers.carveCrooked(M, mxi, myi, bx, by, bw, depth + 1);
		}
	}

	public static function findCenter(node:Dynamic):TileCoord
	{
		if (node == null)
			return null;
		if (node.roomCenter != null)
			return node.roomCenter;
		var l:TileCoord = MapGenHelpers.findCenter(node.left);
		if (l != null)
			return l;
		return MapGenHelpers.findCenter(node.right);
	}

	public static function connectNode(M:Array<Array<Int>>, node:Dynamic):Void
	{
		if (node == null)
			return;
		if (node.left != null && node.right != null)
		{
			var a:TileCoord = MapGenHelpers.findCenter(node.left);
			var b:TileCoord = MapGenHelpers.findCenter(node.right);
			if (a != null && b != null)
			{
				var w = Std.int(3 + Std.int(FlxG.random.float() * 6));
				MapGenHelpers.carveCrooked(M, a.x, a.y, b.x, b.y, w, 0);
			}
		}
		if (node.left != null)
			MapGenHelpers.connectNode(M, node.left);
		if (node.right != null)
			MapGenHelpers.connectNode(M, node.right);
	}
}
