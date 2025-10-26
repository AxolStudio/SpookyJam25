package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxButton.FlxButtonState;
import flixel.ui.FlxButton.FlxTypedButton;
import ui.GameText;

class VirtualKeyboard extends FlxGroup
{
	public var isVisible:Bool = false;
	public var currentText:String = "";
	public var maxLength:Int = 20;
	public var onSubmit:String->Void;
	public var onCancel:Void->Void;

	// UI Elements
	private var background:NineSliceSprite;
	private var inputDisplay:GameText;
	private var keys:Array<FlxTypedButton<GameText>> = [];
	private var currentKeyIndex:Int = 0;
	private var isUppercase:Bool = true;
	private var highlight:FlxSprite;
	private var caseButton:FlxTypedButton<GameText>; // Reference to case toggle button
	private var inputBg:FlxSprite; // Reference to input background

	// Layout constants - properly centered
	private static inline var KEY_WIDTH:Int = 12;
	private static inline var KEY_HEIGHT:Int = 12;
	private static inline var KEY_SPACING:Int = 2;
	private static inline var KEYBOARD_WIDTH:Int = 13 * (KEY_WIDTH + KEY_SPACING) - KEY_SPACING; // Width for 13 keys
	private static inline var BG_WIDTH:Int = 280;
	private static inline var BG_HEIGHT:Int = 120;
	private static inline var BG_X:Int = Std.int((320 - BG_WIDTH) / 2); // Center on 320px screen
	private static inline var BG_Y:Int = 80;
	private static inline var KEYBOARD_Y:Int = BG_Y + 36; // 6px lower in background
	private static inline var INPUT_Y:Int = BG_Y + 16; // Position within background

	// Character sets - reorganized into logical groups
	private var lowercaseRow1:String = "abcdefghijklm";
	private var lowercaseRow2:String = "nopqrstuvwxyz";
	private var lowercaseRow3:String = " 0123456789-_"; // Space first, then numbers and symbols
	private var uppercaseRow1:String = "ABCDEFGHIJKLM";
	private var uppercaseRow2:String = "NOPQRSTUVWXYZ";
	private var uppercaseRow3:String = " 0123456789-_"; // Space first, then numbers and symbols

	public var x(get, set):Float;
	public var y(get, set):Float;
	public var width(get, never):Float;
	public var height(get, never):Float;

	function get_x():Float
	{
		return background == null ? BG_X : background.x;
	}

	function get_y():Float
	{
		return background == null ? BG_Y : background.y;
	}

	function get_width():Float
	{
		return background == null ? BG_WIDTH : background.width;
	}

	function get_height():Float
	{
		return background == null ? BG_HEIGHT : background.height;
	}

	function set_x(value:Float):Float
	{
		if (background == null)
			return BG_X;
		background.x = value;
		return background.x;
	}

	function set_y(value:Float):Float
	{
		if (background == null)
			return BG_Y;
		background.y = value;
		return background.y;
	}

	public function new()
	{
		super();
		createKeyboard();
		exists = false; // Start hidden
	}

	private function createKeyboard():Void
	{
		// Create 9-slice background
		background = new NineSliceSprite(BG_X, BG_Y, BG_WIDTH, BG_HEIGHT);
		add(background);

		// Dark background for input display - centered with more horizontal margins
		var inputBgWidth = 260; // Increased to 260 for more horizontal space
		inputBg = new FlxSprite(BG_X + (BG_WIDTH - inputBgWidth) / 2, INPUT_Y - 5);
		inputBg.makeGraphic(inputBgWidth, 22, 0xFF000000);
		add(inputBg);

		// Input display - centered with more space
		inputDisplay = new GameText(BG_X + (BG_WIDTH - 260) / 2, INPUT_Y, "");
		inputDisplay.autoSize = false;
		inputDisplay.fieldWidth = 260;
		add(inputDisplay);

		// Create character keys in a grid
		createCharacterGrid();

		// Create action buttons
		createActionButtons();

		// Highlight sprite for navigation
		highlight = new FlxSprite();
		highlight.makeGraphic(KEY_WIDTH + 2, KEY_HEIGHT + 2, 0xFFFFFF00);
		highlight.alpha = 0.5;
		add(highlight);

		updateDisplay();
	}

	private function createCharacterGrid():Void
	{
		var rows = getCurrentRows();

		for (rowIndex in 0...rows.length)
		{
			var rowChars = rows[rowIndex];
			var rowWidth = rowChars.length * (KEY_WIDTH + KEY_SPACING) - KEY_SPACING;
			var startX = BG_X + (BG_WIDTH - rowWidth) / 2; // Center each row within background

			for (charIdx in 0...rowChars.length)
			{
				var char = rowChars.charAt(charIdx);
				var x = startX + charIdx * (KEY_WIDTH + KEY_SPACING);
				var y = KEYBOARD_Y + rowIndex * (KEY_HEIGHT + KEY_SPACING);

				// Use the actual character (including space)
				var key = createCharacterKey(x, y, char, char);
				keys.push(key);
				add(key);
			}
		}
	}

