package;

import flixel.FlxG;
import flixel.input.actions.FlxAction.FlxActionAnalog;
import flixel.input.actions.FlxAction.FlxActionDigital;
import flixel.input.actions.FlxActionInput.FlxInputDevice;
import flixel.input.actions.FlxActionInput.FlxInputDeviceID;
import flixel.input.actions.FlxActionManager;
import flixel.input.actions.FlxActionSet;

class Actions
{
	public static var usingGamepad:Bool = false;

	public static var actions:FlxActionManager;

	public static var menuIndex:Int = -1;
	public static var gameplayIndex:Int = -1;

	public static var up:FlxActionDigital;
	public static var down:FlxActionDigital;
	public static var left:FlxActionDigital;
	public static var right:FlxActionDigital;
	public static var attack:FlxActionDigital;

	public static var upUI:FlxActionDigital;
	public static var downUI:FlxActionDigital;
	public static var leftUI:FlxActionDigital;
	public static var rightUI:FlxActionDigital;
	public static var pressUI:FlxActionDigital;
	public static var pressUIPress:FlxActionDigital;
	public static var pause:FlxActionDigital;
	public static var any:FlxActionDigital;

	public static var leftStick:FlxActionAnalog;
	public static var rightStick:FlxActionAnalog;

	private static var initialized:Bool = false;

