# res://scripts/ui/DeathScreen.gd
extends Control
class_name DeathScreen

@onready var message_label: Label = get_node_or_null("Panel/VBoxContainer/MessageLabel")
@onready var retry_button: Button = get_node_or_null("Panel/VBoxContainer/RetryButton")
@onready var menu_button: Button = get_node_or_null("Panel/VBoxContainer/MenuButton")

var last_checkpoint: String = "default"

func _ready() -> void:
	# 🔥 CRÍTICO: Process Mode debe ser Always
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 🔥 CRÍTICO: Empezar OCULTO pero permitir clics
	visible = false
	modulate.a = 0.0
	
	# 🔥 CRÍTICO: Desactivar mouse filter mientras está oculto
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Añadir al grupo
	if not is_in_group("death_screen"):
		add_to_group("death_screen")
	
	# Conectar botones
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
		print("✅ RetryButton conectado")
	else:
		push_error("❌ RetryButton NO encontrado - Verifica ruta: Panel/VBoxContainer/RetryButton")
	
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
		print("✅ MenuButton conectado")
	else:
		push_error("❌ MenuButton NO encontrado - Verifica ruta: Panel/VBoxContainer/MenuButton")
	
	print("💀 DeathScreen inicializado")
	print("  - Process Mode: ", process_mode)
	print("  - Visible: ", visible)
	print("  - Modulate Alpha: ", modulate.a)
	print("  - Mouse Filter: ", mouse_filter)

func show_death_screen(checkpoint: String = "default") -> void:
	print("💀 show_death_screen() LLAMADO")
	print("  - Checkpoint: ", checkpoint)
	
	last_checkpoint = checkpoint
	
	# 🔥 ASEGURAR que está visible
	visible = true
	
	# 🔥 ACTIVAR MOUSE FILTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 🔥 PAUSAR EL JUEGO
	print("⏸️ Pausando juego...")
	get_tree().paused = true
	print("  - Juego pausado: ", get_tree().paused)
	
	# 🔥 FADE IN
	print("🎬 Iniciando fade in...")
	modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # 🔥 CRÍTICO: Funciona aunque esté pausado
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	
	print("✅ DeathScreen visible - Alpha: ", modulate.a)

func _on_retry_pressed() -> void:
	print("🔄 REINTENTAR presionado")
	print("  - Último checkpoint: ", last_checkpoint)
	
	# 🔥 DESACTIVAR MOUSE FILTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 🔥 DESPAUSAR
	get_tree().paused = false
	
	# 🔥 OCULTAR
	visible = false
	modulate.a = 0.0
	
	# 🆕 RESPAWNEAR ENEMIGOS - Limpiar lista ANTES de cambiar escena
	print("☠️ Limpiando enemigos muertos para respawn...")
	if SceneManager:
		# 🔥 USAR EL NOMBRE DEL NODO RAÍZ, NO DEL ARCHIVO
		var scene_root_name = get_tree().current_scene.name
		print("  🏷️ Nombre de escena (nodo raíz): ", scene_root_name)
		
		var enemies_to_remove = []
		
		for enemy_id in SceneManager.world_state["killed_enemies"]:
			if enemy_id.begins_with(scene_root_name):
				enemies_to_remove.append(enemy_id)
		
		for enemy_id in enemies_to_remove:
			SceneManager.world_state["killed_enemies"].erase(enemy_id)
			print("  ✅ Enemigo limpiado: ", enemy_id)
		
		print("  📋 Enemigos restantes en lista global: ", SceneManager.world_state["killed_enemies"])
	
	# 🆕 CAMBIAR A ESCENA DEL CHECKPOINT
	print("🔄 Cambiando a escena del checkpoint...")
	if SceneManager:
		var checkpoint_scene = SceneManager.last_checkpoint_scene
		var checkpoint_id = SceneManager.last_checkpoint_id
		
		# Si no hay checkpoint guardado, usar la escena actual
		if checkpoint_scene.is_empty():
			checkpoint_scene = get_tree().current_scene.scene_file_path
		
		print("  - Escena: ", checkpoint_scene)
		print("  - Checkpoint ID: ", checkpoint_id)
		
		# 🔥 IMPORTANTE: Marcar para restaurar vida completa al respawnear
		SceneManager.player_data = {}
		SceneManager.should_restore_full_health = true
		
		# Cambiar a la escena del checkpoint (esto recargará los enemigos)
		SceneManager.change_scene(checkpoint_scene, checkpoint_id)
	else:
		# Fallback: recargar escena actual
		print("⚠️ SceneManager no encontrado, recargando escena actual")
		SceneManager.spawn_point_id = last_checkpoint
		get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	print("🏠 MENÚ PRINCIPAL presionado")
	
	# 🔥 DESACTIVAR MOUSE FILTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 🔥 DESPAUSAR
	get_tree().paused = false
	
	# 🔥 OCULTAR
	visible = false
	modulate.a = 0.0
	
	# 🔥 IR AL MENÚ
	print("🏠 Cambiando a main menu...")
	SceneManager.change_scene("res://assets/scenas/ui/main_menu.tscn")