	private function createActionButtons():Void
	{
		var buttonWidth = 35;
		var buttonSpacing = 5;
		var buttonsY = KEYBOARD_Y + 3 * (KEY_HEIGHT + KEY_SPACING) + 5; // Below keyboard grid

		// Calculate total width and center the button row
		var totalButtonWidth = 6 * buttonWidth + 5 * buttonSpacing;
		var startX = BG_X + (BG_WIDTH - totalButtonWidth) / 2;

		// CLEAR button
		var clearBtn = createActionKey(startX, buttonsY, buttonWidth, "CLR", clearText);
		keys.push(clearBtn);
		add(clearBtn);

		// DELETE button
		var deleteBtn = createActionKey(startX + (buttonWidth + buttonSpacing), buttonsY, buttonWidth, "DEL", deleteChar);
		keys.push(deleteBtn);
		add(deleteBtn);

		// TOGGLE CASE button
		caseButton = createActionKey(startX + 2 * (buttonWidth + buttonSpacing), buttonsY, buttonWidth, "ABC", toggleCase);
		keys.push(caseButton);
		add(caseButton);

		// RANDOM button
		var randomBtn = createActionKey(startX + 3 * (buttonWidth + buttonSpacing), buttonsY, buttonWidth, "RND", generateRandomName);
		keys.push(randomBtn);
		add(randomBtn);

		// SUBMIT button
		var submitBtn = createActionKey(startX + 4 * (buttonWidth + buttonSpacing), buttonsY, buttonWidth, "OK", submitName);
		keys.push(submitBtn);
		add(submitBtn);

		// CANCEL button
		var cancelBtn = createActionKey(startX + 5 * (buttonWidth + buttonSpacing), buttonsY, buttonWidth, "Close", cancelInput);
		keys.push(cancelBtn);
		add(cancelBtn);
	}

	private function getCurrentCharSet():String
	{
		// This method is kept for compatibility but not used in new layout
		return isUppercase ? "ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789-_" : "abcdefghijklmnopqrstuvwxyz 0123456789-_";
	}

	private function getCurrentRows():Array<String>
	{
		if (isUppercase)
		{
			return [uppercaseRow1, uppercaseRow2, uppercaseRow3];
		}
		else
		{
			return [lowercaseRow1, lowercaseRow2, lowercaseRow3];
		}
	}

	private function getCurrentTotalCharKeys():Int
	{
		var rows = getCurrentRows();
		var total = 0;
		for (row in rows)
		{
			total += row.length;
		}
		return total;
	}

	public function show(initialText:String = ""):Void
	{
		currentText = initialText;
		isVisible = true;
		exists = true; // Make visible
		currentKeyIndex = 0;
		updateDisplay();
		updateHighlight();

		// Temporarily just show without animation for debugging
		// TODO: Re-enable animation once positioning works
	}

	public function hide():Void
	{
		isVisible = false;

		// Animate sliding down quickly
		var targetY = FlxG.height + 20;
		FlxTween.tween(this, {y: targetY}, 0.2, {
			ease: FlxEase.backIn,
			onComplete: function(_)
			{
				exists = false;
			} // Hide after animation
		});
	}

	public function handleInput():Void
	{
		if (!isVisible)
			return;

		// Navigation
		if (Actions.rightUI.triggered)
		{
			navigateRight();
		}
		else if (Actions.leftUI.triggered)
		{
			navigateLeft();
		}
		else if (Actions.downUI.triggered)
		{
			navigateDown();
		}
		else if (Actions.upUI.triggered)
		{
			navigateUp();
		}

		// Activation
		if (Actions.pressUI.triggered)
		{
			activateCurrentKey();
		}

		// Mouse input
		if (FlxG.mouse.justPressed)
		{
			handleMouseClick();
		}

		updateHighlight();
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
			// From row 1 to row 2
			var newIndex = currentKeyIndex + row1Length;
			if (newIndex < totalCharKeys)
				currentKeyIndex = newIndex;
		}
		else if (currentKeyIndex < row1Length + row2Length)
		{
			// From row 2 to row 3
			var newIndex = currentKeyIndex + row2Length;
			if (newIndex < totalCharKeys)
				currentKeyIndex = newIndex;
		}
		else if (currentKeyIndex < totalCharKeys)
		{
			// From row 3 to action buttons
			currentKeyIndex = totalCharKeys; // First action button
		}
		else
		{
			// Cycle through action buttons
			var actionIndex = currentKeyIndex - totalCharKeys;
			actionIndex = (actionIndex + 1) % 6; // 6 action buttons
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
		{
			// From row 1 to action buttons (wrap around)
			currentKeyIndex = keys.length - 1; // Last action button
		}
		else if (currentKeyIndex < row1Length + row2Length)
		{
			// From row 2 to row 1
			var newIndex = currentKeyIndex - row1Length;
			if (newIndex >= 0)
				currentKeyIndex = newIndex;
		}
		else if (currentKeyIndex < totalCharKeys)
		{
			// From row 3 to row 2
			var newIndex = currentKeyIndex - row2Length;
			if (newIndex >= row1Length)
				currentKeyIndex = newIndex;
		}
		else
		{
			// From action buttons to row 3
			currentKeyIndex = totalCharKeys - 1; // Last char in row 3
		}
	}

