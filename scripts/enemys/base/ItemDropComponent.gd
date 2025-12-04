# res://scripts/items/ItemDropComponent.gd
extends Node
class_name ItemDropComponent

# ============================================
# CONFIGURACIÓN DESDE INSPECTOR
# ============================================

@export_group("Drop Settings")
@export var drop_chance: float = 0.8
@export_range(1, 10) var min_drops: int = 1
@export_range(1, 10) var max_drops: int = 1

@export_group("Moneda (Asterion)")
## ¿Este enemigo dropea Asterion?
@export var drops_currency: bool = true
## Cantidad mínima de Asterion
@export_range(0, 1000) var min_currency: int = 5
## Cantidad máxima de Asterion
@export_range(0, 1000) var max_currency: int = 15
## Probabilidad de dropear Asterion (separada de items)
@export_range(0.0, 1.0) var currency_drop_chance: float = 1.0

@export_group("Items a Dropear")
## IDs de items desde ItemDatabase (ej: "soul_basic", "health_potion")
@export var drop_item_ids: Array[String] = []
## Pesos de probabilidad (mismo tamaño que drop_item_ids)
@export var drop_weights: Array[int] = []

var enemy: EnemyBase

func _ready() -> void:
	await get_tree().process_frame
	enemy = get_parent() as EnemyBase
	
	if not enemy:
		push_error("ItemDropComponent debe ser hijo de un EnemyBase")
		return
	
	if not enemy.enemy_died.is_connected(_on_enemy_died):
		enemy.enemy_died.connect(_on_enemy_died)
	
	_validate_configuration()
	_print_configuration()

func _validate_configuration() -> void:
	# Validar arrays de items
	if drop_item_ids.size() != drop_weights.size():
		push_warning("⚠️ Número de items y pesos no coincide. Ajustando...")
		while drop_weights.size() < drop_item_ids.size():
			drop_weights.append(100)
	
	# Validar que los items existan
	for item_id in drop_item_ids:
		if not ItemDB.item_exists(item_id):
			push_warning("⚠️ Item ID no existe en ItemDB: ", item_id)
	
	# Validar moneda
	if min_currency > max_currency:
		push_warning("⚠️ min_currency > max_currency. Intercambiando valores...")
		var temp = min_currency
		min_currency = max_currency
		max_currency = temp

func _print_configuration() -> void:
	print("💰 ItemDropComponent inicializado para: ", enemy.name)
	
	if drops_currency:
		print("  🪙 Asterion: (", min_currency, "-", max_currency, ") | Chance: ", currency_drop_chance * 100, "%")
	else:
		print("  🪙 No dropea Asterion")
	
	if not drop_item_ids.is_empty():
		print("  📦 Items: ", drop_item_ids)
	else:
		print("  📦 No dropea items")

func _on_enemy_died() -> void:
	print("💀 ", enemy.name, " murió")
	
	var death_position = enemy.global_position
	
	# DROPEAR ASTERION (independiente de items)
	if drops_currency:
		_drop_currency(death_position)
	
	# DROPEAR ITEMS
	if not drop_item_ids.is_empty():
		_drop_items(death_position)

# ============================================
# SISTEMA DE ASTERION
# ============================================

func _drop_currency(spawn_position: Vector2) -> void:
	# Roll de probabilidad
	if randf() > currency_drop_chance:
		print("  ❌ No dropea Asterion (probabilidad)")
		return
	
	# Calcular cantidad aleatoria
	var amount = randi_range(min_currency, max_currency)
	
	if amount <= 0:
		print("  ⚠️ Cantidad de Asterion es 0")
		return
	
	# 🔧 CREAR ASTERION CON CANTIDAD ESPECÍFICA
	var asterion = ItemDB.create_asterion(amount)
	
	if not asterion:
		push_error("  ❌ No se pudo crear Asterion")
		return
	
	print("  🪙 Dropeó: ", amount, " Asterion")
	_spawn_drop(asterion, spawn_position)

# ============================================
# SISTEMA DE ITEMS
# ============================================

func _drop_items(spawn_position: Vector2) -> void:
	# Roll de probabilidad de items
	if randf() > drop_chance:
		return
	
	# Dropear 1 item (respeta min_drops y max_drops)
	var drop_count = randi_range(min_drops, max_drops)
	
	for i in range(drop_count):
		var item = _roll_drop()
		if item:
			_spawn_drop(item, spawn_position)

func _roll_drop() -> Item:
	if drop_item_ids.is_empty():
		return null
	
	var total_weight = 0
	for weight in drop_weights:
		total_weight += weight
	
	var roll = randf() * total_weight
	var cumulative = 0.0
	
	for i in range(drop_item_ids.size()):
		cumulative += drop_weights[i]
		if roll <= cumulative:
			var item_id = drop_item_ids[i]
			var item = ItemDB.create_item(item_id)
			
			if not item:
				push_warning("  ⚠️ No se pudo crear item: ", item_id)
				continue
			return item
	
	var fallback_id = drop_item_ids[0]
	return ItemDB.create_item(fallback_id)

