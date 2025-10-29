package shaders;

import flixel.math.FlxMath;
import flixel.system.FlxAssets.FlxShader;

@:keep
class PhotoDissolve extends FlxShader
{
	public var dissolve(default, set):Float = 0;
	public var desat(default, set):Float = 0;
	public var time(default, set):Float = 0.0;

	@:glFragmentSource('
		#pragma header
		uniform float fDesat;
		uniform float fDissolve;
		uniform float iTime;

		vec3 toGray(vec3 c){ float g = dot(c, vec3(0.299,0.587,0.114)); return vec3(g); }

		void main(){
			vec2 uv = openfl_TextureCoordv;
			vec4 src = flixel_texture2D(bitmap, uv);
			
			vec3 baseGray = mix(src.rgb, toGray(src.rgb), clamp(fDesat,0.0,1.0));

		
			const float ROWS = 16.0;
			float vflip = 1.0 - uv.y;
			float rowF = floor(vflip * ROWS);

			
			float progressed = clamp(fDissolve * ROWS, 0.0, ROWS);
			float currentRow = floor(progressed);
			float local = clamp(progressed - currentRow, 0.0, 1.0);

		
			float FALL_PER_ROW = 0.02;

			
			if (rowF < currentRow) {
				gl_FragColor = vec4(vec3(0.0), 0.0);
				return;
			}

			
			if (rowF == currentRow) {
				float fall = local * (currentRow + 1.0) * FALL_PER_ROW;
				vec2 sampleUV = uv - vec2(0.0, fall);
				sampleUV.y = clamp(sampleUV.y, 0.0, 1.0);
				vec4 sampled = flixel_texture2D(bitmap, sampleUV);
				vec3 finalCol = mix(sampled.rgb, toGray(sampled.rgb), clamp(fDesat,0.0,1.0));
				float alpha = sampled.a * (1.0 - smoothstep(0.0, 1.0, local));
				gl_FragColor = vec4(finalCol * alpha, alpha);
				return;
			}

			
			vec4 sampled = flixel_texture2D(bitmap, uv);
			vec3 finalCol = mix(sampled.rgb, toGray(sampled.rgb), clamp(fDesat,0.0,1.0));
			
			gl_FragColor = vec4(finalCol * sampled.a, sampled.a);
		}
    ')
	public function new()
	{
		super();
		try
		{
			dissolve = 0;
		}
		catch (e:Dynamic) {}
		try
		{
			desat = 0;
		}
		catch (e:Dynamic) {}
		try
		{
			time = 0;
		}
		catch (e:Dynamic) {}
	}

	private function set_dissolve(Value:Float):Float
	{
		dissolve = FlxMath.bound(Value, 0, 1);

		if (fDissolve != null)
		{
			try
			{
				fDissolve.value = [dissolve];
			}
			catch (e:Dynamic) {}
		}
		return dissolve;
	}

	private function set_desat(Value:Float):Float
	{
		desat = FlxMath.bound(Value, 0, 1);
		if (fDesat != null)
		{
			try
			{
				fDesat.value = [desat];
			}
			catch (e:Dynamic) {}
		}
		return desat;
	}

	private function set_time(Value:Float):Float
	{
		time = Value;
		if (iTime != null)
		{
			try
			{
				iTime.value = [time];
			}
			catch (e:Dynamic) {}
		}
		return time;
	}
}
