class_name Viento
extends Node3D

## El viento del campo, por zonas.
##
## La idea es la de partir el suelo en una rejilla de celdas y darle a cada una
## una direccion y una fuerza propias, que van cambiando. La hoja de hierba
## busca la celda que tiene debajo en una textura pequena, y como el filtro de
## la textura es lineal no se ven las costuras entre celdas.
##
## Aparte del balanceo de cada celda hay dos cosas globales:
##
## - La direccion principal gira muy despacio, asi que el campo entero va
##   cambiando de rumbo con el rato, como cuando cambia el tiempo.
## - Una ola que cruza el campo en linea recta. Es la que se ve pasar por encima
##   de la hierba de un lado a otro; sin ella cada celda va por libre y se ve un
##   ruido que hierve en vez de un campo de hierba.
##
## No se dibuja nada: esto solo alimenta un mapa del viento. Lo que se mueve de
## verdad es cada hoja, en el shader.

## Lado de una celda, en metros. OJO: este valor es un punto de partida nomas.
## _conectar() lo recalcula para que el mapa mida exactamente lo que el campo de
## hierba, porque la hoja calcula su sitio en el mapa suponiendo eso. Si se
## cambia el radio del campo hay que volver a sembrar la hierba, o el viento
## sale descuadrado.
@export_range(1.0, 8.0, 0.1) var lado_celda := 2.8
## Celdas por lado. El mapa entero son celdas*celdas texels, o sea que esto no
## cuesta nada: 32 son 4 KB de textura.
@export_range(4, 64, 1) var celdas := 32
## Fuerza global. Multiplica a todo lo demas.
@export_range(0.0, 2.0, 0.01) var fuerza := 0.25
## Cuantas veces se rehace el mapa por segundo. A ojo no se nota la diferencia
## entre 10 y 20, y con 10 hay una quinta parte de trabajo.
@export_range(4.0, 30.0, 1.0) var pasos_por_segundo := 10.0
## Rapidez con la que gira la direccion principal. Un giro cada varios minutos.
@export var giro_lento := 0.035
## Rapidez de la ola que cruza el campo.
@export var rapidez_ola := 0.9
## Semilla. Con la misma sale siempre el mismo viento, que es lo que hace falta
## para poder comparar dos pruebas.
@export var semilla := 7381

var _textura: ImageTexture
var _imagen: Image
var _datos := PackedByteArray()
var _fase_a := PackedFloat32Array()
var _fase_b := PackedFloat32Array()
var _hierba: Array[Hierba] = []
## El material de CADA campo de hierba, no solo el primero. Antes se guardaba
## uno solo en `_mat` y el tiempo del shader se metia ahi, con lo que el segundo
## tipo de maleza se quedaba con el `tiempo` en 0 para siempre: no se doblaba
## nunca y se veia como un cartel de plastico clavado en el suelo. Con la lista,
## el tiempo va a todos y cada tipo ondea a su aire.
var _mats: Array[ShaderMaterial] = []
var _tiempo := 0.0
var _acumulado := 0.0
## Radio del campo mas grande que se ha encontrado. El mapa tiene que medir lo
## mismo que el campo mas ancho, y no lo que mida el primero que aparezca: con
## dos tipos de hierba, si el segundo es mas grande, la hoja del segundo se
## salia del mapa. Guardarlo permite además notar cuando cambia.
var _radio_campo := 0.0
## Fotogramas que quedan por estar atentos a que aparezca otro campo de hierba.
##
## El viento vive en el mundo, como hermano de los campos. Se mantiene una
## ventana corta de descubrimiento para admitir campos de hierba que entren al
## árbol después del arranque; en la escena principal ambos ya existen antes.
var _vigilando := 90
## Cuantos campos se conectaron la ultima vez, solo para no repetir el aviso.
## Se comparan los CAMPOS y no los materiales, que es lo que dice el aviso.
var _conectado := -1


func _ready() -> void:
	_fase_a.resize(celdas * celdas)
	_fase_b.resize(celdas * celdas)
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	for i in celdas * celdas:
		_fase_a[i] = rng.randf() * TAU
		_fase_b[i] = rng.randf() * TAU
	_datos.resize(celdas * celdas * 4)
	_pintar()
	_textura = ImageTexture.create_from_image(_imagen)
	_conectar()


## Recorre el mapa y lo dibuja. Se llama a unos 10 por segundo.
func _pintar() -> Image:
	var lado := float(celdas)
	# El mapa empieza en la esquina del campo, no en el centro, y la hoja lo
	# lee con los mismos numeros.
	var mitad := lado_celda * lado * 0.5
	var centro := global_position
	var rumbo := _tiempo * giro_lento
	var dir_principal := Vector2(cos(rumbo), sin(rumbo))
	# La ola va en un rumbo un poco distinto al principal, para que se vea
	# cruzar el campo en vez de ir siempre en la misma linea.
	var ang_ola := rumbo + 0.7
	var dir_ola := Vector2(cos(ang_ola), sin(ang_ola))

	var d := _datos
	for j in lado:
		for i in lado:
			var k := (j * celdas + i) * 4
			# Cada celda tiene su propio vaiven.
			var v1 := sin(_tiempo * 0.31 + _fase_a[k / 4])
			var v2 := sin(_tiempo * 0.57 + _fase_b[k / 4])
			var ang := rumbo + v1 * 0.75
			var dir := Vector2(cos(ang), sin(ang))
			# La ola: una onda plana que se desplaza. El valor va de 0 a 1 y se
			# multiplica por la distancia a lo largo de la ola, no por la
			# distancia al centro, para que la cresta sea recta.
			var pos := Vector2(float(i) - lado * 0.5, float(j) - lado * 0.5) * lado_celda
			var ola := 0.5 + 0.5 * sin(pos.dot(dir_ola) * 0.075 - _tiempo * rapidez_ola)
			# Fuerza de la celda: un suelo, su vaiven y la ola por encima.
			var rel := 0.34 + 0.30 * v2 + 0.55 * ola
			rel = clampf(rel / 1.2, 0.0, 1.0)
			d[k + 0] = int((dir.x * 0.5 + 0.5) * 255.0)
			d[k + 1] = int((dir.y * 0.5 + 0.5) * 255.0)
			d[k + 2] = int(rel * 255.0)
			d[k + 3] = 255
	_imagen = Image.create_from_data(celdas, celdas, false, Image.FORMAT_RGBA8, d)
	return _imagen


