package;

import flixel.FlxSprite;
import flixel.group.FlxGroup;

class NineSliceSprite extends FlxGroup
{
	public var x(get, set):Float;
	public var y(get, set):Float;
	public var width(get, never):Float;
	public var height(get, never):Float;

	private var boundsWidth:Float = 0;
	private var boundsHeight:Float = 0;
	private var sliceSize:Int = 16;
	private var sprites:Array<FlxSprite> = [];
	private var graphicPath:String = "";

	public function new(x:Float, y:Float, width:Float, height:Float, graphicPath:String = "assets/ui/ui_box_16x16.png")
	{
		super();
		boundsWidth = width;
		boundsHeight = height;
		this.graphicPath = graphicPath;
		createSlices(x, y, width, height, graphicPath);
	}

	// Public API to resize the nine-slice graphic. Recreates internal slice sprites.
	public function setGraphicSize(width:Float, height:Float):Void
	{
		boundsWidth = width;
		boundsHeight = height;
		// recreate slices at current position
		createSlices(get_x(), get_y(), width, height, graphicPath);
	}

	function get_x():Float
	{
		return sprites.length > 0 ? sprites[0].x : 0;
	}

	function get_y():Float
	{
		return sprites.length > 0 ? sprites[0].y : 0;
	}

	function get_width():Float
	{
		return boundsWidth;
	}

	function get_height():Float
	{
		return boundsHeight;
	}

	function set_x(value:Float):Float
	{
		var currentX = get_x();
		var offsetX = value - currentX;

		// Move all sprites by the offset
		for (sprite in sprites)
		{
			sprite.x += offsetX;
		}

		return value;
	}

	function set_y(value:Float):Float
	{
		var currentY = get_y();
		var offsetY = value - currentY;

		// Move all sprites by the offset
		for (sprite in sprites)
		{
			sprite.y += offsetY;
		}

		return value;
	}

	private function createSlices(x:Float, y:Float, width:Float, height:Float, graphicPath:String):Void
	{
		// Remove any existing sprites from the group before recreating
		for (sprite in sprites)
		{
			// remove from group
			remove(sprite);
		}
		sprites = [];

		// Corner pieces (never tiled)
		// Top-left corner
		var topLeft = new FlxSprite(x, y);
		topLeft.loadGraphic(graphicPath, true, sliceSize, sliceSize);
		topLeft.animation.frameIndex = 0;
		sprites.push(topLeft);
		add(topLeft);

		// Top-right corner
		var topRight = new FlxSprite(x + width - sliceSize, y);
		topRight.loadGraphic(graphicPath, true, sliceSize, sliceSize);
		topRight.animation.frameIndex = 2;
		sprites.push(topRight);
		add(topRight);

		// Bottom-left corner
		var bottomLeft = new FlxSprite(x, y + height - sliceSize);
		bottomLeft.loadGraphic(graphicPath, true, sliceSize, sliceSize);
		bottomLeft.animation.frameIndex = 6;
		sprites.push(bottomLeft);
		add(bottomLeft);

		// Bottom-right corner
		var bottomRight = new FlxSprite(x + width - sliceSize, y + height - sliceSize);
		bottomRight.loadGraphic(graphicPath, true, sliceSize, sliceSize);
		bottomRight.animation.frameIndex = 8;
		sprites.push(bottomRight);
		add(bottomRight);

		// Edges with proper tiling
		// Top edge
		var remainingWidth = (width - sliceSize * 2);
		var currentX = x + sliceSize;
		while (remainingWidth > 0)
		{
			var tileWidth = Std.int(Math.min(sliceSize, remainingWidth));
			var topTile = new FlxSprite(currentX, y);
			topTile.loadGraphic(graphicPath, true, sliceSize, sliceSize);
			topTile.animation.frameIndex = 1;
			if (tileWidth < sliceSize)
			{
				topTile.clipRect = new flixel.math.FlxRect(0, 0, tileWidth, sliceSize);
			}
			sprites.push(topTile);
			add(topTile);
			currentX += tileWidth;
			remainingWidth -= tileWidth;
		}

		// Bottom edge
		remainingWidth = (width - sliceSize * 2);
		currentX = x + sliceSize;
		while (remainingWidth > 0)
		{
			var tileWidth = Std.int(Math.min(sliceSize, remainingWidth));
			var bottomTile = new FlxSprite(currentX, y + height - sliceSize);
			bottomTile.loadGraphic(graphicPath, true, sliceSize, sliceSize);
			bottomTile.animation.frameIndex = 7;
			if (tileWidth < sliceSize)
			{
				bottomTile.clipRect = new flixel.math.FlxRect(0, 0, tileWidth, sliceSize);
			}
			sprites.push(bottomTile);
			add(bottomTile);
			currentX += tileWidth;
			remainingWidth -= tileWidth;
		}

		// Left edge
		var remainingHeight = (height - sliceSize * 2);
		var currentY = y + sliceSize;
		while (remainingHeight > 0)
		{
			var tileHeight = Std.int(Math.min(sliceSize, remainingHeight));
			var leftTile = new FlxSprite(x, currentY);
			leftTile.loadGraphic(graphicPath, true, sliceSize, sliceSize);
			leftTile.animation.frameIndex = 3;
			if (tileHeight < sliceSize)
			{
				leftTile.clipRect = new flixel.math.FlxRect(0, 0, sliceSize, tileHeight);
			}
			sprites.push(leftTile);
			add(leftTile);
			currentY += tileHeight;
			remainingHeight -= tileHeight;
		}

		// Right edge
		remainingHeight = (height - sliceSize * 2);
		currentY = y + sliceSize;
		while (remainingHeight > 0)
		{
			var tileHeight = Std.int(Math.min(sliceSize, remainingHeight));
			var rightTile = new FlxSprite(x + width - sliceSize, currentY);
			rightTile.loadGraphic(graphicPath, true, sliceSize, sliceSize);
			rightTile.animation.frameIndex = 5;
			if (tileHeight < sliceSize)
			{
				rightTile.clipRect = new flixel.math.FlxRect(0, 0, sliceSize, tileHeight);
			}
			sprites.push(rightTile);
			add(rightTile);
			currentY += tileHeight;
			remainingHeight -= tileHeight;
		}

		// Center with proper tiling
		remainingHeight = (height - sliceSize * 2);
		currentY = y + sliceSize;
		while (remainingHeight > 0)
		{
			var tileHeight = Std.int(Math.min(sliceSize, remainingHeight));
			remainingWidth = (width - sliceSize * 2);
			currentX = x + sliceSize;
			while (remainingWidth > 0)
			{
				var tileWidth = Std.int(Math.min(sliceSize, remainingWidth));
				var centerTile = new FlxSprite(currentX, currentY);
				centerTile.loadGraphic(graphicPath, true, sliceSize, sliceSize);
				centerTile.animation.frameIndex = 4;
				if (tileWidth < sliceSize || tileHeight < sliceSize)
				{
					centerTile.clipRect = new flixel.math.FlxRect(0, 0, tileWidth, tileHeight);
				}
				sprites.push(centerTile);
				add(centerTile);
				currentX += tileWidth;
				remainingWidth -= tileWidth;
			}
			currentY += tileHeight;
			remainingHeight -= tileHeight;
		}
	}
}