# ============================================
# SPAWN (común para Asterion e items)
# ============================================

func _spawn_drop(item: Item, spawn_position: Vector2) -> void:
	var drop_scene
	
	# 🆕 Seleccionar escena según tipo de item
	if item is Currency:
		drop_scene = load("res://assets/scenas/items/coin_pickup.tscn")
	elif item.id.contains("soul") or item.id.contains("alma"):
		drop_scene = load("res://assets/scenas/items/soul_pickup.tscn")
	else:
		drop_scene = load("res://assets/scenas/items/item_pickup.tscn")
	
	if not drop_scene:
		push_error("  ❌ Escena de item no encontrada")
		return
	
	# 🆕 EFECTO LLUVIA DE MONEDAS: Spawnear múltiples monedas
	if item is Currency:
		var amount = (item as Currency).amount
		var coin_count = _calculate_coin_count(amount)
		
		print("  💰 Spawneando ", coin_count, " monedas (", amount, " Asteriones)")
		
		for i in range(coin_count):
			var drop_instance = drop_scene.instantiate()
			
			# Dividir cantidad entre las monedas
			var coin_value = int(float(amount) / float(coin_count))
			var coin_currency = Currency.create_asterion(coin_value)
			drop_instance.item = coin_currency
			
			# Posición con spread aleatorio
			var spread = Vector2(randf_range(-30, 30), randf_range(-20, 20))
			drop_instance.global_position = spawn_position + spread
			
			# Configurar efectos visuales
			drop_instance.setup_as_coin()
			
			# Velocidad con spread (efecto explosión)
			var angle = randf_range(-PI, PI)
			var speed = randf_range(100, 200)
			drop_instance.linear_velocity = Vector2(
				cos(angle) * speed,
				sin(angle) * speed - randf_range(150, 250)  # Siempre hacia arriba
			)
			drop_instance.angular_velocity = randf_range(-5, 5)
			
			var level = get_tree().current_scene
			level.call_deferred("add_child", drop_instance)
			
			# Todas las monedas aparecen a la vez (sin delay)
	
	# Items normales y almas (spawn único)
	else:
		var drop_instance = drop_scene.instantiate()
		drop_instance.item = item
		drop_instance.global_position = spawn_position
		
		# Agregar a la escena primero
		var level = get_tree().current_scene
		level.call_deferred("add_child", drop_instance)
		
		# 🔧 Esperar a que _ready() termine antes de configurar efectos
		await drop_instance.ready
		
		# Configurar efectos visuales según tipo
		if item.id.contains("soul") or item.id.contains("alma"):
			drop_instance.setup_as_soul()
			drop_instance.linear_velocity = Vector2(
				randf_range(-120, 120),
				randf_range(-250, -180)
			)
		else:
			drop_instance.setup_as_item()
			drop_instance.linear_velocity = Vector2(
				randf_range(-100, 100),
				randf_range(-220, -150)
			)
		
		drop_instance.angular_velocity = randf_range(-3, 3)

# 🆕 Calcular cuántas monedas visuales spawnear según la cantidad
func _calculate_coin_count(amount: int) -> int:
	if amount >= 100:
		return 15  # Muchas monedas
	elif amount >= 50:
		return 10  # Bastantes monedas
	elif amount >= 20:
		return 6   # Varias monedas
	elif amount >= 10:
		return 4   # Pocas monedas
	else:
		return 2   # Mínimo 2 monedas

# ============================================
# UTILIDADES PÚBLICAS
# ============================================

func add_drop_item(item_id: String, weight: int = 100) -> void:
	if not ItemDB.item_exists(item_id):
		push_warning("⚠️ Item ID no existe: ", item_id)
		return
	
	drop_item_ids.append(item_id)
	drop_weights.append(weight)
	print("✅ Item añadido a drop table: ", item_id, " (peso: ", weight, ")")

func remove_drop_item(item_id: String) -> void:
	var index = drop_item_ids.find(item_id)
	if index != -1:
		drop_item_ids.remove_at(index)
		drop_weights.remove_at(index)
		print("🗑️ Item removido de drop table: ", item_id)

func clear_drops() -> void:
	drop_item_ids.clear()
	drop_weights.clear()
	print("🗑️ Drop table limpiada")

# 🆕 Configurar Asterion programáticamente
func set_asterion_drop(enabled: bool, min_amount: int = 5, max_amount: int = 15, drop_probability: float = 1.0) -> void:
	drops_currency = enabled
	min_currency = min_amount
	max_currency = max_amount
	currency_drop_chance = drop_probability
	print("🪙 Asterion configurado: ", enabled, " (", min_amount, "-", max_amount, ") | Chance: ", drop_probability * 100, "%")
