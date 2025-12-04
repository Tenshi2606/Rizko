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
## Godot solo verifica uso dentro del mismo archivo.

# Suprimir advertencias de señales no usadas (son usadas en otros scripts)
@warning_ignore("unused_signal")

# ============================================
# COMBATE
# ============================================

## Emitido cuando el player ataca
signal player_attacked(damage: int, target: Node)

## Emitido cuando un enemigo es atacado
signal enemy_attacked(damage: int, enemy: EnemyBase, attacker: Node)

## Emitido cuando un enemigo muere
signal enemy_killed(enemy: EnemyBase, killer: Node)

## Emitido cuando se aplica daño (genérico)
signal damage_dealt(amount: int, target: Node, source: Node)

## Emitido cuando se aplica knockback
signal knockback_applied(target: Node, force: Vector2)

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

## Emitido cuando el player muere
signal player_died

## Emitido cuando se activa un checkpoint
signal checkpoint_activated(checkpoint: Node)

# ============================================
# PLAYER STATE
# ============================================

## Emitido cuando cambia la vida del player
signal player_health_changed(current: int, max_health: int)

## Emitido cuando el player se cura
signal player_healed(amount: int)

## Emitido cuando el player recibe daño
signal player_damaged(amount: int)

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
