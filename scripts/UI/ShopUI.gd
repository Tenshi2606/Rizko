extends Control
class_name ShopUI

signal shop_closed

var current_vendor: Vendor = null
var is_active: bool = false

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var greeting_label: Label = $Panel/VBoxContainer/GreetingLabel
@onready var wallet_display: Label = $Panel/VBoxContainer/WalletDisplay
@onready var scroll_container: ScrollContainer = $Panel/VBoxContainer/ScrollContainer
@onready var items_list: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/ItemsList
@onready var close_button: Button = $Panel/VBoxContainer/ScrollContainer/CloseButton

func _ready() -> void:
	visible = false
	is_active = false
	
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	print("🏪 ShopUI inicializado")

func _input(event: InputEvent) -> void:
	if not is_active or not visible:
		return
	
	# Cerrar con ESC (pero NO con I, para evitar conflictos con inventario)
	if event.is_action_pressed("ui_cancel"):
		HUDManager.close_shop()
		get_viewport().set_input_as_handled()

func open_shop(vendor: Vendor) -> void:
	if not vendor:
		print("❌ Vendor es null")
		return
	
	# ❌ VERIFICAR QUE NO HAYA OTRO MENÚ ACTIVO
	if not HUDManager.can_open_menu("shop"):
		print("❌ No se puede abrir tienda - Hay otro menú activo")
		return
	
	HUDManager.open_shop()
	
	current_vendor = vendor
	is_active = true
	visible = true
	
	if title_label:
		title_label.text = "🏪 " + vendor.shop_name
	
	if greeting_label:
		greeting_label.text = vendor.greeting
	
	_update_wallet_display()
	_populate_items()
	
	print("🏪 ShopUI abierto: ", vendor.shop_name)

func close_shop() -> void:
	HUDManager.close_shop()
	
	visible = false
	is_active = false
	
	# 🆕 Limpiar referencia antes de llamar stop_interaction
	var vendor_ref = current_vendor
	current_vendor = null
	
	if vendor_ref:
		vendor_ref.stop_interaction()
	
	shop_closed.emit()
	print("🏪 ShopUI cerrado")

func _update_wallet_display() -> void:
	if not wallet_display or not current_vendor or not current_vendor.player_nearby:
		return
	
	var wallet = current_vendor.player_nearby.get_node_or_null("Wallet") as Wallet
	if wallet:
		var amount = wallet.get_asteriones()
		wallet_display.text = "💰 Tienes: " + str(amount) + " Asteriones"

func _populate_items() -> void:
	if not items_list or not current_vendor:
		return
	
	# Limpiar lista
	for child in items_list.get_children():
		child.queue_free()
	
	var shop_items = current_vendor.get_shop_items()
	
	if shop_items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No hay items disponibles"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_list.add_child(empty_label)
		return
	
	# Crear slot por cada item
	for item_data in shop_items:
		var slot = _create_item_slot(item_data)
		items_list.add_child(slot)

func _create_item_slot(item_data: Dictionary) -> Control:
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(400, 80)
	
	# Estilo del slot
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.4)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	slot.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	slot.add_child(hbox)
	
	# Icono (color según rareza)
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(60, 60)
	icon.color = _get_rarity_color(item_data.get("rarity", 0))
	hbox.add_child(icon)
	
	# Info del item
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	# Nombre
	var name_label = Label.new()
	name_label.text = item_data["name"]
	name_label.add_theme_color_override("font_color", _get_rarity_color(item_data.get("rarity", 0)))
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	# Descripción
	var desc_label = Label.new()
	desc_label.text = item_data["description"]
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(desc_label)
	
	# Precio
	var price_label = Label.new()
	price_label.text = "💰 " + str(item_data["price"]) + " Asteriones"
	price_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	price_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(price_label)
	
	# Botón comprar
	var buy_button = Button.new()
	buy_button.text = "Comprar"
	buy_button.custom_minimum_size = Vector2(100, 40)
	
	# Guardar datos en metadata
	buy_button.set_meta("item_id", item_data["item_id"])
	buy_button.set_meta("price", item_data["price"])
	
	buy_button.pressed.connect(_on_buy_button_pressed.bind(buy_button))
	hbox.add_child(buy_button)
	
	return slot

func _on_buy_button_pressed(button: Button) -> void:
	var item_id = button.get_meta("item_id")
	var price = button.get_meta("price")
	
	if current_vendor.purchase_item(item_id, price):
		print("✅ Compra exitosa")
		_update_wallet_display()
		
		# Feedback visual
		button.text = "✓ Comprado"
		button.disabled = true
		
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(button):
			button.text = "Comprar"
			button.disabled = false
	else:
		print("❌ Compra fallida")
		
		# Feedback visual
		button.text = "❌ Sin dinero"
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(button):
			button.text = "Comprar"

func _on_close_button_pressed() -> void:
	HUDManager.close_shop()

func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		0:  # COMMON
			return Color(0.8, 0.8, 0.8)
		1:  # UNCOMMON
			return Color(0.3, 1, 0.3)
		2:  # RARE
			return Color(0.3, 0.5, 1)
		3:  # EPIC
			return Color(0.8, 0.3, 1)
		4:  # LEGENDARY
			return Color(1, 0.65, 0)
		_:
			return Color(1, 1, 1)
