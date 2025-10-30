package;

typedef SavedCreature =
{
	var enemyType:String; // "001", "002", etc
	var photoIndex:Int; // 1, 2, 3, etc
	var hue:Float;
	var speed:Float;
	var aggression:Float;
	var skittishness:Float; // 0.0-1.0, how likely to flee
	var power:Int; // 1-5 stars
	var name:String;
	var date:String; // MM/DD/YYYY format
	var frameName:String; // The specific photo frame name selected
}
