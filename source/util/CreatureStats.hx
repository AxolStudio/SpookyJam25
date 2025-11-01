package util;

/**
 * Unified creature statistics calculator.
 * Used by both GameResults and ArchiveState to ensure consistent
 * star ratings, fame, and money calculations.
 */
class CreatureStats
{
	// Speed constants
	private static inline var MIN_SPEED:Float = 20.0;
	private static inline var MAX_SPEED:Float = 70.0;

	/**
	 * Calculate speed stars (1-5) from speed value
	 */
	public static function calculateSpeedStars(speed:Float):Int
	{
		var t:Float = (speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED);
		if (t < 0)
			t = 0;
		if (t > 1)
			t = 1;
		return Std.int(Math.floor(t * 4.0)) + 1; // 1-5 stars
	}

	/**
	 * Calculate aggression stars (1-5) from aggression value (-1 to 1)
	 */
	public static function calculateAggressionStars(aggression:Float):Int
	{
		var a:Float = aggression;
		if (a < -1)
			a = -1;
		if (a > 1)
			a = 1;
		var an:Float = (a + 1.0) / 2.0; // Normalize to 0-1
		return Std.int(Math.floor(an * 4.0)) + 1; // 1-5 stars
	}

	/**
	 * Calculate skittishness stars (1-5) from skittishness value (0 to 1)
	 */
	public static function calculateSkittishStars(skittishness:Float):Int
	{
		var s:Float = skittishness;
		if (s < 0)
			s = 0;
		if (s > 1)
			s = 1;
		return Std.int(Math.floor(s * 4.0)) + 1; // 1-5 stars
	}

	/**
	 * Calculate power stars (1-5) from power value
	 * Power is already an integer, just clamp to 1-5
	 */
	public static function calculatePowerStars(power:Int):Int
	{
		var p:Int = power;
		if (p < 1)
			p = 1;
		if (p > 5)
			p = 5;
		return p;
	}

	/**
	 * Calculate total difficulty stars (sum of all 4 categories)
	 * Max possible: 20 stars (5+5+5+5)
	 */
	public static function calculateTotalStars(speedStars:Int, aggrStars:Int, skittStars:Int, powerStars:Int):Int
	{
		return speedStars + aggrStars + skittStars + powerStars;
	}

	/**
	 * Calculate money reward based on total stars and fame level
	 */
	public static function calculateMoneyReward(totalStars:Int, fameLevel:Int):Int
	{
		var maxStars:Int = 20; // 5+5+5+5
		var difficultyMultiplier:Float = totalStars / maxStars; // 0.2 to 1.0
		var baseMoneyPerStar:Int = 2;
		var moneyMultiplier:Float = 0.8 + (difficultyMultiplier * 0.4); // 0.8-1.2 variation
		return Std.int(Math.max(5, totalStars * baseMoneyPerStar * fameLevel * moneyMultiplier));
	}

	/**
	 * Calculate fame earned based on total stars and current fame level
	 */
	public static function calculateFameReward(totalStars:Int, fameLevel:Int):Int
	{
		var maxStars:Int = 20; // 5+5+5+5
		var fameNeeded:Int = Globals.getFameNeededForNextLevel();
		var baseFame:Float = fameNeeded * 0.20; // Target 20% per creature
		var difficultyMultiplier:Float = totalStars / maxStars; // 0.2 to 1.0
		return Std.int(Math.max(3, Math.round(baseFame * difficultyMultiplier)));
	}
}
