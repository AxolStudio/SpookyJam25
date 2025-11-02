package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxButton.FlxButtonState;
import ui.GameText;
import ui.NineSliceButton;
import AnimatedReticle;

class VirtualKeyboard extends FlxGroup
{
	public var isVisible:Bool = false;
	public var currentText:String = "";
	public var maxLength:Int = 20;
	public var onSubmit:String->Void;
	public var onCancel:Void->Void;

	private var background:NineSliceSprite;
	private var inputDisplay:GameText;
	private var keys:Array<NineSliceButton<GameText>> = [];
	private var currentKeyIndex:Int = 0;
	private var isUppercase:Bool = true;
	public var sharedReticle:AnimatedReticle;

	private var caseButton:NineSliceButton<GameText>;
	private var inputBg:FlxSprite;
	private var lastMouseX:Int = 0;
	private var lastMouseY:Int = 0;

	@:keep public var tweenY:Float = 0;

	private static inline var KEY_WIDTH:Int = 14;
	private static inline var KEY_HEIGHT:Int = 14;
	private static inline var KEY_SPACING:Int = 2;
	private static inline var PAD_X:Int = 6;
	private static inline var PAD_Y:Int = 6;

	private var lowercaseRow1:String = "abcdefghijklm";
	private var lowercaseRow2:String = "nopqrstuvwxyz";
	private var lowercaseRow3:String = " 0123456789-_";
	private var uppercaseRow1:String = "ABCDEFGHIJKLM";
	private var uppercaseRow2:String = "NOPQRSTUVWXYZ";
	private var uppercaseRow3:String = " 0123456789-_";

	public var x(get, set):Float;
	public var y(get, set):Float;
	public var width(get, never):Float;
	public var height(get, never):Float;

	function get_x():Float
	{
		return background == null ? 0 : background.x;
	}

	function get_y():Float
	{
		return background == null ? 0 : background.y;
	}

	function get_width():Float
	{
		return background == null ? 0 : background.width;
	}

	function get_height():Float
	{
		return background == null ? 0 : background.height;
	}

	function set_x(value:Float):Float
	{
		if (background == null)
			return value;
		var delta:Float = value - background.x;
		background.x += delta;
		if (inputBg != null)
			inputBg.x += delta;
		if (inputDisplay != null)
			inputDisplay.x += delta;
		for (k in keys)
			k.x += delta;
		return background.x;
	}

	function set_y(value:Float):Float
	{
		if (background == null)
			return value;
		var delta:Float = value - background.y;
		background.y += delta;
		if (inputBg != null)
			inputBg.y += delta;
		if (inputDisplay != null)
			inputDisplay.y += delta;
		for (k in keys)
			k.y += delta;
		return background.y;
	}

	public function new()
	{
		super();
		createKeyboard();
		exists = false;
	}

