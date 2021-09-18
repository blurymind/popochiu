tool
class_name PopochiuObjectRow
extends HBoxContainer
# NOTA: El icono para el menú contextual podría ser el icon_GUI_tab_menu_hl.svg
#		de los iconos de Godot.

enum MenuOptions { ADD_TO_CORE, SET_AS_MAIN, DELETE }

const SELECTED_FONT_COLOR := Color('706deb')

var type := ''
var path := ''
var main_dock setget _set_main_dock
var is_main := false setget _set_is_main

var _confirmation_dialog: ConfirmationDialog
var _delete_all_checkbox: CheckBox

onready var _label: Label = find_node('Label')
onready var _dflt_font_color: Color = _label.get_color('font_color')
onready var _fav_icon: TextureRect = find_node('FavIcon')
onready var _menu_btn: MenuButton = find_node('MenuButton')
onready var _menu_popup: PopupMenu = _menu_btn.get_popup()
onready var _btn_open: Button = find_node('Open')
onready var _menu_cfg := [
	{
		id = MenuOptions.ADD_TO_CORE,
		icon = preload(\
		'res://addons/Popochiu/Editor/MainDock/ObjectRow/add_to_core.png'),
		label = 'Meter a Popochiu'
	},
	{
		id = MenuOptions.SET_AS_MAIN,
		icon = get_icon('Heart', 'EditorIcons'),
		label = 'Establecer como principal',
		type = 'room'
	},
	null,
	{
		id = MenuOptions.DELETE,
		icon = get_icon('Remove', 'EditorIcons'),
		label = 'Eliminar'
	}
]


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos de Godot ░░░░
func _ready() -> void:
	_label.text = name
	
	# Definir iconos
	_fav_icon.texture = get_icon('Heart', 'EditorIcons')
	_btn_open.icon = get_icon('InstanceOptions', 'EditorIcons')
	_menu_btn.icon = get_icon('GuiTabMenu', 'EditorIcons')
	
	# Crear menú contextual
	_create_menu()
	_menu_popup.set_item_disabled(MenuOptions.ADD_TO_CORE, true)
	
	# Ocultar cosas que se verán dependiendo de otras cosas
	_fav_icon.hide()
	
	connect('gui_input', self, 'select')
	_menu_popup.connect('id_pressed', self, '_menu_item_pressed')
	_btn_open.connect('pressed', self, '_open')


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos públicos ░░░░
func select(event: InputEvent) -> void:
	var mouse_event: = event as InputEventMouseButton
	if mouse_event\
	and mouse_event.button_index == BUTTON_LEFT and mouse_event.pressed:
		if main_dock.last_selected:
			main_dock.last_selected.unselect()
		
		main_dock.ei.select_file(path)
		_label.add_color_override('font_color', SELECTED_FONT_COLOR)
		main_dock.last_selected = self


func unselect() -> void:
	_label.add_color_override('font_color', _dflt_font_color)


func show_add_to_core() -> void:
	_menu_popup.set_item_disabled(0, false)


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos privados ░░░░
func _create_menu() -> void:
	_menu_popup.clear()
	
	for option in _menu_cfg:
		if option:
			if option.has('type') and option.type != type: continue
			
			_menu_popup.add_icon_item(
				option.icon,
				option.label,
				option.id
			)
		else:
			_menu_popup.add_separator()


func _menu_item_pressed(id: int) -> void:
	match id:
		MenuOptions.ADD_TO_CORE:
			_add_object_to_core()
		MenuOptions.SET_AS_MAIN:
			main_dock.set_main_scene(path)
			self.is_main = true
		MenuOptions.DELETE:
			_ask_basic_delete()


# Agrega este objeto (representado por una fila en una de las categorías de la
# sección Main en el dock de Popochiu) al núcleo del plugin (Popochiu.tscn) para
# que pueda ser usado (p. ej. Que se pueda navegar a la habitación, que se pueda
# mostrar a un personaje en una habitación, etc.).
func _add_object_to_core() -> void:
	var popochiu: Popochiu = main_dock.get_popochiu()
	var target_array := ''
	var resource: Resource
	
	if path.find('.tscn') > -1:
		resource = load(path.replace('.tscn', '.tres'))
	else:
		resource = load(path)
	
	match type:
		'room':
			target_array = 'rooms'
		'character':
			target_array = 'characters'
		'inventory_item':
			target_array = 'inventory_items'
		'dialog':
			target_array = 'dialogs'
		_:
			# TODO: Mostrar un mensaje de error o algo.
			return
	
	if popochiu[target_array].empty():
		popochiu[target_array] = [resource]
	else:
		popochiu[target_array].append(resource)
	
	if main_dock.save_popochiu() != OK:
		push_error('No se pudo agregar el objeto a Popochiu: %s' %\
		name)
		return
	
	_menu_popup.set_item_disabled(0, true)
#	_btn_add.hide()


# Selecciona el archivo principal del objeto en el FileSystem y lo abre para que
# pueda ser editado.
func _open() -> void:
	main_dock.ei.select_file(path)
	if path.find('.tres') < 0:
		main_dock.ei.open_scene_from_path(path)
	else:
		main_dock.ei.edit_resource(load(path))


