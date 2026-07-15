extends Resource
class_name FishData

enum Species {
	NEON_TETRA,
	ZEBRAFISH,
	GUPPY,
	CARDINAL_TETRA,
	MOLLY,
	MICKEY_MOUSE_PLATY,
	RUMMYNOSE_TETRA,
	HARLEQUIN_RASBORA,
	OTOCINCLUS,
	CORYDORAS,
	MOONFISH,
	SERPAE_TETRA,
	TIGER_BARB,
	BETTA,
	GOLDFISH,
	GOURAMI,
	PEARL_GOURAMI,
	BRISTLENOSE_PLECO,
	ANGELFISH,
	DISCUS,
	PLECOSTOMUS,
	AROWANA,
	COUNT
}

static func get_species_name(species: Species) -> String:
	match species:
		Species.NEON_TETRA:
			return "红绿灯鱼"
		Species.ZEBRAFISH:
			return "斑马鱼"
		Species.GUPPY:
			return "孔雀鱼"
		Species.CARDINAL_TETRA:
			return "宝莲灯鱼"
		Species.MOLLY:
			return "玛丽鱼"
		Species.MICKEY_MOUSE_PLATY:
			return "米奇鱼"
		Species.RUMMYNOSE_TETRA:
			return "红鼻剪刀"
		Species.HARLEQUIN_RASBORA:
			return "三角灯鱼"
		Species.OTOCINCLUS:
			return "小精灵鱼"
		Species.CORYDORAS:
			return "鼠鱼"
		Species.MOONFISH:
			return "月光鱼"
		Species.SERPAE_TETRA:
			return "红十字鱼"
		Species.TIGER_BARB:
			return "虎皮鱼"
		Species.BETTA:
			return "斗鱼"
		Species.GOLDFISH:
			return "金鱼"
		Species.GOURAMI:
			return "曼龙鱼"
		Species.PEARL_GOURAMI:
			return "珍珠马甲"
		Species.BRISTLENOSE_PLECO:
			return "黄金大胡子"
		Species.ANGELFISH:
			return "神仙鱼"
		Species.DISCUS:
			return "七彩神仙鱼"
		Species.PLECOSTOMUS:
			return "清道夫"
		Species.AROWANA:
			return "龙鱼"
	return ""

static func get_species_name_en(species: Species) -> String:
	match species:
		Species.NEON_TETRA:
			return "NeonTetra"
		Species.ZEBRAFISH:
			return "Zebrafish"
		Species.GUPPY:
			return "Guppy"
		Species.CARDINAL_TETRA:
			return "CardinalTetra"
		Species.MOLLY:
			return "Molly"
		Species.MICKEY_MOUSE_PLATY:
			return "MickeyMousePlaty"
		Species.RUMMYNOSE_TETRA:
			return "RummynoseTetra"
		Species.HARLEQUIN_RASBORA:
			return "HarlequinRasbora"
		Species.OTOCINCLUS:
			return "Otocinclus"
		Species.CORYDORAS:
			return "Corydoras"
		Species.MOONFISH:
			return "Moonfish"
		Species.SERPAE_TETRA:
			return "SerpaeTetra"
		Species.TIGER_BARB:
			return "TigerBarb"
		Species.BETTA:
			return "Betta"
		Species.GOLDFISH:
			return "Goldfish"
		Species.GOURAMI:
			return "Gourami"
		Species.PEARL_GOURAMI:
			return "PearlGourami"
		Species.BRISTLENOSE_PLECO:
			return "BristlenosePleco"
		Species.ANGELFISH:
			return "Angelfish"
		Species.DISCUS:
			return "Discus"
		Species.PLECOSTOMUS:
			return "Plecostomus"
		Species.AROWANA:
			return "Arowana"
	return ""

static func get_buy_cost(species: Species) -> int:
	match species:
		Species.NEON_TETRA:
			return 30
		Species.ZEBRAFISH:
			return 40
		Species.GUPPY:
			return 50
		Species.CARDINAL_TETRA:
			return 60
		Species.MOLLY:
			return 70
		Species.MICKEY_MOUSE_PLATY:
			return 60
		Species.RUMMYNOSE_TETRA:
			return 80
		Species.HARLEQUIN_RASBORA:
			return 70
		Species.OTOCINCLUS:
			return 90
		Species.CORYDORAS:
			return 80
		Species.MOONFISH:
			return 60
		Species.SERPAE_TETRA:
			return 90
		Species.TIGER_BARB:
			return 120
		Species.BETTA:
			return 130
		Species.GOLDFISH:
			return 150
		Species.GOURAMI:
			return 200
		Species.PEARL_GOURAMI:
			return 250
		Species.BRISTLENOSE_PLECO:
			return 300
		Species.ANGELFISH:
			return 400
		Species.DISCUS:
			return 600
		Species.PLECOSTOMUS:
			return 700
		Species.AROWANA:
			return 1000
	return 0

