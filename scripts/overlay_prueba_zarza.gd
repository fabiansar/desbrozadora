extends CanvasLayer

## Panel de la escena de pruebas de zarza.
##
## Esta escena se usa para ver COMO se sostiene la maraña, asi que el panel dice
## lo unico que de verdad importa mientras se prueba: cuantas coronas quedan en
## pie (el trabajo que falta), cuanta vegetacion hay y cuantas cañas se han
## quedado sin apoyo. Con eso a la vista no hace falta tumbar medio zarzal para
## averiguar si una pasada ha servido.
##
## Solo lee la API publica de la zarza. No toca nada.

var _lista: Label
var _ayuda: Label


func _ready() -> void:
	layer = 20
	_construir_panel()


func _construir_panel() -> void:
	var panel := PanelContainer.new()
	# Arriba a la derecha y no a la izquierda: el panel de la herramienta ya
	# vive en la esquina de arriba, y con los dos en el mismo sitio no se leia
	# ninguno de los dos. Se ancla a la derecha y se separan los bordes, en vez
	# de dar una posicion, que con un panel que se ajusta solo al contenido
	# empuja la caja fuera de la pantalla.
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -360.0
	panel.offset_right = -18.0
	panel.offset_top = 18.0
	panel.offset_bottom = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.035, 0.055, 0.045, 0.88)
	fondo.set_corner_radius_all(5)
	fondo.content_margin_left = 12.0
	fondo.content_margin_right = 12.0
	fondo.content_margin_top = 9.0
	fondo.content_margin_bottom = 9.0
	panel.add_theme_stylebox_override("panel", fondo)
	add_child(panel)

	var filas := VBoxContainer.new()
	filas.add_theme_constant_override("separation", 2)
	panel.add_child(filas)

	var titulo := Label.new()
	titulo.text = "ZARZA"
	titulo.add_theme_color_override("font_color", Color(0.83, 0.88, 0.78))
	filas.add_child(titulo)

	_ayuda = Label.new()
	_ayuda.text = "caja roja = corona · raya = enganche"
	_ayuda.add_theme_font_size_override("font_size", 12)
	_ayuda.add_theme_color_override("font_color", Color(0.95, 0.6, 0.45))
	filas.add_child(_ayuda)

	var ayuda2 := Label.new()
	ayuda2.text = "WORMAL: ACCELERAR (raton) · MOVER: WASD"
	ayuda2.add_theme_font_size_override("font_size", 12)
	ayuda2.add_theme_color_override("font_color", Color(0.7, 0.74, 0.66))
	filas.add_child(ayuda2)

	_lista = Label.new()
	_lista.add_theme_color_override("font_color", Color(0.94, 0.95, 0.9))
	filas.add_child(_lista)


func _process(_delta: float) -> void:
	if _lista == null:
		return
	var texto := ""
	for nodo in get_tree().get_nodes_in_group("zarzas"):
		var z := nodo as Zarza
		if z == null:
			continue
		var coronas := z.coronas_en_pie()
		var trabajo := "TUMBADA"
		if coronas > 0:
			trabajo = "FALTA LA RAIZ"
		texto += "%-14s RAIZ %d  en pie %4d  %6.1f m   %s\n" % [
			z.name, coronas, z.columnas_en_pie(), z.altura_total(), trabajo]
	_lista.text = texto
