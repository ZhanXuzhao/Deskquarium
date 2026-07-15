extends Resource
class_name DecorationData

enum DecorationType {
	# 水草 (Plant)
	ANUBIAS,
	BUCEPHALANDRA,
	HYDRILLA,
	MOSS_1,
	MOSS_2,
	MOSS_3,
	MOSS_4,
	VALLISNERIA,
	# 珊瑚 (Coral)
	CORAL_1,
	CORAL_2,
	CORAL_3,
	CORAL_BONE_1,
	CORAL_BONE_2,
	# 装饰 (Ornament)
	CONCH,
	SEASHELL,
	SHRIMP_AVE,
	CRAB,
	OYSTER,
	ROCK,
	ROCK_2,
	ROCK_3,
	SCALLOP,
	# 底砂 (Substrate)
	SAND_1,
	SAND_2,
	SAND_3,
	COUNT,
}

static func get_display_name(deco_type: DecorationType) -> String:
	match deco_type:
		# 水草 (Plant)
		DecorationType.ANUBIAS:
			return "水榕"
		DecorationType.BUCEPHALANDRA:
			return "椒草"
		DecorationType.HYDRILLA:
			return "水蕴草"
		DecorationType.MOSS_1:
			return "莫斯 1"
		DecorationType.MOSS_2:
			return "莫斯 2"
		DecorationType.MOSS_3:
			return "莫斯 3"
		DecorationType.MOSS_4:
			return "莫斯 4"
		DecorationType.VALLISNERIA:
			return "水兰"
		# 珊瑚 (Coral)
		DecorationType.CORAL_1:
			return "珊瑚（红）"
		DecorationType.CORAL_2:
			return "珊瑚（蓝）"
		DecorationType.CORAL_3:
			return "珊瑚（紫）"
		DecorationType.CORAL_BONE_1:
			return "珊瑚骨（大）"
		DecorationType.CORAL_BONE_2:
			return "珊瑚骨（小）"
		# 装饰 (Ornament)
		DecorationType.CONCH:
			return "海螺"
		DecorationType.SEASHELL:
			return "贝壳"
		DecorationType.SHRIMP_AVE:
			return "虾屋"
		DecorationType.CRAB:
			return "螃蟹"
		DecorationType.OYSTER:
			return "牡蛎"
		DecorationType.ROCK:
			return "石头 1"
		DecorationType.ROCK_2:
			return "石头 2"
		DecorationType.ROCK_3:
			return "石头 3"
		DecorationType.SCALLOP:
			return "扇贝"
		# 底砂 (Substrate)
		DecorationType.SAND_1:
			return "细沙（浅）"
		DecorationType.SAND_2:
			return "细沙（深）"
		DecorationType.SAND_3:
			return "细沙（中）"
	return ""

static func get_cost(deco_type: DecorationType) -> int:
	match deco_type:
		# 水草 (Plant)
		DecorationType.ANUBIAS:
			return 80
		DecorationType.BUCEPHALANDRA:
			return 100
		DecorationType.HYDRILLA:
			return 60
		DecorationType.MOSS_1:
			return 50
		DecorationType.MOSS_2:
			return 50
		DecorationType.MOSS_3:
			return 50
		DecorationType.MOSS_4:
			return 50
		DecorationType.VALLISNERIA:
			return 70
		# 珊瑚 (Coral)
		DecorationType.CORAL_1:
			return 120
		DecorationType.CORAL_2:
			return 120
		DecorationType.CORAL_3:
			return 120
		DecorationType.CORAL_BONE_1:
			return 100
		DecorationType.CORAL_BONE_2:
			return 80
		# 装饰 (Ornament)
		DecorationType.CONCH:
			return 60
		DecorationType.SEASHELL:
			return 70
		DecorationType.SHRIMP_AVE:
			return 90
		DecorationType.CRAB:
			return 100
		DecorationType.OYSTER:
			return 80
		DecorationType.ROCK:
			return 50
		DecorationType.ROCK_2:
			return 55
		DecorationType.ROCK_3:
			return 60
		DecorationType.SCALLOP:
			return 75
		# 底砂 (Substrate)
		DecorationType.SAND_1:
			return 40
		DecorationType.SAND_2:
			return 40
		DecorationType.SAND_3:
			return 45
	return 0

