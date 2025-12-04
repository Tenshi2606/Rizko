# res://scripts/ui/MainMenu.gd
extends Control
class_name MainMenu

@onready var new_game_button: Button = get_node_or_null("MarginContainer/VBoxContainer/NewGameButton")
@onready var continue_button: Button = get_node_or_null("MarginContainer/VBoxContainer/ContinueButton")
@onready var options_button: Button = get_node_or_null("MarginContainer/VBoxContainer/OptionsButton")
@onready var quit_button: Button = get_node_or_null("MarginContainer/VBoxContainer/QuitButton")

func _ready() -> void:
	print("🏠 MainMenu inicializando...")
	
	# Conectar botones
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
		print("  ✅ NewGameButton conectado")
	
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		
		if SaveManager and SaveManager.has_save_file():
			continue_button.disabled = false
			print("  ✅ ContinueButton habilitado")
		else:
			continue_button.disabled = true
			print("  ⚠️ ContinueButton deshabilitado")
	
	if options_button:
		options_button.pressed.connect(_on_options_pressed)
		print("  ✅ OptionsButton conectado")
	
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
		print("  ✅ QuitButton conectado")
	
	print("🏠 MainMenu inicializado correctamente")

# ============================================
# BOTONES
# ============================================

func _on_new_game_pressed() -> void:
	print("🆕 Nueva partida iniciada")
	
	# 🔥 DESCONECTAR BOTONES PARA EVITAR DOBLE CLICK
	_disconnect_all_buttons()
	
	# Limpiar datos
	if SaveManager:
		SaveManager.delete_save()
	
	# 🔥 OCULTAR MENÚ INMEDIATAMENTE
	visible = false
	
	# 🔥 USAR GAMEMANAGER (no SceneManager directamente)
	if GameManager:
		GameManager.start_new_game()
	else:
		# Fallback si GameManager no existe
		var first_level = "res://assets/scenas/Principal/Escenaprincipal.tscn"
		SceneManager.change_scene(first_level, "default")
	
	# 🔥 DESTRUIR ESTE MENÚ DESPUÉS DE 0.1s
	await get_tree().create_timer(0.1).timeout
	queue_free()

func _on_continue_pressed() -> void:
	print("📂 Continuando partida guardada")
	
	_disconnect_all_buttons()
	visible = false
	
	if GameManager:
		GameManager.continue_game()
	elif SaveManager:
		SaveManager.load_game()
	
	await get_tree().create_timer(0.1).timeout
	queue_free()

func _on_options_pressed() -> void:
	print("⚙️ Abriendo menú de opciones")
	print("  ⚠️ Menú de opciones aún no implementado")

func _on_quit_pressed() -> void:
	print("🚪 Saliendo del juego...")
	get_tree().quit()

# ============================================
# UTILIDADES
# ============================================

func _disconnect_all_buttons() -> void:
	# Desconectar para evitar doble click
	if new_game_button and new_game_button.pressed.is_connected(_on_new_game_pressed):
		new_game_button.pressed.disconnect(_on_new_game_pressed)
	
	if continue_button and continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.disconnect(_on_continue_pressed)
	
	if options_button and options_button.pressed.is_connected(_on_options_pressed):
		options_button.pressed.disconnect(_on_options_pressed)
	
	if quit_button and quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.disconnect(_on_quit_pressed)
