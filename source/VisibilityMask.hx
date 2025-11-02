package;

import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.geom.Point;
import flixel.FlxCamera;

class VisibilityMask
{
	public var tileGrid:Array<Array<Int>>;
	public var tileSize:Int;
	public var map:GameMap;
	public var maskScale:Float = 0.25;
	public var debug:Bool = false;

	public var blurRadiusFull:Int = 16;


	private static var _bayer8:Array<Int> = null;

	public function destroy():Void
	{
		map = null;
	}

	private static function getBayer8():Array<Int>
	{
		if (_bayer8 == null)
		{
			_bayer8 = [
				 0, 48, 12, 60,  3, 51, 15, 63,
				32, 16, 44, 28, 35, 19, 47, 31,
				 8, 56,  4, 52, 11, 59,  7, 55,
				40, 24, 36, 20, 43, 27, 39, 23,
				 2, 50, 14, 62,  1, 49, 13, 61,
				34, 18, 46, 30, 33, 17, 45, 29,
				10, 58,  6, 54,  9, 57,  5, 53,
				42, 26, 38, 22, 41, 25, 37, 21
			];
		}
		return _bayer8;
	}


	private var _cachedBmp:BitmapData = null;
	private var _lastPlayerX:Float = -1e9;
	private var _lastPlayerY:Float = -1e9;
	private var _lastCamX:Float = -1e9;
	private var _lastCamY:Float = -1e9;
	private var _lastMaskScale:Float = -1.0;
	private var _lastBlurRadiusFull:Int = -1;


	public function setRevealPixels(px:Int):Void
	{
		this.blurRadiusFull = px;

		if (_cachedBmp != null)
		{
			_cachedBmp.dispose();
			_cachedBmp = null;
		}
	}

	public function new(tileGrid:Array<Array<Int>>, tileSize:Int, ?maskScale:Float, ?debug:Bool, ?map:GameMap)
	{
		this.tileGrid = (tileGrid == null) ? [] : tileGrid;
		this.tileSize = tileSize;
		if (maskScale != null)
			this.maskScale = maskScale;
		if (debug != null)
			this.debug = debug;
		this.map = map;
	}

