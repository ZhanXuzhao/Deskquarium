extends Resource
class_name FishData

enum Species {
	GUPPY,
	GOLDFISH,
	ANGELFISH,
	AROWANA,
	COUNT
}

static func get_species_name(species: Species) -> String:
	match species:
		Species.GUPPY:
			return "孔雀鱼"
		Species.GOLDFISH:
			return "金鱼"
		Species.ANGELFISH:
			return "神仙鱼"
		Species.AROWANA:
			return "龙鱼"
	return ""

static func get_species_name_en(species: Species) -> String:
	match species:
		Species.GUPPY:
			return "Guppy"
		Species.GOLDFISH:
			return "Goldfish"
		Species.ANGELFISH:
			return "Angelfish"
		Species.AROWANA:
			return "Arowana"
	return ""

static func get_buy_cost(species: Species) -> int:
	match species:
		Species.GUPPY:
			return 50
		Species.GOLDFISH:
			return 150
		Species.ANGELFISH:
			return 400
		Species.AROWANA:
			return 1000
	return 0

static func get_base_sell_price(species: Species) -> int:
	match species:
		Species.GUPPY:
			return 30
		Species.GOLDFISH:
			return 100
		Species.ANGELFISH:
			return 300
		Species.AROWANA:
			return 800
	return 0

static func get_food_cost(species: Species) -> int:
	match species:
		Species.GUPPY:
			return 5
		Species.GOLDFISH:
			return 10
		Species.ANGELFISH:
			return 20
		Species.AROWANA:
			return 40
	return 0

static func get_growth_rate(species: Species) -> float:
	match species:
		Species.GUPPY:
			return 0.12
		Species.GOLDFISH:
			return 0.08
		Species.ANGELFISH:
			return 0.06
		Species.AROWANA:
			return 0.04
	return 0.0

static func get_max_level(species: Species) -> int:
	match species:
		Species.GUPPY:
			return 5
		Species.GOLDFISH:
			return 8
		Species.ANGELFISH:
			return 12
		Species.AROWANA:
			return 15
	return 1

static func get_svg_path(species: Species) -> String:
	match species:
		Species.GUPPY:
			return "res://assets/fish/fish_guppy.svg"
		Species.GOLDFISH:
			return "res://assets/fish/fish_goldfish.svg"
		Species.ANGELFISH:
			return "res://assets/fish/fish_angelfish.svg"
		Species.AROWANA:
			return "res://assets/fish/fish_arowana.svg"
	return ""

static func get_unlock_requirement(species: Species) -> Dictionary:
	match species:
		Species.GUPPY:
			return {"type": "none"}
		Species.GOLDFISH:
			return {"type": "total_earned", "value": 500}
		Species.ANGELFISH:
			return {"type": "total_earned", "value": 2000}
		Species.AROWANA:
			return {"type": "total_earned", "value": 5000}
	return {"type": "none"}

static func get_description(species: Species) -> String:
	match species:
		Species.GUPPY:
			return "色彩鲜艳的小型热带鱼，非常适合新手饲养。"
		Species.GOLDFISH:
			return "经典的金鱼，圆润可爱，成长性好。"
		Species.ANGELFISH:
			return "优雅的神仙鱼，拥有独特的三角体型和长鳍。"
		Species.AROWANA:
			return "传说中的龙鱼，体型修长，价值不菲。"
	return ""

static func get_max_hunger(species: Species) -> float:
	match species:
		Species.GUPPY:
			return 100.0
		Species.GOLDFISH:
			return 120.0
		Species.ANGELFISH:
			return 150.0
		Species.AROWANA:
			return 200.0
	return 100.0

static func get_hunger_drain_rate(species: Species) -> float:
	return 2.0

static func get_sell_price(fish_species: Species, level: int) -> int:
	var base = get_base_sell_price(fish_species)
	return int(base * (1.0 + 0.3 * level))