static func get_texture_path(deco_type: DecorationType) -> String:
	match deco_type:
		# 水草 (Plant)
		DecorationType.ANUBIAS:
			return "res://assets/decorations/deco_plant_anubias.png"
		DecorationType.BUCEPHALANDRA:
			return "res://assets/decorations/deco_plant_bucephalandra.png"
		DecorationType.HYDRILLA:
			return "res://assets/decorations/deco_plant_hydrilla.png"
		DecorationType.MOSS_1:
			return "res://assets/decorations/deco_plant_moss_1.png"
		DecorationType.MOSS_2:
			return "res://assets/decorations/deco_plant_moss_2.png"
		DecorationType.MOSS_3:
			return "res://assets/decorations/deco_plant_moss_3.png"
		DecorationType.MOSS_4:
			return "res://assets/decorations/deco_plant_moss_4.png"
		DecorationType.VALLISNERIA:
			return "res://assets/decorations/deco_plant_vallisneria.png"
		# 珊瑚 (Coral)
		DecorationType.CORAL_1:
			return "res://assets/decorations/deco_coral_coral_1.png"
		DecorationType.CORAL_2:
			return "res://assets/decorations/deco_coral_coral_2.png"
		DecorationType.CORAL_3:
			return "res://assets/decorations/deco_coral_coral_3.png"
		DecorationType.CORAL_BONE_1:
			return "res://assets/decorations/deco_coral_coral_bone_1.png"
		DecorationType.CORAL_BONE_2:
			return "res://assets/decorations/deco_coral_coral_bone_2.png"
		# 装饰 (Ornament)
		DecorationType.CONCH:
			return "res://assets/decorations/deco_ornament_conch.png"
		DecorationType.SEASHELL:
			return "res://assets/decorations/deco_ornament_seashell.png"
		DecorationType.SHRIMP_AVE:
			return "res://assets/decorations/deco_ornament_shrimp_ave.png"
		DecorationType.CRAB:
			return "res://assets/decorations/deco_ornament_crab.png"
		DecorationType.OYSTER:
			return "res://assets/decorations/deco_ornament_oyster.png"
		DecorationType.ROCK:
			return "res://assets/decorations/deco_ornament_rock.png"
		DecorationType.ROCK_2:
			return "res://assets/decorations/deco_ornament_rock_2.png"
		DecorationType.ROCK_3:
			return "res://assets/decorations/deco_ornament_rock_3.png"
		DecorationType.SCALLOP:
			return "res://assets/decorations/deco_ornament_scallop.png"
		# 底砂 (Substrate)
		DecorationType.SAND_1:
			return "res://assets/decorations/deco_substrate_sand_1.png"
		DecorationType.SAND_2:
			return "res://assets/decorations/deco_substrate_sand_2.png"
		DecorationType.SAND_3:
			return "res://assets/decorations/deco_substrate_sand_3.png"
	return ""

static func get_sell_price(deco_type: DecorationType) -> int:
	return get_cost(deco_type) / 2