static func get_base_sell_price(species: Species) -> int:
	match species:
		Species.NEON_TETRA:
			return 15
		Species.ZEBRAFISH:
			return 20
		Species.GUPPY:
			return 30
		Species.CARDINAL_TETRA:
			return 35
		Species.MOLLY:
			return 40
		Species.MICKEY_MOUSE_PLATY:
			return 35
		Species.RUMMYNOSE_TETRA:
			return 45
		Species.HARLEQUIN_RASBORA:
			return 40
		Species.OTOCINCLUS:
			return 50
		Species.CORYDORAS:
			return 45
		Species.MOONFISH:
			return 35
		Species.SERPAE_TETRA:
			return 50
		Species.TIGER_BARB:
			return 70
		Species.BETTA:
			return 80
		Species.GOLDFISH:
			return 100
		Species.GOURAMI:
			return 130
		Species.PEARL_GOURAMI:
			return 160
		Species.BRISTLENOSE_PLECO:
			return 200
		Species.ANGELFISH:
			return 300
		Species.DISCUS:
			return 400
		Species.PLECOSTOMUS:
			return 500
		Species.AROWANA:
			return 800
	return 0

static func get_food_cost(species: Species) -> int:
	match species:
		Species.NEON_TETRA:
			return 2
		Species.ZEBRAFISH:
			return 3
		Species.GUPPY:
			return 5
		Species.CARDINAL_TETRA:
			return 5
		Species.MOLLY:
			return 6
		Species.MICKEY_MOUSE_PLATY:
			return 5
		Species.RUMMYNOSE_TETRA:
			return 5
		Species.HARLEQUIN_RASBORA:
			return 5
		Species.OTOCINCLUS:
			return 6
		Species.CORYDORAS:
			return 6
		Species.MOONFISH:
			return 5
		Species.SERPAE_TETRA:
			return 6
		Species.TIGER_BARB:
			return 8
		Species.BETTA:
			return 8
		Species.GOLDFISH:
			return 10
		Species.GOURAMI:
			return 12
		Species.PEARL_GOURAMI:
			return 15
		Species.BRISTLENOSE_PLECO:
			return 15
		Species.ANGELFISH:
			return 20
		Species.DISCUS:
			return 25
		Species.PLECOSTOMUS:
			return 30
		Species.AROWANA:
			return 40
	return 0

static func get_growth_rate(species: Species) -> float:
	match species:
		Species.NEON_TETRA:
			return 0.18
		Species.ZEBRAFISH:
			return 0.15
		Species.GUPPY:
			return 0.12
		Species.CARDINAL_TETRA:
			return 0.14
		Species.MOLLY:
			return 0.13
		Species.MICKEY_MOUSE_PLATY:
			return 0.14
		Species.RUMMYNOSE_TETRA:
			return 0.12
		Species.HARLEQUIN_RASBORA:
			return 0.13
		Species.OTOCINCLUS:
			return 0.11
		Species.CORYDORAS:
			return 0.11
		Species.MOONFISH:
			return 0.14
		Species.SERPAE_TETRA:
			return 0.12
		Species.TIGER_BARB:
			return 0.10
		Species.BETTA:
			return 0.10
		Species.GOLDFISH:
			return 0.08
		Species.GOURAMI:
			return 0.09
		Species.PEARL_GOURAMI:
			return 0.08
		Species.BRISTLENOSE_PLECO:
			return 0.07
		Species.ANGELFISH:
			return 0.06
		Species.DISCUS:
			return 0.05
		Species.PLECOSTOMUS:
			return 0.05
		Species.AROWANA:
			return 0.04
	return 0.0

