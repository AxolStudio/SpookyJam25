package ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxPoint;
import flixel.text.FlxText.FlxTextAlign;
import flixel.ui.FlxButton.FlxButtonState;
import flixel.ui.FlxButton.FlxTypedButton;
import openfl.display.BitmapData;
import openfl.geom.Point;
import openfl.geom.Rectangle;

/**
 * A 9-slice button that uses button.png with three states (normal, highlight, pressed).
 * Can be used with GameText or FlxSprite labels.
 */
class NineSliceButton<T:FlxSprite> extends FlxTypedButton<T>
{
	private var buttonWidth:Float;
	private var buttonHeight:Float;

	private var normalGraphic:FlxGraphic;
	private var highlightGraphic:FlxGraphic;
	private var pressedGraphic:FlxGraphic;

	private static var graphicsCache:Map<String, FlxGraphic> = new Map<String, FlxGraphic>();

	private static var instanceCounter:Int = 0;

	private var instanceId:Int;

	public var isCancelButton:Bool = false;

	private var previousStatus:FlxButtonState = NORMAL;

	private static var NORMAL_SLICES:Array<Rectangle> = [
		new Rectangle(0, 0, 4, 3), // top-left
		new Rectangle(4, 0, 8, 3), // top-center
		new Rectangle(12, 0, 4, 3), // top-right
		new Rectangle(0, 3, 4, 7), // middle-left
		new Rectangle(4, 3, 8, 7), // middle-center
		new Rectangle(12, 3, 4, 7), // middle-right
		new Rectangle(0, 10, 4, 6), // bottom-left
		new Rectangle(4, 10, 8, 6), // bottom-center
		new Rectangle(12, 10, 4, 6) // bottom-right
	];

	private static var HIGHLIGHT_SLICES:Array<Rectangle> = [
		new Rectangle(16, 0, 4, 4), // top-left
		new Rectangle(20, 0, 8, 4), // top-center
		new Rectangle(28, 0, 4, 4), // top-right
		new Rectangle(16, 4, 4, 7), // middle-left
		new Rectangle(20, 4, 8, 7), // middle-center
		new Rectangle(28, 4, 4, 7), // middle-right
		new Rectangle(16, 11, 4, 5), // bottom-left
		new Rectangle(20, 11, 8, 5), // bottom-center
		new Rectangle(28, 11, 4, 5) // bottom-right
	];

	private static var PRESSED_SLICES:Array<Rectangle> = [
		new Rectangle(32, 0, 4, 5), // top-left
		new Rectangle(36, 0, 8, 5), // top-center
		new Rectangle(44, 0, 4, 5), // top-right
		new Rectangle(32, 5, 4, 7), // middle-left
		new Rectangle(36, 5, 8, 7), // middle-center
		new Rectangle(44, 5, 4, 7), // middle-right
		new Rectangle(32, 12, 4, 4), // bottom-left
		new Rectangle(36, 12, 8, 4), // bottom-center
		new Rectangle(44, 12, 4, 4) // bottom-right
	];

	private var sourceBitmap:BitmapData;

	private static var sharedSourceBitmap:BitmapData;

	public function new(X:Float = 0, Y:Float = 0, Width:Float = 40, Height:Float = 16, ?OnClick:Void->Void)
	{
		buttonWidth = Width;
		buttonHeight = Height;

		instanceId = instanceCounter++;

		if (sharedSourceBitmap == null)
		{
			var graphic = FlxG.bitmap.add("assets/ui/button.png");
			graphic.persist = true;
			graphic.destroyOnNoUse = false;
			sharedSourceBitmap = graphic.bitmap;
		}
		sourceBitmap = sharedSourceBitmap;

		super(X, Y, OnClick);

		normalGraphic = render9Slice(NORMAL_SLICES, "normal");
		highlightGraphic = render9Slice(HIGHLIGHT_SLICES, "highlight");
		pressedGraphic = render9Slice(PRESSED_SLICES, "pressed");

		loadGraphic(normalGraphic);

		labelAlphas = [1.0, 1.0, 1.0, 0.5];
	}