	public function buildMask(cam:FlxCamera, worldPlayerX:Float, worldPlayerY:Float):BitmapData
	{
		var w:Int = Std.int(cam.width * maskScale);
		var h:Int = Std.int(cam.height * maskScale);
		if (w <= 0)
			w = 1;
		if (h <= 0)
			h = 1;
		var bmp:BitmapData = new BitmapData(w, h, true, 0x00000000);


		var playerScreenFullX:Float = (worldPlayerX - cam.scroll.x);
		var playerScreenFullY:Float = (worldPlayerY - cam.scroll.y);


		if (_cachedBmp != null && _lastPlayerX == worldPlayerX && _lastPlayerY == worldPlayerY && _lastCamX == cam.scroll.x && _lastCamY == cam.scroll.y
			&& _lastMaskScale == maskScale && _lastBlurRadiusFull == blurRadiusFull)
		{
			return _cachedBmp.clone();
		}


		var fullMin:Float = Math.min(cam.width, cam.height);
		var radiusFull:Float = fullMin * 0.33;
		if (radiusFull < 0)
			radiusFull = 0;
		var radiusScaled:Float = radiusFull * maskScale;
		var radiusSq:Float = radiusFull * radiusFull;


		function tileAtWorld(wx:Float, wy:Float):Int
		{
			var tx:Int = Std.int(Math.floor(wx / tileSize));
			var ty:Int = Std.int(Math.floor(wy / tileSize));
			var gridH:Int = tileGrid != null ? tileGrid.length : 0;
			if (ty < 0 || ty >= gridH)
				return 1;
			var row:Array<Int> = tileGrid[ty];
			if (row == null)
				return 1;
			var gridW:Int = row.length;
			if (tx < 0 || tx >= gridW)
				return 1;
			return row[tx];
		}


		function rayHitsWallTo(worldTx:Float, worldTy:Float):Bool
		{
			if (this.map != null)
				return !this.map.lineOfSight(worldPlayerX, worldPlayerY, worldTx, worldTy);

			var x0:Float = worldPlayerX;
			var y0:Float = worldPlayerY;
			var tx:Int = Std.int(Math.floor(x0 / tileSize));
			var ty:Int = Std.int(Math.floor(y0 / tileSize));
			var txEnd:Int = Std.int(Math.floor(worldTx / tileSize));
			var tyEnd:Int = Std.int(Math.floor(worldTy / tileSize));

			var dx:Float = worldTx - x0;
			var dy:Float = worldTy - y0;

			if (tx == txEnd && ty == tyEnd)
				return (tileAtWorld(worldTx, worldTy) == 1);

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
				var nextGridX:Float = (tx + (stepX > 0 ? 1 : 0)) * tileSize;
				tMaxX = Math.abs((nextGridX - x0) / dx);
				tDeltaX = Math.abs(tileSize / dx);
			}

			if (dy == 0)
			{
				tMaxY = 1e9;
				tDeltaY = 1e9;
			}
			else
			{
				var nextGridY:Float = (ty + (stepY > 0 ? 1 : 0)) * tileSize;
				tMaxY = Math.abs((nextGridY - y0) / dy);
				tDeltaY = Math.abs(tileSize / dy);
			}

			var gridH:Int = tileGrid != null ? tileGrid.length : 0;
			var gridW:Int = (gridH > 0 && tileGrid[0] != null) ? tileGrid[0].length : 0;

			var maxSteps:Int = 1024;
			while (maxSteps-- > 0)
			{
				if (tx < 0 || ty < 0 || ty >= gridH || tx >= gridW)
					return true;

				if (gridH > 0 && gridW > 0 && tileGrid[ty][tx] == 1)
					return true;

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

			return false;
		}


		var alpha:Array<Int> = [];
		alpha.resize(w * h);
		for (py in 0...h)
		{
			for (px in 0...w)
			{

				var screenXFull:Float = (px + 0.5) / maskScale;
				var screenYFull:Float = (py + 0.5) / maskScale;
				var worldX:Float = cam.scroll.x + screenXFull;
				var worldY:Float = cam.scroll.y + screenYFull;
				var blocked:Bool = rayHitsWallTo(worldX, worldY);
				alpha[py * w + px] = blocked ? 255 : 0;
			}
		}

		var circleRsq:Float = radiusSq;
		for (py in 0...h)
		{
			for (px in 0...w)
			{
				var screenXFull2:Float = (px + 0.5) / maskScale;
				var screenYFull2:Float = (py + 0.5) / maskScale;
				var dx:Float = screenXFull2 - playerScreenFullX;
				var dy:Float = screenYFull2 - playerScreenFullY;
				var insideCircle:Bool = (dx * dx + dy * dy <= circleRsq);
				var idx:Int = py * w + px;

				if (insideCircle && alpha[idx] == 0)
				{

					alpha[idx] = 0;
				}
				else
				{

					alpha[idx] = 255;
				}
			}
		}

		var outlineScreenPx:Int = 32;
		var outlineMaskPx:Int = Std.int(Math.max(1, Math.ceil(outlineScreenPx * maskScale)));
		if (outlineMaskPx > 0)
		{
			var maxIndex:Int = w * h;
			var dist:Array<Int> = [];
			dist.resize(maxIndex);
			for (i in 0...maxIndex)
				dist[i] = 0x3fffffff;
			var q:Array<Int> = [];

			for (i in 0...maxIndex)
			{
				if (alpha[i] == 0)
				{
					dist[i] = 0;
					q.push(i);
				}
			}

			var qHead:Int = 0;
			while (qHead < q.length)
			{
				var idx:Int = q[qHead++];
				var cx:Int = idx % w;
				var cy:Int = Std.int(idx / w);
				var cd:Int = dist[idx];
				if (cd >= outlineMaskPx)
					continue;

				if (cx > 0)
				{
					var n:Int = idx - 1;
					if (dist[n] > cd + 1)
					{
						dist[n] = cd + 1;
						q.push(n);
					}
				}
				if (cx < w - 1)
				{
					var n2:Int = idx + 1;
					if (dist[n2] > cd + 1)
					{
						dist[n2] = cd + 1;
						q.push(n2);
					}
				}
				if (cy > 0)
				{
					var n3:Int = idx - w;
					if (dist[n3] > cd + 1)
					{
						dist[n3] = cd + 1;
						q.push(n3);
					}
				}
				if (cy < h - 1)
				{
					var n4:Int = idx + w;
					if (dist[n4] > cd + 1)
					{
						dist[n4] = cd + 1;
						q.push(n4);
					}
				}
			}

			for (i in 0...maxIndex)
			{
				if (alpha[i] == 255 && dist[i] > 0 && dist[i] <= outlineMaskPx)
				{
					var ratio:Float = (cast dist[i] : Float) / outlineMaskPx;
					var a:Int = Std.int(ratio * 255.0);
					if (a < 0)
						a = 0;
					if (a > 255)
						a = 255;
					alpha[i] = a;
				}
			}
		}


		if (debug)
		{
			for (py in 0...h)
			{
				for (px in 0...w)
				{
					var a:Int = alpha[py * w + px];
					bmp.setPixel32(px, py, (a << 24));
				}
			}
			return bmp;
		}


		for (py in 0...h)
		{
			for (px in 0...w)
			{
				var idx = py * w + px;
				var aVal:Int = alpha[idx];
				bmp.setPixel32(px, py, (aVal << 24));
			}
		}


		if (_cachedBmp != null)
			_cachedBmp.dispose();
		_cachedBmp = bmp.clone();
		_lastPlayerX = worldPlayerX;
		_lastPlayerY = worldPlayerY;
		_lastCamX = cam.scroll.x;
		_lastCamY = cam.scroll.y;
		_lastMaskScale = maskScale;
		_lastBlurRadiusFull = blurRadiusFull;

		return bmp;
	}
}