	public static function init():Void
	{
		if (initialized)
			return;
		initialized = true;

		if (Actions.actions != null)
			return;
		Actions.actions = FlxG.inputs.addUniqueType(new FlxActionManager());
		Actions.actions.resetOnStateSwitch = ResetPolicy.NONE;

		Actions.up = new FlxActionDigital("Up");
		Actions.down = new FlxActionDigital("Down");
		Actions.left = new FlxActionDigital("Left");
		Actions.right = new FlxActionDigital("Right");
		Actions.attack = new FlxActionDigital("Attack");
		Actions.upUI = new FlxActionDigital("UpUI");
		Actions.downUI = new FlxActionDigital("DownUI");
		Actions.leftUI = new FlxActionDigital("LeftUI");
		Actions.rightUI = new FlxActionDigital("RightUI");
		Actions.pressUI = new FlxActionDigital("PressUI");
		Actions.pressUIPress = new FlxActionDigital("PressUIPress");
		Actions.pause = new FlxActionDigital("Pause");
		Actions.any = new FlxActionDigital("Any");
		Actions.leftStick = new FlxActionAnalog("LeftStick");
		Actions.rightStick = new FlxActionAnalog("RightStick");

		var menuSet:FlxActionSet = new FlxActionSet("MenuControls", [
			Actions.upUI,
			Actions.downUI,
			Actions.leftUI,
			Actions.rightUI,
			Actions.pressUI,
			Actions.pressUIPress,
			Actions.any
		], [Actions.leftStick]);

		var gameplaySet:FlxActionSet = new FlxActionSet("GameplayControls", [
			Actions.up,
			Actions.down,
			Actions.left,
			Actions.right,
			Actions.pause,
			Actions.attack
		], [Actions.leftStick, Actions.rightStick]);

		menuIndex = Actions.actions.addSet(menuSet);
		gameplayIndex = Actions.actions.addSet(gameplaySet);

		Actions.up.addKey(UP, PRESSED);
		Actions.up.addKey(W, PRESSED);
		Actions.down.addKey(DOWN, PRESSED);
		Actions.down.addKey(S, PRESSED);
		Actions.left.addKey(LEFT, PRESSED);
		Actions.left.addKey(A, PRESSED);
		Actions.right.addKey(RIGHT, PRESSED);
		Actions.right.addKey(D, PRESSED);

		Actions.pause.addKey(P, JUST_PRESSED);
		Actions.pause.addKey(ESCAPE, JUST_PRESSED);

		Actions.attack.addKey(SPACE, JUST_PRESSED);
		Actions.attack.addKey(X, JUST_PRESSED);
		Actions.attack.addGamepad(A, JUST_PRESSED);
		Actions.attack.addGamepad(B, JUST_PRESSED);
		Actions.attack.addGamepad(RIGHT_TRIGGER, JUST_PRESSED);
		Actions.attack.addGamepad(RIGHT_SHOULDER, JUST_PRESSED);
		Actions.attack.addMouse(LEFT, JUST_PRESSED);

		Actions.up.addGamepad(DPAD_UP, PRESSED);
		Actions.down.addGamepad(DPAD_DOWN, PRESSED);
		Actions.left.addGamepad(DPAD_LEFT, PRESSED);
		Actions.right.addGamepad(DPAD_RIGHT, PRESSED);

		Actions.up.addGamepad(LEFT_STICK_DIGITAL_UP, PRESSED);
		Actions.down.addGamepad(LEFT_STICK_DIGITAL_DOWN, PRESSED);
		Actions.left.addGamepad(LEFT_STICK_DIGITAL_LEFT, PRESSED);
		Actions.right.addGamepad(LEFT_STICK_DIGITAL_RIGHT, PRESSED);

		Actions.pause.addGamepad(START, JUST_PRESSED);

		Actions.upUI.addKey(UP, JUST_RELEASED);
		Actions.upUI.addKey(W, JUST_RELEASED);
		Actions.downUI.addKey(DOWN, JUST_RELEASED);
		Actions.downUI.addKey(S, JUST_RELEASED);
		Actions.leftUI.addKey(LEFT, JUST_RELEASED);
		Actions.leftUI.addKey(A, JUST_RELEASED);
		Actions.rightUI.addKey(TAB, JUST_RELEASED);
		Actions.rightUI.addKey(RIGHT, JUST_RELEASED);
		Actions.rightUI.addKey(D, JUST_RELEASED);

		Actions.pressUI.addKey(ENTER, JUST_RELEASED);
		Actions.pressUI.addKey(SPACE, JUST_RELEASED);
		Actions.pressUI.addKey(X, JUST_RELEASED);

		Actions.pressUIPress.addKey(ENTER, PRESSED);
		Actions.pressUIPress.addKey(SPACE, PRESSED);
		Actions.pressUIPress.addKey(X, PRESSED);

		Actions.upUI.addGamepad(DPAD_UP, JUST_RELEASED);
		Actions.downUI.addGamepad(DPAD_DOWN, JUST_RELEASED);
		Actions.leftUI.addGamepad(DPAD_LEFT, JUST_RELEASED);
		Actions.rightUI.addGamepad(DPAD_RIGHT, JUST_RELEASED);
		Actions.pressUI.addGamepad(A, JUST_RELEASED);
		Actions.pressUI.addGamepad(B, JUST_RELEASED);
		Actions.pressUIPress.addGamepad(A, PRESSED);
		Actions.pressUIPress.addGamepad(B, PRESSED);

		Actions.leftStick.addGamepad(LEFT_ANALOG_STICK, MOVED, EITHER);
		Actions.rightStick.addGamepad(RIGHT_ANALOG_STICK, MOVED, EITHER);

		Actions.upUI.addGamepad(LEFT_STICK_DIGITAL_UP, JUST_RELEASED);
		Actions.downUI.addGamepad(LEFT_STICK_DIGITAL_DOWN, JUST_RELEASED);
		Actions.leftUI.addGamepad(LEFT_STICK_DIGITAL_LEFT, JUST_RELEASED);
		Actions.rightUI.addGamepad(LEFT_STICK_DIGITAL_RIGHT, JUST_RELEASED);

		Actions.any.addGamepad(A, JUST_RELEASED);
		Actions.any.addGamepad(B, JUST_RELEASED);
		Actions.any.addGamepad(X, JUST_RELEASED);
		Actions.any.addGamepad(Y, JUST_RELEASED);
		Actions.any.addGamepad(START, JUST_RELEASED);

		Actions.any.addKey(ANY, JUST_RELEASED);
	}

	public static function switchSet(NewSet:Int):Void
	{
		Actions.actions.activateSet(NewSet, FlxInputDevice.ALL, FlxInputDeviceID.ALL);
	}
}
