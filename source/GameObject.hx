package;

import flixel.FlxSprite;


class GameObject extends FlxSprite
{
	public var speed:Float = 80;
	public var moveAngle:Float = 0;

	public function new(x:Int = 0, y:Int = 0)
	{

		super(x, y);

		buildGraphics();
	}

	public function buildGraphics():Void {}

	public function move(angleDegrees:Float):Void
	{
		moveAngle = angleDegrees;
		velocity.set(speed, 0).rotateByDegrees(moveAngle);
	}

	public function stop():Void
	{
		velocity.set(0, 0);
		acceleration.set(0, 0);
	}
}
