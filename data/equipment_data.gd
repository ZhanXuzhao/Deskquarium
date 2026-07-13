extends Resource
class_name EquipmentData

enum EquipmentType {
	AUTO_FEEDER,
}

static func get_display_name(eq_type: int) -> String:
	match eq_type:
		EquipmentType.AUTO_FEEDER:
			return "自动投喂机"
	return ""

static func get_cost(eq_type: int) -> int:
	match eq_type:
		EquipmentType.AUTO_FEEDER:
			return 300
	return 0

static func get_description(eq_type: int) -> String:
	match eq_type:
		EquipmentType.AUTO_FEEDER:
			return "自动检测鱼食，缺少时自动投放。解放双手！"
	return ""
