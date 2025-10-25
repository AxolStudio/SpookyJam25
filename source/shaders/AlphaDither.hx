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
        int ix = int(mod(pixelIndex.x, 4.0));
        int iy = int(mod(pixelIndex.y, 4.0));

		// 4x4 Bayer values (explicit nested if/else to avoid dynamic indexing)
		float ditherValue = 0.0;
		if (ix == 0) {
			if (iy == 0) ditherValue = 15.0/16.0;
			else if (iy == 1) ditherValue = 7.0/16.0;
			else if (iy == 2) ditherValue = 13.0/16.0;
			else ditherValue = 5.0/16.0;
		} else if (ix == 1) {
			if (iy == 0) ditherValue = 3.0/16.0;
			else if (iy == 1) ditherValue = 11.0/16.0;
			else if (iy == 2) ditherValue = 1.0/16.0;
			else ditherValue = 9.0/16.0;
		} else if (ix == 2) {
			if (iy == 0) ditherValue = 14.0/16.0;
			else if (iy == 1) ditherValue = 6.0/16.0;
			else if (iy == 2) ditherValue = 12.0/16.0;
			else ditherValue = 4.0/16.0;
		} else {
			if (iy == 0) ditherValue = 2.0/16.0;
			else if (iy == 1) ditherValue = 10.0/16.0;
			else if (iy == 2) ditherValue = 0.0;
			else ditherValue = 8.0/16.0;
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
