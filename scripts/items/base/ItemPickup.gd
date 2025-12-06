extends RigidBody2D
class_name ItemPickup

# 🪙 Texturas de fragmentos de moneda (3 variantes aleatorias)
const COIN_FRAGMENTS = [
	preload("res://textures/items/Coin/Coin1.png"),
	preload("res://textures/items/Coin/Coin2.png"),
	preload("res://textures/items/Coin/Coin3.png")
]

@export var item: Item
@export var quantity: int = 1
@export var magnet_range: float = 150.0
@export var magnet_speed: float = 300.0
@export var despawn_time: float = 120.0

var is_attracted: bool = false
var target_player: Player = null
var lifetime: float = 0.0
var blink_timer: float = 0.0
var is_blinking: bool = false

# Referencias a nodos (se buscan en _ready)
var sprite: AnimatedSprite2D
var light: PointLight2D

func _ready() -> void:
	# 🔧 Buscar nodos dinámicamente
	sprite = get_node_or_null("AnimatedSprite2D")
	if not sprite:
		sprite = find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	
	light = get_node_or_null("PointLight2D")
	if not light:
		light = find_child("PointLight2D", true, false) as PointLight2D
	
	# 🔧 CONFIGURAR COLLISION LAYERS (CRÍTICO)
	# Layer 4 = Items (solo están en esta capa)
	# Mask 1 = World (solo colisionan con el suelo/paredes)
	collision_layer = 8  # Bit 4 (2^3 = 8)
	collision_mask = 1   # Bit 1 (solo suelo)
	
	# 🔧 PREVENIR ATRAVESAR SUELO
	# CCD (Continuous Collision Detection) para objetos rápidos
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	
	# Configurar física
	gravity_scale = 1.0
	linear_damp = 0.5
	
	# Crear PhysicsMaterial para bounce (Godot 4)
	var physics_mat = PhysicsMaterial.new()
	physics_mat.bounce = 0.3
	physics_material_override = physics_mat
	
	# 🆕 Configurar SpriteFrames para monedas (AnimatedSprite2D)
	if item is Currency and sprite:
		# Crear SpriteFrames si no existe
		if not sprite.sprite_frames:
			sprite.sprite_frames = SpriteFrames.new()
		
		# Crear animación "coin" si no existe
		if not sprite.sprite_frames.has_animation("coin"):
			sprite.sprite_frames.add_animation("coin")
		
		# Seleccionar textura aleatoria
		var random_coin = COIN_FRAGMENTS[randi() % COIN_FRAGMENTS.size()]
		
		# Limpiar frames anteriores
		while sprite.sprite_frames.get_frame_count("coin") > 0:
			sprite.sprite_frames.remove_frame("coin", 0)
		
		# Agregar frame único
		sprite.sprite_frames.add_frame("coin", random_coin)
		sprite.sprite_frames.set_animation_speed("coin", 1.0)
		
		# Reproducir animación
		sprite.play("coin")
	
	# 🆕 Ajustar tamaño de colisión según textura
	# DESACTIVADO - Ahora se configura manualmente en la escena
	# _setup_collision_shape()
	
	# Crear luz si no existe
	if not has_node("PointLight2D"):
		light = PointLight2D.new()
		light.enabled = false
		add_child(light)
	else:
		light = $PointLight2D
	
	# 🆕 Conectar señal de DetectionArea (debe existir en la escena)
	var detection_area = get_node_or_null("DetectionArea")
	if detection_area and detection_area is Area2D:
		if not detection_area.body_entered.is_connected(_on_body_entered):
			detection_area.body_entered.connect(_on_body_entered)
	else:
		push_warning("⚠️ DetectionArea no encontrado. Agrega un Area2D hijo llamado 'DetectionArea'")
	
	add_to_group("item_pickups")

func _physics_process(delta: float) -> void:
	# Actualizar tiempo de vida
	lifetime += delta
	
	# Parpadear en los últimos 30 segundos
	if lifetime > despawn_time - 30.0 and not is_blinking:
		is_blinking = true
		print("⚠️ Item ", item.name, " empezará a parpadear")
	
	if is_blinking:
		blink_timer += delta
		var blink_speed = 0.5 - ((lifetime - (despawn_time - 30.0)) / 30.0) * 0.3
		if blink_timer >= blink_speed:
			blink_timer = 0.0
			visible = !visible
	
	# Despawnear después del tiempo límite
	if lifetime >= despawn_time:
		print("💨 Item ", item.name, " desapareció por tiempo")
		_despawn_with_effect()
		return
	
	# Lógica de imán
	if not is_attracted or not target_player:
		return
	
	var direction = (target_player.global_position - global_position).normalized()
	global_position += direction * magnet_speed * delta
	
	if global_position.distance_to(target_player.global_position) < 20:
		_collect(target_player)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_collect(body as Player)

func _collect(player: Player) -> void:
	if not item:
		queue_free()
		return
	
	# 🎯 USAR EVENTBUS PARA MONEDAS
	if item is Currency:
		EventBus.currency_collected.emit(item.amount, player)
		print("⭐ Recogido: %d Asteriones" % item.amount)
		queue_free()

		return
	
	# 🎯 USAR EVENTBUS PARA ITEMS
	EventBus.item_collected.emit(item, player)
	print("✨ Recogido: %s" % item.name)
	queue_free()

