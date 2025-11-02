package;

import Types;

class CapturedInfo
{
	public var variant:String;
	public var aggression:Float;
	public var speed:Float;
	public var skittishness:Float; // 0.0-1.0, how likely to flee
	public var hue:Int;
	public var photoIndex:Int;
	public var power:Int; // 1-5 stars
	public var variantType:EnemyVariant; // NORMAL, ALPHA, or SHINY

	public function new(variant:String, aggression:Float, speed:Float, hue:Int, photoIndex:Int = 1, power:Int = 3, skittishness:Float = 0.0,
			variantType:EnemyVariant = NORMAL)
	{
		this.variant = variant;
		this.aggression = aggression;
		this.speed = speed;
		this.skittishness = skittishness;
		this.hue = hue;
		this.photoIndex = photoIndex;
		this.power = power;
		this.variantType = variantType;
	}
}
