extends Area2D
class_name WeaponPickup

## ID del arma a desbloquear (desde WeaponDB)
@export var weapon_id: String = "scythe"

## Configuración visual
@export var glow_color: Color = Color(0.5, 1.0, 0.5)  # Verde espectral
@export var float_amplitude: float = 10.0
@export var float_speed: float = 2.0

var weapon_data: WeaponData = null
var can_absorb: bool = true
var player_nearby: Player = null
var time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var prompt_label: Label = $PromptLabel  # "Presiona E para absorber"

func _ready() -> void:
	# Cargar datos del arma
	weapon_data = WeaponDB.get_weapon(weapon_id)
	
	if not weapon_data:
		push_error("❌ WeaponPickup: Arma no encontrada en database: ", weapon_id)
		queue_free()
		return
	
	# Configurar label
	if label:
		label.text = weapon_data.weapon_name
		label.modulate = glow_color
	
	# Configurar prompt
	if prompt_label:
		prompt_label.text = "Presiona E para absorber"
		prompt_label.visible = false
	
	# Configurar sprite
	if sprite:
		sprite.modulate = glow_color
		# TODO: Cargar sprite del arma desde weapon_data.icon
	
	# Conectar señales
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	add_to_group("weapon_pickups")
	
	print("🗡️ WeaponPickup spawneado: ", weapon_data.weapon_name)

func _process(delta: float) -> void:
	# Efecto flotante
	time += delta
	if sprite:
		sprite.position.y = sin(time * float_speed) * float_amplitude
	
	# Efecto de brillo pulsante
	if sprite:
		var pulse = (sin(time * 3.0) + 1.0) * 0.5  # 0.0 a 1.0
		var glow_intensity = 0.7 + pulse * 0.3  # 0.7 a 1.0
		sprite.modulate = Color(
			glow_color.r * glow_intensity,
			glow_color.g * glow_intensity,
			glow_color.b * glow_intensity
		)
	
	# Detectar input de absorción
	if player_nearby and Input.is_action_just_pressed("interact"):
		_absorb_weapon()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_nearby = body as Player
		
		# Verificar si ya tiene el arma
		if player_nearby.weapon_system and player_nearby.weapon_system.has_weapon(weapon_id):
			if prompt_label:
				prompt_label.text = "Ya tienes esta arma"
				prompt_label.modulate = Color(1, 0.5, 0.5)  # Rojo
				prompt_label.visible = true
			can_absorb = false
		else:
			if prompt_label:
				prompt_label.visible = true
			can_absorb = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_nearby = null
		if prompt_label:
			prompt_label.visible = false
		can_absorb = true

func _absorb_weapon() -> void:
	if not can_absorb or not player_nearby or not weapon_data:
		return
	
	var weapon_system = player_nearby.weapon_system as WeaponSystem
	
	if not weapon_system:
		push_error("❌ Player no tiene WeaponSystem")
		return
	
	# Verificar si ya tiene el arma
	if weapon_system.has_weapon(weapon_id):
		print("⚠️ Ya tienes esta arma: ", weapon_data.weapon_name)
		return
	
	# 🔥 ABSORBER ARMA
	print("✨ ABSORBIENDO ARMA: ", weapon_data.weapon_name)
	
	# Desbloquear arma
	weapon_system.unlock_weapon(weapon_data, true)
	
	# Equipar automáticamente
	weapon_system.equip_weapon(weapon_data)
	
	# Efecto visual de absorción
	_play_absorption_effect()
	
	# Destruir pickup
	await get_tree().create_timer(0.3).timeout
	queue_free()

func _play_absorption_effect() -> void:
	# Efecto de partículas (opcional)
	print("✨ Efecto de absorción activado")
	
	# Animación de escala
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.2)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.1)
	
	# Animación de label
	if label:
		var tween2 = create_tween()
		tween2.tween_property(label, "position:y", label.position.y - 30, 0.3)
		tween2.tween_property(label, "modulate:a", 0.0, 0.1)
