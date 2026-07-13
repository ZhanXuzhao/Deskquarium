extends Resource
class_name DecorationData

enum DecorationType {
	PLANT,
	ROCK,
}

static func get_display_name(deco_type: DecorationType) -> String:
	match deco_type:
		DecorationType.PLANT:
			return "水草"
		DecorationType.ROCK:
			return "石头"
	return ""

static func get_cost(deco_type: DecorationType) -> int:
	match deco_type:
		DecorationType.PLANT:
			return 80
		DecorationType.ROCK:
			return 50
	return 0

static func get_svg_path(deco_type: DecorationType) -> String:
	match deco_type:
		DecorationType.PLANT:
			return "res://assets/decorations/deco_plant.svg"
		DecorationType.ROCK:
			return "res://assets/decorations/deco_rock.svg"
	return ""

static func get_description(deco_type: DecorationType) -> String:
	match deco_type:
		DecorationType.PLANT:
			return "翠绿的水草，为鱼儿提供躲藏的场所。"
		DecorationType.ROCK:
			return "自然的石头，增添鱼缸的层次感。"
	return ""
