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
	var NEUTRAL = 0;
	var ENEMY_TARGETED = 1;
	var OUT_OF_FILM = 2;
	var ON_COOLDOWN = 3;
}

enum abstract EnemyState(Int) to Int
{
	var IDLE = 0;
	var ALERT = 1;
	var CHASE = 2;
	var ATTACK = 3;
	var FLEE = 4;
	var CORNERED = 5;
}

enum abstract AggressionType(String) to String
{
	var HUNTER = "hunter";
	var TERRITORIAL = "territorial";
	var SKITTISH = "skittish";
	var AMBUSHER = "ambusher";
}

enum abstract EnemyVariant(String) to String
{
	var NORMAL = "normal";
	var ALPHA = "alpha";
	var SHINY = "shiny";
}
