extends Resource
class_name Ability

enum AbilityType {
	PASSIVE,      # Siempre activa (life steal, críticos)
	ACTIVE,       # Requiere input (dash, poder especial)
	MOVEMENT,     # Mejora movimiento (doble salto, wall jump)
	COMBAT        # Mejora combate (combo, nuevo ataque)
}

@export var id: String = ""
@export var ability_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var type: AbilityType = AbilityType.PASSIVE

# Variables específicas según el tipo
@export_group("Stats")
@export var value: float = 0.0  # Ej: 0.15 para 15% de crítico
@export var cooldown: float = 0.0  # Para habilidades activas

func activate(_player: Player) -> void:
	# Override en clases hijas
	pass

func deactivate(_player: Player) -> void:
	# Override en clases hijas
	pass
