extends Node

const SAVE_PATH: String = "user://deskquarium_save.json"

func _process(_delta: float) -> void:
	if Global.save_dirty:
		Global.save_dirty = false
		save_game()


func save_game() -> void:
	var data := Global.get_save_data()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_str := file.get_as_text()
		file.close()
		var json := JSON.new()
		var parse_result := json.parse(json_str)
		if parse_result == OK and json.data is Dictionary:
			Global.load_save_data(json.data)
			return true
	return false


func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	get_tree().reload_current_scene()
