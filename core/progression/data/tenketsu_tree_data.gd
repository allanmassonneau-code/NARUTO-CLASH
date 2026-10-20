class_name TenketsuTreeData
extends Resource

@export var id: StringName = &"tenketsu"
@export var nodes: Array[TenketsuNodeData] = []


func get_node_data(node_id: StringName) -> TenketsuNodeData:
	for node: TenketsuNodeData in nodes:
		if node.id == node_id:
			return node
	return null
