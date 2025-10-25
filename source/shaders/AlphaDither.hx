package shaders;

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.system.FlxAssets.FlxShader;

@:keep
class AlphaDither extends FlxShader
{
	// Global alpha controlled from Haxe (tween this to fade)
	public var globalAlpha(default, set):Float = 1.0;

	// Game virtual size (FlxG.width, FlxG.height) - used to compute pixel coords
	public var size(default, set):Array<Float> = [FlxG.width, FlxG.height];

	@:glFragmentSource('
    #pragma header
    uniform vec2 fSize;
    uniform float fGlobalAlpha;

    void main(){
        vec2 uv = openfl_TextureCoordv;
        vec4 src = flixel_texture2D(bitmap, uv);

        float desired = src.a * fGlobalAlpha;
        if (desired <= 0.0) {
            gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
            return;
        }

		vec2 pixelIndex = floor(uv * fSize);
		int ix = int(mod(pixelIndex.x, 8.0));
		int iy = int(mod(pixelIndex.y, 8.0));

		// 8x8 Bayer thresholds (values 0..63) converted to 0..1 by /64.0
		float ditherValue = 0.0;
		if (ix == 0) {
			if (iy == 0) ditherValue = (0.0 + 0.5) / 64.0;
			else if (iy == 1) ditherValue = (48.0 + 0.5) / 64.0;
			else if (iy == 2) ditherValue = (12.0 + 0.5) / 64.0;
			else if (iy == 3) ditherValue = (60.0 + 0.5) / 64.0;
			else if (iy == 4) ditherValue = (3.0 + 0.5) / 64.0;
			else if (iy == 5) ditherValue = (51.0 + 0.5) / 64.0;
			else if (iy == 6) ditherValue = (15.0 + 0.5) / 64.0;
			else ditherValue = (63.0 + 0.5) / 64.0;
		} else if (ix == 1) {
			if (iy == 0) ditherValue = (32.0 + 0.5) / 64.0;
			else if (iy == 1) ditherValue = (16.0 + 0.5) / 64.0;
			else if (iy == 2) ditherValue = (44.0 + 0.5) / 64.0;
			else if (iy == 3) ditherValue = (28.0 + 0.5) / 64.0;
			else if (iy == 4) ditherValue = (35.0 + 0.5) / 64.0;
			else if (iy == 5) ditherValue = (19.0 + 0.5) / 64.0;
			else if (iy == 6) ditherValue = (47.0 + 0.5) / 64.0;
			else ditherValue = (31.0 + 0.5) / 64.0;
		} else if (ix == 2) {
			if (iy == 0) ditherValue = (8.0 + 0.5) / 64.0;
			else if (iy == 1) ditherValue = (56.0 + 0.5) / 64.0;
			else if (iy == 2) ditherValue = (4.0 + 0.5) / 64.0;
			else if (iy == 3) ditherValue = (52.0 + 0.5) / 64.0;
			else if (iy == 4) ditherValue = (11.0 + 0.5) / 64.0;
			else if (iy == 5) ditherValue = (59.0 + 0.5) / 64.0;
			else if (iy == 6) ditherValue = (7.0 + 0.5) / 64.0;
			else ditherValue = (55.0 + 0.5) / 64.0;
		} else if (ix == 3) {
			if (iy == 0) ditherValue = (40.0 + 0.5) / 64.0;
			else if (iy == 1) ditherValue = (24.0 + 0.5) / 64.0;
			else if (iy == 2) ditherValue = (36.0 + 0.5) / 64.0;
			else if (iy == 3) ditherValue = (20.0 + 0.5) / 64.0;
			else if (iy == 4) ditherValue = (43.0 + 0.5) / 64.0;
			else if (iy == 5) ditherValue = (27.0 + 0.5) / 64.0;
			else if (iy == 6) ditherValue = (39.0 + 0.5) / 64.0;
			else ditherValue = (23.0 + 0.5) / 64.0;
		} else if (ix == 4) {
			if (iy == 0) ditherValue = (2.0 + 0.5) / 64.0;
			else if (iy == 1) ditherValue = (50.0 + 0.5) / 64.0;
			else if (iy == 2) ditherValue = (14.0 + 0.5) / 64.0;
			else if (iy == 3) ditherValue = (62.0 + 0.5) / 64.0;
			else if (iy == 4) ditherValue = (1.0 + 0.5) / 64.0;
			else if (iy == 5) ditherValue = (49.0 + 0.5) / 64.0;
			else if (iy == 6) ditherValue = (13.0 + 0.5) / 64.0;
			else ditherValue = (61.0 + 0.5) / 64.0;
		} else if (ix == 5) {
			if (iy == 0) ditherValue = (34.0 + 0.5) / 64.0;
			else if (iy == 1) ditherValue = (18.0 + 0.5) / 64.0;
			else if (iy == 2) ditherValue = (46.0 + 0.5) / 64.0;
			else if (iy == 3) ditherValue = (30.0 + 0.5) / 64.0;
			else if (iy == 4) ditherValue = (33.0 + 0.5) / 64.0;
			else if (iy == 5) ditherValue = (17.0 + 0.5) / 64.0;
			else if (iy == 6) ditherValue = (45.0 + 0.5) / 64.0;
			else ditherValue = (29.0 + 0.5) / 64.0;
		} else if (ix == 6) {
			if (iy == 0) ditherValue = (10.0 + 0.5) / 64.0;
			else if (iy == 1) ditherValue = (58.0 + 0.5) / 64.0;
			else if (iy == 2) ditherValue = (6.0 + 0.5) / 64.0;
			else if (iy == 3) ditherValue = (54.0 + 0.5) / 64.0;
			else if (iy == 4) ditherValue = (9.0 + 0.5) / 64.0;
			else if (iy == 5) ditherValue = (57.0 + 0.5) / 64.0;
			else if (iy == 6) ditherValue = (5.0 + 0.5) / 64.0;
			else ditherValue = (53.0 + 0.5) / 64.0;
		} else {
			if (iy == 0) ditherValue = (42.0 + 0.5) / 64.0;
			else if (iy == 1) ditherValue = (26.0 + 0.5) / 64.0;
			else if (iy == 2) ditherValue = (38.0 + 0.5) / 64.0;
			else if (iy == 3) ditherValue = (22.0 + 0.5) / 64.0;
			else if (iy == 4) ditherValue = (41.0 + 0.5) / 64.0;
			else if (iy == 5) ditherValue = (25.0 + 0.5) / 64.0;
			else if (iy == 6) ditherValue = (37.0 + 0.5) / 64.0;
			else ditherValue = (21.0 + 0.5) / 64.0;
		}

        float outAlpha = desired > ditherValue ? 1.0 : 0.0;
        gl_FragColor = vec4(src.rgb * outAlpha, outAlpha);
    }
    ')
	public function new()
	{
		super();
		try
		{
			globalAlpha = 1.0;
		}
		catch (e:Dynamic) {}
		try
		{
			size = [FlxG.width, FlxG.height];
		}
		catch (e:Dynamic) {}
	}

	private function set_globalAlpha(v:Float):Float
	{
		globalAlpha = FlxMath.bound(v, 0.0, 1.0);
		try
		{
			fGlobalAlpha.value = [globalAlpha];
		}
		catch (e:Dynamic) {}
		return globalAlpha;
	}

	private function set_size(v:Array<Float>):Array<Float>
	{
		size = v;
		try
		{
			fSize.value = [size[0], size[1]];
		}
		catch (e:Dynamic) {}
		return size;
	}
}