## Busca la hierba del campo y le pasa el mapa y los numeros del mismo. Asi no
## hay que acordarse de ponerlos a mano en el inspector.
func _conectar() -> void:
	_hierba.clear()
	_mats.clear()
	for n in get_tree().get_nodes_in_group("hierba"):
		if n is Hierba:
			_hierba.append(n as Hierba)
	# El mapa del viento tiene que medir lo mismo que el campo mas ancho, porque
	# la hoja calcula su UV suponiendo eso. Si no, cada hoja busca su celda en el
	# sitio equivocado y el viento sale descuadrado.
	#
	# Con dos tipos de hierba esto ya no es "el radio del primer nodo que me
	# encuentro": es el MAYOR de todos. Asi el campo pequeño queda dentro del
	# mapa (busca su trozo, que es lo correcto) y el grande no se sale, que es lo
	# que hacia que la zarza se doblara con el ultimo borde del mapa.
	_radio_campo = 0.0
	for h in _hierba:
		var campo: float = h.radio
		_radio_campo = maxf(_radio_campo, campo)
	var cuarto := _radio_campo * 2.0 / float(maxi(celdas, 1))
	if _radio_campo > 0.0 and not is_equal_approx(cuarto, lado_celda):
		lado_celda = cuarto
		_pintar()
		if _textura != null:
			_textura.update(_imagen)
	for h in _hierba:
		var mat := h.material_compartido()
		if mat == null:
			continue
		mat.set_shader_parameter("viento", _textura)
		mat.set_shader_parameter("fuerza", fuerza)
		# Se guardan TODOS para meterles el tiempo en cada fotograma. Con el
		# campo partido en cuadrados, buscar el material es recorrer los hijos
		# del campo, y eso sesenta veces por segundo por gusto no.
		if not _mats.has(mat):
			_mats.append(mat)
	# El aviso solo sale cuando algo cambia de verdad. Con el rastreo de los
	# primeros fotogramas se reconecta varias veces seguidas, y sin esto el
	# arranque llenaba la consola de lineas iguales.
	if _hierba.size() != _conectado or not is_equal_approx(cuarto, lado_celda):
		_conectado = _hierba.size()
		print("Viento: mapa de %d x %d celdas de %.1f m, %d hojas conectadas"
			% [celdas, celdas, lado_celda, _hierba.size()])


func _process(delta: float) -> void:
	_tiempo += delta
	# Si un campo se añade dinámicamente al mundo, se vuelve a conectar durante
	# la ventana de descubrimiento. Los campos de main.tscn normalmente están
	# disponibles desde el primer fotograma.
	if _hierba.is_empty():
		_conectar()
		return
	# Si el radio de algun campo se ha movido en caliente, el mapa tiene que
	# cambiar de tamano con el. Antes el lado de la celda se calculaba una vez al
	# conectar y se quedaba para siempre, con lo que agrandar el campo en el
	# Inspector dejaba el viento corrido. Son dos o tres nodos, asi que mirarlo
	# cada fotograma no cuesta nada.
	var mayor := 0.0
	for h in _hierba:
		mayor = maxf(mayor, h.radio)
	if mayor > 0.0 and not is_equal_approx(mayor, _radio_campo):
		_conectar()
		return
	# Y los primeros fotogramas, por si aparece un campo mas tarde que los otros.
	if _vigilando > 0:
		_vigilando -= 1
		if get_tree().get_nodes_in_group("hierba").size() != _hierba.size():
			_conectar()
			return
	_acumulado += delta
	var paso := 1.0 / pasos_por_segundo
	if _acumulado >= paso:
		_acumulado = fmod(_acumulado, paso)
		_pintar()
		_textura.update(_imagen)
	# El tiempo va en el shader para el aleteo de cada hoja, que es distinto
	# del del viento de las zonas. Se usa la lista de materiales guardada al
	# conectar, y no uno nuevo cada fotograma: todos los cuadrados de un campo
	# comparten el mismo recurso, y con lo que hay uno por tipo de hierba.
	for mat in _mats:
		mat.set_shader_parameter("tiempo", _tiempo)

## Fuerza de una celda concreta, de 0 a 1. Para las pruebas: la media de todo
## el mapa casi no se mueve, porque unas celdas empujan hacia un lado y otras
## hacia el contrario, pero cada celda si cambia.
## Cuantos campos de hierba hay agora mismo conectados a este mapa. Lo preguntan
## las pruebas: con la hierba partida en varios tipos, si esto bajara de dos
## significaria que un campo se ha quedado sin viento.
func campos_conectados() -> int:
	return _hierba.size()


func fuerza_en(ix: int, iy: int) -> float:
	return _datos[(iy * celdas + ix) * 4 + 2] / 255.0



