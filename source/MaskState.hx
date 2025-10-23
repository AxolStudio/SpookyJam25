package;

import VisibilityMask;
import openfl.display.BitmapData;

class MaskState
{
    public var mask:VisibilityMask;
    public var lastBmp:BitmapData;
    public var age:Int = 0;
    public var maxAge:Int = 3;
    public var lastPlayerX:Float = -1;
    public var lastPlayerY:Float = -1;

    public function new() {}
}
