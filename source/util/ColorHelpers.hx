package util;

import flixel.util.typeLimit.OneOfTwo;
import openfl.display.BitmapData;
import openfl.geom.Point;
import flixel.FlxG;
import flixel.system.FlxAssets;

class ColorHelpers
{
	public static function getHueColoredBmp(Source:OneOfTwo<String, BitmapData>, hue:Int):BitmapData
	{
		var src:BitmapData;
		if (Std.is(Source, String))
			src = FlxAssets.getBitmapData(cast Source);
		else
			src = (cast Source).clone();

		var result:BitmapData = new BitmapData(src.width, src.height, true, 0x00000000);
		result.copyPixels(src, src.rect, new Point(0, 0));

		var sat:Float = 0.7;
		var vLight:Float = 0.60;
		var vDark:Float = 0.18;
		var hn:Float = (hue % 360) / 360.0;

		for (yy in 0...result.height)
		{
			for (xx in 0...result.width)
			{
				var px:Int = src.getPixel32(xx, yy);
				var a:Int = (px >> 24) & 0xFF;
				if (a == 0)
					continue;
				var r:Int = (px >> 16) & 0xFF;
				var g:Int = (px >> 8) & 0xFF;
				var b:Int = px & 0xFF;
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

	/**
	 * Version with luminance boost for Shiny enemies
	 */
	public static function getHueColoredBmpBright(Source:OneOfTwo<String, BitmapData>, hue:Int, lumBoost:Float = 0.0):BitmapData
	{
		var src:BitmapData;
		if (Std.is(Source, String))
			src = FlxAssets.getBitmapData(cast Source);
		else
			src = (cast Source).clone();

		var result:BitmapData = new BitmapData(src.width, src.height, true, 0x00000000);
		result.copyPixels(src, src.rect, new Point(0, 0));

		var sat:Float = 1.0;
		var vLight:Float = 0.90 + lumBoost;
		var vDark:Float = 0.40 + lumBoost;
		var hn:Float = (hue % 360) / 360.0;

		for (yy in 0...result.height)
		{
			for (xx in 0...result.width)
			{
				var px:Int = src.getPixel32(xx, yy);
				var a:Int = (px >> 24) & 0xFF;
				if (a == 0)
					continue;
				var r:Int = (px >> 16) & 0xFF;
				var g:Int = (px >> 8) & 0xFF;
				var b:Int = px & 0xFF;
				var vf:Float = Math.max(r / 255.0, Math.max(g / 255.0, b / 255.0));
				var v:Float = Math.min(1.0, vDark + vf * (vLight - vDark));

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
}
