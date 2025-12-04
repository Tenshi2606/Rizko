extends Area2D
class_name AbilityUnlocker

@export var ability_id: String = "dash"
@export var unlock_message: String = "¡Has desbloqueado: {ability}!"
@export var auto_unlock: bool = true  # Si se desbloquea automáticamente al tocar

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: Label = $Label

var is_unlocked: bool = false
var player_nearby: Player = null

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	# Mostrar nombre de la habilidad
	var ability = AbilityDB.get_ability(ability_id)
	if ability and label:
		label.text = ability.ability_name
	
	add_to_group("ability_unlockers")

func _input(event: InputEvent) -> void:
	# Si requiere input manual (ej: presionar E)
	if not auto_unlock and player_nearby and not is_unlocked:
		if event.is_action_pressed("ui_accept"):
			_unlock_ability()

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not is_unlocked:
		player_nearby = body as Player
		
		if auto_unlock:
			_unlock_ability()
		else:
			# Mostrar prompt "Presiona E para obtener habilidad"
			if label:
				label.text = "Presiona E"

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_nearby = null

func _unlock_ability() -> void:
	if is_unlocked:
		return
	
	var ability = AbilityDB.get_ability(ability_id)
	if not ability:
		push_error("Habilidad no encontrada: ", ability_id)
		return
	
	# Desbloquear en el jugador
	var ability_system = player_nearby.get_node_or_null("AbilitySystem") as AbilitySystem
	if ability_system:
		ability_system.unlock_ability(ability)
		
		# Mostrar mensaje
		_show_unlock_effect(ability)
		
		is_unlocked = true
		
		# Desaparecer con efecto
		_despawn_with_effect()

func _show_unlock_effect(ability: Ability) -> void:
	print("✨ ¡HABILIDAD DESBLOQUEADA! ✨")
	print("📜 ", ability.ability_name)
	print("💬 ", ability.description)
	
	# TODO: Mostrar UI de desbloqueo (panel con info de la habilidad)
	# UnlockNotification.show(ability)

func _despawn_with_effect() -> void:
	# Efecto visual de desbloqueo
	if sprite:
		sprite.play("unlock")  # Si tienes animación
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 1.0)
	await tween.finished
	
	queue_free()
