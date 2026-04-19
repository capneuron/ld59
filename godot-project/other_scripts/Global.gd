extends Node

# 全局数据字典，用于跨场景传递参数
var global_data: Dictionary = {}

# 示例函数：设置参数
func set_param(key: String, value) -> void:
	global_data[key] = value

# 示例函数：获取参数
func get_param(key: String):
	return global_data.get(key)

# 示例函数：清除所有参数
func clear_params() -> void:
	global_data.clear()