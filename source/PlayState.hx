package;

import flixel.util.FlxColor;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxPoint;
import ui.Hud;

class PlayState extends FlxState
{
	public var tilemap:GameMap;
	public var player:Player;
	public var reticle:Reticle;
	public var enemies:FlxTypedGroup<Enemy>;
	public var mainCam:FlxCamera;
	public var overCam:FlxCamera;
	public var hudCam:FlxCamera;
	public var atmosphereHue:Int;
	public var hud:Hud;
	public var fog:FlxSprite;
	public var fogShader:shaders.Fog;

	private var _visibilityMask:VisibilityMask;
	private var _lastMaskBmp:openfl.display.BitmapData;
	private var _maskAge:Int = 0;
	private var _maskMaxAge:Int = 3;
	private var _lastPlayerX:Float = -1;
	private var _lastPlayerY:Float = -1;

	override public function create():Void
	{
		Actions.init();
		Actions.switchSet(Actions.gameplayIndex);
		atmosphereHue = FlxG.random.int(0, 359);
		createCameras();
		tilemap = new GameMap();
		tilemap.generate(atmosphereHue);
		add(tilemap);
		player = new Player(tilemap.portalTileX * Constants.TILE_SIZE, tilemap.portalTileY * Constants.TILE_SIZE);
		add(player);
		enemies = new FlxTypedGroup<Enemy>();
		add(enemies);
		try
		{
			tilemap.spawnEnemies(enemies, atmosphereHue);
		}
		catch (e:Dynamic) {}
		reticle = new Reticle(player);
		add(reticle);
		hud = new Hud(player);
		add(hud);
		tilemap.cameras = player.cameras = enemies.cameras = [mainCam];
		reticle.cameras = [overCam];
		hud.cameras = [hudCam];
		try
		{
			setupFog();
		}
		catch (e:Dynamic) {}
		mainCam.setScrollBoundsRect(0, 0, Std.int(tilemap.width), Std.int(tilemap.height), true);
		mainCam.follow(player);
		overCam.setScrollBoundsRect(0, 0, Std.int(tilemap.width), Std.int(tilemap.height), true);
		overCam.follow(player);
		super.create();
	}

	private function setupFog():Void
	{
		fog = new FlxSprite(0, 0);
		fog.makeGraphic(Std.int(mainCam.width), Std.int(mainCam.height), FlxColor.TRANSPARENT);
		fogShader = new shaders.Fog();
		fog.shader = fogShader;
		try
		{
			fogShader.hue = (cast atmosphereHue : Int);
		}
		catch (e:Dynamic) {}
		fog.cameras = [mainCam];
		fog.scrollFactor.set(0, 0);
		add(fog);
	}