# Verificar si el inventario puede aceptar este item
func _can_inventory_accept(inventory: InventoryComponent) -> bool:
	if not item:
		return false
	
	# Si el item ya existe en el inventario
	if inventory.items.has(item.id):
		var current_quantity = inventory.items[item.id]["quantity"]
		# Verificar si hay espacio en el stack
		if current_quantity >= item.max_stack:
			return false  # Stack lleno
		return true  # Hay espacio en el stack
	else:
		# Item nuevo - verificar si hay slots disponibles
		if inventory.get_item_count() >= inventory.max_slots:
			return false  # No hay slots libres
		return true  # Hay espacio

# Despawnear con efecto visual
func _despawn_with_effect() -> void:
	if sprite:
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
		await tween.finished
	
	queue_free()

func activate_magnet(player: Player) -> void:
	is_attracted = true
	target_player = player

# ============================================
# 🆕 CONFIGURACIÓN VISUAL
# ============================================

## Configurar como moneda con color según cantidad
func setup_as_coin() -> void:
	if not item is Currency:
		return
	
	var amount = (item as Currency).amount
	var coin_color: Color
	var glow_color: Color
	var glow_energy: float
	
	# Determinar color según cantidad
	if amount >= 50:  # Metálica (mucho dinero)
		coin_color = Color(0.9, 0.9, 1.0)  # Plateado brillante
		glow_color = Color(0.7, 0.8, 1.0)  # Azul metálico
		glow_energy = 0.3
	elif amount >= 20:  # Dorada
		coin_color = Color(1.0, 0.85, 0.3)  # Dorado
		glow_color = Color(1.0, 0.9, 0.5)  # Amarillo dorado
		glow_energy = 0.25
	else:  # Bronce (poco dinero)
		coin_color = Color(0.8, 0.5, 0.3)  # Bronce
		glow_color = Color(0.9, 0.6, 0.4)  # Naranja tenue
		glow_energy = 0.15
	
	# 🆕 Seleccionar textura aleatoria (tienes 3 fragmentos)
	# Las texturas se asignan en la escena item_pickup.tscn
	# Aquí solo aplicamos el color
	if sprite:
		sprite.modulate = coin_color
	
	# Configurar brillo sutil
	if light:
		light.enabled = true
		light.color = glow_color
		light.energy = glow_energy
		light.texture_scale = 0.5
	
	# Configurar física (monedas rebotan más)
	if physics_material_override:
		physics_material_override.bounce = 0.4


## Configurar como alma con color según rareza
func setup_as_soul() -> void:
	if not item:
		return
	
	var soul_color: Color
	var glow_color: Color
	var glow_energy: float
	
	# Determinar color según rareza del alma
	match item.rarity:
		Item.ItemRarity.LEGENDARY, Item.ItemRarity.EPIC:  # Alma DORADA (pura)
			soul_color = Color(1.0, 0.9, 0.3)  # Dorado brillante
			glow_color = Color(1.0, 0.85, 0.4)  # Amarillo dorado
			glow_energy = 1.2  # Muy brillante
		Item.ItemRarity.UNCOMMON:  # Alma MORADA (intermedia)
			soul_color = Color(0.4, 0.2, 0.5)  # Morado oscuro
			glow_color = Color(0.6, 0.3, 0.8)  # Púrpura brillante intenso
			glow_energy = 1.0  # Brillante
		_:  # Alma BLANCA (básica - COMMON)
			soul_color = Color(1.0, 1.0, 1.0)  # Blanco puro
			glow_color = Color(0.7, 0.85, 1.0)  # Azul claro
			glow_energy = 0.8  # Moderado
	
	# Reproducir animación del alma
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("soul"):
		sprite.play("soul")
		sprite.modulate = soul_color
	
	# Configurar brillo (PointLight2D con el color correspondiente)
	if light:
		light.enabled = true
		light.color = glow_color
		light.energy = glow_energy
		light.texture_scale = 0.8
	
	# Configurar física (almas rebotan menos)
	if physics_material_override:
		physics_material_override.bounce = 0.2
	linear_damp = 0.7

## Configurar como item normal (salud, etc.)
func setup_as_item() -> void:
	if not item:
		return
	
	# Color según rareza del item
	var item_color = item.get_rarity_color()
	
	if sprite:
		sprite.modulate = item_color
	
	# Brillo muy sutil para items especiales
	if item.rarity >= Item.ItemRarity.RARE and light:
		light.enabled = true
		light.color = item_color
		light.energy = 0.2
		light.texture_scale = 0.6
	
	# Física normal
	if physics_material_override:
		physics_material_override.bounce = 0.3


# ============================================
# 🆕 CONFIGURACIÓN DE COLISIÓN
# ============================================

## Ajusta el tamaño de la colisión según el tipo de item
func _setup_collision_shape() -> void:
	var collision_shape = get_node_or_null("CollisionShape2D")
	
	if not collision_shape:
		return
	
	# Obtener o crear CircleShape2D
	var shape = collision_shape.shape
	if not shape is CircleShape2D:
		shape = CircleShape2D.new()
		collision_shape.shape = shape
	
	# Ajustar radio según tipo de item
	if item is Currency:
		# Monedas: colisión MUY pequeña (son fragmentos pequeños)
		shape.radius = 4.0
	elif item and (item.id.contains("soul") or item.id.contains("alma")):
		# Almas: colisión grande
		shape.radius = 12.0
	else:
		# Items normales: colisión estándar
		shape.radius = 8.0
