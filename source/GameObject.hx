package;

import flixel.FlxSprite;


class GameObject extends FlxSprite
{
	public var speed(default, set):Float = 80;
	public var moveAngle:Float = 0;

	// Constructor expects pixel coordinates (top-left). `x`/`y` are pixel
	// positions where the object should spawn (commonly tileX * TILE_SIZE).
	// GameObject will call `buildGraphics()` and apply the standard inset
	// hitbox so subclasses only need to override `buildGraphics()`.
	public function new(x:Int = 0, y:Int = 0)
	{
		// call FlxSprite with a 1px inset so sprite sits inside the tile
		super(x + 1, y + 1);
		// initialize maxVelocity via the speed setter
		speed = speed;

		// Let subclass set up graphics/frames, then apply the standard inset hitbox
		buildGraphics();
		setOffsetAmount(1);
	}

	// Set a symmetric inset (in pixels) from each tile edge. For Size=1 and
	// TILE_SIZE=16 this gives width=height=14 and offset=1.
	public function setOffsetAmount(Size:Int):Void
	{
		var ts = Constants.TILE_SIZE;
		var w = ts - Size * 2;
		this.width = w;
		this.height = w;
		this.offset.x = Size;
		this.offset.y = Size;
	}

	// Subclasses should override this to load graphics/animations. It is not
	// called automatically so they can control ordering (e.g. pick a variant
	// then load frames). Callers should call `buildGraphics()` and then
	// `setOffsetAmount(1)` from the subclass constructor.
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
