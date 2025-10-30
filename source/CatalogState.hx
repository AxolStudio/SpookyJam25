package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxColor;
import ui.GameText;
import ui.NineSliceButton;

class CatalogState extends FlxState
{
	private var bg:FlxSprite;
	private var closeBtn:NineSliceButton<FlxSprite>;
	private var moneyText:GameText;

	private var upgradeItems:Array<UpgradeItem> = [];

	private var blackOut:BlackOut;
	private var isTransitioning:Bool = false;

	private static inline var MAX_LEVEL:Int = 5;
	private static inline var BASE_PRICE:Int = 50;

	override public function create():Void
	{
		super.create();

		Globals.init();
		Actions.switchSet(Actions.menuIndex);

		bg = new FlxSprite(0, 0, "assets/ui/room_catalog.png");
		add(bg);

		// Money display - single line at top
		moneyText = new GameText(35, 30, "YOUR FUNDS: $" + Globals.playerMoney);
		add(moneyText);

		// Create upgrade items (moved up by ~8 pixels, which is about half a pip height)
		createUpgradeItem("O2 LEVEL", "o2", 25, 62);
		createUpgradeItem("SPEED", "speed", 25, 97);
		createUpgradeItem("ARMOR", "armor", 25, 132);
		createUpgradeItem("FILM", "film", 25, 167);

		// Close button (moved down)
		var closeIcon = new FlxSprite(0, 0, "assets/ui/close.png");
		closeBtn = new NineSliceButton<FlxSprite>(FlxG.width - 60, FlxG.height - 25, 50, 24, onClose);
		closeBtn.isCancelButton = true;
		closeBtn.label = closeIcon;
		closeBtn.positionLabel();
		add(closeBtn);

		// BlackOut for transitions
		var overCam = new flixel.FlxCamera(0, 0, FlxG.width, FlxG.height);
		overCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(overCam, false);

		blackOut = new BlackOut(overCam);
		add(blackOut);

		blackOut.fade(null, false, 0.33, FlxColor.BLACK);

		FlxG.mouse.visible = true;
	}

	private function createUpgradeItem(name:String, upgradeKey:String, x:Float, y:Float):Void
	{
		var currentLevel = getUpgradeLevel(upgradeKey);
		var price = calculatePrice(currentLevel);

		var item = new UpgradeItem(name, upgradeKey, currentLevel, price, x, y, onBuy);
		upgradeItems.push(item);
		add(item);
	}

	private function getUpgradeLevel(key:String):Int
	{
		if (Globals.gameSave.data.upgrades == null)
		{
			Globals.gameSave.data.upgrades = {};
			Globals.gameSave.flush();
		}

		var level = Reflect.field(Globals.gameSave.data.upgrades, key);
		return level != null ? level : 0;
	}

	private function setUpgradeLevel(key:String, level:Int):Void
	{
		if (Globals.gameSave.data.upgrades == null)
		{
			Globals.gameSave.data.upgrades = {};
		}

		Reflect.setField(Globals.gameSave.data.upgrades, key, level);
		Globals.gameSave.flush();
	}

	private function calculatePrice(currentLevel:Int):Int
	{
		if (currentLevel >= MAX_LEVEL)
			return 0;

		// Level 1 = $50, Level 2 = $150, Level 3 = $400, Level 4 = $1000, Level 5 = maxed out
		// Using a steeper exponential curve: 50 * (3^level)
		return BASE_PRICE * Std.int(Math.pow(3, currentLevel));
	}

	private function onBuy(upgradeKey:String):Void
	{
		var currentLevel = getUpgradeLevel(upgradeKey);

		if (currentLevel >= MAX_LEVEL)
			return;

		var price = calculatePrice(currentLevel);

		if (Globals.playerMoney < price)
		{
			trace("Not enough money!");
			return;
		}

		// Purchase the upgrade
		Globals.playerMoney -= price;
		Globals.gameSave.data.money = Globals.playerMoney;

		setUpgradeLevel(upgradeKey, currentLevel + 1);
		Globals.gameSave.flush();

		// Play purchase sound
		util.SoundHelper.playSound("upgrade_buy");

		// Track purchase event
		axollib.AxolAPI.sendEvent("UPGRADE_PURCHASED_" + upgradeKey.toUpperCase(), currentLevel + 1);

		// Update money display
		moneyText.text = "YOUR FUNDS: $" + Globals.playerMoney;

		// Refresh all upgrade items (affordability may have changed)
		for (item in upgradeItems)
		{
			if (item.upgradeKey == upgradeKey)
			{
				item.updateUpgrade(currentLevel + 1, calculatePrice(currentLevel + 1));
			}
			else
			{
				// Update affordability color for other items
				item.updateAffordability(Globals.playerMoney);
			}
		}

		trace("Purchased " + upgradeKey + " level " + (currentLevel + 1) + " for $" + price);
	}

