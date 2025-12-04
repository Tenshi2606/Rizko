# res://scripts/ui/PauseMenu.gd
extends Control
class_name PauseMenu

@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var save_button: Button = $Panel/VBoxContainer/SaveButton
@onready var restart_checkpoint_button: Button = $Panel/VBoxContainer/RestartCheckpointButton
@onready var options_button: Button = $Panel/VBoxContainer/OptionsButton
@onready var menu_button: Button = $Panel/VBoxContainer/MenuButton

var is_paused: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # Funciona aunque el juego esté pausado
	
	# Conectar botones
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if restart_checkpoint_button:
		restart_checkpoint_button.pressed.connect(_on_restart_checkpoint_pressed)
	if options_button:
		options_button.pressed.connect(_on_options_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
	
	print("⏸️ PauseMenu inicializado")

func _input(event: InputEvent) -> void:
	# ESC para pausar/reanudar
	if event.is_action_pressed("ui_cancel"):
		if is_paused:
			_on_resume_pressed()
		else:
			_show_pause()
		get_viewport().set_input_as_handled()

func _show_pause() -> void:
	is_paused = true
	visible = true
	get_tree().paused = true
	
	# 🎯 EMITIR EVENTO
	EventBus.game_paused.emit()
	
	# 🎯 Cerrar otros menús abiertos
	if HUDManager:
		HUDManager.close_all()
	
	print("⏸️ Juego pausado")

func _on_resume_pressed() -> void:
	is_paused = false
	visible = false
	get_tree().paused = false
	
	# 🎯 EMITIR EVENTO
	EventBus.game_resumed.emit()
	
	print("▶️ Juego reanudado")

func _on_save_pressed() -> void:
	print("💾 Guardando partida...")
	
	if SaveManager:
		if SaveManager.save_game():
			print("✅ Partida guardada exitosamente")
			_show_save_feedback()
		else:
			print("❌ Error al guardar partida")
			_show_error_feedback()
	else:
		print("❌ SaveManager no encontrado")

func _on_restart_checkpoint_pressed() -> void:
	print("🔄 Reiniciando desde último checkpoint...")
	
	# Obtener último checkpoint guardado
	var checkpoint_id = SceneManager.spawn_point_id
	
	if checkpoint_id.is_empty():
		checkpoint_id = "default"
	
	print("  📍 Checkpoint: ", checkpoint_id)
	
	# Despausar
	get_tree().paused = false
	
	# Recargar escena
	SceneManager.spawn_point_id = checkpoint_id
	get_tree().reload_current_scene()

func _on_options_pressed() -> void:
	print("⚙️ Opciones (por implementar)")
	# TODO: Abrir menú de opciones

func _on_menu_pressed() -> void:
	print("🏠 Volver al menú principal")
	
	# Mostrar confirmación
	_show_confirmation_dialog()

func _show_confirmation_dialog() -> void:
	# TODO: Mostrar diálogo "¿Guardar antes de salir?"
	# Por ahora, salir directamente
	
	get_tree().paused = false
	SceneManager.change_scene("res://assets/scenas/ui/main_menu.tscn")

func _show_save_feedback() -> void:
	# Cambiar texto del botón temporalmente
	if save_button:
		var original_text = save_button.text
		save_button.text = "✅ Guardado!"
		save_button.disabled = true
		
		await get_tree().create_timer(1.0).timeout
		
		if is_instance_valid(save_button):
			save_button.text = original_text
			save_button.disabled = false

func _show_error_feedback() -> void:
	if save_button:
		var original_text = save_button.text
		save_button.text = "❌ Error"
		
		await get_tree().create_timer(1.0).timeout
		
		if is_instance_valid(save_button):
			save_button.text = original_text