	public function positionLabel():Void
	{
		if (label != null)
		{
			if (Std.isOfType(label, GameText))
			{
				var gameText:GameText = cast label;
				gameText.autoSize = false;
				gameText.fieldWidth = Std.int(buttonWidth - 8);
				gameText.alignment = FlxTextAlign.CENTER;

				// Force update the text field to recalculate dimensions
				gameText.updateHitbox();

				labelOffsets[0].set(4, calculateLabelY(3, 6, gameText.height));
				labelOffsets[1].set(4, calculateLabelY(4, 5, gameText.height));
				labelOffsets[2].set(4, calculateLabelY(5, 4, gameText.height));
				labelOffsets[3].set(4, calculateLabelY(3, 6, gameText.height));
			}
			else
			{
				// For FlxSprite labels (like icons), center in middle slice for each state
				var xOffset:Float = (buttonWidth - label.width) / 2;

				// Apply same middle-slice centering logic as GameText
				labelOffsets[0].set(xOffset, calculateLabelY(3, 6, label.height)); // NORMAL
				labelOffsets[1].set(xOffset, calculateLabelY(4, 5, label.height)); // HIGHLIGHT
				labelOffsets[2].set(xOffset, calculateLabelY(5, 4, label.height)); // PRESSED
				labelOffsets[3].set(xOffset, calculateLabelY(3, 6, label.height)); // DISABLED
			}
		}
	}

	private function calculateLabelY(topSliceHeight:Float, bottomSliceHeight:Float, textHeight:Float):Float
	{
		var middleSliceHeight:Float = buttonHeight - topSliceHeight - bottomSliceHeight;
		return topSliceHeight + (middleSliceHeight - textHeight) / 2;
	}

	/**
	 * Helper method to calculate the button size needed for a GameText label
	 */
	public static function sizeForText(text:GameText):FlxPoint
	{
		var width = text.width + 8;
		var height = Math.max(text.height + 9, 16);
		return new FlxPoint(width, height);
	}

	/**
	 * Helper method to calculate the button size needed for a FlxSprite label
	 */
	public static function sizeForSprite(sprite:FlxSprite):FlxPoint
	{
		var width = sprite.width + 8;
		var height = sprite.height + 9;
		return new FlxPoint(width, height);
	}

