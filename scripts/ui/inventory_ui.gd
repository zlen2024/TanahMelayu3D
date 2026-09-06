extends PanelContainer

# InventoryUI: 16-slot Bag & Equipment Paperdoll UI controller
# With UI Focus Lock and Quick Access slot bindings

@onready var grid: GridContainer = $VBox/Grid
@onready var info_label: Label = $VBox/InfoLabel
@onready var close_btn: Button = $VBox/CloseBtn

var slot_buttons: Array = []
var equip_weapon_btn: Button
var equip_armor_btn: Button
var equip_acc_btn: Button

func _ready():
	visible = false
	GameState.inventory_updated.connect(_on_inventory_updated)
	GameState.equipped_gear_updated.connect(_on_equipped_updated)
	close_btn.pressed.connect(func(): set_open(false))
	
	_build_paperdoll_ui()
	
	# Build 16 slot buttons
	for i in range(16):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(48, 48)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var slot_idx = i
		btn.pressed.connect(func(): _on_slot_clicked(slot_idx))
		btn.gui_input.connect(func(event): _on_slot_gui_input(event, slot_idx))
		btn.mouse_entered.connect(func(): _on_slot_hover(slot_idx))
		grid.add_child(btn)
		slot_buttons.append(btn)
		
	_refresh_slots()

func _build_paperdoll_ui():
	var vbox = get_node("VBox")
	var equip_hbox = HBoxContainer.new()
	equip_hbox.name = "EquipHBox"
	equip_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	equip_weapon_btn = Button.new()
	equip_weapon_btn.custom_minimum_size = Vector2(68, 36)
	equip_weapon_btn.text = "[WPN]"
	equip_weapon_btn.tooltip_text = "Weapon Slot (Click to unequip)"
	equip_weapon_btn.pressed.connect(func(): GameState.unequip_slot("weapon"))
	
	equip_armor_btn = Button.new()
	equip_armor_btn.custom_minimum_size = Vector2(68, 36)
	equip_armor_btn.text = "[ARM]"
	equip_armor_btn.tooltip_text = "Armor Slot (Click to unequip)"
	equip_armor_btn.pressed.connect(func(): GameState.unequip_slot("armor"))
	
	equip_acc_btn = Button.new()
	equip_acc_btn.custom_minimum_size = Vector2(68, 36)
	equip_acc_btn.text = "[ACC]"
	equip_acc_btn.tooltip_text = "Accessory Slot (Click to unequip)"
	equip_acc_btn.pressed.connect(func(): GameState.unequip_slot("accessory"))
	
	equip_hbox.add_child(equip_weapon_btn)
	equip_hbox.add_child(equip_armor_btn)
	equip_hbox.add_child(equip_acc_btn)
	
	# Insert right before grid
	var grid_idx = grid.get_index()
	vbox.add_child(equip_hbox)
	vbox.move_child(equip_hbox, grid_idx)

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B or event.keycode == KEY_I:
			toggle()

func toggle():
	set_open(not visible)

func set_open(open: bool):
	if visible == open:
		return
	visible = open
	GameState.set_ui_modal_open(visible)
	if visible:
		_refresh_slots()
		_on_equipped_updated(GameState.equipped_gear)

func _on_inventory_updated(_items: Array):
	_refresh_slots()

func _on_equipped_updated(gear: Dictionary):
	if equip_weapon_btn:
		var wpn = gear.get("weapon")
		equip_weapon_btn.text = wpn.get("name", "[WPN]") if wpn else "[WPN]"
		equip_weapon_btn.modulate = ItemDatabase.get_rarity_color(wpn.get("rarity", "Common")) if wpn else Color.GRAY
		
	if equip_armor_btn:
		var arm = gear.get("armor")
		equip_armor_btn.text = arm.get("name", "[ARM]") if arm else "[ARM]"
		equip_armor_btn.modulate = ItemDatabase.get_rarity_color(arm.get("rarity", "Common")) if arm else Color.GRAY
		
	if equip_acc_btn:
		var acc = gear.get("accessory")
		equip_acc_btn.text = acc.get("name", "[ACC]") if acc else "[ACC]"
		equip_acc_btn.modulate = ItemDatabase.get_rarity_color(acc.get("rarity", "Common")) if acc else Color.GRAY

func _refresh_slots():
	for i in range(16):
		var btn: Button = slot_buttons[i]
		var item = GameState.inventory[i] if i < GameState.inventory.size() else null
		if item != null:
			var item_id = item.get("id", "")
			var qty = item.get("quantity", 1)
			var rarity = item.get("rarity", "Common")
			var slot_type = item.get("slot_type", "")
			
			var icon_text = "[ITEM]"
			if item_id == "potion_hp": icon_text = "[HP]"
			elif item_id == "potion_mp": icon_text = "[MP]"
			elif slot_type == "weapon": icon_text = "[WPN]"
			elif slot_type == "armor": icon_text = "[ARM]"
			elif slot_type == "accessory": icon_text = "[ACC]"
			elif item_id == "gold": icon_text = "[$]"
			
			btn.text = "%s\nx%d" % [icon_text, qty] if qty > 1 else icon_text
			btn.modulate = ItemDatabase.get_rarity_color(rarity)
			btn.tooltip_text = "%s (%s)\nRarity: %s\nLeft-Click: Use/Equip\nRight-Click: Assign Hotbar [Q/E]" % [item.get("name", "Item"), slot_type, rarity]
		else:
			btn.text = "---"
			btn.modulate = Color(0.7, 0.7, 0.7)
			btn.tooltip_text = "Empty Slot"

func _on_slot_hover(slot_idx: int):
	var item = GameState.inventory[slot_idx] if slot_idx < GameState.inventory.size() else null
	if item != null:
		var slot_type = item.get("slot_type", "item")
		info_label.text = "%s (%s): Click to equip/use" % [item.get("name", "Item"), slot_type]
	else:
		info_label.text = "Slot %d: Empty" % (slot_idx + 1)

func _on_slot_clicked(slot_idx: int):
	var item = GameState.inventory[slot_idx] if slot_idx < GameState.inventory.size() else null
	if item == null:
		return
		
	var slot_type = str(item.get("slot_type", ""))
	if slot_type in ["weapon", "armor", "accessory"]:
		# Attempt to equip
		var success = GameState.equip_item(slot_idx, 1) # Checked against level
		if success:
			info_label.text = "Equipped %s!" % item.get("name", "Item")
			SoundManager.play("levelup")
		else:
			info_label.text = "Cannot equip %s (Level/Class mismatch)" % item.get("name", "Item")
	else:
		# Consumable
		NetworkManager.send_item_use(slot_idx)
		info_label.text = "Used %s!" % item.get("name", "Item")

func _on_slot_gui_input(event: InputEvent, slot_idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# Right click binds to Quick Slot [Q] (or [E] if Q is filled)
		var item = GameState.inventory[slot_idx] if slot_idx < GameState.inventory.size() else null
		if item != null:
			if GameState.quick_slots[0] == null:
				GameState.assign_quick_slot(0, slot_idx)
				info_label.text = "Bound %s to [Q] Hotbar!" % item.get("name", "Item")
			else:
				GameState.assign_quick_slot(1, slot_idx)
				info_label.text = "Bound %s to [E] Hotbar!" % item.get("name", "Item")
