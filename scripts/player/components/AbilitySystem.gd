extends Node
class_name AbilitySystem

signal ability_unlocked(ability: Ability)
signal ability_activated(ability: Ability)

var player: Player
var unlocked_abilities: Dictionary = {}  # { "ability_id": Ability }
var active_abilities: Dictionary = {}    # Habilidades activas con cooldowns

func _ready() -> void:
	await get_tree().process_frame
	player = get_parent() as Player
	
	if not player:
		push_error("AbilitySystem debe ser hijo de un Player")
		return
	
	print("🌟 AbilitySystem inicializado")

# Desbloquear una habilidad
func unlock_ability(ability: Ability) -> void:
	if unlocked_abilities.has(ability.id):
		print("⚠️ Ya tienes la habilidad: ", ability.ability_name)
		return
	
	unlocked_abilities[ability.id] = ability
	print("✨ Habilidad desbloqueada: ", ability.ability_name)
	
	# 🔧 SOLO activar habilidades PASIVAS al desbloquear
	if ability.type == Ability.AbilityType.PASSIVE:
		ability.activate(player)
		print("  ✅ Habilidad pasiva activada automáticamente")
	elif ability.type == Ability.AbilityType.ACTIVE:
		print("  💨 Habilidad activa lista - Presiona C para usar")
	
	ability_unlocked.emit(ability)
	_save_abilities()

# Verificar si tienes una habilidad
func has_ability(ability_id: String) -> bool:
	return unlocked_abilities.has(ability_id)

# Obtener habilidad
func get_ability(ability_id: String) -> Ability:
	if unlocked_abilities.has(ability_id):
		return unlocked_abilities[ability_id]
	return null

# Usar habilidad activa (dash, etc.)
func use_ability(ability_id: String) -> bool:
	if not has_ability(ability_id):
		return false
	
	var ability = unlocked_abilities[ability_id]
	
	# Verificar cooldown
	if active_abilities.has(ability_id):
		var time_left = active_abilities[ability_id]
		if time_left > 0:
			print("⏱️ Habilidad en cooldown: %.1f" % time_left, "s")
			return false
	
	# Activar
	ability.activate(player)
	
	# Iniciar cooldown
	if ability.cooldown > 0:
		active_abilities[ability_id] = ability.cooldown
	
	ability_activated.emit(ability)
	return true

func _process(delta: float) -> void:
	# Actualizar cooldowns
	for ability_id in active_abilities.keys():
		active_abilities[ability_id] -= delta
		if active_abilities[ability_id] <= 0:
			active_abilities.erase(ability_id)

# Guardar habilidades desbloqueadas
func _save_abilities() -> void:
	var save_data = []
	for ability_id in unlocked_abilities.keys():
		save_data.append(ability_id)
	
	print("💾 Habilidades guardadas: ", save_data)

# Cargar habilidades guardadas
func load_abilities(ability_ids: Array) -> void:
	for ability_id in ability_ids:
		var ability = AbilityDB.get_ability(ability_id)
		if ability:
			unlock_ability(ability)
