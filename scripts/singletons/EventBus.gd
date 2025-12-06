# res://scripts/singletons/EventBus.gd
extends Node

## ============================================
## EVENT BUS - SISTEMA DE EVENTOS CENTRALIZADO
## ============================================
## Desacopla sistemas del juego mediante eventos
## Uso: EventBus.signal_name.emit(args)
##      EventBus.signal_name.connect(callback)
##
## ⚠️ NOTA: Las advertencias "UNUSED_SIGNAL" son NORMALES
## Las señales se usan en OTROS scripts, no en EventBus.gd

# ============================================
# COMBAT
# ============================================

# Suprimir advertencias - las señales se usan en otros scripts
@warning_ignore("unused_signal")

signal enemy_killed(enemy: EnemyBase, killer: Node)

## Emitido cuando se lanza un enemigo al aire (launcher/uppercut)
signal enemy_launched(enemy: EnemyBase)

## Emitido cuando se hace pogo bounce sobre un enemigo
signal pogo_bounce(enemy: EnemyBase)

## Emitido cuando se ejecuta un ataque de combo
signal combo_attack_executed(attack_name: String, combo_index: int)

## Emitido cuando se aplica daño (genérico)
signal damage_dealt(amount: int, target: Node, source: Node)

## Emitido cuando se aplica knockback
signal knockback_applied(target: Node, force: Vector2)

## Emitido cuando el player ataca a un enemigo (para combo tracking)
signal enemy_attacked(enemy: Node, damage: int, attacker: Node)

## Emitido cuando un enemigo recibe daño
signal enemy_damaged(enemy: Node, damage: int, attacker: Node)

# ============================================
# PLAYER EVENTS
# ============================================

## Emitido cuando el player salta
signal player_jumped

## Emitido cuando el player aterriza
signal player_landed

## Emitido cuando el player hace dash
signal player_dashed

## Emitido cuando el player entra en curación
signal healing_started

## Emitido cuando el player termina curación
signal healing_ended

## Emitido cuando el player recibe daño
signal player_damaged(damage: int, source: Node)

## Emitido cuando el player se cura
signal player_healed(amount: int)

## Emitido cuando la vida del player cambia
signal player_health_changed(current_health: int, max_health: int)

## Emitido cuando el player muere (con posición para death screen)
signal player_death(position: Vector2)

# ============================================
# ITEMS
# ============================================

## Emitido cuando se recoge un item
signal item_collected(item: Item, collector: Node)

## Emitido cuando se dropea un item
signal item_dropped(item: Item, position: Vector2)

## Emitido cuando se recoge moneda
signal currency_collected(amount: int, collector: Node)

## Emitido cuando se usa un fragmento de alma
signal soul_fragment_used(fragment: SoulFragment, user: Node)

## Emitido cuando cambia el inventario
signal inventory_changed

# ============================================
# UI
# ============================================

## Emitido cuando se abre el inventario
signal inventory_opened

## Emitido cuando se cierra el inventario
signal inventory_closed

## Emitido cuando se abre una tienda
signal shop_opened(shop: Node)

## Emitido cuando se cierra una tienda
signal shop_closed

## Emitido cuando inicia un diálogo
signal dialogue_started(npc: Node, dialogue_id: String)

## Emitido cuando termina un diálogo
signal dialogue_ended

# ============================================
# GAME STATE
# ============================================

## Emitido cuando cambia de escena
signal scene_changed(from_scene: String, to_scene: String)

## Emitido cuando se pausa el juego
signal game_paused

## Emitido cuando se reanuda el juego
signal game_resumed

## Emitido cuando el player muere (versión simple)
signal player_died

## Emitido cuando se activa un checkpoint
signal checkpoint_activated(checkpoint: Node)

## Emitido cuando cambia el arma equipada
signal weapon_changed(old_weapon: WeaponData, new_weapon: WeaponData)

# ============================================
# UTILIDADES
# ============================================

func _ready() -> void:
	print("🎯 EventBus inicializado")

## Desconectar todas las señales de un nodo (útil para cleanup)
func disconnect_all(node: Node) -> void:
	for sig in get_signal_list():
		var signal_name = sig["name"]
		var connections = get_signal_connection_list(signal_name)
		
		for connection in connections:
			if connection["callable"].get_object() == node:
				disconnect(signal_name, connection["callable"])
