package shaders;

import openfl.display.BitmapData;
import openfl.geom.Matrix;

class VisibilityHelpers
{
	// Scale a low-res mask bitmap into a full-size bitmap using the mask's scale.
	public static function scaleMaskTo(fullW:Int, fullH:Int, bmp:BitmapData, maskScale:Float):BitmapData
	{
		var full = new BitmapData(fullW, fullH, true, 0x00000000);
		full.draw(bmp, new Matrix(1 / maskScale, 0, 0, 1 / maskScale), null, null, null, false);
		return full;
	}

	// Set mask texel uniforms on the fog shader safely.
	public static function setFogMaskTexel(f:Fog, bmp:BitmapData):Void
	{
		try
		{
			if (f != null && bmp != null)
			{
				f.maskTexelX = 1.0 / bmp.width;
				f.maskTexelY = 1.0 / bmp.height;
			}
		}
		catch (e:Dynamic) {}
	}
}
