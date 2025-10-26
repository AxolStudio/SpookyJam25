package;

class CapturedInfo
{
	public var variant:String;
	public var aggression:Float;
	public var speed:Float;
	public var hue:Int;

	public function new(variant:String, aggression:Float, speed:Float, hue:Int)
	{
		this.variant = variant;
		this.aggression = aggression;
		this.speed = speed;
		this.hue = hue;
	}
}