	private function createKeyboard():Void
	{
		var rows = getCurrentRows();
		var widestRow:Int = 0;
		for (rowChars in rows)
		{
			var rw = rowChars.length * (KEY_WIDTH + KEY_SPACING) - KEY_SPACING;
			if (rw > widestRow)
				widestRow = rw;
		}

		var buttonWidth = 35;
		var buttonSpacing = 5;
		var smallGap = 10;
		var baseWidth = Math.max(widestRow, 0);

		var totalButtonWidth = (2 * buttonWidth) + buttonSpacing + smallGap + (2 * buttonWidth) + buttonSpacing + smallGap + buttonWidth;

		var INPUT_SIDE_MARGIN = 12;
		var inputBgWidth = Math.max(widestRow, totalButtonWidth) - INPUT_SIDE_MARGIN;
		if (inputBgWidth < 80)
			inputBgWidth = 80;

		var contentWidth = Math.max(Math.max(widestRow, totalButtonWidth), inputBgWidth);
		var targetBgW = Std.int(contentWidth + PAD_X * 2);

		var rowsCount = rows.length;
		var keysHeight = rowsCount * KEY_HEIGHT + (rowsCount - 1) * KEY_SPACING;
		var INPUT_INSET_Y = 2;
		var inputBgHeight = KEY_HEIGHT + INPUT_INSET_Y * 2;
		var buttonsHeight = KEY_HEIGHT;
		var contentHeight = inputBgHeight + PAD_Y + keysHeight + PAD_Y + buttonsHeight;
		var targetBgH = Std.int(contentHeight + PAD_Y * 2);

		var targetBgX = Std.int((FlxG.width - targetBgW) / 2);
		var targetBgY = Std.int(FlxG.height - 8 - targetBgH);

		background = new NineSliceSprite(targetBgX, targetBgY, targetBgW, targetBgH);
		add(background);

		var contentX = targetBgX + PAD_X;
		var contentY = targetBgY + PAD_Y;

		inputBg = new FlxSprite(contentX + Std.int((contentWidth - inputBgWidth) / 2), contentY);
		inputBg.makeGraphic(Std.int(inputBgWidth), Std.int(inputBgHeight), 0xFF000000);
		add(inputBg);

		var inputDisplayX = inputBg.x + 4;
		var inputDisplayY = inputBg.y + Std.int((inputBg.height - KEY_HEIGHT) / 2);
		inputDisplay = new GameText(inputDisplayX, inputDisplayY, "");
		inputDisplay.autoSize = false;
		inputDisplay.fieldWidth = Std.int(inputBgWidth - 8);
		add(inputDisplay);

		var keyboardTop = inputBg.y + inputBg.height + PAD_Y;
		createCharacterGrid(Std.int(contentX), Std.int(keyboardTop), Std.int(contentWidth));
		createActionButtons(Std.int(contentX), Std.int(keyboardTop + keysHeight + PAD_Y), Std.int(contentWidth));

		updateDisplay();
	}

	private function createCharacterGrid(contentX:Float, contentY:Float, contentWidth:Int):Void
	{
		var rows = getCurrentRows();
		for (rowIndex in 0...rows.length)
		{
			var rowChars = rows[rowIndex];
			var rowWidth = rowChars.length * (KEY_WIDTH + KEY_SPACING) - KEY_SPACING;
			var startX = contentX + Std.int((contentWidth - rowWidth) / 2);

			for (charIdx in 0...rowChars.length)
			{
				var char = rowChars.charAt(charIdx);
				var x = startX + charIdx * (KEY_WIDTH + KEY_SPACING);
				var y = contentY + rowIndex * (KEY_HEIGHT + KEY_SPACING);
				var key = createCharacterKey(x, y, char, char);
				keys.push(key);
				add(key);
			}
		}
	}

	private function createActionButtons(contentX:Float, buttonsY:Float, contentWidth:Int):Void
	{
		var buttonWidth = 35;
		var buttonSpacing = 5;
		var smallGap = 10;
		var totalButtonWidth = 5 * buttonWidth + 2 * buttonSpacing + 2 * smallGap;
		var startX = contentX + Std.int((contentWidth - totalButtonWidth) / 2);

		var xPos = startX;
		var caseLabel = isUppercase ? "abc" : "ABC";
		caseButton = createActionKey(xPos, buttonsY, buttonWidth, caseLabel, toggleCase);
		keys.push(caseButton);
		add(caseButton);
		xPos += buttonWidth + buttonSpacing;

		var deleteBtn = createActionKey(xPos, buttonsY, buttonWidth, "DEL", deleteChar);
		keys.push(deleteBtn);
		add(deleteBtn);
		xPos += buttonWidth + smallGap;

		var clearBtn = createActionKey(xPos, buttonsY, buttonWidth, "CLR", clearText);
		keys.push(clearBtn);
		add(clearBtn);
		xPos += buttonWidth + buttonSpacing;

		var randomBtn = createActionKey(xPos, buttonsY, buttonWidth, "RND", generateRandomName);
		keys.push(randomBtn);
		add(randomBtn);
		xPos += buttonWidth + smallGap;

		var submitBtn = createActionKey(xPos, buttonsY, buttonWidth, "OK", submitName);
		keys.push(submitBtn);
		add(submitBtn);
	}

