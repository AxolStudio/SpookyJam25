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
	private var oneTimeUpgradeItems:Array<OneTimeUpgradeItem> = [];

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

		moneyText = new GameText(35, 30, "YOUR FUNDS: $" + Globals.playerMoney);
		add(moneyText);

		createUpgradeItem("O2 LEVEL", "o2", 25, 58);
		createUpgradeItem("SPEED", "speed", 25, 86);
		createUpgradeItem("ARMOR", "armor", 25, 114);
		createUpgradeItem("FILM", "film", 25, 142);

		// One-time upgrades (side by side)
		createOneTimeUpgrade("COMPASS", "compass", 300, 25, 175);
		createOneTimeUpgrade("SHUTTER+", "shutter", 400, 150, 175);

		var closeIcon = new FlxSprite(0, 0, "assets/ui/close.png");
		closeBtn = new NineSliceButton<FlxSprite>(FlxG.width - 60, FlxG.height - 25, 50, 24, onClose);
		closeBtn.isCancelButton = true;
		closeBtn.label = closeIcon;
		closeBtn.positionLabel();
		add(closeBtn);

		var overCam = new flixel.FlxCamera(0, 0, FlxG.width, FlxG.height);
		overCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(overCam, false);

		blackOut = new BlackOut(overCam);
		add(blackOut);

		blackOut.fade(null, false, 0.33, FlxColor.BLACK);
	}

	private function createUpgradeItem(name:String, upgradeKey:String, x:Float, y:Float):Void
	{
		var currentLevel = getUpgradeLevel(upgradeKey);
		var price = calculatePrice(currentLevel);

		var item = new UpgradeItem(name, upgradeKey, currentLevel, price, x, y, onBuy);
		upgradeItems.push(item);
		add(item);
	}

	private function createOneTimeUpgrade(name:String, upgradeKey:String, price:Int, x:Float, y:Float):Void
	{
		var owned = getUpgradeLevel(upgradeKey) > 0;
		var item = new OneTimeUpgradeItem(name, upgradeKey, owned, price, x, y, onBuyOneTime);
		oneTimeUpgradeItems.push(item);
		add(item);
	}

	private function onBuyOneTime(upgradeKey:String, price:Int):Void
	{
		if (getUpgradeLevel(upgradeKey) > 0)
			return;

		if (Globals.playerMoney < price)
		{
			trace("Not enough money!");
			return;
		}

		Globals.playerMoney -= price;
		Globals.gameSave.data.money = Globals.playerMoney;

		setUpgradeLevel(upgradeKey, 1);
		Globals.gameSave.flush();

		util.SoundHelper.playSound("upgrade_buy");
		axollib.AxolAPI.sendEvent("UPGRADE_PURCHASED_" + upgradeKey.toUpperCase(), 1);

		moneyText.text = "YOUR FUNDS: $" + Globals.playerMoney;

		for (item in upgradeItems)
		{
			item.updateAffordability(Globals.playerMoney);
		}

		for (item in oneTimeUpgradeItems)
		{
			item.updateAffordability(Globals.playerMoney);
		}

		trace("Purchased " + upgradeKey + " for $" + price);
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

		return BASE_PRICE * Std.int(Math.pow(3.5, currentLevel));
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

		Globals.playerMoney -= price;
		Globals.gameSave.data.money = Globals.playerMoney;

		setUpgradeLevel(upgradeKey, currentLevel + 1);
		Globals.gameSave.flush();

		util.SoundHelper.playSound("upgrade_buy");

		axollib.AxolAPI.sendEvent("UPGRADE_PURCHASED_" + upgradeKey.toUpperCase(), currentLevel + 1);

		moneyText.text = "YOUR FUNDS: $" + Globals.playerMoney;

		for (item in upgradeItems)
		{
			if (item.upgradeKey == upgradeKey)
			{
				item.updateUpgrade(currentLevel + 1, calculatePrice(currentLevel + 1));
			}
			else
			{
				item.updateAffordability(Globals.playerMoney);
			}
		}

		for (item in oneTimeUpgradeItems)
		{
			item.updateAffordability(Globals.playerMoney);
		}

		trace("Purchased " + upgradeKey + " level " + (currentLevel + 1) + " for $" + price);
	}

	private function onClose():Void
	{
		if (isTransitioning)
			return;

		isTransitioning = true;
		util.SoundHelper.playSound("phone_hangup");
		blackOut.fade(() -> FlxG.switchState(() -> new OfficeState()), true, 0.33, FlxColor.BLACK);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		util.InputManager.forceMouseVisibility(true);
		util.InputManager.update();

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

		nameText = new GameText(Std.int(x + 10), Std.int(y), name);
		add(nameText);

		for (i in 0...5)
		{
			var pip = new FlxSprite(x + 64 + i * 18, y + 2);
			pip.loadGraphic("assets/ui/purchase_pip.png", true, 16, 16);
			pip.animation.frameIndex = i < level ? 1 : 0;
			pips.push(pip);
			add(pip);
		}

		var priceStr = price > 0 ? "$" + price : "SOLD OUT";
		priceText = new GameText(Std.int(x + 159), Std.int(y), priceStr);
		if (price > 0)
		{
			priceText.color = Globals.playerMoney >= price ? 0xFF00FF00 : 0xFFFF0000;
		}
		add(priceText);

		if (level < 5)
		{
			var buyIcon = new FlxSprite(0, 0, "assets/ui/buy.png");
			var btnHeight = Std.int(buyIcon.height + 9);
			var btnWidth = Std.int(Math.max(buyIcon.width + 8, btnHeight));
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

		for (i in 0...pips.length)
		{
			pips[i].animation.frameIndex = i < newLevel ? 1 : 0;
		}

		var priceStr = newPrice > 0 ? "$" + newPrice : "SOLD OUT";
		priceText.text = priceStr;
		if (newPrice > 0)
		{
			priceText.color = Globals.playerMoney >= newPrice ? 0xFF00FF00 : 0xFFFF0000;
		}

		if (newLevel >= 5 && buyBtn != null)
		{
			remove(buyBtn);
			buyBtn.destroy();
			buyBtn = null;
		}
	}

	public function updateAffordability(currentMoney:Int):Void
	{
		if (currentLevel < 5)
		{
			var price = 50 * Std.int(Math.pow(3.5, currentLevel));
			priceText.color = currentMoney >= price ? 0xFF00FF00 : 0xFFFF0000;
		}
	}
}

