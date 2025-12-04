extends Ability
class_name PassiveAbility

@export var stat_to_modify: String = ""

func activate(player: Player) -> void:
	match stat_to_modify:
		"crit_chance":
			player.crit_chance = value
			print("  💫 Críticos activados: ", value * 100, "%")
		"lifesteal_on_crit":
			player.lifesteal_on_crit = int(value)
			print("  💚 Life steal activado: +", value, " HP por crítico")
		_:
			push_warning("Stat desconocida: ", stat_to_modify)