	private function getCurrentRows():Array<String>
	{
		return isUppercase ? [uppercaseRow1, uppercaseRow2, uppercaseRow3] : [lowercaseRow1, lowercaseRow2, lowercaseRow3];
	}

	private function getCurrentTotalCharKeys():Int
	{
		var rows = getCurrentRows();
		var total = 0;
		for (row in rows)
			total += row.length;
		return total;
	}

	public function show(initialText:String = ""):Void
	{
		currentText = initialText;
		isVisible = true;
		exists = true;
		currentKeyIndex = 0;
		updateDisplay();

		var offY = FlxG.height + 20;
		this.y = offY;
		tweenY = offY;
		var targetY:Float = FlxG.height - 8 - this.height;
		FlxTween.tween(this, {tweenY: targetY}, 0.28, {
			ease: FlxEase.backOut,
			onComplete: function(_)
			{
				if (sharedReticle != null && currentKeyIndex < keys.length)
				{
					var key = keys[currentKeyIndex];
					sharedReticle.setTarget(Std.int(key.x - 1), Std.int(key.y - 1), Std.int(key.width + 2), Std.int(key.height + 2));
					sharedReticle.visible = !Globals.usingMouse;
				}
			}
		});
	}

	public function hide():Void
	{
		isVisible = false;
		var targetY = FlxG.height + 20;
		FlxTween.tween(this, {tweenY: targetY}, 0.2, {
			ease: FlxEase.backIn,
			onComplete: function(_)
			{
				exists = false;
			}
		});
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (this.y != tweenY)
		{
			this.y = tweenY;
		}
	}

	public function handleInput():Void
	{
		if (!isVisible)
			return;
		checkInputMode();

		// Handle physical keyboard input FIRST (before nav keys)
		handlePhysicalKeyboard();

		if (Actions.rightUI.triggered)
			navigateRight();
		else if (Actions.leftUI.triggered)
			navigateLeft();
		else if (Actions.downUI.triggered)
			navigateDown();
		else if (Actions.upUI.triggered)
			navigateUp();
		if (Actions.pressUI.triggered)
			activateCurrentKey();
		if (FlxG.mouse.justPressed)
			handleMouseClick();
		updateHighlight();
	}

	/**
	 * Handle physical keyboard typing when virtual keyboard is visible
	 */
	private function handlePhysicalKeyboard():Void
	{
		// Only process if something was just pressed
		if (!FlxG.keys.justPressed.ANY)
			return;

		// Check for backspace/delete
		if (FlxG.keys.justPressed.BACKSPACE || FlxG.keys.justPressed.DELETE)
		{
			deleteChar();
			return;
		}

		// Check for enter/escape
		if (FlxG.keys.justPressed.ENTER)
		{
			submitName();
			return;
		}

		if (FlxG.keys.justPressed.ESCAPE)
		{
			cancelInput();
			return;
		}

		// Check for alphanumeric keys and allowed symbols
		var validChars:String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 -_";

		// Get the pressed key as a string
		var pressedKey:String = getJustPressedKey();

		if (pressedKey != null && pressedKey.length == 1)
		{
			// Check if it's a valid character
			if (validChars.indexOf(pressedKey) >= 0)
			{
				if (currentText.length < maxLength)
				{
					// Apply case (respect uppercase/lowercase mode of virtual keyboard)
					var char = pressedKey;
					if (isUppercase && char.toLowerCase() == char && char.toUpperCase() != char)
					{
						char = char.toUpperCase();
					}
					else if (!isUppercase && char.toUpperCase() == char && char.toLowerCase() != char)
					{
						char = char.toLowerCase();
					}

					currentText += char;
					updateDisplay();
				}
			}
		}
	}

