package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.geom.Point;

class AnimatedReticle extends FlxSprite
{
	private static inline var CORNER_SIZE:Int = 6;
	private static inline var EDGE_SIZE:Int = 4;
	private static inline var FRAME_SIZE:Int = 16;

	private var _sourceGraphic:FlxGraphic;
	private var _padding:Float = 0;
	private var _lastBuiltWidth:Int = 0;
	private var _lastBuiltHeight:Int = 0;

	// Simple public fields for FlxTween to use (avoids DCE issues with properties)
	@:keep public var targetX:Float = 0;
	@:keep public var targetY:Float = 0;
	@:keep public var targetWidth:Float = 0;
	@:keep public var targetHeight:Float = 0;

	public function new(x:Float = 0, y:Float = 0, width:Float = 16, height:Float = 16)
	{
		super(x, y);

		_sourceGraphic = FlxG.bitmap.add("assets/images/reticle.png");
		visible = false;

		targetX = x;
		targetY = y;
		targetWidth = width;
		targetHeight = height;

		rebuild();
	}

	public function setTarget(x:Float, y:Float, width:Float, height:Float, padding:Float = 3):Void
	{
		_padding = padding;
		targetX = x - padding;
		targetY = y - padding;
		targetWidth = width + padding * 2;
		targetHeight = height + padding * 2;

		FlxTween.cancelTweensOf(this);
		rebuild();
		setPosition(targetX, targetY);
	}

	public function changeTarget(x:Float, y:Float, width:Float, height:Float, padding:Float = 3):Void
	{
		_padding = padding;

		var newX = x - padding;
		var newY = y - padding;
		var newW = width + padding * 2;
		var newH = height + padding * 2;

		FlxTween.cancelTweensOf(this);
		FlxTween.tween(this, {
			targetX: newX,
			targetY: newY,
			targetWidth: newW,
			targetHeight: newH
		}, 0.15, {
			ease: FlxEase.quadOut
		});
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Sync position to target
		if (this.x != targetX || this.y != targetY)
		{
			setPosition(targetX, targetY);
		}

		// Check if size changed and needs rebuild
		var w = Std.int(targetWidth);
		var h = Std.int(targetHeight);
		if (w != _lastBuiltWidth || h != _lastBuiltHeight)
		{
			rebuild();
		}
	}

	private function rebuild():Void
	{
		var w = Std.int(targetWidth);
		var h = Std.int(targetHeight);
		if (w < CORNER_SIZE * 2 || h < CORNER_SIZE * 2)
			return;

		if (w == _lastBuiltWidth && h == _lastBuiltHeight)
		{
			return;
		}

		_lastBuiltWidth = w;
		_lastBuiltHeight = h;

		var frame0 = buildFrame(0, w, h);
		var frame1 = buildFrame(1, w, h);

		var combined = new BitmapData(w * 2, h, true, 0x00000000);
		combined.copyPixels(frame0, new Rectangle(0, 0, w, h), new Point(0, 0));
		combined.copyPixels(frame1, new Rectangle(0, 0, w, h), new Point(w, 0));

		frame0.dispose();
		frame1.dispose();

		var wasPlaying = animation != null && animation.curAnim != null && animation.curAnim.name == "idle";
		var currentFrame = wasPlaying ? animation.frameIndex : 0;

		loadGraphic(FlxGraphic.fromBitmapData(combined, false, null, false), true, w, h);
		animation.add("idle", [0, 1], 8, true);
		animation.play("idle");

		if (wasPlaying && currentFrame < animation.numFrames)
		{
			animation.frameIndex = currentFrame;
		}
	}

	private function buildFrame(frameIndex:Int, targetW:Int, targetH:Int):BitmapData
	{
		var sourceBmp = _sourceGraphic.bitmap;
		var frameOffsetX = frameIndex * FRAME_SIZE;
		var result = new BitmapData(targetW, targetH, true, 0x00000000);

		var edgeW = targetW - CORNER_SIZE * 2;
		var edgeH = targetH - CORNER_SIZE * 2;

		result.copyPixels(sourceBmp, new Rectangle(frameOffsetX, 0, CORNER_SIZE, CORNER_SIZE), new Point(0, 0));
		result.copyPixels(sourceBmp, new Rectangle(frameOffsetX + CORNER_SIZE + EDGE_SIZE, 0, CORNER_SIZE, CORNER_SIZE), new Point(targetW - CORNER_SIZE, 0));
		result.copyPixels(sourceBmp, new Rectangle(frameOffsetX, CORNER_SIZE + EDGE_SIZE, CORNER_SIZE, CORNER_SIZE), new Point(0, targetH - CORNER_SIZE));
		result.copyPixels(sourceBmp, new Rectangle(frameOffsetX + CORNER_SIZE + EDGE_SIZE, CORNER_SIZE + EDGE_SIZE, CORNER_SIZE, CORNER_SIZE),
			new Point(targetW - CORNER_SIZE, targetH - CORNER_SIZE));

		for (i in 0...Std.int(Math.ceil(edgeW / EDGE_SIZE)))
		{
			var drawW = Std.int(Math.min(EDGE_SIZE, edgeW - i * EDGE_SIZE));
			result.copyPixels(sourceBmp, new Rectangle(frameOffsetX + CORNER_SIZE, 0, drawW, CORNER_SIZE), new Point(CORNER_SIZE + i * EDGE_SIZE, 0));
			result.copyPixels(sourceBmp, new Rectangle(frameOffsetX + CORNER_SIZE, CORNER_SIZE + EDGE_SIZE, drawW, CORNER_SIZE),
				new Point(CORNER_SIZE + i * EDGE_SIZE, targetH - CORNER_SIZE));
		}

		for (i in 0...Std.int(Math.ceil(edgeH / EDGE_SIZE)))
		{
			var drawH = Std.int(Math.min(EDGE_SIZE, edgeH - i * EDGE_SIZE));
			result.copyPixels(sourceBmp, new Rectangle(frameOffsetX, CORNER_SIZE, CORNER_SIZE, drawH), new Point(0, CORNER_SIZE + i * EDGE_SIZE));
			result.copyPixels(sourceBmp, new Rectangle(frameOffsetX + CORNER_SIZE + EDGE_SIZE, CORNER_SIZE, CORNER_SIZE, drawH),
				new Point(targetW - CORNER_SIZE, CORNER_SIZE + i * EDGE_SIZE));
		}

		return result;
	}
}