static func get_description(deco_type: DecorationType) -> String:
	match deco_type:
		# 水草 (Plant)
		DecorationType.ANUBIAS:
			return "漂亮的水榕，适合绑在沉木上。"
		DecorationType.BUCEPHALANDRA:
			return "精致的椒草，增添绿色层次。"
		DecorationType.HYDRILLA:
			return "茂盛的水蕴草，快速生长。"
		DecorationType.MOSS_1:
			return "莫斯草皮 1 号。"
		DecorationType.MOSS_2:
			return "莫斯草皮 2 号。"
		DecorationType.MOSS_3:
			return "莫斯草皮 3 号。"
		DecorationType.MOSS_4:
			return "莫斯草皮 4 号。"
		DecorationType.VALLISNERIA:
			return "水兰，飘逸的长叶水草。"
		# 珊瑚 (Coral)
		DecorationType.CORAL_1:
			return "红色的珊瑚装饰。"
		DecorationType.CORAL_2:
			return "蓝色的珊瑚装饰。"
		DecorationType.CORAL_3:
			return "紫色的珊瑚装饰。"
		DecorationType.CORAL_BONE_1:
			return "大块的珊瑚骨，营造自然景观。"
		DecorationType.CORAL_BONE_2:
			return "小块的珊瑚骨，适合点缀。"
		# 装饰 (Ornament)
		DecorationType.CONCH:
			return "来自海洋的海螺壳。"
		DecorationType.SEASHELL:
			return "精美的贝壳。"
		DecorationType.SHRIMP_AVE:
			return "虾屋，为虾类提供住所。"
		DecorationType.CRAB:
			return "红色的小螃蟹，在水底穿梭。"
		DecorationType.OYSTER:
			return "牡蛎壳，表面有独特的纹理。"
		DecorationType.ROCK:
			return "圆形的小石头。"
		DecorationType.ROCK_2:
			return "不规则形状的石头。"
		DecorationType.ROCK_3:
			return "扁平的石头，适合叠放。"
		DecorationType.SCALLOP:
			return "扇贝壳，造型优雅。"
		# 底砂 (Substrate)
		DecorationType.SAND_1:
			return "浅色细沙，铺设缸底。"
		DecorationType.SAND_2:
			return "深色细沙，铺设缸底。"
		DecorationType.SAND_3:
			return "中等色细沙，自然柔和。"
	return ""

# 装饰类型分组枚举
enum TypeGroup {
	PLANT,     # 水草
	CORAL,     # 珊瑚
	ORNAMENT,  # 装饰
	SUBSTRATE, # 底砂
}

# 获取装饰所属的类型分组
static func get_type_group(deco_type: DecorationType) -> TypeGroup:
	match deco_type:
		DecorationType.ANUBIAS, DecorationType.BUCEPHALANDRA, \
		DecorationType.HYDRILLA, DecorationType.MOSS_1, DecorationType.MOSS_2, \
		DecorationType.MOSS_3, DecorationType.MOSS_4, DecorationType.VALLISNERIA:
			return TypeGroup.PLANT
		DecorationType.CORAL_1, DecorationType.CORAL_2, DecorationType.CORAL_3, \
		DecorationType.CORAL_BONE_1, DecorationType.CORAL_BONE_2:
			return TypeGroup.CORAL
		DecorationType.CONCH, DecorationType.SEASHELL, DecorationType.SHRIMP_AVE, \
		DecorationType.CRAB, DecorationType.OYSTER, DecorationType.ROCK, \
		DecorationType.ROCK_2, DecorationType.ROCK_3, DecorationType.SCALLOP:
			return TypeGroup.ORNAMENT
		DecorationType.SAND_1, DecorationType.SAND_2, DecorationType.SAND_3:
			return TypeGroup.SUBSTRATE
	return TypeGroup.PLANT

# 获取类型分组的中文显示名
static func get_type_group_name(group: TypeGroup) -> String:
	match group:
		TypeGroup.PLANT:
			return "水草"
		TypeGroup.CORAL:
			return "珊瑚"
		TypeGroup.ORNAMENT:
			return "装饰"
		TypeGroup.SUBSTRATE:
			return "底砂"
	return ""

# 获取类型分组的英文名
static func get_type_group_name_en(group: TypeGroup) -> String:
	match group:
		TypeGroup.PLANT:
			return "Plant"
		TypeGroup.CORAL:
			return "Coral"
		TypeGroup.ORNAMENT:
			return "Ornament"
		TypeGroup.SUBSTRATE:
			return "Substrate"
	return ""