	private function onClose():Void
	{
		if (isTransitioning)
			return;

		isTransitioning = true;
		blackOut.fade(() -> FlxG.switchState(() -> new OfficeState()), true, 0.33, FlxColor.BLACK);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// ESC to close
		if (FlxG.keys.justPressed.ESCAPE && !isTransitioning)
		{
			onClose();
		}
	}
}

class UpgradeItem extends flixel.group.FlxGroup
{
	public var upgradeKey:String;

	private var nameText:GameText;
	private var priceText:GameText;
	private var pips:Array<FlxSprite> = [];
	private var buyBtn:NineSliceButton<FlxSprite>;
	private var currentLevel:Int;
	private var onBuyCallback:String->Void;

	public function new(name:String, upgradeKey:String, level:Int, price:Int, x:Float, y:Float, onBuy:String->Void)
	{
		super();

		this.upgradeKey = upgradeKey;
		this.currentLevel = level;
		this.onBuyCallback = onBuy;

		// Name (moved right by ~10 pixels, about 2 letter widths)
		nameText = new GameText(Std.int(x + 10), Std.int(y), name);
		add(nameText);

		// Pips showing level
		for (i in 0...5)
		{
			var pip = new FlxSprite(x + 64 + i * 18, y + 2);
			pip.loadGraphic("assets/ui/purchase_pip.png", true, 16, 16);
			pip.animation.frameIndex = i < level ? 1 : 0;
			pips.push(pip);
			add(pip);
		}

		// Price - same y as name
		var priceStr = price > 0 ? "$" + price : "SOLD OUT";
		priceText = new GameText(Std.int(x + 159), Std.int(y), priceStr);
		// Color price based on affordability
		if (price > 0)
		{
			priceText.color = Globals.playerMoney >= price ? 0xFF00FF00 : 0xFFFF0000;
		}
		add(priceText);

		// Buy button - taller and more square
		if (level < 5)
		{
			var buyIcon = new FlxSprite(0, 0, "assets/ui/buy.png");
			// Make button fit icon properly: icon is likely ~16x16, so use height that fits middle slice
			var btnHeight = Std.int(buyIcon.height + 9); // Top + bottom slices + icon
			var btnWidth = Std.int(Math.max(buyIcon.width + 8, btnHeight)); // Make square-ish
			buyBtn = new NineSliceButton<FlxSprite>(Std.int(x + 209), Std.int(y - 3), btnWidth, btnHeight, onBuyClick);
			buyBtn.label = buyIcon;
			buyBtn.positionLabel();
			add(buyBtn);
		}
	}

	private function onBuyClick():Void
	{
		if (onBuyCallback != null)
		{
			onBuyCallback(upgradeKey);
		}
	}

	public function updateUpgrade(newLevel:Int, newPrice:Int):Void
	{
		currentLevel = newLevel;

		// Update pips
		for (i in 0...pips.length)
		{
			pips[i].animation.frameIndex = i < newLevel ? 1 : 0;
		}

		// Update price
		var priceStr = newPrice > 0 ? "$" + newPrice : "SOLD OUT";
		priceText.text = priceStr;
		// Update color based on affordability
		if (newPrice > 0)
		{
			priceText.color = Globals.playerMoney >= newPrice ? 0xFF00FF00 : 0xFFFF0000;
		}

		// Hide buy button if maxed out
		if (newLevel >= 5 && buyBtn != null)
		{
			remove(buyBtn);
			buyBtn.destroy();
			buyBtn = null;
		}
	}

	public function updateAffordability(currentMoney:Int):Void
	{
		// Just update price color based on current money
		if (currentLevel < 5)
		{
			var price = 50 * Std.int(Math.pow(3, currentLevel));
			priceText.color = currentMoney >= price ? 0xFF00FF00 : 0xFFFF0000;
		}
	}
}