static func get_max_level(species: Species) -> int:
	match species:
		Species.NEON_TETRA:
			return 4
		Species.ZEBRAFISH:
			return 4
		Species.GUPPY:
			return 5
		Species.CARDINAL_TETRA:
			return 5
		Species.MOLLY:
			return 6
		Species.MICKEY_MOUSE_PLATY:
			return 5
		Species.RUMMYNOSE_TETRA:
			return 6
		Species.HARLEQUIN_RASBORA:
			return 5
		Species.OTOCINCLUS:
			return 6
		Species.CORYDORAS:
			return 6
		Species.MOONFISH:
			return 5
		Species.SERPAE_TETRA:
			return 6
		Species.TIGER_BARB:
			return 7
		Species.BETTA:
			return 7
		Species.GOLDFISH:
			return 8
		Species.GOURAMI:
			return 9
		Species.PEARL_GOURAMI:
			return 10
		Species.BRISTLENOSE_PLECO:
			return 10
		Species.ANGELFISH:
			return 12
		Species.DISCUS:
			return 13
		Species.PLECOSTOMUS:
			return 14
		Species.AROWANA:
			return 15
	return 1

static func get_texture_path(species: Species) -> String:
	match species:
		Species.NEON_TETRA:
			return "res://assets/fish/fish_neontetra.png"
		Species.ZEBRAFISH:
			return "res://assets/fish/fish_zebrafish.png"
		Species.GUPPY:
			return "res://assets/fish/fish_guppy.png"
		Species.CARDINAL_TETRA:
			return "res://assets/fish/fish_cardinaltetra.png"
		Species.MOLLY:
			return "res://assets/fish/fish_molly.png"
		Species.MICKEY_MOUSE_PLATY:
			return "res://assets/fish/fish_mickeymouseplaty.png"
		Species.RUMMYNOSE_TETRA:
			return "res://assets/fish/fish_rummynosetetra.png"
		Species.HARLEQUIN_RASBORA:
			return "res://assets/fish/fish_harlequinrasbora.png"
		Species.OTOCINCLUS:
			return "res://assets/fish/fish_otocinclus.png"
		Species.CORYDORAS:
			return "res://assets/fish/fish_corydoras.png"
		Species.MOONFISH:
			return "res://assets/fish/fish_moonfish.png"
		Species.SERPAE_TETRA:
			return "res://assets/fish/fish_serpaetetra.png"
		Species.TIGER_BARB:
			return "res://assets/fish/fish_tigerbarb.png"
		Species.BETTA:
			return "res://assets/fish/fish_betta.png"
		Species.GOLDFISH:
			return "res://assets/fish/fish_goldfish.png"
		Species.GOURAMI:
			return "res://assets/fish/fish_gourami.png"
		Species.PEARL_GOURAMI:
			return "res://assets/fish/fish_pearlgourami.png"
		Species.BRISTLENOSE_PLECO:
			return "res://assets/fish/fish_bristlenosepleco.png"
		Species.ANGELFISH:
			return "res://assets/fish/fish_angelfish.png"
		Species.DISCUS:
			return "res://assets/fish/fish_discus.png"
		Species.PLECOSTOMUS:
			return "res://assets/fish/fish_plecostomus.png"
		Species.AROWANA:
			return "res://assets/fish/fish_arowana.png"
	return ""

static func get_unlock_requirement(species: Species) -> Dictionary:
	match species:
		Species.NEON_TETRA:
			return {"type": "none"}
		Species.ZEBRAFISH:
			return {"type": "none"}
		Species.GUPPY:
			return {"type": "none"}
		Species.CARDINAL_TETRA:
			return {"type": "total_earned", "value": 100}
		Species.MOLLY:
			return {"type": "total_earned", "value": 150}
		Species.MICKEY_MOUSE_PLATY:
			return {"type": "total_earned", "value": 150}
		Species.RUMMYNOSE_TETRA:
			return {"type": "total_earned", "value": 200}
		Species.HARLEQUIN_RASBORA:
			return {"type": "total_earned", "value": 200}
		Species.OTOCINCLUS:
			return {"type": "total_earned", "value": 250}
		Species.CORYDORAS:
			return {"type": "total_earned", "value": 250}
		Species.MOONFISH:
			return {"type": "total_earned", "value": 150}
		Species.SERPAE_TETRA:
			return {"type": "total_earned", "value": 300}
		Species.TIGER_BARB:
			return {"type": "total_earned", "value": 350}
		Species.BETTA:
			return {"type": "total_earned", "value": 400}
		Species.GOLDFISH:
			return {"type": "total_earned", "value": 500}
		Species.GOURAMI:
			return {"type": "total_earned", "value": 800}
		Species.PEARL_GOURAMI:
			return {"type": "total_earned", "value": 1200}
		Species.BRISTLENOSE_PLECO:
			return {"type": "total_earned", "value": 1500}
		Species.ANGELFISH:
			return {"type": "total_earned", "value": 2000}
		Species.DISCUS:
			return {"type": "total_earned", "value": 3000}
		Species.PLECOSTOMUS:
			return {"type": "total_earned", "value": 4000}
		Species.AROWANA:
			return {"type": "total_earned", "value": 5000}
	return {"type": "none"}

