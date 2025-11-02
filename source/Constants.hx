package;

class Constants
{
	public static var Mouse:MouseHandler;

	public static inline var TILE_SIZE:Int = 16;
	// Photo mechanic tuning
	public static inline var PHOTO_START_FILM:Int = 5;
	public static inline var PHOTO_COOLDOWN:Float = 1.5; // Increased from 1.0 (1.5x)
	public static inline var PHOTO_FLASH_TIME:Float = 0.12;
	public static inline var PHOTO_DISSOLVE_DELAY:Float = 0.25;
	// Make the dissolve dramatic: increased slightly (was 2.8)
	public static inline var PHOTO_DISSOLVE_DURATION:Float = 3.4;

	// Number of rows the shader uses for the stepped dissolve (should match shader ROWS)
	public static inline var PHOTO_DISSOLVE_ROWS:Int = 16;

	// How many rows are removed instantly at flash (the "ash statue" base)
	public static inline var PHOTO_DISSOLVE_INSTANT_ROWS:Int = 2;
}
