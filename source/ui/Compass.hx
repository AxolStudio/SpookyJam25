package ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import openfl.display.Shape;

class Compass extends FlxSprite
{
	private var target:FlxPoint;
	private var playerPos:FlxPoint;
	private var needleSprite:FlxSprite;

	public function new(x:Float, y:Float)
	{
		super(x, y);

		// Create a simple compass graphic using BitmapData
		var bmp = new BitmapData(24, 24, true, 0x00000000);
		var shape = new Shape();

		// Draw outer circle
		shape.graphics.beginFill(0x000000);
		shape.graphics.drawCircle(12, 12, 11);
		shape.graphics.endFill();

		shape.graphics.beginFill(0x444444);
		shape.graphics.drawCircle(12, 12, 10);
		shape.graphics.endFill();

		// Draw inner background
		shape.graphics.beginFill(0x000000);
		shape.graphics.drawCircle(12, 12, 8);
		shape.graphics.endFill();

		bmp.draw(shape);
		loadGraphic(bmp);

		scrollFactor.set(0, 0);

		// Create needle sprite
		needleSprite = new FlxSprite(x, y);
		var needleBmp = new BitmapData(24, 24, true, 0x00000000);
		var needleShape = new Shape();

		// Draw red triangle pointing up
		needleShape.graphics.beginFill(0xFF0000);
		needleShape.graphics.moveTo(12, 4);
		needleShape.graphics.lineTo(10, 10);
		needleShape.graphics.lineTo(14, 10);
		needleShape.graphics.lineTo(12, 4);
		needleShape.graphics.endFill();

		needleBmp.draw(needleShape);
		needleSprite.loadGraphic(needleBmp);
		needleSprite.scrollFactor.set(0, 0);
		needleSprite.origin.set(12, 12);

		target = FlxPoint.get();
		playerPos = FlxPoint.get();
	}

	public function setTarget(targetX:Float, targetY:Float):Void
	{
		target.set(targetX, targetY);
	}

	public function setPlayerPosition(x:Float, y:Float):Void
	{
		playerPos.set(x, y);
	}

	public function addToState(state:flixel.FlxState):Void
	{
		state.add(this);
		state.add(needleSprite);
	}

	public function setCameras(cam:flixel.FlxCamera):Void
	{
		cameras = [cam];
		needleSprite.cameras = [cam];
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Calculate angle to target
		var angleToTarget = Math.atan2(target.y - playerPos.y, target.x - playerPos.x);
		needleSprite.angle = angleToTarget * 180 / Math.PI + 90; // Convert to degrees and adjust for sprite orientation

		// Keep needle positioned with compass
		needleSprite.setPosition(x, y);
	}

	override public function destroy():Void
	{
		if (needleSprite != null)
			needleSprite.destroy();
		target.put();
		playerPos.put();
		super.destroy();
	}
}