class OneTimeUpgradeItem extends flixel.group.FlxGroup
{
	public var upgradeKey:String;

	private var nameText:GameText;
	private var priceText:GameText;
	private var statusText:GameText;
	private var buyBtn:NineSliceButton<FlxSprite>;
	private var owned:Bool;
	private var price:Int;
	private var onBuyCallback:(String, Int) -> Void;

	public function new(name:String, upgradeKey:String, owned:Bool, price:Int, x:Float, y:Float, onBuy:(String, Int) -> Void)
	{
		super();

		this.upgradeKey = upgradeKey;
		this.owned = owned;
		this.price = price;
		this.onBuyCallback = onBuy;

		nameText = new GameText(Std.int(x + 10), Std.int(y), name);
		add(nameText);

		if (owned)
		{
			statusText = new GameText(Std.int(x + 10), Std.int(y + 15), "OWNED");
			statusText.color = 0xFF00FF00;
			add(statusText);
		}
		else
		{
			priceText = new GameText(Std.int(x + 10), Std.int(y + 15), "$" + price);
			priceText.color = Globals.playerMoney >= price ? 0xFF00FF00 : 0xFFFF0000;
			add(priceText);

			var buyIcon = new FlxSprite(0, 0, "assets/ui/buy.png");
			var btnHeight = Std.int(buyIcon.height + 9);
			var btnWidth = Std.int(Math.max(buyIcon.width + 8, btnHeight));
			buyBtn = new NineSliceButton<FlxSprite>(Std.int(x + 60), Std.int(y + 12), btnWidth, btnHeight, onBuyClick);
			buyBtn.label = buyIcon;
			buyBtn.positionLabel();
			add(buyBtn);
		}
	}

	private function onBuyClick():Void
	{
		if (onBuyCallback != null && !owned)
		{
			onBuyCallback(upgradeKey, price);
			owned = true;

			// Update display
			if (priceText != null)
			{
				remove(priceText);
				priceText.destroy();
				priceText = null;
			}

			if (buyBtn != null)
			{
				remove(buyBtn);
				buyBtn.destroy();
				buyBtn = null;
			}

			statusText = new GameText(Std.int(nameText.x), Std.int(nameText.y + 15), "OWNED");
			statusText.color = 0xFF00FF00;
			add(statusText);
		}
	}

	public function updateAffordability(currentMoney:Int):Void
	{
		if (!owned && priceText != null)
		{
			priceText.color = currentMoney >= price ? 0xFF00FF00 : 0xFFFF0000;
		}
	}
}
