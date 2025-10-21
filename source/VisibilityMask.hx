import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.geom.Point;
import flixel.FlxCamera;

class VisibilityMask
{
	public var tileGrid:Array<Array<Int>>;
	public var tileSize:Int;
	public var maskScale:Float = 0.25; // render mask at one-quarter resolution by default for perf
	public var debug:Bool = false;

	// configurable blur radius in full-resolution pixels (default 8). Set higher for stronger blur.
	// default reduced for cheaper blur; lower value tightens the soft band
	public var blurRadiusFull:Int = 16;

	// 8x8 Bayer matrix for ordered dithering of softened edges (values 0..63)
	private static var _bayer8:Array<Int> = null;

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

	// simple cache to avoid recomputing when player/camera don't move
	private var _cachedBmp:BitmapData = null;
	private var _lastPlayerX:Float = -1e9;
	private var _lastPlayerY:Float = -1e9;
	private var _lastCamX:Float = -1e9;
	private var _lastCamY:Float = -1e9;
	private var _lastMaskScale:Float = -1.0;
	private var _lastBlurRadiusFull:Int = -1;

	// Set how many full-resolution pixels of wall should remain revealed (inward fade radius).
	public function setRevealPixels(px:Int):Void
	{
		this.blurRadiusFull = px;
		// invalidate cache so next build recomputes with new radius
		if (_cachedBmp != null)
		{
			_cachedBmp.dispose();
			_cachedBmp = null;
		}
	}

	public function new(tileGrid:Array<Array<Int>>, tileSize:Int, ?maskScale:Float, ?debug:Bool)
	{
		this.tileGrid = tileGrid;
		this.tileSize = tileSize;
		if (maskScale != null)
			this.maskScale = maskScale;
		if (debug != null)
			this.debug = debug;
	}

	// worldPlayerX/Y are world coords in pixels; camera is FlxCamera for viewport transform
	// returns an openfl BitmapData with ARGB where alpha=255 means fog (opaque) and alpha=0 means visible
	public function buildMask(cam:FlxCamera, worldPlayerX:Float, worldPlayerY:Float):BitmapData
	{
		var w:Int = Std.int(cam.width * maskScale);
		var h:Int = Std.int(cam.height * maskScale);
		if (w <= 0)
			w = 1;
		if (h <= 0)
			h = 1;
		var bmp:BitmapData = new BitmapData(w, h, true, 0x00000000);

		// compute player position in full-resolution screen pixels (camera space)
		// Do NOT mix scaled and full coords — use full-res for distance checks and ray steps
		var playerScreenFullX:Float = (worldPlayerX - cam.scroll.x);
		var playerScreenFullY:Float = (worldPlayerY - cam.scroll.y);

		// simple cache: if nothing relevant changed, return cached BitmapData
		if (_cachedBmp != null && _lastPlayerX == worldPlayerX && _lastPlayerY == worldPlayerY && _lastCamX == cam.scroll.x && _lastCamY == cam.scroll.y
			&& _lastMaskScale == maskScale && _lastBlurRadiusFull == blurRadiusFull)
		{
			return _cachedBmp.clone(); // return a copy so callers can safely modify pixels if needed
		}

		// circle radius: use 40% of the min dimension, but reduce by 8 full-resolution pixels per request
		var fullMin:Float = Math.min(cam.width, cam.height);
		var radiusFull:Float = fullMin * 0.33;
		if (radiusFull < 0)
			radiusFull = 0;
		var radiusScaled:Float = radiusFull * maskScale;
		var radiusSq:Float = radiusFull * radiusFull; // use full-res radius for checks below

		// helper: get tile at world pixel coords, return 1=wall, 0=floor, out-of-bounds treated as wall
		function tileAtWorld(wx:Float, wy:Float):Int
		{
			var tx:Int = Std.int(Math.floor(wx / tileSize));
			var ty:Int = Std.int(Math.floor(wy / tileSize));
			if (ty < 0 || ty >= tileGrid.length)
				return 1;
			var row:Array<Int> = tileGrid[ty];
			if (tx < 0 || tx >= row.length)
				return 1;
			return row[tx];
		}

		// Ray/Tile intersection using Amanatides & Woo grid traversal (integer-robust)
		// worldTx/worldTy are world-space pixel coords
		function rayHitsWallTo(worldTx:Float, worldTy:Float):Bool
		{
			// start tile
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

			// traverse until reaching target tile or hitting a wall
			var maxSteps:Int = 1024; // safety
			while (maxSteps-- > 0)
			{
				if (tx < 0 || ty < 0 || ty >= tileGrid.length || tx >= tileGrid[0].length)
					return true; // out of bounds => treat as solid

				if (tileGrid[ty][tx] == 1)
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

		// first pass: binary mask (0 = visible, 255 = shadow)
		var alpha:Array<Int> = [];
		alpha.resize(w * h);
		for (py in 0...h)
		{
			for (px in 0...w)
			{
				// sample pixel center in full-resolution camera coordinates
				var screenXFull:Float = (px + 0.5) / maskScale;
				var screenYFull:Float = (py + 0.5) / maskScale;
				var worldX:Float = cam.scroll.x + screenXFull;
				var worldY:Float = cam.scroll.y + screenYFull;
				var blocked:Bool = rayHitsWallTo(worldX, worldY);
				alpha[py * w + px] = blocked ? 255 : 0;
			}
		}

		// Clamp visibility to a sharp player-centered circle: pixels are visible only if
		// (inside circle) AND (not blocked by walls). Everything else becomes shadow.
		var circleRsq:Float = radiusSq; // radiusFull * radiusFull computed earlier
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
				// alpha[idx] currently holds 0 for visible (ray not blocked) or 255 for blocked
				if (insideCircle && alpha[idx] == 0)
				{
					// remains visible
					alpha[idx] = 0;
				}
				else
				{
					// outside circle, or blocked inside circle -> shadow
					alpha[idx] = 255;
				}
			}
		}

		// If debug, return the raw binary mask (no softening)
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

		// Simple symmetric inward blur: use EDT to compute distance to nearest transparent pixel.
		var blurRadiusScaled:Int = Std.int(this.blurRadiusFull * maskScale);
		if (blurRadiusScaled < 1)
			blurRadiusScaled = 1;
		var r:Int = blurRadiusScaled;

		// compute distances (in pixels, scaled-to-mask units) using EDT
		var distArr:Array<Float> = VisibilityEDT.computeEDT(w, h, alpha);

		for (py in 0...h)
		{
			for (px in 0...w)
			{
				var idx = py * w + px;
				var aVal:Int = alpha[idx];
				if (aVal == 0)
				{
					bmp.setPixel32(px, py, 0x00000000);
					continue;
				}
				var d:Float = distArr[idx];
				// fully outside softened radius -> opaque
				if (d >= r)
				{
					bmp.setPixel32(px, py, (255 << 24));
					continue;
				}
				// strictly inside -> visible
				if (d <= 0)
				{
					bmp.setPixel32(px, py, 0x00000000);
					continue;
				}
				// in the softened band: compute smooth alpha (0..1) and encode it as 0..255
				var t:Float = d / r;
				// smootherstep inward fade
				t = t * t * (3.0 - 2.0 * t);
				var a:Int = Std.int(255.0 * t);
				if (a <= 0)
					bmp.setPixel32(px, py, 0x00000000);
				else
					bmp.setPixel32(px, py, (a << 24));
			}
		}

		// update cache
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
