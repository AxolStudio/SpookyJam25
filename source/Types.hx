package;

typedef TileCoord =
{
	x:Int,
	y:Int
};

typedef Vec2 =
{
	x:Float,
	y:Float
};

typedef Rect =
{
	x:Int,
	y:Int,
	w:Int,
	h:Int
};

enum abstract ReticleState(Int) to Int
{
	var NEUTRAL = 0; // White - nothing targeted
	var ENEMY_TARGETED = 1; // Green - enemy in range
	var OUT_OF_FILM = 2; // Red - no film left
	var ON_COOLDOWN = 3; // Yellow - camera cooling down
}

enum abstract EnemyState(Int) to Int
{
	var IDLE = 0; // Wandering randomly, not aware of player
	var ALERT = 1; // Heard/saw something, investigating
	var CHASE = 2; // Actively pursuing player
	var ATTACK = 3; // In attack range, preparing to strike
	var FLEE = 4; // Running away from player (skittish types)
	var CORNERED = 5; // Can't escape, will charge through player
}

enum abstract AggressionType(String) to String
{
	var HUNTER = "hunter"; // Always aggressive, chases relentlessly
	var TERRITORIAL = "territorial"; // Defensive, only chases if too close
	var SKITTISH = "skittish"; // Runs away when spotted
	var AMBUSHER = "ambusher"; // Hides and waits, strikes when player is close
}

enum abstract EnemyVariant(String) to String
{
	var NORMAL = "normal";
	var ALPHA = "alpha"; // 1.5x size, 1.25x speed, 1.5x damage
	var SHINY = "shiny"; // Different color, 1.5x value
}
