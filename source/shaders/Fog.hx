package shaders;

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.system.FlxAssets.FlxShader;

@:keep
class Fog extends FlxShader
{
	public var time(default, set):Float = 0.0;
	public var hue(default, set):Float = 0.0;
	public var sat(default, set):Float = 0.5;
	public var vDark(default, set):Float = 0.25;
	public var vLight(default, set):Float = 0.30;
	public var playerX(default, set):Float = 0.0;
	public var playerY(default, set):Float = 0.0;
	public var innerRadius(default, set):Float = 0.0;
	public var outerRadius(default, set):Float = 0.0;

	public var maskTexelX(default, set):Float = 0.0;
	public var maskTexelY(default, set):Float = 0.0;

	public var scaleX(default, set):Float = 1.0;
	public var scaleY(default, set):Float = 1.0;
	public var contrast(default, set):Float = 0.15;
	public var useDither(default, set):Float = 1.0;
	@:glFragmentSource('
	#pragma header
	uniform float iTime;
	uniform float fHue;
	uniform float fSat;
	uniform float fVDark;
	uniform float fVLight;
	uniform float fContrast;

	uniform float pX;
	uniform float pY;
	uniform float sX;
	uniform float sY;

	uniform float rInner;
	uniform float rOuter;

	uniform float mTexelX;
	uniform float mTexelY;
    uniform float fUseDither;

        
        float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453123); }
        
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

        
		float fbm(vec2 p){
				float v = 0.0;
				float amp = 0.5;
                
				v += amp * noise(p);
				p *= 2.0; amp *= 0.5;
				v += amp * noise(p);
				p *= 2.0; amp *= 0.5;
				v += amp * noise(p);
			return v;
		}

        
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
            
			float aspect = 1.0;
            
			vec4 maskEarly = flixel_texture2D(bitmap, uv);
			float maskAlphaEarly = maskEarly.a;
			if (maskAlphaEarly <= 0.0) {
				gl_FragColor = vec4(vec3(0.0), 0.0);
				return;
			}

				vec2 npos = uv * vec2(1.2, 1.2);
				npos += vec2(iTime * 0.04, iTime * 0.03);
				vec2 swirl = vec2(sin(iTime * 0.23 + uv.y * 0.5), cos(iTime * 0.17 + uv.x * 0.5)) * 0.35;
				npos += swirl;
				float clouds = fbm(npos * 2.2);

				float h = fHue;
				float sat = fSat;
			float midV = (fVDark + fVLight) * 0.5;
			float vDarkMod = fVDark + 0.03 * sin(iTime * 0.6 + uv.x * 3.0);
			float vDarkC = mix(midV, vDarkMod, fContrast);
			float vLightC = mix(midV, fVLight, fContrast);
			float vDarkOrig = fVDark;
			float vLightOrig = fVLight;
			vec3 darkColOrig = hsv2rgb(vec3(h, sat, vDarkOrig));
			vec3 lightColOrig = hsv2rgb(vec3(h, sat, vLightOrig));
			vec3 darkColC = hsv2rgb(vec3(h, sat, vDarkC));
			vec3 lightColC = hsv2rgb(vec3(h, sat, vLightC));

			vec2 maskPosF = floor(uv / vec2(mTexelX, mTexelY));
			int bx = int(mod(maskPosF.x, 8.0));
			int by = int(mod(maskPosF.y, 8.0));
			int idx = bx + by * 8;
			int thr = 0;
			if (idx == 0) thr = 0; else if (idx == 1) thr = 48; else if (idx == 2) thr = 12; else if (idx == 3) thr = 60; else if (idx == 4) thr = 3; else if (idx == 5) thr = 51; else if (idx == 6) thr = 15; else if (idx == 7) thr = 63;
			else if (idx == 8) thr = 32; else if (idx == 9) thr = 16; else if (idx == 10) thr = 44; else if (idx == 11) thr = 28; else if (idx == 12) thr = 35; else if (idx == 13) thr = 19; else if (idx == 14) thr = 47; else if (idx == 15) thr = 31;
			else if (idx == 16) thr = 8; else if (idx == 17) thr = 56; else if (idx == 18) thr = 4; else if (idx == 19) thr = 52; else if (idx == 20) thr = 11; else if (idx == 21) thr = 59; else if (idx == 22) thr = 7; else if (idx == 23) thr = 55;
			else if (idx == 24) thr = 40; else if (idx == 25) thr = 24; else if (idx == 26) thr = 36; else if (idx == 27) thr = 20; else if (idx == 28) thr = 43; else if (idx == 29) thr = 27; else if (idx == 30) thr = 39; else if (idx == 31) thr = 23;
			else if (idx == 32) thr = 2; else if (idx == 33) thr = 50; else if (idx == 34) thr = 14; else if (idx == 35) thr = 62; else if (idx == 36) thr = 1; else if (idx == 37) thr = 49; else if (idx == 38) thr = 13; else if (idx == 39) thr = 61;
			else if (idx == 40) thr = 34; else if (idx == 41) thr = 18; else if (idx == 42) thr = 46; else if (idx == 43) thr = 30; else if (idx == 44) thr = 33; else if (idx == 45) thr = 17; else if (idx == 46) thr = 45; else if (idx == 47) thr = 29;
			else if (idx == 48) thr = 10; else if (idx == 49) thr = 58; else if (idx == 50) thr = 6; else if (idx == 51) thr = 54; else if (idx == 52) thr = 9; else if (idx == 53) thr = 57; else if (idx == 54) thr = 5; else if (idx == 55) thr = 53;
			else if (idx == 56) thr = 42; else if (idx == 57) thr = 26; else if (idx == 58) thr = 38; else if (idx == 59) thr = 22; else if (idx == 60) thr = 41; else if (idx == 61) thr = 25; else if (idx == 62) thr = 37; else if (idx == 63) thr = 21;
			float threshold = (float(thr) + 0.5) / 64.0;

			float bias = threshold - 0.5;
			float qf = floor(clamp(clouds * 3.0 + bias, 0.0, 2.0));

			float vMidOrig = mix(vDarkOrig, vLightOrig, 0.5);
			float vMidC = mix(vDarkC, vLightC, 0.5);
			vec3 midColOrig = hsv2rgb(vec3(h, sat, vMidOrig));
			vec3 midColC = hsv2rgb(vec3(h, sat, vMidC));

			float vDiff = abs(vLightC - vDarkC);
			vec3 cloudColorC;
			vec3 cloudColorOrig;
			if (qf < 0.5) {
				cloudColorC = darkColC;
				cloudColorOrig = darkColOrig;
			} else if (qf < 1.5) {
				cloudColorC = midColC;
				cloudColorOrig = midColOrig;
			} else {
				cloudColorC = lightColC;
				cloudColorOrig = lightColOrig;
			}
			vec3 cloudColor = vDiff < 0.02 ? cloudColorOrig : cloudColorC;

			vec2 p = vec2(pX, pY);
			vec2 d = vec2((uv.x - p.x) * sX, (uv.y - p.y) * sY);
			float dist = length(d);

            float inner = rInner;
            float outer = rOuter;
            float hole = 0.0;
            if (dist <= inner) {
                hole = 0.0;
            } else if (dist >= outer) {
                hole = 1.0;
            } else {
                float t = smoothstep(inner, outer, dist);
                hole = t;
            }

			float maskAlpha = maskAlphaEarly;
			float desiredAlpha = maskAlpha;

			if (desiredAlpha <= 0.0) {
				gl_FragColor = vec4(vec3(0.0), 0.0);
				return;
			}

			if (desiredAlpha >= 1.0) {
				vec3 finalColor = cloudColor * mix(0.9, 1.05, clouds);
				gl_FragColor = vec4(finalColor, 1.0);
				return;
			}

			float outAlpha;
			if (fUseDither > 0.5) {
				outAlpha = desiredAlpha > threshold ? 1.0 : 0.0;
			} else {
				outAlpha = desiredAlpha;
			}
			vec3 finalColor = cloudColor;
			gl_FragColor = vec4(finalColor * outAlpha, outAlpha);
        }
    ')
	public function new()
	{
		super();
		time = 0.0;
		hue = 0.0;
		playerX = 0.5;
		playerY = 0.5;
		innerRadius = 0.15;
		outerRadius = 0.30;
		sat = 0.5;
		vDark = 0.10;
		vLight = 0.40;
		useDither = 1.0;
	}
	private function set_maskTexelX(v:Float):Float
	{
		maskTexelX = v;
		mTexelX.value = [maskTexelX];
		return maskTexelX;
	}

	private function set_maskTexelY(v:Float):Float
	{
		maskTexelY = v;
		mTexelY.value = [maskTexelY];
		return maskTexelY;
	}

	private function set_time(v:Float):Float
	{
		time = v;
		iTime.value = [time];
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
		fSat.value = [sat];
		return sat;
	}

	private function set_vDark(v:Float):Float
	{
		vDark = v;
		fVDark.value = [vDark];
		return vDark;
	}

	private function set_vLight(v:Float):Float
	{
		vLight = v;
		fVLight.value = [vLight];
		return vLight;
	}

	private function set_playerX(v:Float):Float
	{
		playerX = v;
		pX.value = [playerX];
		return playerX;
	}

	private function set_playerY(v:Float):Float
	{
		playerY = v;
		pY.value = [playerY];
		return playerY;
	}

	private function set_innerRadius(v:Float):Float
	{
		innerRadius = v;
		rInner.value = [innerRadius];
		return innerRadius;
	}

	private function set_outerRadius(v:Float):Float
	{
		outerRadius = v;
		rOuter.value = [outerRadius];
		return outerRadius;
	}

	private function set_scaleX(v:Float):Float
	{
		scaleX = v;
		sX.value = [scaleX];
		return scaleX;
	}

	private function set_scaleY(v:Float):Float
	{
		scaleY = v;
		sY.value = [scaleY];
		return scaleY;
	}

	private function set_contrast(v:Float):Float
	{
		contrast = v;
		fContrast.value = [contrast];
		return contrast;
	}

	private function set_useDither(v:Float):Float
	{
		useDither = v;
		fUseDither.value = [useDither];
		return useDither;
	}
	public function updateFog(cam:flixel.FlxCamera, playerWorldX:Float, playerWorldY:Float, fogSprite:flixel.FlxSprite, maskState:MaskState,
			?tilemap:GameMap):Void
	{
		if (cam == null || fogSprite == null)
			return;

		time += FlxG.elapsed;

		var screenX = (playerWorldX) - cam.scroll.x;
		var screenY = (playerWorldY) - cam.scroll.y;
		playerX = FlxMath.bound(screenX / cam.width, 0.0, 1.0);
		playerY = FlxMath.bound(screenY / cam.height, 0.0, 1.0);

		var camMin:Float = Math.min(cam.width, cam.height);
		scaleX = cam.width / camMin;
		scaleY = cam.height / camMin;

		var radiusPixels = Std.int(cam.height / 3.0);
		innerRadius = (radiusPixels * 0.66) / camMin;
		outerRadius = (radiusPixels) / camMin;

		if (maskState == null)
			return;
		var grid = tilemap != null ? tilemap.wallGrid : null;
		// compute maskScale so fog texels align with game pixels at current camera zoom
		var camZoom:Float = 1.0;
		try
		{
			camZoom = cam.zoom;
		}
		catch (e:Dynamic)
		{
			camZoom = 1.0;
		}
		if (camZoom <= 0)
			camZoom = 1.0;
		// maskScale is 1 camera-pixel per mask-pixel -> inverse of zoom
		var desiredMaskScale:Float = 1.0 / camZoom;
		// keep maskScale reasonable
		if (desiredMaskScale < 0.125)
			desiredMaskScale = 0.125;
		if (desiredMaskScale > 1.0)
			desiredMaskScale = 1.0;
		if (maskState.mask == null || Math.abs(maskState.mask.maskScale - desiredMaskScale) > 1e-6)
		{
			maskState.mask = new VisibilityMask(grid, Constants.TILE_SIZE, desiredMaskScale, false, tilemap);
		}
		// update shader texel size for the current mask
		try
		{
			this.maskTexelX = (maskState.mask.maskScale) / cam.width;
			this.maskTexelY = (maskState.mask.maskScale) / cam.height;
		}
		catch (e:Dynamic) {}
		var needRebuild:Bool = true;
		var moveThreshold:Float = 1.0;
		if (maskState.lastBmp != null)
		{
			var dx = Math.abs(maskState.lastPlayerX - playerWorldX);
			var dy = Math.abs(maskState.lastPlayerY - playerWorldY);
			if ((maskState.age < maskState.maxAge) && dx <= moveThreshold && dy <= moveThreshold)
				needRebuild = false;
		}

		var bmp:openfl.display.BitmapData;
		if (!needRebuild)
		{
			bmp = maskState.lastBmp;
			maskState.age++;
		}
		else
		{
			bmp = maskState.mask.buildMask(cam, playerWorldX, playerWorldY);
			maskState.lastBmp = bmp;
			maskState.age = 0;
			maskState.lastPlayerX = playerWorldX;
			maskState.lastPlayerY = playerWorldY;
		}

		if (bmp != null && (bmp.width != Std.int(cam.width) || bmp.height != Std.int(cam.height)))
		{
			var full = shaders.VisibilityHelpers.scaleMaskTo(Std.int(cam.width), Std.int(cam.height), bmp, maskState.mask.maskScale);
			if (fogSprite != null && full != null)
				fogSprite.pixels = full;
			shaders.VisibilityHelpers.setFogMaskTexel(this, full);
		}
		else
		{
			if (fogSprite != null && bmp != null)
				fogSprite.pixels = bmp;
			shaders.VisibilityHelpers.setFogMaskTexel(this, bmp);
		}
		if (fogSprite != null)
			fogSprite.dirty = true;
	}
}