	/**
	 * Get the character of the key that was just pressed
	 */
	private function getJustPressedKey():String
	{
		// Letters
		if (FlxG.keys.justPressed.A)
			return "a";
		if (FlxG.keys.justPressed.B)
			return "b";
		if (FlxG.keys.justPressed.C)
			return "c";
		if (FlxG.keys.justPressed.D)
			return "d";
		if (FlxG.keys.justPressed.E)
			return "e";
		if (FlxG.keys.justPressed.F)
			return "f";
		if (FlxG.keys.justPressed.G)
			return "g";
		if (FlxG.keys.justPressed.H)
			return "h";
		if (FlxG.keys.justPressed.I)
			return "i";
		if (FlxG.keys.justPressed.J)
			return "j";
		if (FlxG.keys.justPressed.K)
			return "k";
		if (FlxG.keys.justPressed.L)
			return "l";
		if (FlxG.keys.justPressed.M)
			return "m";
		if (FlxG.keys.justPressed.N)
			return "n";
		if (FlxG.keys.justPressed.O)
			return "o";
		if (FlxG.keys.justPressed.P)
			return "p";
		if (FlxG.keys.justPressed.Q)
			return "q";
		if (FlxG.keys.justPressed.R)
			return "r";
		if (FlxG.keys.justPressed.S)
			return "s";
		if (FlxG.keys.justPressed.T)
			return "t";
		if (FlxG.keys.justPressed.U)
			return "u";
		if (FlxG.keys.justPressed.V)
			return "v";
		if (FlxG.keys.justPressed.W)
			return "w";
		if (FlxG.keys.justPressed.X)
			return "x";
		if (FlxG.keys.justPressed.Y)
			return "y";
		if (FlxG.keys.justPressed.Z)
			return "z";

		// Numbers
		if (FlxG.keys.justPressed.ZERO)
			return "0";
		if (FlxG.keys.justPressed.ONE)
			return "1";
		if (FlxG.keys.justPressed.TWO)
			return "2";
		if (FlxG.keys.justPressed.THREE)
			return "3";
		if (FlxG.keys.justPressed.FOUR)
			return "4";
		if (FlxG.keys.justPressed.FIVE)
			return "5";
		if (FlxG.keys.justPressed.SIX)
			return "6";
		if (FlxG.keys.justPressed.SEVEN)
			return "7";
		if (FlxG.keys.justPressed.EIGHT)
			return "8";
		if (FlxG.keys.justPressed.NINE)
			return "9";

		// Special characters
		if (FlxG.keys.justPressed.SPACE)
			return " ";
		if (FlxG.keys.justPressed.MINUS)
			return "-";
		// Note: underscore requires shift+minus, not handled here - use virtual keyboard for _

		return null;
	}

	private function checkInputMode():Void
	{
		if (FlxG.mouse.viewX != lastMouseX || FlxG.mouse.viewY != lastMouseY)
		{
			lastMouseX = FlxG.mouse.viewX;
			lastMouseY = FlxG.mouse.viewY;
			Globals.usingMouse = true;
			FlxG.mouse.visible = true;
			if (sharedReticle != null)
			{
				sharedReticle.visible = false;
			}
		}
		else if (Actions.upUI.triggered || Actions.downUI.triggered || Actions.leftUI.triggered || Actions.rightUI.triggered)
		{
			Globals.usingMouse = false;
			FlxG.mouse.visible = false;
			if (sharedReticle != null)
			{
				sharedReticle.visible = true;
			}
		}
	}

	private function navigateRight():Void
	{
		currentKeyIndex = (currentKeyIndex + 1) % keys.length;
	}

	private function navigateLeft():Void
	{
		currentKeyIndex = currentKeyIndex > 0 ? currentKeyIndex - 1 : keys.length - 1;
	}

