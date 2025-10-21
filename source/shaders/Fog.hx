package shaders;

import flixel.math.FlxMath;
import flixel.system.FlxAssets.FlxShader;

@:keep
class Fog extends FlxShader
{
	public var time(default, set):Float = 0.0;
	public var hue(default, set):Float = 0.0; // degrees 0..359
	public var sat(default, set):Float = 0.5; // 0..1
	public var vDark(default, set):Float = 0.10;
	public var vLight(default, set):Float = 0.40;
	public var playerX(default, set):Float = 0.0; // screen-space 0..1
	public var playerY(default, set):Float = 0.0; // screen-space 0..1
	public var innerRadius(default, set):Float = 0.0; // in screen 0..1 (fraction of smaller dimension)
	public var outerRadius(default, set):Float = 0.0;

	@:glFragmentSource('
	#pragma header
	uniform float iTime;
	uniform float fHue; // 0..1
	uniform float fSat; // saturation 0..1
	uniform float fVDark; // value (brightness) for dark fog 0..1
	uniform float fVLight; // value for light fog 0..1

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

		// convert HSV (h 0..1, s 0..1, v 0..1) to RGB
		vec3 hsv2rgb(vec3 c){
			float h = c.x;
			float s = c.y;
			float v = c.z;
			if (s <= 0.0) return vec3(v, v, v);
			float hh = fract(h) * 6.0;
			float i = floor(hh);
			float f = hh - i;
			float p = v * (1.0 - s);
			float q = v * (1.0 - s * f);
			float t = v * (1.0 - s * (1.0 - f));
			if (i < 1.0) return vec3(v, t, p);
			else if (i < 2.0) return vec3(q, v, p);
			else if (i < 3.0) return vec3(p, v, t);
			else if (i < 4.0) return vec3(p, q, v);
			else if (i < 5.0) return vec3(t, p, v);
			return vec3(v, p, q);
		}

        void main(){
            vec2 uv = openfl_TextureCoordv;
            // generate noise in world-space by scaling UV
            float aspect = 1.0; // screen aspect handled by main
			// world-space noise with slow motion
			vec2 npos = uv * vec2(1.2, 1.2);
			npos += vec2(iTime * 0.04, iTime * 0.03);
			float clouds = fbm(npos * 2.0);

			// compute fog colors using the same base hue (atmosphereHue) but in HSV
			// so hue mapping matches the tile recolor algorithm more closely.
			float h = fHue; // 0..1 (same hue as tilemap/floor/walls)
			float sat = fSat; // uniform-set saturation
			float vDark = fVDark;
			float vLight = fVLight;
			vec3 darkCol = hsv2rgb(vec3(h, sat, vDark));
			vec3 lightCol = hsv2rgb(vec3(h, sat, vLight));
			// blend between dark and light based on cloud noise (so clouds brighten/darken)
			vec3 fogCol = mix(darkCol, lightCol, clouds);

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

			// Use the CPU-generated visibility mask alpha directly (legacy behavior):
			// maskSample.a == 1.0 means fog/opaque, 0.0 means visible. The mask already
			// encodes the circular hole in VisibilityMask.buildMask(), so sample it.
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
		try
		{
			sat = 0.5;
			vDark = 0.10;
			vLight = 0.40;
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

	private function set_sat(v:Float):Float
	{
		sat = v;
		try
		{
			fSat.value = [sat];
		}
		catch (e:Dynamic) {}
		return sat;
	}

	private function set_vDark(v:Float):Float
	{
		vDark = v;
		try
		{
			fVDark.value = [vDark];
		}
		catch (e:Dynamic) {}
		return vDark;
	}

	private function set_vLight(v:Float):Float
	{
		vLight = v;
		try
		{
			fVLight.value = [vLight];
		}
		catch (e:Dynamic) {}
		return vLight;
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
