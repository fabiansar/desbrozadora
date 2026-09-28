extends CanvasLayer

## La rueda del inventario: nueve sectores, arriba a la derecha.
##
## Es un circulo y no una tira de cuadrados porque lo unico que hay que saber de
## un vistazo es cual de las dos o tres cosas que llevas tienes en la mano. Con
## una tira hay que leer los numeros de izquierda a derecha; con una rueda el
## sector elegido se ve resaltado, y los numeros son solo para cuando se busca
## uno en concreto.
##
## Los sectores vacios tambien se dibujan. Un hueco vacio es un estado de
## verdad (has soltado lo que llevabas) y si no se dibujara, el circulo pareceria
## rotto en vez de vacio.
##
## No dibuja nada de la herramienta: solo el nombre y el numero. Para el icono
## haria falta una textura por herramienta, y con dos herramientas en el juego
## eso es trabajo que no se ve.

const COLOR_FONDO := Color(0.035, 0.055, 0.045, 0.86)
const COLOR_BORDE := Color(0.30, 0.36, 0.30, 0.9)
const COLOR_ACTIVO := Color(0.32, 0.46, 0.20, 0.96)
const COLOR_VACIO := Color(0.13, 0.16, 0.14, 0.75)
const COLOR_TEXTO := Color(0.92, 0.94, 0.88)
const COLOR_APAGADO := Color(0.62, 0.66, 0.60)

const RADIO_EXTERIOR := 96.0
const RADIO_INTERIOR := 56.0
## Separacion entre sectores, en radianes. Sin esto los nueve se tocan y la
## rueda se lee como un disco entero en vez de como nueve cosas.
const HUECO := 0.030
## Donde va el centro de la rueda: pegado a la esquina de arriba a la derecha, con
## un margen para que no se recorte contra el borde de la pantalla.
const DESPLAZAMIENTO := Vector2(118.0, 122.0)

var _inventario: Inventario
var _rueda: Control
var _recoger: Label
var _aviso: Label
var _nombre: Label


func _ready() -> void:
	layer = 15
	_inventario = _buscar_inventario()
	_rueda = Control.new()
	_rueda.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rueda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rueda.draw.connect(_dibujar_rueda)
	add_child(_rueda)

	_recoger = _etiqueta(-124.0, -96.0, 18, Color(0.72, 0.94, 0.55))
	_aviso = _etiqueta(-96.0, -58.0, 16, COLOR_APAGADO)
	_nombre = _etiqueta(-58.0, -22.0, 22, COLOR_TEXTO)


## Una linea de texto centrada abajo, con contorno para que se lea sobre la
## maleza. Los tres textos van en lineas separadas: el aviso sale un momento y
## se va, y si compartiera linea con el "E recoger" taparia justo lo que el
## jugador necesita ver en el momento de mirar una herramienta en el suelo, que
## es justo despues de soltarla.
func _etiqueta(arriba: float, abajo: float, tamano: int,
		color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	etiqueta.offset_left = -220.0
	etiqueta.offset_right = 220.0
	etiqueta.offset_top = arriba
	etiqueta.offset_bottom = abajo
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	etiqueta.add_theme_constant_override("outline_size", 6)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(etiqueta)
	return etiqueta


func _process(_delta: float) -> void:
	if _inventario == null:
		_inventario = _buscar_inventario()
		if _inventario == null:
			return
	_rueda.queue_redraw()
	_nombre.text = _inventario.nombre_de(_inventario.seleccion())
	if _nombre.text == "":
		_nombre.text = "manos vacias"
	_avisito()


## El "E recoger" sale solo cuando hay algo que recoger Y se puede coger. Con el
## inventario lleno el texto es otro, porque si no el jugador ve el aviso de
## recoger, pulsa y no pasa nada, y eso es peor que no dibujar nada.
func _avisito() -> void:
	var texto := ""
	var bajo := _inventario.objeto_bajo_mirada()
	if bajo != null:
		texto = "E  recoger" if _inventario.hay_hueco_libre() else "inventario lleno"
	_recoger.text = texto
	_aviso.text = _inventario.aviso_actual()


func _dibujar_rueda() -> void:
	if _inventario == null:
		return
	var centro := Vector2(_rueda.size.x - DESPLAZAMIENTO.x, DESPLAZAMIENTO.y)
	var fuente := ThemeDB.fallback_font
	var paso := TAU / Inventario.HUECOS
	# El sector 1 queda arriba y los demas van en sentido horario, que es como
	# se lee una rueda de verdad y como gira la rueda del raton hacia abajo.
	for i in Inventario.HUECOS:
		var a0 := -PI * 0.5 + paso * float(i) + HUECO
		var a1 := -PI * 0.5 + paso * float(i + 1) - HUECO
		var lleno := _inventario.hay_algo(i)
		var elegido := i == _inventario.seleccion()
		var color := COLOR_ACTIVO if elegido else (COLOR_FONDO if lleno else COLOR_VACIO)
		if elegido:
			color.a = 0.98
		_rueda.draw_colored_polygon(_sector(centro, a0, a1), color)
		_rueda.draw_polyline(_sector(centro, a0, a1), COLOR_BORDE, 1.5, true)
		# El numero va a una proporcion del camino del medio del sector, que es
		# donde cabe sin salirse ni con los nombres largos.
		var medio := (a0 + a1) * 0.5
		var punto := centro + Vector2(cos(medio), sin(medio)) * ((RADIO_EXTERIOR + RADIO_INTERIOR) * 0.5)
		var texto := str(i + 1)
		var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_rueda.draw_string(fuente, punto - Vector2(ancho * 0.5, -5.0), texto,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			COLOR_TEXTO if lleno else COLOR_APAGADO)
	# Un anillo por fuera, para que el circulo se lea entero aunque un sector este
	# vacio y no se note el borde.
	var exterior := PackedVector2Array()
	for i in range(49):
		var a := -PI * 0.5 + TAU * float(i) / 48.0
		exterior.append(centro + Vector2(cos(a), sin(a)) * RADIO_EXTERIOR)
	_rueda.draw_polyline(exterior, COLOR_BORDE, 2.0, true)


## Un sector de anillo: el arco de fuera, y el de dentro en sentido contrario.
## Sin el hueco interior sale un sector lleno en forma de tarta y no se ve que
## es un anillo.
func _sector(centro: Vector2, a0: float, a1: float) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	var pasos := 8
	for i in range(pasos + 1):
		var a := lerpf(a0, a1, float(i) / float(pasos))
		puntos.append(centro + Vector2(cos(a), sin(a)) * RADIO_EXTERIOR)
	for i in range(pasos, -1, -1):
		var a := lerpf(a0, a1, float(i) / float(pasos))
		puntos.append(centro + Vector2(cos(a), sin(a)) * RADIO_INTERIOR)
	return puntos


func _buscar_inventario() -> Inventario:
	for nodo in get_tree().get_nodes_in_group("inventario"):
		if nodo is Inventario:
			return nodo as Inventario
	return null