	private function navigateDown():Void
	{
		var rows = getCurrentRows();
		var row1Length = rows[0].length;
		var row2Length = rows[1].length;
		var row3Length = rows[2].length;
		var totalCharKeys = row1Length + row2Length + row3Length;
		if (currentKeyIndex < row1Length)
		{
			var newIndex = currentKeyIndex + row1Length;
			if (newIndex < totalCharKeys)
				currentKeyIndex = newIndex;
		}
		else if (currentKeyIndex < row1Length + row2Length)
		{
			var newIndex = currentKeyIndex + row2Length;
			if (newIndex < totalCharKeys)
				currentKeyIndex = newIndex;
		}
		else if (currentKeyIndex < totalCharKeys)
			currentKeyIndex = totalCharKeys;
		else
		{
			var actionIndex = currentKeyIndex - totalCharKeys;
			var actionCount = keys.length - totalCharKeys;
			actionIndex = (actionIndex + 1) % actionCount;
			currentKeyIndex = totalCharKeys + actionIndex;
		}
	}

	private function navigateUp():Void
	{
		var rows = getCurrentRows();
		var row1Length = rows[0].length;
		var row2Length = rows[1].length;
		var row3Length = rows[2].length;
		var totalCharKeys = row1Length + row2Length + row3Length;
		if (currentKeyIndex < row1Length)
			currentKeyIndex = keys.length - 1;
		else if (currentKeyIndex < row1Length + row2Length)
		{
			var newIndex = currentKeyIndex - row1Length;
			if (newIndex >= 0)
				currentKeyIndex = newIndex;
		}
		else if (currentKeyIndex < totalCharKeys)
		{
			var newIndex = currentKeyIndex - row2Length;
			if (newIndex >= row1Length)
				currentKeyIndex = newIndex;
		}
		else
			currentKeyIndex = totalCharKeys - 1;
	}

	private function handleMouseClick():Void
	{
		var mousePos = FlxG.mouse.getWorldPosition();
		for (i in 0...keys.length)
			if (keys[i].overlapsPoint(mousePos))
			{
				currentKeyIndex = i;
				break;
			}
		mousePos.put();
	}

	private function activateCurrentKey():Void
	{
		if (currentKeyIndex >= keys.length)
			return;
		var key = keys[currentKeyIndex];
		key.onUp.fire();
	}

	private function toggleCase():Void
	{
		isUppercase = !isUppercase;
		if (caseButton != null)
			caseButton.label.text = isUppercase ? "ABC" : "abc";
		var rows = getCurrentRows();
		var keyIndex = 0;
		for (rowIndex in 0...rows.length)
		{
			var rowChars = rows[rowIndex];
			for (charIdx in 0...rowChars.length)
			{
				if (keyIndex < keys.length && keyIndex < getCurrentTotalCharKeys())
				{
					var char = rowChars.charAt(charIdx);
					keys[keyIndex].label.text = char;
					var capturedChar = char;
					keys[keyIndex].onUp.callback = function()
					{
						if (currentText.length < maxLength)
						{
							currentText += capturedChar;
							updateDisplay();
						}
					};
					keyIndex++;
				}
			}
		}
	}

	private function createCharacterKey(x:Float, y:Float, char:String, ?displayChar:String):NineSliceButton<GameText>
	{
		if (displayChar == null)
			displayChar = char;
		var label = new GameText(0, 0, displayChar);
		label.updateHitbox();

		var btn = new NineSliceButton<GameText>(Std.int(x), Std.int(y), KEY_WIDTH, KEY_HEIGHT, function()
		{
			if (currentText.length < maxLength)
			{
				currentText += char;
				updateDisplay();
			}
		});
		btn.label = label;
		btn.positionLabel();
		return btn;
	}

	private function createActionKey(x:Float, y:Float, width:Int, text:String, callback:Void->Void):NineSliceButton<GameText>
	{
		var label = new GameText(0, 0, text);
		label.updateHitbox();

		var btn = new NineSliceButton<GameText>(Std.int(x), Std.int(y), width, KEY_HEIGHT, callback);
		btn.label = label;
		btn.positionLabel();
		return btn;
	}

