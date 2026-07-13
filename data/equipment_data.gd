extends Resource
class_name EquipmentData

enum EquipmentType {
	AUTO_FEEDER,
	AUTO_SELL,
	AUTO_BUY,
}

static func get_display_name(eq_type: int) -> String:
	match eq_type:
		EquipmentType.AUTO_FEEDER:
			return "自动投喂机"
		EquipmentType.AUTO_SELL:
			return "满级自售"
		EquipmentType.AUTO_BUY:
			return "自动买鱼"
	return ""

static func get_cost(eq_type: int) -> int:
	match eq_type:
		EquipmentType.AUTO_FEEDER:
			return 300
		EquipmentType.AUTO_SELL:
			return 500
		EquipmentType.AUTO_BUY:
			return 800
	return 0

static func get_description(eq_type: int) -> String:
	match eq_type:
		EquipmentType.AUTO_FEEDER:
			return "自动检测鱼食，缺少时自动投放。解放双手！"
		EquipmentType.AUTO_SELL:
			return "购买后所有鱼达到满级时自动出售，可随时开关。"
		EquipmentType.AUTO_BUY:
			return "自动检测鱼缸中鱼的数量，不足时自动购买新鱼。"
	return ""