static func get_description(species: Species) -> String:
	match species:
		Species.NEON_TETRA:
			return "体型小巧的红蓝条纹灯鱼，群游效果极佳。"
		Species.ZEBRAFISH:
			return "适应性超强的条纹小鱼，活泼好动。"
		Species.GUPPY:
			return "色彩鲜艳的小型热带鱼，非常适合新手饲养。"
		Species.CARDINAL_TETRA:
			return "红腹蓝线的美丽灯鱼，比红绿灯更艳丽。"
		Species.MOLLY:
			return "圆润可爱的卵胎生鱼，会啃食藻类。"
		Species.MICKEY_MOUSE_PLATY:
			return "尾鳍上有米奇图案的趣味小鱼。"
		Species.RUMMYNOSE_TETRA:
			return "红鼻银身的群游小鱼，需要成群饲养。"
		Species.HARLEQUIN_RASBORA:
			return "带有黑色三角斑纹的文静灯鱼。"
		Species.OTOCINCLUS:
			return "专吃藻类的小型工具鱼，水质要求高。"
		Species.CORYDORAS:
			return "底层翻砂的装甲猫鱼，群养效果好。"
		Species.MOONFISH:
			return "温和的卵胎生小鱼，适合混养。"
		Species.SERPAE_TETRA:
			return "红色的活泼灯鱼，成年后有攻击性。"
		Species.TIGER_BARB:
			return "虎纹斑纹的活跃鱼，爱咬长鳍鱼。"
		Species.BETTA:
			return "拥有华丽长鳍的斗鱼，雄鱼不能同缸。"
		Species.GOLDFISH:
			return "经典的金鱼，圆润可爱，成长性好。"
		Species.GOURAMI:
			return "耐低氧的攀鲈科鱼，会呼吸空气。"
		Species.PEARL_GOURAMI:
			return "全身珍珠斑点的优雅攀鲈鱼。"
		Species.BRISTLENOSE_PLECO:
			return "长胡须的异型鱼，啃食沉木和藻类。"
		Species.ANGELFISH:
			return "优雅的神仙鱼，拥有独特的三角体型和长鳍。"
		Species.DISCUS:
			return "圆盘形状的高贵慈鲷，水质要求极高。"
		Species.PLECOSTOMUS:
			return "大型清道夫，啃食缸壁残饵和藻类。"
		Species.AROWANA:
			return "传说中的龙鱼，体型修长，价值不菲。"
	return ""

static func get_max_hunger(species: Species) -> float:
	match species:
		Species.NEON_TETRA:
			return 60.0
		Species.ZEBRAFISH:
			return 70.0
		Species.GUPPY:
			return 100.0
		Species.CARDINAL_TETRA:
			return 70.0
		Species.MOLLY:
			return 100.0
		Species.MICKEY_MOUSE_PLATY:
			return 70.0
		Species.RUMMYNOSE_TETRA:
			return 80.0
		Species.HARLEQUIN_RASBORA:
			return 70.0
		Species.OTOCINCLUS:
			return 80.0
		Species.CORYDORAS:
			return 90.0
		Species.MOONFISH:
			return 70.0
		Species.SERPAE_TETRA:
			return 80.0
		Species.TIGER_BARB:
			return 100.0
		Species.BETTA:
			return 100.0
		Species.GOLDFISH:
			return 120.0
		Species.GOURAMI:
			return 130.0
		Species.PEARL_GOURAMI:
			return 130.0
		Species.BRISTLENOSE_PLECO:
			return 140.0
		Species.ANGELFISH:
			return 150.0
		Species.DISCUS:
			return 160.0
		Species.PLECOSTOMUS:
			return 180.0
		Species.AROWANA:
			return 200.0
	return 100.0

static func get_hunger_drain_rate(_species: Species) -> float:
	return 2.0

static func get_sell_price(fish_species: Species, level: int) -> int:
	var base = get_base_sell_price(fish_species)
	return base * level

# 根据枚举值获取对应的英文文件名（小写）
static func get_texture_filename(species: Species) -> String:
	return get_species_name_en(species).to_lower()