	private function clearText():Void
	{
		currentText = "";
		updateDisplay();
	}

	private function deleteChar():Void
	{
		if (currentText.length > 0)
		{
			currentText = currentText.substring(0, currentText.length - 1);
			updateDisplay();
		}
	}

	private function submitName():Void
	{
		if (onSubmit != null)
			onSubmit(currentText);
		hide();
	}

	private function cancelInput():Void
	{
		if (onCancel != null)
			onCancel();
		hide();
	}

	/**
	 * Public method to generate and return a random name without updating display
	 */
	public function generatePublicRandomName():String
	{
		return generateRandomNameInternal();
	}

	private function generateRandomName():Void
	{
		currentText = generateRandomNameInternal();
		updateDisplay();
	}

	private function generateRandomNameInternal():String
	{
		var syllables:Array<String> = [
			"ba", "bah", "be", "bee", "bo", "boo", "bu", "buh", "cha", "choo", "chi", "che", "chu", "da", "dah", "de", "dee", "do", "doo", "du", "duh", "fa",
			"fah", "fe", "fee", "fo", "foo", "fu", "fuh", "ga", "gah", "ge", "gee", "go", "goo", "gu", "guh", "ha", "hah", "he", "hee", "ho", "hoo", "hu",
			"huh", "ja", "jah", "je", "jee", "jo", "joo", "ju", "juh", "ka", "kah", "ke", "kee", "ko", "koo", "ku", "kuh", "la", "lah", "le", "lee", "lo",
			"loo", "lu", "luh", "ma", "mah", "me", "mee", "mo", "moo", "mu", "muh", "na", "nah", "ne", "nee", "no", "noo", "nu", "nuh", "pa", "pah", "pe",
			"pee", "po", "poo", "pu", "puh", "ra", "rah", "re", "ree", "ro", "roo", "ru", "ruh", "sa", "sah", "se", "see", "so", "soo", "su", "suh", "ta",
			"tah", "te", "tee", "to", "too", "tu", "tuh", "va", "vah", "ve", "vee", "vo", "voo", "vu", "vuh", "wa", "wah", "we", "wee", "wo", "woo", "wu",
			"wuh", "ya", "yah", "ye", "yee", "yo", "yoo", "yu", "yuh", "za", "zah", "ze", "zee", "zo", "zoo", "zu", "zuh"
		];

		var name = "";
		var usedSeparator = false;
		var maxLength = 20;

		var numSyllables = 2 + Std.int(Math.random() * 3);

		for (i in 0...numSyllables)
		{
			var syl = syllables[Std.int(Math.random() * syllables.length)];
			name += syl;

			if (!usedSeparator && i < numSyllables - 1 && Math.random() < 0.3)
			{
				var separator = Math.random() < 0.5 ? " " : "-";
				name += separator;
				usedSeparator = true;
			}

			if (name.length >= maxLength - 3)
				break;
		}

		if (name.length > maxLength)
		{
			name = name.substring(0, maxLength);
		}

		var result = "";
		var capitalizeNext = true;
		for (i in 0...name.length)
		{
			var char = name.charAt(i);
			if (capitalizeNext)
			{
				result += char.toUpperCase();
				capitalizeNext = false;
			}
			else
			{
				result += char;
			}

			if (char == " " || char == "-")
			{
				capitalizeNext = true;
			}
		}

		return result;
	}

	private function updateDisplay():Void
	{
		if (inputDisplay != null)
		{
			var displayText = currentText == "" ? "_" : currentText;
			inputDisplay.text = displayText;
		}
	}

	private function updateHighlight():Void
	{
		if (currentKeyIndex < keys.length && sharedReticle != null)
		{
			var key = keys[currentKeyIndex];
			sharedReticle.changeTarget(Std.int(key.x - 1), Std.int(key.y - 1), Std.int(key.width + 2), Std.int(key.height + 2));
		}
	}
}
