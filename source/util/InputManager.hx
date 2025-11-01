package util;

import flixel.FlxG;
import flixel.FlxSprite;

/**
 * Centralized input manager for handling mouse/keyboard/gamepad/touch input modes.
 * 
 * Usage:
 * 1. Call InputManager.init() once at game start
 * 2. Call InputManager.update() in each state's update()
 * 3. Use InputManager.isUsingMouse() to check input mode
 * 4. Optional: Set a reticle sprite with setReticle() for gamepad mode
 * 
 * Benefits:
 * - Consistent input handling across all states
 * - Automatic mouse show/hide based on input device
 * - Automatic reticle show/hide for gamepad mode
 * - Easy to extend with touch support
 * - Single source of truth for input mode
 */
class InputManager
{
	/**
	 * Current input mode
	 */
	private static var usingMouse:Bool = true;

	/**
	 * Last recorded mouse position for detecting movement
	 */
	private static var lastMouseX:Int = 0;

	private static var lastMouseY:Int = 0;

	/**
	 * Optional reticle sprite to show/hide based on input mode
	 */
	private static var reticleSprite:FlxSprite = null;

	/**
	 * Force mouse visible (for specific screens that always need mouse)
	 */
	private static var forceMouseVisible:Bool = false;

	/**
	 * Deadzone for gamepad analog stick detection
	 */
	private static inline var GAMEPAD_DEADZONE:Float = 0.15;

	/**
	 * Initialize the input manager
	 * Call once at game start
	 */
	public static function init():Void
	{
		lastMouseX = FlxG.mouse.viewX;
		lastMouseY = FlxG.mouse.viewY;
		usingMouse = false; // Start hidden until mouse moves
		FlxG.mouse.visible = false;
	}

	/**
	 * Update input detection
	 * Call this in every state's update() method
	 * 
	 * @param allowGamepad - Whether gamepad input should hide mouse (default: true)
	 *                       Set to false for states that don't support gamepad
	 */
	public static function update(allowGamepad:Bool = true):Void
	{
		// Check for mouse movement
		var currentMouseX = FlxG.mouse.viewX;
		var currentMouseY = FlxG.mouse.viewY;

		if (currentMouseX != lastMouseX || currentMouseY != lastMouseY)
		{
			lastMouseX = currentMouseX;
			lastMouseY = currentMouseY;

			// Mouse moved - switch to mouse mode
			if (!usingMouse)
			{
				switchToMouse();
			}
		}

		// Check for gamepad/keyboard input (if allowed)
		if (allowGamepad && !forceMouseVisible)
		{
			var gamepadInput = checkGamepadInput();
			var keyboardInput = checkKeyboardInput();

			if (gamepadInput || keyboardInput)
			{
				if (usingMouse)
				{
					switchToGamepad();
				}
			}
		}

		// Apply mouse visibility based on mode
		if (forceMouseVisible)
		{
			FlxG.mouse.visible = true;
		}
		else
		{
			FlxG.mouse.visible = usingMouse;
		}

		// Update reticle visibility if set
		if (reticleSprite != null)
		{
			reticleSprite.visible = !usingMouse;
		}
	}

	/**
	 * Check if any gamepad input is active
	 */
	private static function checkGamepadInput():Bool
	{
		// Check action inputs
		if (Actions.leftUI != null && Actions.leftUI.triggered)
			return true;
		if (Actions.rightUI != null && Actions.rightUI.triggered)
			return true;
		if (Actions.upUI != null && Actions.upUI.triggered)
			return true;
		if (Actions.downUI != null && Actions.downUI.triggered)
			return true;
		if (Actions.pressUI != null && Actions.pressUI.triggered)
			return true;

		// Check analog stick movement
		if (Actions.leftStick != null)
		{
			if (Math.abs(Actions.leftStick.x) > GAMEPAD_DEADZONE || Math.abs(Actions.leftStick.y) > GAMEPAD_DEADZONE)
			{
				return true;
			}
		}

		return false;
	}

	/**
	 * Check if any keyboard input is active
	 */
	private static function checkKeyboardInput():Bool
	{
		// Check arrow keys and WASD
		if (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.W
			|| FlxG.keys.justPressed.A || FlxG.keys.justPressed.S || FlxG.keys.justPressed.D)
		{
			return true;
		}

		// Check Enter/Space/Escape
		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE || FlxG.keys.justPressed.ESCAPE)
		{
			return true;
		}

		return false;
	}

	/**
	 * Switch to mouse mode
	 */
	public static function switchToMouse():Void
	{
		usingMouse = true;
		Globals.usingMouse = true;

		if (!forceMouseVisible)
		{
			FlxG.mouse.visible = true;
		}

		if (reticleSprite != null)
		{
			reticleSprite.visible = false;
		}
	}

	/**
	 * Switch to gamepad/keyboard mode
	 */
	public static function switchToGamepad():Void
	{
		usingMouse = false;
		Globals.usingMouse = false;

		if (!forceMouseVisible)
		{
			FlxG.mouse.visible = false;
		}

		if (reticleSprite != null)
		{
			reticleSprite.visible = true;
		}
	}

	/**
	 * Check if currently using mouse
	 */
	public static function isUsingMouse():Bool
	{
		return usingMouse;
	}

	/**
	 * Set the reticle sprite to auto-show/hide based on input mode
	 * Pass null to clear
	 */
	public static function setReticle(sprite:FlxSprite):Void
	{
		reticleSprite = sprite;
		if (reticleSprite != null)
		{
			reticleSprite.visible = !usingMouse;
		}
	}

	/**
	 * Force mouse to always be visible (for specific screens)
	 * @param force - true to force visible, false to allow auto-hide
	 */
	public static function forceMouseVisibility(force:Bool):Void
	{
		forceMouseVisible = force;
		if (force)
		{
			FlxG.mouse.visible = true;
		}
	}

	/**
	 * Force switch to mouse mode (for specific situations like dialog boxes)
	 */
	public static function forceMouse():Void
	{
		switchToMouse();
	}

	/**
	 * For touch support (future): Check if using touch
	 */
	public static function isUsingTouch():Bool
	{
		// TODO: Implement touch detection
		// Check FlxG.touches for active touches
		#if mobile
		return FlxG.touches.list.length > 0;
		#else
		return false;
		#end
	}

	/**
	 * For touch support (future): Get primary touch point
	 */
	public static function getPrimaryTouch():flixel.input.touch.FlxTouch
	{
		#if mobile
		if (FlxG.touches.list.length > 0)
		{
			return FlxG.touches.list[0];
		}
		#end
		return null;
	}
}
