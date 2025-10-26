package;

import flixel.FlxSprite;

class Portal extends FlxSprite
{
	public var playerOn:Bool = true;

	public function new(X:Float = 0, Y:Float = 0)
	{
		super(X - 8, Y - 8);
		loadGraphic("assets/images/portal.png", true, 16, 20, false, 'portal');
		animation.add("idle", [0, 1, 2, 3], 6, true);
		animation.play("idle");
	}
}
