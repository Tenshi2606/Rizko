extends Ability
class_name ActiveAbility

@export var dash_speed: float = 350.0
@export var dash_duration: float = 0.15
@export var requires_ability: String = ""

func activate(player: Player) -> void:
	# Ejecutar dash (cambiar a DashState)
	if id == "dash" or id == "air_dash":
		var state_machine = player.get_node_or_null("StateMachine")
		if state_machine:
			state_machine.change_to("Dash")
			print("  💨 Dash ejecutado")