	private function render9Slice(slices:Array<Rectangle>, stateName:String):FlxGraphic
	{
		// Use shared cache based on size and state, not instance
		// This allows graphics to persist across state changes
		var cacheKey = "button_" + stateName + "_" + Std.int(buttonWidth) + "x" + Std.int(buttonHeight);

		// Check if we already have this graphic cached AND it's still valid
		if (graphicsCache.exists(cacheKey))
		{
			var cachedGraphic = graphicsCache.get(cacheKey);
			// Verify the graphic hasn't been destroyed/garbage collected
			if (cachedGraphic != null && cachedGraphic.bitmap != null)
			{
				return cachedGraphic;
			}
			else
			{
				// Graphic was destroyed, remove from cache and recreate
				graphicsCache.remove(cacheKey);
			}
		}

		// Also check Flixel's bitmap cache
		var flixelCached = FlxG.bitmap.get(cacheKey);
		if (flixelCached != null && flixelCached.bitmap != null)
		{
			// Add back to our cache and return
			graphicsCache.set(cacheKey, flixelCached);
			return flixelCached;
		}

		// Create a new bitmap for this button state
		var buttonBitmap = new BitmapData(Std.int(buttonWidth), Std.int(buttonHeight), true, 0x00000000);

		// Calculate dimensions
		var leftW = slices[0].width;
		var rightW = slices[2].width;
		var topH = slices[0].height;
		var bottomH = slices[6].height;

		var centerW = buttonWidth - leftW - rightW;
		var centerH = buttonHeight - topH - bottomH;

		var destPoint = new Point();

		// Top row
		destPoint.setTo(0, 0);
		buttonBitmap.copyPixels(sourceBitmap, slices[0], destPoint);

		// Tile top-center
		var tx:Float = leftW;
		while (tx < leftW + centerW)
		{
			var tileW = Math.min(slices[1].width, leftW + centerW - tx);
			destPoint.setTo(tx, 0);
			var srcRect = slices[1].clone();
			srcRect.width = tileW;
			buttonBitmap.copyPixels(sourceBitmap, srcRect, destPoint);
			tx += tileW;
		}

		destPoint.setTo(leftW + centerW, 0);
		buttonBitmap.copyPixels(sourceBitmap, slices[2], destPoint);

		// Middle row
		var ty:Float = topH;
		while (ty < topH + centerH)
		{
			var tileH = Math.min(slices[3].height, topH + centerH - ty);

			// Left
			destPoint.setTo(0, ty);
			var srcRect = slices[3].clone();
			srcRect.height = tileH;
			buttonBitmap.copyPixels(sourceBitmap, srcRect, destPoint);

			// Center (tile both x and y)
			tx = leftW;
			while (tx < leftW + centerW)
			{
				var tileW = Math.min(slices[4].width, leftW + centerW - tx);
				destPoint.setTo(tx, ty);
				srcRect = slices[4].clone();
				srcRect.width = tileW;
				srcRect.height = tileH;
				buttonBitmap.copyPixels(sourceBitmap, srcRect, destPoint);
				tx += tileW;
			}

			// Right
			destPoint.setTo(leftW + centerW, ty);
			srcRect = slices[5].clone();
			srcRect.height = tileH;
			buttonBitmap.copyPixels(sourceBitmap, srcRect, destPoint);

			ty += tileH;
		}

		// Bottom row
		destPoint.setTo(0, topH + centerH);
		buttonBitmap.copyPixels(sourceBitmap, slices[6], destPoint);

		// Tile bottom-center
		tx = leftW;
		while (tx < leftW + centerW)
		{
			var tileW = Math.min(slices[7].width, leftW + centerW - tx);
			destPoint.setTo(tx, topH + centerH);
			var srcRect = slices[7].clone();
			srcRect.width = tileW;
			buttonBitmap.copyPixels(sourceBitmap, srcRect, destPoint);
			tx += tileW;
		}

		destPoint.setTo(leftW + centerW, topH + centerH);
		buttonBitmap.copyPixels(sourceBitmap, slices[8], destPoint);

		// Create FlxGraphic and ADD to Flixel's cache with persist flag
		// This ensures the graphic won't be garbage collected
		var graphic = FlxGraphic.fromBitmapData(buttonBitmap, true, cacheKey);

		// Mark as persistent so it survives state changes
		graphic.persist = true;
		graphic.destroyOnNoUse = false;

		// Add to our own static cache for reuse
		graphicsCache.set(cacheKey, graphic);

		return graphic;
	}

	override function set_status(value:FlxButtonState):FlxButtonState
	{
		var result = super.set_status(value);

		// Only update graphics if they've been created
		// This prevents errors during construction
		if (normalGraphic == null || highlightGraphic == null || pressedGraphic == null)
			return result;

		// Play hover sound when transitioning to HIGHLIGHT state
		if (value == HIGHLIGHT && previousStatus != HIGHLIGHT)
		{
			util.SoundHelper.playSound("ui_hover");
		}

		// Play click sound when transitioning to PRESSED state
		if (value == PRESSED && previousStatus != PRESSED)
		{
			if (isCancelButton)
			{
				util.SoundHelper.playSound("ui_cancel");
			}
			else
			{
				util.SoundHelper.playSound("ui_select");
			}
		}

		previousStatus = value; // Check if graphics are still valid, recreate if needed
		if (normalGraphic.bitmap == null)
		{
			normalGraphic = render9Slice(NORMAL_SLICES, "normal");
		}
		if (highlightGraphic.bitmap == null)
		{
			highlightGraphic = render9Slice(HIGHLIGHT_SLICES, "highlight");
		}
		if (pressedGraphic.bitmap == null)
		{
			pressedGraphic = render9Slice(PRESSED_SLICES, "pressed");
		}

		// Simply swap to the cached graphic for this state
		switch (value)
		{
			case HIGHLIGHT:
				loadGraphic(highlightGraphic);
			case PRESSED:
				loadGraphic(pressedGraphic);
			case DISABLED:
				loadGraphic(normalGraphic);
			default:
				loadGraphic(normalGraphic);
		}

		return result;
	}

	override public function destroy():Void
	{
		sourceBitmap = null;

		// Don't destroy the graphics - they're marked as persistent
		// Just null out the references
		normalGraphic = null;
		highlightGraphic = null;
		pressedGraphic = null;

		super.destroy();
	}
}
