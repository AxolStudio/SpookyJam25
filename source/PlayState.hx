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
	private var _maskState:MaskState;

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
		if (tilemap != null)
			tilemap.spawnEnemies(enemies, atmosphereHue, Std.int(player.x / Constants.TILE_SIZE), Std.int(player.y / Constants.TILE_SIZE));
		reticle = new Reticle(player);
		add(reticle);
		hud = new Hud(player);
		add(hud);
		tilemap.cameras = player.cameras = enemies.cameras = [mainCam];
		reticle.cameras = [overCam];
		hud.cameras = [hudCam];
		setupFog();
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
		if (fogShader != null)
			fogShader.hue = (cast atmosphereHue : Int);
		fog.cameras = [mainCam];
		fog.scrollFactor.set(0, 0);
		add(fog);
	}

	private function updateFogAndMask():Void
	{
		if (fogShader == null || player == null)
			return;
		if (_maskState == null)
			_maskState = new MaskState();
		var cam = mainCam;
		fogShader.updateFog(cam, player.x + player.width * 0.5, player.y + player.height * 0.5, fog, _maskState, tilemap);
	}

	override public function update(elapsed:Float):Void
	{
		playerMovement(elapsed);
		if (reticle != null)
			reticle.updateFromPlayer(player, overCam);
		super.update(elapsed);
		FlxG.collide(player, tilemap.wallsMap);
		FlxG.collide(enemies, tilemap.wallsMap);
		if (fogShader != null && player != null)
		{
			updateFogAndMask();
		}
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
		var analogOrigSpeed:Float = -1.0;

		if (Actions.leftStick.check() && (Math.abs(Actions.leftStick.x) > 0.1 || Math.abs(Actions.leftStick.y) > 0.1))
		{
			move.x = Actions.leftStick.x;
			move.y = Actions.leftStick.y;
			moveAngle = Math.atan2(move.y, move.x);
			any = true;
			var stickMag:Float = Math.sqrt(move.x * move.x + move.y * move.y);
			if (stickMag > 1.0)
				stickMag = 1.0;

			analogOrigSpeed = player.speed;
			player.speed = analogOrigSpeed * stickMag;
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
		{
			player.move(moveAngle * 180.0 / Math.PI);
			if (analogOrigSpeed >= 0)
			{
				player.speed = analogOrigSpeed;
			}
		}
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
