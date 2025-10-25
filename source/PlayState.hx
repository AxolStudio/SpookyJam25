package;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxAngle;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import ui.Hud;
import util.SoundHelper;

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
	public var blackOut:BlackOut;

	private var _visibilityMask:VisibilityMask;
	private var _maskState:MaskState;

	public var ready:Bool = false;

	override public function create():Void
	{
		Actions.init();
		Actions.switchSet(Actions.gameplayIndex);
		SoundHelper.initSounds();

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
		blackOut = new BlackOut(hudCam);
		add(blackOut);
		
		mainCam.setScrollBoundsRect(0, 0, Std.int(tilemap.width), Std.int(tilemap.height), true);
		mainCam.follow(player);
		overCam.setScrollBoundsRect(0, 0, Std.int(tilemap.width), Std.int(tilemap.height), true);
		overCam.follow(player);
		blackOut.fade(() ->
		{
			ready = true;
		}, false, 1.5, FlxColor.BLACK);

		super.create();
	}


	private function setupFog():Void
	{
		fog = new FlxSprite(0, 0);
		fog.makeGraphic(Std.int(mainCam.width), Std.int(mainCam.height), FlxColor.TRANSPARENT);
		fogShader = new shaders.Fog();
		fog.shader = fogShader;
		if (fogShader != null)
			fogShader.hue = atmosphereHue;
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
		var pMid:FlxPoint = player.getMidpoint();
		fogShader.updateFog(cam, pMid.x, pMid.y, fog, _maskState, tilemap);
		pMid.put();
	}

	override public function update(elapsed:Float):Void
	{
		if (!ready)
		{
			super.update(elapsed);
		}
		else
		{
			playerMovement(elapsed);
			ai.EnemyBrain.process(player, enemies, tilemap, elapsed, mainCam);
			if (reticle != null)
				reticle.updateFromPlayer(player, overCam);
			super.update(elapsed);
			FlxG.collide(player, tilemap.wallsMap);
			FlxG.collide(enemies, tilemap.wallsMap);
		}

		updateFogAndMask();
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
			moveAngle = Math.atan2(move.y, move.x) * FlxAngle.TO_DEG;
			any = true;
			var stickMag:Float = Math.sqrt(move.x * move.x + move.y * move.y);
			if (stickMag > 1.0)
				stickMag = 1.0;

			analogOrigSpeed = player.speed;
			player.speed = analogOrigSpeed * stickMag;
		}
		else if (any)
		{
			// assign degrees so moveAngle stays consistent with stick input (which uses degrees)
			if (left)
				moveAngle = 180.0;
			else if (right)
				moveAngle = 0.0;
			else if (up)
				moveAngle = -90.0;
			else if (down)
				moveAngle = 90.0;

			if (left && up)
				moveAngle = -135.0;
			else if (right && up)
				moveAngle = -45.0;
			else if (left && down)
				moveAngle = 135.0;
			else if (right && down)
				moveAngle = 45.0;

			move.x = Math.cos(moveAngle * FlxAngle.TO_RAD);
			move.y = Math.sin(moveAngle * FlxAngle.TO_RAD);
		}

		if (any)
		{
			// moveAngle is already in degrees (when set from sticks or keys)
			player.move(moveAngle);
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
				FlxG.overlap(reticle, enemies, function(a:Reticle, b:Enemy):Void
				{
					if (b != null && b.alive && b.exists)
						hits.push(b);
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
		hudCam = new FlxCamera(0, 0, FlxG.width, FlxG.height);
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
