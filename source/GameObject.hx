package;

import flixel.FlxSprite;


class GameObject extends FlxSprite
{
	public var speed(default, set):Float = 80;
	public var moveAngle:Float = 0;

	public function new(x:Int = 0, y:Int = 0)
	{

		super(x + 1, y + 1);
		speed = speed;


		buildGraphics();
		setOffsetAmount(1);
	}


	public function setOffsetAmount(Size:Int):Void
	{
		var ts = Constants.TILE_SIZE;
		var w = ts - Size * 2;
		this.width = w;
		this.height = w;
		this.offset.x = Size;
		this.offset.y = Size;
	}


	public function buildGraphics():Void {}

	public function move(angleDegrees:Float):Void
	{
		moveAngle = angleDegrees;
		var rad:Float = angleDegrees * Math.PI / 180.0;
		velocity.set(Math.cos(rad) * speed, Math.sin(rad) * speed);
	}

	private function set_speed(Value:Float):Float
	{
		maxVelocity.set(Value, Value);
		return Value;
	}

	public function stop():Void
	{
		velocity.set(0, 0);
		acceleration.set(0, 0);
	}
}
