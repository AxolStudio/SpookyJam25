package shaders;

import flixel.math.FlxMath;
import flixel.system.FlxAssets.FlxShader;

@:keep
class Fog extends FlxShader
{
	public var time(default, set):Float = 0.0;
	public var hue(default, set):Float = 0.0; // degrees 0..359
	public var playerX(default, set):Float = 0.0; // screen-space 0..1
	public var playerY(default, set):Float = 0.0; // screen-space 0..1
	public var innerRadius(default, set):Float = 0.0; // in screen 0..1 (fraction of smaller dimension)
	public var outerRadius(default, set):Float = 0.0;

	@:glFragmentSource('
        #pragma header
        uniform float iTime;
        uniform float fHue; // 0..1
	uniform float pX;
	uniform float pY;
	uniform float sX; // scale x = cam.width / camMin
	uniform float sY; // scale y = cam.height / camMin
        uniform float rInner;
        uniform float rOuter;

        // simple hash
        float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453123); }
        // value noise
        float noise(vec2 p){
            vec2 i = floor(p);
            vec2 f = fract(p);
            float a = hash(i);
            float b = hash(i + vec2(1.0, 0.0));
            float c = hash(i + vec2(0.0, 1.0));
            float d = hash(i + vec2(1.0, 1.0));
            vec2 u = f * f * (3.0 - 2.0 * f);
            return mix(a, b, u.x) + (c - a)*u.y*(1.0 - u.x) + (d - b)*u.x*u.y;
        }

        // fractal noise (FBM)
        float fbm(vec2 p){
                float v = 0.0;
                float amp = 0.5;
                // unrolled 4-octave FBM
                v += amp * noise(p);
                p *= 2.0; amp *= 0.5;
                v += amp * noise(p);
                p *= 2.0; amp *= 0.5;
                v += amp * noise(p);
                p *= 2.0; amp *= 0.5;
                v += amp * noise(p);
            return v;
        }

		// convert HSL (h 0..1, s 0..1, l 0..1) to RGB
		float hue2rgb(float p, float q, float t){
			if (t < 0.0) t += 1.0;
			if (t > 1.0) t -= 1.0;
			if (t < 1.0/6.0) return p + (q - p) * 6.0 * t;
			if (t < 1.0/2.0) return q;
			if (t < 2.0/3.0) return p + (q - p) * (2.0/3.0 - t) * 6.0;
			return p;
		}
		vec3 hsl2rgb(vec3 c){
			float h = c.x;
			float s = c.y;
			float l = c.z;
			if (s == 0.0) return vec3(l, l, l);
			float q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
			float p = 2.0 * l - q;
			float r = hue2rgb(p, q, h + 1.0/3.0);
			float g = hue2rgb(p, q, h);
			float b = hue2rgb(p, q, h - 1.0/3.0);
			return vec3(r, g, b);
		}

        void main(){
            vec2 uv = openfl_TextureCoordv;
            // generate noise in world-space by scaling UV
            float aspect = 1.0; // screen aspect handled by main
			// world-space noise with slow motion
			vec2 npos = uv * vec2(1.2, 1.2);
			npos += vec2(iTime * 0.04, iTime * 0.03);
			float clouds = fbm(npos * 2.0);

			// compute hue shift +/-5 degrees and lightness between 6%..14% (HSL)
			float h = fHue; // 0..1
			float hueShift = h + ((clouds * 10.0) - 5.0) / 360.0;
			hueShift = fract(hueShift);
			// use a wider lightness range to make fog color more visible (5%..20%)
			float lightness = mix(0.05, 0.20, clouds);
			float saturation = 0.5;
			// convert from HSL to RGB for correct perceived lightness
			vec3 fogCol = hsl2rgb(vec3(hueShift, saturation, lightness));

            // player-centered cutout
            vec2 p = vec2(pX, pY);
            // compute screen-space scaled radius (we consider 0..1 space where 1 is min(width,height))
			// account for non-square viewport so the hole is circular in pixel space
			vec2 d = vec2((uv.x - p.x) * sX, (uv.y - p.y) * sY);
			float dist = length(d);

            float inner = rInner;
            float outer = rOuter;
            float hole = 0.0;
            if (dist <= inner) {
                hole = 0.0; // fully transparent here
            } else if (dist >= outer) {
                hole = 1.0; // fully fog
            } else {
                float t = smoothstep(inner, outer, dist);
                // ensure 2/3 center fully transparent by making inner smaller than outer*2/3 from caller
                hole = t;
            }

			// For walls-only debug: use mask alpha exclusively (ignore circular hole)
			vec4 maskSample = flixel_texture2D(bitmap, uv);
			float finalAlpha = maskSample.a;
			// Use fog color modulated by clouds
			vec3 finalColor = fogCol * mix(0.9, 1.05, clouds);

			// Output premultiplied alpha so we fully occlude where alpha==1
			gl_FragColor = vec4(finalColor * finalAlpha, finalAlpha);
        }
    ')
	public function new()
	{
		super();
		try
		{
			time = 0.0;
		}
		catch (e:Dynamic) {}
		try
		{
			hue = 0.0;
		}
		catch (e:Dynamic) {}
		try
		{
			playerX = 0.5;
			playerY = 0.5;
		}
		catch (e:Dynamic) {}
		try
		{
			innerRadius = 0.15;
			outerRadius = 0.30;
		}
		catch (e:Dynamic) {}
	}

	private function set_time(v:Float):Float
	{
		time = v;
		try
		{
			iTime.value = [time];
		}
		catch (e:Dynamic) {}
		return time;
	}

	private function set_hue(v:Float):Float
	{
		var hv:Float = v % 360.0;
		if (hv < 0)
			hv += 360.0;
		hue = hv;
		try
		{
			fHue.value = [hue / 360.0];
		}
		catch (e:Dynamic) {}
		return hue;
	}

	private function set_playerX(v:Float):Float
	{
		playerX = v;
		try
		{
			pX.value = [playerX];
		}
		catch (e:Dynamic) {}
		return playerX;
	}

	private function set_playerY(v:Float):Float
	{
		playerY = v;
		try
		{
			pY.value = [playerY];
		}
		catch (e:Dynamic) {}
		return playerY;
	}

	private function set_innerRadius(v:Float):Float
	{
		innerRadius = v;
		try
		{
			rInner.value = [innerRadius];
		}
		catch (e:Dynamic) {}
		return innerRadius;
	}

	private function set_outerRadius(v:Float):Float
	{
		outerRadius = v;
		try
		{
			rOuter.value = [outerRadius];
		}
		catch (e:Dynamic) {}
		return outerRadius;
	}

	// scale setters (for non-square viewports)
	public var scaleX(default, set):Float = 1.0;
	public var scaleY(default, set):Float = 1.0;

	private function set_scaleX(v:Float):Float
	{
		scaleX = v;
		try
		{
			sX.value = [scaleX];
		}
		catch (e:Dynamic) {}
		return scaleX;
	}

	private function set_scaleY(v:Float):Float
	{
		scaleY = v;
		try
		{
			sY.value = [scaleY];
		}
		catch (e:Dynamic) {}
		return scaleY;
	}
}
