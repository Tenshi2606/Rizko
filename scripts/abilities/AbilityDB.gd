extends Node
# ⚠️ NO USES class_name EN AUTOLOADS

# 🔧 REMOVER "static" de TODAS las funciones
func get_ability(ability_id: String) -> Ability:
	match ability_id:
		"dash":
			return create_dash()
		"critical_hit":
			return create_critical_hit()
		"life_steal":
			return create_life_steal()
		"double_jump":
			return create_double_jump()
		"wall_jump":
			return create_wall_jump()
		"air_dash":
			return create_air_dash()
		"combo_master":
			return create_combo_master()
		_:
			push_warning("Habilidad no encontrada: ", ability_id)
			return null

# ========================================
# HABILIDADES PASIVAS
# ========================================

func create_critical_hit() -> PassiveAbility:
	var ability = PassiveAbility.new()
	ability.id = "critical_hit"
	ability.ability_name = "Golpe Crítico"
	ability.description = "5% de probabilidad de golpe crítico (x2 daño)"
	ability.type = Ability.AbilityType.PASSIVE
	ability.value = 0.05  # 5% (1 de cada 20 golpes)
	ability.stat_to_modify = "crit_chance"
	return ability

func create_life_steal() -> PassiveAbility:
	var ability = PassiveAbility.new()
	ability.id = "life_steal"
	ability.ability_name = "Robo de Vida"
	ability.description = "Los golpes críticos curan 1 HP"
	ability.type = Ability.AbilityType.PASSIVE
	ability.value = 1.0
	ability.stat_to_modify = "lifesteal_on_crit"
	return ability

func create_combo_master() -> PassiveAbility:
	var ability = PassiveAbility.new()
	ability.id = "combo_master"
	ability.ability_name = "Maestro del Combo"
	ability.description = "Desbloquea combo de 3 ataques"
	ability.type = Ability.AbilityType.COMBAT
	ability.value = 3.0
	ability.stat_to_modify = "max_combo"
	return ability

# ========================================
# HABILIDADES ACTIVAS
# ========================================

func create_dash() -> ActiveAbility:
	var ability = ActiveAbility.new()
	ability.id = "dash"
	ability.ability_name = "Dash"
	ability.description = "Evasión rápida (C)"
	ability.type = Ability.AbilityType.ACTIVE
	ability.cooldown = 0.8
	ability.dash_speed = 350.0
	ability.dash_duration = 0.15
	return ability

func create_air_dash() -> ActiveAbility:
	var ability = ActiveAbility.new()
	ability.id = "air_dash"
	ability.ability_name = "Dash Aéreo"
	ability.description = "Dash en el aire (C)"
	ability.type = Ability.AbilityType.ACTIVE
	ability.cooldown = 1.5
	ability.dash_speed = 350.0
	ability.dash_duration = 0.15
	ability.requires_ability = "dash"
	return ability

# ========================================
# HABILIDADES DE MOVIMIENTO
# ========================================

func create_double_jump() -> MovementAbility:
	var ability = MovementAbility.new()
	ability.id = "double_jump"
	ability.ability_name = "Doble Salto"
	ability.description = "Salta dos veces en el aire"
	ability.type = Ability.AbilityType.MOVEMENT
	ability.value = 2.0
	return ability

func create_wall_jump() -> MovementAbility:
	var ability = MovementAbility.new()
	ability.id = "wall_jump"
	ability.ability_name = "Salto de Pared"
	ability.description = "Salta desde paredes"
	ability.type = Ability.AbilityType.MOVEMENT
	return ability
