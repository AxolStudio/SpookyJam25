package shaders;

import flixel.math.FlxMath;
import flixel.system.FlxAssets.FlxShader;

@:keep
class HueShift extends FlxShader
{
	public var hue(default, set):Float = 0.0; // degrees 0..359

	@:glFragmentSource('
        #pragma header
        uniform float fHue; // 0..1

        vec3 rgb2hsv(vec3 c){
            vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
            vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
            vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
            float d = q.x - min(q.w, q.y);
            float e = 1.0e-10;
            return vec3(abs((q.w - q.y) / (6.0 * d + e) + q.z), d / (q.x + e), q.x);
        }

        vec3 hsv2rgb(vec3 c){
            vec3 K = vec3(1.0, 2.0/3.0, 1.0/3.0);
            vec3 p = abs(fract(c.xxx + K) * 6.0 - 3.0);
            return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
        }

        void main(){
            vec2 uv = openfl_TextureCoordv;
            vec4 src = flixel_texture2D(bitmap, uv);
            // preserve alpha
            if (src.a <= 0.0) {
                gl_FragColor = src;
                return;
            }

            vec3 hsv = rgb2hsv(src.rgb);
            // rotate hue (fHue in 0..1)
            hsv.x = fract(hsv.x + fHue);
            vec3 rgb = hsv2rgb(hsv);
            // premultiplied output
            gl_FragColor = vec4(rgb * src.a, src.a);
        }
    ')
	public function new()
	{
		super();
		try
		{
			hue = 0.0;
		}
		catch (e:Dynamic) {}
	}

	private function set_hue(v:Float):Float
	{
		// wrap in floating space
		var hv:Float = v % 360.0;
		if (hv < 0.0)
			hv += 360.0;
		hue = hv;
		try
		{
			fHue.value = [hue / 360.0];
		}
		catch (e:Dynamic) {}
		return hue;
	}
}
