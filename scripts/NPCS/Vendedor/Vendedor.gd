extends NPCBase
class_name Vendor

@export_group("Shop Settings")
@export var shop_name: String = "Tienda General"
@export var greeting: String = "¡Bienvenido a mi tienda!"

@export_group("Inventory")
## Formato: "item_id:precio" (ej: "health_potion:10")
@export var shop_inventory: Array[String] = [
	"health_potion:10",
	"soul_basic:30"
]

@export var buys_items: bool = false
@export var buy_price_multiplier: float = 0.5

var current_shop_ui: ShopUI = null  # 🆕 Guardar referencia

func _on_ready() -> void:
	npc_type = "vendor"
	interaction_prompt = "Presiona E para comprar"
	print("🏪 Vendedor configurado: ", shop_name)
	_validate_inventory()

func _validate_inventory() -> void:
	for entry in shop_inventory:
		var parts = entry.split(":")
		if parts.size() != 2:
			push_warning("⚠️ Formato incorrecto: ", entry)
			continue
		
		var item_id = parts[0]
		if not ItemDB.item_exists(item_id):
			push_warning("⚠️ Item no existe: ", item_id)

func on_interact() -> void:
	print("🏪 Buscando ShopUI...")
	var shop_ui = _find_shop_ui()
	
	if not shop_ui:
		push_error("❌ ShopUI no encontrado")
		stop_interaction()
		return
	
	# 🆕 Guardar referencia
	current_shop_ui = shop_ui
	
	print("✅ Abriendo tienda")
	shop_ui.open_shop(self)

# 🆕 CERRAR TIENDA AL ALEJARSE
func on_interaction_forced_close() -> void:
	print("🏪 Forzando cierre de tienda (jugador se alejó)")
	
	if current_shop_ui and current_shop_ui.visible:
		current_shop_ui.close_shop()
	
	current_shop_ui = null

func _find_shop_ui():
	return _search_node(get_tree().root, "ShopUI")

func _search_node(node: Node, node_name: String):
	if node.name == node_name:
		return node
	
	for child in node.get_children():
		var result = _search_node(child, node_name)
		if result:
			return result
	
	return null

func get_shop_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	
	for entry in shop_inventory:
		var parts = entry.split(":")
		if parts.size() != 2:
			continue
		
		var item_id = parts[0]
		var price = int(parts[1])
		
		var item_info = ItemDB.get_item_info(item_id)
		if item_info.is_empty():
			print("⚠️ Item no existe: ", item_id)
			continue
		
		items.append({
			"item_id": item_id,
			"name": item_info["name"],
			"description": item_info["description"],
			"price": price,
			"rarity": item_info.get("rarity", 0)
		})
	
	return items

func purchase_item(item_id: String, price: int) -> bool:
	if not player_nearby:
		print("❌ Player no está cerca")
		return false
	
	var wallet = player_nearby.get_node_or_null("Wallet") as Wallet
	var inventory = player_nearby.get_node_or_null("InventoryComponent") as InventoryComponent
	
	if not wallet:
		print("❌ Player no tiene Wallet")
		return false
	
	if not inventory:
		print("❌ Player no tiene InventoryComponent")
		return false
	
	if not wallet.can_afford(price):
		print("❌ No tienes suficientes Asteriones (Necesitas: ", price, ", Tienes: ", wallet.get_asteriones(), ")")
		return false
	
	if not wallet.spend_asteriones(price):
		print("❌ Error al gastar Asteriones")
		return false
	
	var item = ItemDB.create_item(item_id)
	if not item:
		wallet.add_asteriones(price)
		print("❌ Error al crear item: ", item_id)
		return false
	
	if inventory.add_item(item, 1):
		print("✅ Compraste: ", item.name, " por ", price, " Asteriones")
		return true
	else:
		wallet.add_asteriones(price)
		print("❌ Inventario lleno")
		return false

func sell_item_to_vendor(item_id: String, base_price: int) -> bool:
	if not buys_items:
		print("❌ Este vendedor no compra items")
		return false
	
	if not player_nearby:
		return false
	
	var wallet = player_nearby.get_node_or_null("Wallet") as Wallet
	var inventory = player_nearby.get_node_or_null("InventoryComponent") as InventoryComponent
	
	if not wallet or not inventory:
		return false
	
	if not inventory.has_item(item_id, 1):
		print("❌ No tienes ese item")
		return false
	
	var sell_price = int(base_price * buy_price_multiplier)
	
	if inventory.remove_item(item_id, 1):
		wallet.add_asteriones(sell_price)
		print("✅ Vendiste item por ", sell_price, " Asteriones")
		return true
	
	return false