	override public function update(elapsed:Float):Void
	{
		playerMovement(elapsed);
		if (reticle != null)
			reticle.updateFromPlayer(player, overCam);
		super.update(elapsed);
		FlxG.collide(player, tilemap.wallsMap);
		FlxG.collide(enemies, tilemap.wallsMap);
		try
		{
			if (fogShader != null && player != null)
			{
				fogShader.time += elapsed;
				var cam = mainCam;
				var screenX = (player.x + player.width * 0.5) - cam.scroll.x;
				var screenY = (player.y + player.height * 0.5) - cam.scroll.y;
				fogShader.playerX = FlxMath.bound(screenX / cam.width, 0.0, 1.0);
				fogShader.playerY = FlxMath.bound(screenY / cam.height, 0.0, 1.0);
				var camMin:Float = Math.min(cam.width, cam.height);
				fogShader.scaleX = cam.width / camMin;
				fogShader.scaleY = cam.height / camMin;
				var radiusPixels = Std.int(cam.height / 3.0);
				fogShader.innerRadius = (radiusPixels * 0.66) / camMin;
				fogShader.outerRadius = (radiusPixels) / camMin;

				if (tilemap != null && (cast tilemap : GameMap).wallGrid != null)
				{
					if (_visibilityMask == null)
						_visibilityMask = new VisibilityMask((cast tilemap : GameMap).wallGrid, Constants.TILE_SIZE, 1.0, false);
					var mask:VisibilityMask = _visibilityMask;
					var worldPX = player.x + player.width * 0.5;
					var worldPY = player.y + player.height * 0.5;
					var needRebuild:Bool = true;
					var moveThreshold:Float = 1.0;
					if (_lastMaskBmp != null)
					{
						var dx = Math.abs(_lastPlayerX - worldPX);
						var dy = Math.abs(_lastPlayerY - worldPY);
						if ((_maskAge < _maskMaxAge) && dx <= moveThreshold && dy <= moveThreshold)
							needRebuild = false;
					}

					var bmp:openfl.display.BitmapData;
					if (!needRebuild)
					{
						bmp = _lastMaskBmp;
						_maskAge++;
					}
					else
					{
						bmp = mask.buildMask(cam, worldPX, worldPY);
						_lastMaskBmp = bmp;
						_maskAge = 0;
						_lastPlayerX = worldPX;
						_lastPlayerY = worldPY;
					}
					if (bmp.width != Std.int(cam.width) || bmp.height != Std.int(cam.height))
					{
						var full = shaders.VisibilityHelpers.scaleMaskTo(Std.int(cam.width), Std.int(cam.height), bmp, mask.maskScale);
						try
						{
							fog.pixels = full;
						}
						catch (e:Dynamic) {}
						shaders.VisibilityHelpers.setFogMaskTexel(fogShader, full);
					}
					else
					{
						try
						{
							fog.pixels = bmp;
						}
						catch (e:Dynamic) {}
						shaders.VisibilityHelpers.setFogMaskTexel(fogShader, bmp);
					}
					try
					{
						fog.dirty = true;
					}
					catch (e:Dynamic) {}
				}
			}
		}
		catch (e:Dynamic) {}
	}

	private function playerMovement(elapsed:Float):Void
	{
		var left:Bool = Actions.left.check();
		var right:Bool = Actions.right.check();
		var up:Bool = Actions.up.check();
		var down:Bool = Actions.down.check();
		if (left && right)
			left = right = false;
		if (up && down)
			up = down = false;
		var any:Bool = left || right || up || down;

		var moveAngle:Float = 0;
		var move:FlxPoint = FlxPoint.get();

		if (Actions.leftStick.check() && (Math.abs(Actions.leftStick.x) > 0.1 || Math.abs(Actions.leftStick.y) > 0.1))
		{
			move.x = Actions.leftStick.x;
			move.y = Actions.leftStick.y;
			moveAngle = Math.atan2(move.y, move.x);
			any = true;
		}
		else if (any)
		{
			if (left)
				moveAngle = Math.PI;
			else if (right)
				moveAngle = 0;
			else if (up)
				moveAngle = -Math.PI / 2;
			else if (down)
				moveAngle = Math.PI / 2;

			if (left && up)
				moveAngle = -3 * Math.PI / 4;
			else if (right && up)
				moveAngle = -Math.PI / 4;
			else if (left && down)
				moveAngle = 3 * Math.PI / 4;
			else if (right && down)
				moveAngle = Math.PI / 4;

			move.x = Math.cos(moveAngle);
			move.y = Math.sin(moveAngle);
		}

		if (any)
			player.move(moveAngle * 180.0 / Math.PI);
		else
			player.stop();
		move.put();
		if (Actions.attack.check())
		{
			if (player.tryTakePhoto())
			{
				var hits:Array<Enemy> = [];
				FlxG.overlap(reticle, enemies, function(a:Dynamic, b:Dynamic):Void
				{
					if (b != null)
						hits.push(cast(b, Enemy));
				});
				for (h in hits)
					if (h != null)
						h.capture(player);
			}
		}
	}

	private function createCameras():Void
	{
		mainCam = new FlxCamera(0, 18, FlxG.width, FlxG.height - 18);
		overCam = new FlxCamera(0, 18, FlxG.width, FlxG.height - 18);
		hudCam = new FlxCamera(0, 0, FlxG.width, 18);
		FlxG.cameras.add(mainCam);
		FlxG.cameras.add(overCam);
		FlxG.cameras.add(hudCam);
		FlxG.camera = mainCam;
		hudCam.bgColor = FlxColor.TRANSPARENT;
		overCam.bgColor = FlxColor.TRANSPARENT;
		mainCam.pixelPerfectRender = true;
		hudCam.pixelPerfectRender = true;
		overCam.pixelPerfectRender = true;
	}
}
