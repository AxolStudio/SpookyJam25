package;

import flixel.util.FlxDestroyUtil;
import shaders.AlphaDither;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxObject;
import flixel.tweens.FlxTween;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxAngle;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.ui.FlxButton.FlxTypedButton;
import ui.Hud;
import util.SoundHelper;

class PlayState extends FlxState
{
	public var tilemap:GameMap;
	public var player:Player;
	public var portal:Portal;
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
	private var isGameOver:Bool = false;
	private var gameOverDialog:NineSliceSprite;

	var portalShader:AlphaDither;
	var playerShader:AlphaDither;

	override public function create():Void
	{
		Globals.init();
		Actions.switchSet(Actions.gameplayIndex);
		FlxG.mouse.visible = false;

		atmosphereHue = FlxG.random.int(0, 359);
		createCameras();
		tilemap = new GameMap();
		tilemap.generate(atmosphereHue);
		add(tilemap);
		portal = new Portal(tilemap.portalTileX * Constants.TILE_SIZE, tilemap.portalTileY * Constants.TILE_SIZE);

		portal.playerOn = true;

		portalShader = new AlphaDither();
		portal.shader = portalShader;
		portalShader.globalAlpha = 0.0;
		add(portal);

		player = new Player(Std.int(portal.x), Std.int(portal.y + portal.height));
		playerShader = new AlphaDither();
		player.shader = playerShader;
		playerShader.globalAlpha = 0.0;
		add(player);

		enemies = new FlxTypedGroup<Enemy>();
		add(enemies);
		if (tilemap != null)
			tilemap.spawnEnemies(enemies, atmosphereHue, Std.int(player.x / Constants.TILE_SIZE), Std.int(player.y / Constants.TILE_SIZE));
		reticle = new Reticle(player);
		add(reticle);
		hud = new Hud(player);
		add(hud);
		portal.cameras = tilemap.cameras = player.cameras = enemies.cameras = [mainCam];
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
			FlxTween.tween(portalShader, {globalAlpha: 1,}, 0.66, {
				onStart: (_) ->
				{
					SoundHelper.playSound("portal");
				},
				startDelay: 0.33,
				onComplete: (_) ->
				{
					FlxTween.tween(playerShader, {globalAlpha: 1.0}, 0.66, {
						startDelay: 0.33,
						onComplete: (_) ->
						{
							player.shader = null;
							portal.shader = null;
							ready = true;
							// Track run start with initial O2
							axollib.AxolAPI.sendEvent("RUN_START", player.o2);
						}
					});
				}
			});
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
		Constants.Mouse.update(elapsed);

		if (!ready)
		{
			super.update(elapsed);
		}
		else if (isGameOver)
		{
			// Game over - only update UI
			super.update(elapsed);
		}
		else
		{
			// Check for O2 depletion
			if (player.o2 <= 0)
			{
				// Track death by O2 depletion
				axollib.AxolAPI.sendEvent("O2_DEPLETED", 0);
				triggerGameOver();
				return;
			}
			
			playerMovement(elapsed);
			ai.EnemyBrain.process(player, enemies, tilemap, elapsed, mainCam);
			if (reticle != null)
				reticle.updateFromPlayer(player, overCam);
			super.update(elapsed);
			FlxG.collide(player, tilemap.wallsMap);
			FlxG.collide(enemies, tilemap.wallsMap);
			// Check enemy collision with player
			if (player.invincibilityTimer <= 0)
			{
				FlxG.overlap(player, enemies, onEnemyHitPlayer);
			}
			
			if (portal.playerOn)
			{
				if (!portal.overlaps(player))
				{
					portal.playerOn = false;
				}
			}
			else
			{
				// if portal.playerOn is false but player now overlaps, treat as re-entry and end game
				if (portal.overlaps(player))
				{
					ready = false;
					player.stop();

					// Track successful run completion with remaining O2
					axollib.AxolAPI.sendEvent("RUN_COMPLETE", player.o2);

					// Track number of photos captured
					var photoCount:Float = player.getCaptured().length;
					axollib.AxolAPI.sendEvent("PHOTOS_CAPTURED", photoCount);

					// Play portal sound
					SoundHelper.playSound("portal");

					for (enemy in enemies.members)
					{
						if (enemy != null)
						{
							enemy.stop();
						}
					}
					blackOut.fade(() ->
					{
						// pass captured items to GameResults
						var items = player.getCaptured();
						FlxG.switchState(() -> new GameResults(items));
					}, true, 1.5, FlxColor.BLACK);
				}
			}
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
				// Track photo attempt with number of hits
				axollib.AxolAPI.sendEvent("PHOTO_TAKEN", hits.length);
				
				for (h in hits)
					if (h != null)
						h.capture(player);
			}
		}
	}
	private function onEnemyHitPlayer(player:FlxObject, enemy:FlxObject):Void
	{
		var enemyObj:Enemy = cast(enemy, Enemy);
		var playerObj:Player = cast(player, Player);

		if (enemyObj == null || !enemyObj.alive || !enemyObj.exists)
			return;
		if (playerObj == null || !playerObj.alive || !playerObj.exists)
			return;
		if (enemyObj.stunTimer > 0)
			return;

		// Calculate damage based on enemy power (1-5 O2 per hit)
		var damage:Float = enemyObj.power;
		playerObj.o2 -= damage;

		// Track enemy hit event with damage dealt
		axollib.AxolAPI.sendEvent("ENEMY_HIT", damage);

		// If this hit causes knockout, track it
		if (playerObj.o2 <= 0)
		{
			axollib.AxolAPI.sendEvent("ENEMY_KNOCKOUT", enemyObj.power);
		}

		// Calculate knockback direction (opposite from enemy)
		var dx:Float = playerObj.x - enemyObj.x;
		var dy:Float = playerObj.y - enemyObj.y;
		var dist:Float = Math.sqrt(dx * dx + dy * dy);
		if (dist > 0)
		{
			// Normalize and apply knockback
			dx /= dist;
			dy /= dist;
			var knockbackForce:Float = 100.0;
			playerObj.velocity.x = dx * knockbackForce;
			playerObj.velocity.y = dy * knockbackForce;
		}

		// Give player invincibility (0.5-1 second)
		playerObj.invincibilityTimer = FlxG.random.float(0.5, 1.0);
		playerObj.flickerTimer = 0;

		// Stun the enemy briefly
		enemyObj.stunTimer = FlxG.random.float(0.2, 0.4);
		enemyObj.stop();
	}

	private function triggerGameOver():Void
	{
		isGameOver = true;
		ready = false;
		player.stop();
		player.o2 = 0;

		// Stop all enemies
		for (enemy in enemies.members)
		{
			if (enemy != null)
			{
				enemy.stop();
			}
		}

		// Fade to WHITE
		blackOut.fade(() ->
		{
			showGameOverDialog();
		}, true, 1.0, FlxColor.WHITE);
	}

	private function showGameOverDialog():Void
	{
		// Clear captured photos
		player.clearCaptured();

		// Create dialog box (centered)
		var dialogWidth:Float = 240;
		var dialogHeight:Float = 80;
		var dialogX:Float = (FlxG.width - dialogWidth) / 2;
		var dialogY:Float = (FlxG.height - dialogHeight) / 2;

		gameOverDialog = new NineSliceSprite(dialogX, dialogY, dialogWidth, dialogHeight);
		gameOverDialog.cameras = [hudCam];
		add(gameOverDialog);

		// Add message text
		var message = new ui.GameText(0, 0,
			"You fell unconscious and\nwere dragged back through\nthe portal by your assistant.\nHowever you lost your photos.");
		message.cameras = [hudCam];
		add(message);
		message.x = dialogX + (dialogWidth - message.width) / 2;
		message.y = dialogY + 8;

		// Add OK button
		var okBtn = new FlxTypedButton<ui.GameText>(0, 0);
		okBtn.makeGraphic(40, 16, 0xFF666666);
		okBtn.label = new ui.GameText(0, 0, "OK");
		okBtn.label.color = 0xFFFFFFFF;
		var centerX = (40 - okBtn.label.width) / 2;
		var centerY = (16 - okBtn.label.height) / 2;
		okBtn.labelOffsets[0].set(centerX, centerY);
		okBtn.labelOffsets[1].set(centerX, centerY);
		okBtn.labelOffsets[2].set(centerX, centerY);
		okBtn.x = dialogX + (dialogWidth - okBtn.width) / 2;
		okBtn.y = dialogY + dialogHeight - okBtn.height - 8;
		okBtn.onUp.callback = onGameOverOK;
		okBtn.cameras = [hudCam];
		add(okBtn);

		// Fade in from WHITE (transparent)
		blackOut.fade(null, false, 1.0, FlxColor.WHITE);
	}

	private function onGameOverOK():Void
	{
		// Fade to black and return to office
		blackOut.fade(() -> FlxG.switchState(() -> new OfficeState()), true, 1.0, FlxColor.BLACK);
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
	override public function destroy():Void
	{
		// we need to destroy every module-level object we've created - AND remove/destroy all the shaders
		// we can use Flixel's FlxDestroyUtil for this to do it safely.
		tilemap = FlxDestroyUtil.destroy(tilemap);
		player = FlxDestroyUtil.destroy(player);
		portal = FlxDestroyUtil.destroy(portal);
		reticle = FlxDestroyUtil.destroy(reticle);
		enemies = FlxDestroyUtil.destroy(enemies);
		hud = FlxDestroyUtil.destroy(hud);
		fog = FlxDestroyUtil.destroy(fog);
		blackOut = FlxDestroyUtil.destroy(blackOut);
		mainCam = FlxDestroyUtil.destroy(mainCam);
		overCam = FlxDestroyUtil.destroy(overCam);
		hudCam = FlxDestroyUtil.destroy(hudCam);
		if (fogShader != null)
			fogShader = null;
		if (_maskState != null)
			_maskState.destroy();
		_maskState = null;
		if (_visibilityMask != null)
			_visibilityMask.destroy();
		_visibilityMask = null;
		portalShader = playerShader = null;
		super.destroy();
	}
}
