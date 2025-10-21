class VisibilityEDT
{
	// Compute Euclidean Distance Transform for a binary mask represented by alpha array (0 = feature/transparent, 255 = object/opaque)
	// Returns an Array<Float> of distances (in pixels) for each cell (length = w*h).
	public static function computeEDT(w:Int, h:Int, alpha:Array<Int>):Array<Float>
	{
		var N:Int = w * h;
		var INF:Float = 1e20;

		// f holds initial values: 0 for feature pixels (alpha==0), INF otherwise
		var f:Array<Float> = new Array<Float>();
		f.resize(N);
		for (i in 0...N)
		{
			f[i] = (alpha[i] == 0) ? 0.0 : INF;
		}

		// intermediate array after column pass
		var d:Array<Float> = new Array<Float>();
		d.resize(N);

		// 1D EDT on an array of floats (returns squared distances array)
		// Implemented as a private static helper below.

		// Column pass
		var col:Array<Float>;
		for (x in 0...w)
		{
			col = new Array<Float>();
			col.resize(h);
			for (y in 0...h)
				col[y] = f[y * w + x];
			var colRes = VisibilityEDT.edt1d(col, h);
			for (y in 0...h)
				d[y * w + x] = colRes[y];
		}

		// Row pass -> produce final distances (sqrt of squared distances)
		var row:Array<Float>;
		for (y in 0...h)
		{
			row = new Array<Float>();
			row.resize(w);
			for (x in 0...w)
				row[x] = d[y * w + x];
			var rowRes = edt1d(row, w);
			for (x in 0...w)
				d[y * w + x] = Math.sqrt(rowRes[x]);
		}

		return d;
	}

	// private 1D EDT helper - returns squared distances array for 1D input
	private static function edt1d(g:Array<Float>, n:Int):Array<Float>
	{
		var res:Array<Float> = new Array<Float>();
		res.resize(n);

		var v:Array<Int> = new Array<Int>();
		v.resize(n);
		var z:Array<Float> = new Array<Float>();
		z.resize(n + 1);

		var k:Int = 0;
		v[0] = 0;
		z[0] = -1e20;
		z[1] = 1e20;

		var q:Int = 1;
		while (q < n)
		{
			var s:Float = 0.0;
			while (true)
			{
				var r:Int = v[k];
				s = ((g[q] + q * q) - (g[r] + r * r)) / (2.0 * (q - r));
				if (s <= z[k])
				{
					k--;
					if (k < 0)
					{
						k = 0;
						break;
					}
					continue;
				}
				break;
			}
			k++;
			v[k] = q;
			z[k] = s;
			z[k + 1] = 1e20;
			q++;
		}

		var idx:Int = 0;
		var kk:Int = 0;
		while (idx < n)
		{
			while (z[kk + 1] < idx)
				kk++;
			var r2:Int = v[kk];
			var diff:Int = idx - r2;
			res[idx] = diff * diff + g[r2];
			idx++;
		}

		return res;
	}
}