	private function handleMouseClick():Void
	{
		var mousePos = FlxG.mouse.getWorldPosition();

		for (i in 0...keys.length)
		{
			if (keys[i].overlapsPoint(mousePos))
			{
				currentKeyIndex = i;
				// FlxTypedButton handles mouse clicks automatically
				break;
			}
		}

		mousePos.put();
	}

	private function activateCurrentKey():Void
	{
		if (currentKeyIndex >= keys.length)
			return;

		// Simulate button press
		var key = keys[currentKeyIndex];
		key.onUp.fire();
	}

	private function toggleCase():Void
	{
		isUppercase = !isUppercase;

		// Update the case button label to reflect current state
		if (caseButton != null)
		{
			caseButton.label.text = isUppercase ? "abc" : "ABC";
		}

		// Update character keys text with new row-based layout
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
					// Update both the button label and its callback
					keys[keyIndex].label.text = char;
					// Update the button's callback to use the new character
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

	private function createCharacterKey(x:Float, y:Float, char:String, ?displayChar:String):FlxTypedButton<GameText>
	{
		if (displayChar == null)
			displayChar = char;

		var btn = new FlxTypedButton<GameText>(Std.int(x), Std.int(y));
		btn.makeGraphic(KEY_WIDTH, KEY_HEIGHT, 0xFF666666);
		btn.label = new GameText(0, 0, displayChar);
		btn.label.color = 0xFFFFFFFF;

		// Center the text in the button for all states
		var centerX = (KEY_WIDTH - btn.label.width) / 2;
		var centerY = (KEY_HEIGHT - btn.label.height) / 2;
		btn.labelOffsets[0].set(centerX, centerY); // NORMAL
		btn.labelOffsets[1].set(centerX, centerY); // HIGHLIGHT
		btn.labelOffsets[2].set(centerX, centerY); // PRESSED

		// Capture the character in a closure
		var capturedChar = char;
		btn.onUp.callback = function()
		{
			if (currentText.length < maxLength)
			{
				currentText += capturedChar;
				updateDisplay();
			}
		};
		return btn;
	}

	private function createActionKey(x:Float, y:Float, width:Int, text:String, callback:Void->Void):FlxTypedButton<GameText>
	{
		var btn = new FlxTypedButton<GameText>(Std.int(x), Std.int(y));
		btn.makeGraphic(width, KEY_HEIGHT, 0xFF888888);
		btn.label = new GameText(0, 0, text);
		btn.label.color = 0xFFFFFFFF;

		// Center the text in the button for all states
		var centerX = (width - btn.label.width) / 2;
		var centerY = (KEY_HEIGHT - btn.label.height) / 2;
		btn.labelOffsets[0].set(centerX, centerY); // NORMAL
		btn.labelOffsets[1].set(centerX, centerY); // HIGHLIGHT
		btn.labelOffsets[2].set(centerX, centerY); // PRESSED

		btn.onUp.callback = callback;
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

	private function generateRandomName():Void
	{
		// TODO: Placeholder for random name generation
		currentText = "RandomName";
		updateDisplay();
	}

	private function updateDisplay():Void
	{
		if (inputDisplay != null)
		{
			var displayText = currentText;
			if (displayText == "")
				displayText = "_";
			inputDisplay.text = displayText;
		}
	}

	private function updateHighlight():Void
	{
		if (currentKeyIndex < keys.length)
		{
			// Reset all buttons to normal state first
			for (key in keys)
			{
				key.status = FlxButtonState.NORMAL;
			}

			// Set current button to highlight state
			var key = keys[currentKeyIndex];
			key.status = FlxButtonState.HIGHLIGHT;

			// Position highlight sprite
			highlight.x = key.x - 1;
			highlight.y = key.y - 1;
			highlight.setGraphicSize(Std.int(key.width + 2), Std.int(key.height + 2));
			highlight.updateHitbox();
		}
	}
}
