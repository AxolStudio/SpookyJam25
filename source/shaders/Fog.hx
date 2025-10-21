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

	public var maskTexelX(default, set):Float = 0.0;
	public var maskTexelY(default, set):Float = 0.0;

	private function set_maskTexelX(v:Float):Float
	{
		maskTexelX = v;
		try
		{
			mTexelX.value = [maskTexelX];
		}
		catch (e:Dynamic) {}
		return maskTexelX;
	}

	private function set_maskTexelY(v:Float):Float
	{
		maskTexelY = v;
		try
		{
			mTexelY.value = [maskTexelY];
		}
		catch (e:Dynamic) {}
		return maskTexelY;
	}

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

	uniform float mTexelX;
	uniform float mTexelY;

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

		// fractal noise (FBM) - 3 octaves for lower ALU cost
		float fbm(vec2 p){
				float v = 0.0;
				float amp = 0.5;
				// unrolled 3-octave FBM
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

			// Sample CPU mask which now provides smooth alpha (0..1)
			vec4 maskSample = flixel_texture2D(bitmap, uv);
			float maskAlpha = maskSample.a;
			// compute desired alpha from CPU mask only (mask already encodes the circular hole)
			float desiredAlpha = maskAlpha;
			// If fully inside or outside, skip dithering
			if (desiredAlpha <= 0.0) {
				gl_FragColor = vec4(vec3(0.0), 0.0);
				return;
			}
			if (desiredAlpha >= 1.0) {
				vec3 finalColor = fogCol * mix(0.9, 1.05, clouds);
				gl_FragColor = vec4(finalColor, 1.0);
				return;
			}

			// compute mask-space pixel coordinates so dither matches mask texel size
			vec2 maskPosF = floor(uv / vec2(mTexelX, mTexelY));
			int bx = int(mod(maskPosF.x, 8.0));
			int by = int(mod(maskPosF.y, 8.0));
			int idx = bx + by * 8;
			int thr = 0;
			// 8x8 Bayer mapping (values 0..63)
			if (idx == 0) thr = 0; else if (idx == 1) thr = 48; else if (idx == 2) thr = 12; else if (idx == 3) thr = 60; else if (idx == 4) thr = 3; else if (idx == 5) thr = 51; else if (idx == 6) thr = 15; else if (idx == 7) thr = 63;
			else if (idx == 8) thr = 32; else if (idx == 9) thr = 16; else if (idx == 10) thr = 44; else if (idx == 11) thr = 28; else if (idx == 12) thr = 35; else if (idx == 13) thr = 19; else if (idx == 14) thr = 47; else if (idx == 15) thr = 31;
			else if (idx == 16) thr = 8; else if (idx == 17) thr = 56; else if (idx == 18) thr = 4; else if (idx == 19) thr = 52; else if (idx == 20) thr = 11; else if (idx == 21) thr = 59; else if (idx == 22) thr = 7; else if (idx == 23) thr = 55;
			else if (idx == 24) thr = 40; else if (idx == 25) thr = 24; else if (idx == 26) thr = 36; else if (idx == 27) thr = 20; else if (idx == 28) thr = 43; else if (idx == 29) thr = 27; else if (idx == 30) thr = 39; else if (idx == 31) thr = 23;
			else if (idx == 32) thr = 2; else if (idx == 33) thr = 50; else if (idx == 34) thr = 14; else if (idx == 35) thr = 62; else if (idx == 36) thr = 1; else if (idx == 37) thr = 49; else if (idx == 38) thr = 13; else if (idx == 39) thr = 61;
			else if (idx == 40) thr = 34; else if (idx == 41) thr = 18; else if (idx == 42) thr = 46; else if (idx == 43) thr = 30; else if (idx == 44) thr = 33; else if (idx == 45) thr = 17; else if (idx == 46) thr = 45; else if (idx == 47) thr = 29;
			else if (idx == 48) thr = 10; else if (idx == 49) thr = 58; else if (idx == 50) thr = 6; else if (idx == 51) thr = 54; else if (idx == 52) thr = 9; else if (idx == 53) thr = 57; else if (idx == 54) thr = 5; else if (idx == 55) thr = 53;
			else if (idx == 56) thr = 42; else if (idx == 57) thr = 26; else if (idx == 58) thr = 38; else if (idx == 59) thr = 22; else if (idx == 60) thr = 41; else if (idx == 61) thr = 25; else if (idx == 62) thr = 37; else if (idx == 63) thr = 21;
			float threshold = (float(thr) + 0.5) / 64.0;

			float outAlpha = desiredAlpha > threshold ? 1.0 : 0.0;
			vec3 finalColor = fogCol * mix(0.9, 1.05, clouds);
			gl_FragColor = vec4(finalColor * outAlpha, outAlpha);
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
		hue = v;
		fHue.value = [hue / 360.0];

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
