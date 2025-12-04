extends Resource
class_name Item

enum ItemType { CONSUMABLE, MATERIAL, EQUIPMENT, KEY_ITEM }
enum ItemRarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var id: String = ""
@export var name: String = "Item"
@export var description: String = "Un item misterioso"
@export var icon: Texture2D = null
@export var type: ItemType = ItemType.CONSUMABLE
@export var rarity: ItemRarity = ItemRarity.COMMON
@export var max_stack: int = 99
@export var can_use: bool = true

# Método virtual que los hijos sobrescriben
func use(_player: Player) -> bool:
	print("⚠️ Item.use() no implementado para: ", name)
	return false

func get_rarity_color() -> Color:
	match rarity:
		ItemRarity.COMMON:
			return Color(0.8, 0.8, 0.8)  # Gris
		ItemRarity.UNCOMMON:
			return Color(0.3, 1, 0.3)    # Verde
		ItemRarity.RARE:
			return Color(0.3, 0.6, 1)    # Azul
		ItemRarity.EPIC:
			return Color(0.8, 0.3, 1)    # Morado
		ItemRarity.LEGENDARY:
			return Color(1, 0.7, 0.2)    # Dorado
	return Color.WHITE