# Abre un popup de confirmación para saber si la desarrolladora quiere eliminar
# el objeto del núcleo del plugin y del sistema.
func _ask_basic_delete() -> void:
	main_dock.show_confirmation(
		'Se eliminará a %s de Popochiu' % name,
		'Esto eliminará la referencia de [b]%s[/b] en Popochiu.' % name +\
		' Los usos de este objeto dentro de los scripts dejarán de funcionar.' +\
		' Esta acción no se puede revertir. ¿Quiere continuar?',
		'Eliminar también la carpeta [b]%s[/b]' % path.get_base_dir() +\
		' (no se puede revertir)'
	)
	
	_confirmation_dialog.get_cancel().connect('pressed', self, '_disconnect_popup')
	_confirmation_dialog.connect('confirmed', self, '_delete_from_core')


func _delete_from_core() -> void:
	_confirmation_dialog.disconnect('confirmed', self, '_delete_from_core')
	
	# Eliminar el objeto de Popochiu -------------------------------------------
	var popochiu: Popochiu = main_dock.get_popochiu()
	
	match type:
		'room':
			for r in popochiu.rooms:
				if (r as PopochiuRoomData).script_name == name:
					popochiu.rooms.erase(r)
					break
		'character':
			for c in popochiu.characters:
				if (c as PopochiuCharacterData).script_name == name:
					popochiu.characters.erase(c)
					break
		'inventory_item':
			for ii in popochiu.inventory_items:
				if (ii as PopochiuInventoryItemData).script_name == name:
					popochiu.inventory_items.erase(ii)
					break
		'dialog':
			for d in popochiu.dialogs:
				if (d as PopochiuDialog).script_name == name:
					popochiu.dialogs.erase(d)
					break
	
	if main_dock.save_popochiu() != OK:
		push_error('No se pudo eliminar el objeto de Popochiu: %s' %\
		name)
		# TODO: Mostrar retroalimentación en el mismo popup
	
	if _delete_all_checkbox.pressed:
		_delete_from_file_system()
	else:
		show_add_to_core()


# Elimina el directorio del objeto del sistema.
func _delete_from_file_system() -> void:
#	_confirmation_dialog.disconnect('confirmed', self, '_delete_from_file_system')
	
	# Eliminar la carpeta del disco y todas sus subcarpetas y archivos si la
	# desarrolladora así lo quiso
	var object_dir: EditorFileSystemDirectory = \
		main_dock.fs.get_filesystem_path(path.get_base_dir())
	
	if _recursive_delete(object_dir) != OK:
		push_error('Hubo un error en la eliminación recursiva de %s' \
		% path.get_base_dir())
		return

	# Eliminar la carpeta del objeto
	if main_dock.dir.remove(path.get_base_dir()) != OK:
		push_error('No se pudo eliminar la carpeta: %s' %\
		main_dock.CHARACTERS_PATH + name)
		return

	# Forzar que se actualice la estructura de archivos en el EditorFileSystem
	main_dock.fs.scan()
	main_dock.fs.scan_sources()
	
	if main_dock.save_popochiu() != OK:
		push_error('No se pudo eliminar la carpeta del sistema: %s' %\
		name)

	# Eliminar el objeto de su lista -------------------------------------------
	_disconnect_popup()
	queue_free()


# Elimina un directorio del sistema. Para que Godot pueda eliminar un directorio,
# este tiene que estar vacío, por eso este método elimina primero los archivos
# del directorio y cada uno de sus subdirectorios.
func _recursive_delete(dir: EditorFileSystemDirectory) -> int:
	if dir.get_subdir_count():
		for folder_idx in dir.get_subdir_count():
			var subfolder := dir.get_subdir(folder_idx)

			_recursive_delete(subfolder)

			var err: int = main_dock.dir.remove(subfolder.get_path())
			if err != OK:
				push_error('[%d] No se pudo eliminar el subdirectorio %s' %\
				[err, subfolder.get_path()])
				return err
	
	return _delete_files(dir)


# Elimina los archivos dentro de un directorio. Primero se obtienen las rutas
# (path) a cada archivo y luego se van eliminando, uno a uno, y llamando a
# EditorFileSystem.update_file(path: String) para que, en caso de que sea un
# archivo importado, se elimine su .import.
func _delete_files(dir: EditorFileSystemDirectory) -> int:
	var files_paths := []
	
	for file_idx in dir.get_file_count():
		files_paths.append(dir.get_file_path(file_idx))

	for fp in files_paths:
		# Así es como se hace en el código fuente del motor para que se eliminen
		# también los .import asociados a los archivos importados. ------------
		var err: int = main_dock.dir.remove(fp)
		main_dock.fs.update_file(fp)
		# ---------------------------------------------------------------------
		if err != OK:
			push_error('[%d] No se pudo eliminar el archivo %s' %\
			[err, fp])
			return err

	main_dock.fs.scan()
	main_dock.fs.scan_sources()

	return OK


# Se desconecta de las señales del popup utilizado para configurar la eliminación.
func _disconnect_popup() -> void:
	if _confirmation_dialog.is_connected('confirmed', self, '_delete_from_core'):
		_confirmation_dialog.disconnect('confirmed', self, '_delete_from_core')
	
	if _confirmation_dialog.is_connected(
	'confirmed', self, '_delete_from_file_system'):
		# Se canceló la eliminación de los archivos en disco
		show_add_to_core()
		_confirmation_dialog.disconnect(
			'confirmed', self, '_delete_from_file_system'
		)


func _set_main_dock(value: Panel) -> void:
	main_dock = value
	_confirmation_dialog = value.delete_dialog
	_delete_all_checkbox = _confirmation_dialog.find_node('CheckBox')


func _set_is_main(value: bool) -> void:
	is_main = value
	_fav_icon.visible = value
	_menu_popup.set_item_disabled(MenuOptions.SET_AS_MAIN, value)
