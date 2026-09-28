class_name Zarza
extends Vegetacion

## Zarza como una maraña de cañas que se sostienen unas a otras.
##
## Antes de esto hubo dos formas de hacerlo y las dos dejaban la mecanica coja.
##
## La primera, un grafo de ramas con anclajes, resolvia bien una pregunta de
## fisica pero no daba juego: cortar una rama no producia ninguna consecuencia
## visible y no habia forma de saber si ibas bien.
##
## La segunda, un mapa de alturas ("cuanto queda en pie en cada celda"), se
## cortaba por capas y se leia bien, pero no tenia manera de saber QUE SOSTIENE
## A QUE. Con ella, cortar la base y cortar la copa eran la misma operacion con
## distinto numero, y no habia forma de que la parte de arriba siguiera en pie
## colgada de otra mata. Faltaba justo el anclaje.
##
## Ahora cada celda guarda tres cosas: cuanta vegetacion le queda, si hay CORONA
## (raiz, el anclaje al suelo) y a que vecinos se agarra. Cuando el cabezal corta
## su franja, una inundacion desde las coronas vivas marca que se sostiene cada
## celda, y **todo lo que no quede marcado cae**. De ahi salen las reglas sin
## escribir ninguna excepcion:
##
##   - Corte a la base de una mata: cae todo lo que solo se sostenia con ella.
##   - Corte en medio de una cana: cae el trozo que se perdia, y el resto sigue
##     en pie si tiene otro enganche con corona.
##   - Corte donde ya no hay nada: no pasa nada.
##   - La copa de un zarzal denso aguanta porque hay muchos enganches, y por eso
##     hay que dar varias pasadas. Un claro se tumba de una.
##
## Y el motivo de que haya que bajar el morro a la base es el de verdad: la raiz
## no muere nunca, de raiz vuelve a brotar cada ano. Arriba no se arregla nada.
## El unico trabajo real es llegar a la corona.
##
## La inundacion corre sobre arrays planos, en CPU, una vez por corte, asi que
## todo esto se puede probar en headless sin GPU.

const TIPO := 3
## Lado de la celda del mapa, en metros. pequeno para que el corte tenga detalle
## fino sin que el mapa se haga enorme.
const PASO := 0.25
## Altura a la que nace una columna. Por debajo de esto ya no se dibuja nada.
const MIN_ALTURA := 0.08
## Los cuatro vecinos, en el mismo orden que los bits de `_enganche`: bit 0 es
## +X, bit 1 es -X, bit 2 es +Z y bit 3 es -Z.
const DIRECCIONES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1)]

@export var semilla := 33031
## Ancho y fondo de la zona sembrada, en metros.
@export_range(1.0, 30.0, 0.5) var ancho := 6.0
@export_range(1.0, 30.0, 0.5) var fondo := 6.0
## Altura de la columna mas alta, en metros.
@export_range(0.5, 8.0, 0.1) var altura_maxima := 2.2
@export_range(0.0, 1.0, 0.01) var densidad := 0.72
@export_range(0.2, 4.0, 0.05) var dureza := 1.4
@export_range(0.0, 0.4, 0.01) var altura_tocon := 0.0
@export var dejar_tocon := true
## Cuantas coronas hay, o sea cuantas matas con raiz. Una sola es un zarzal que
## se tumba entero de una pasada; varias hacen que haya que ir una por una, que
## es el trabajo de verdad.
@export_range(1, 8, 1) var matas := 2
## Cuanto se engancha una celda a las que no la sostienen. Es el enredo: con
## mucho, la copa aguanta los cortes de uno en uno y hay que dar varias pasadas.
@export_range(0.0, 1.0, 0.01) var enredio := 0.45
## Marca en pantalla donde esta la corona y por donde van los enganches. Solo para
## la escena de pruebas, donde hay que poder ver que sostiene a que.
@export var marcar_anclajes := false
## Radio de la corona en celdas. Es donde las cañas nacen de verdad: un punto, no
## un area.
const RADIO_CORONA := 1.4

## Altura de vegetacion que le queda a cada celda, en metros. Es el estado real
## del juego: una celda con 0 ya no tiene nada que cortar.
var _alturas := PackedFloat32Array()
## Cuanto media cada celda cuando se sembro. El shader encoge la hoja con esta
## proporcion (INSTANCE_CUSTOM.x = cuanto le queda), y para que una columna de
## pie salga a su altura entera el divisor tiene que ser su propia altura de
## origen, no la del campo entero: con la del campo, una mata de 60 cm dentro de
## una zarza de 2 m salia a 18 cm y la zarza entera se veia como un tapete.
var _alturas_origen := PackedFloat32Array()
## Cuanto se ha cortado de cada celda, para el desgaste y el dibujo.
var _cortado := PackedFloat32Array()
## 1 si en esa celda hay corona: el anclaje al suelo del que sale todo.
var _coronas := PackedByteArray()
## 1 si la cana sigue entera. Es lo que separa "aqui no hay hoja" de "aqui el
## cabezal ha pasado": un hueco de follaje deja la cana en pie, y una cana
## cortada ya no sostiene a nadie aunque le quede un palmo de tallo.
var _cana := PackedByteArray()
## Mascara de los cuatro vecinos a los que se agarra esa celda, en el orden de
## `DIRECCIONES`.
var _enganche := PackedByteArray()
## Resultado de la ultima inundacion: 1 si esa celda se sostiene desde alguna
## corona. Las que valen 0 han caido y ya no tienen material en pie.
var _sostenida := PackedByteArray()
## Distancia de cada celda a la corona mas cercana, en celdas de `PASO`. Es el
## campo de flujo: cada celda se agarra a los vecinos que la acercan a una corona,
## que es como se construye una maraña sin escribir ningun camino a mano.
var _distancia_corona := PackedFloat32Array()
## Indices de las celdas que han caido en la ultima inundacion, con su altura.
var _caidas := PackedInt32Array()
var _alturas_caida := PackedFloat32Array()
## Donde se sembraron las matas, en metros sin el centrado de la malla.
var _puntos_corona: Array[Vector2] = []
## Las celdas de cada corona, para poder contar matas y no celdas: una corona son
## unas diez celdas, y decir "quedan 5 raices" cuando hay una sola mata seria
## mentira en el panel de la escena de pruebas.
var _celdas_de_corona: Array[PackedInt32Array] = []
var _lado := 0
var _filas := 0

var _montones: Montes
var _malla: MultiMeshInstance3D
var _marcadores: MultiMeshInstance3D
var _material: ShaderMaterial
## Cuantas hojas hay por celda. Son matas de varias hojas, no un bloque solido.
const HOJAS_POR_CELDA := 3
const ANCHO_HOJA := 0.13


func _ready() -> void:
	add_to_group("vegetacion")
	add_to_group("zarzas")
	_generar()
	_montones = Montes.obtener(get_tree())
	_crear_malla()
	_dibujar()
	if marcar_anclajes:
		_crear_marcadores()


## Reparte la altura por la zona. No es una mata de tres tallos: es un campo con
## varias lomas, para que haya partes altas y partes bajas mezcladas y haya
## que trabajar a distintos niveles en el mismo recorrido.
func _generar() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	_lado = maxi(1, int(round(ancho / PASO)))
	_filas = maxi(1, int(round(fondo / PASO)))
	var total := _lado * _filas
	_alturas.resize(total)
	_alturas_origen.resize(total)
	_cortado.resize(total)
	_coronas.resize(total)
	_cana.resize(total)
	_enganche.resize(total)
	_sostenida.resize(total)
	_distancia_corona.resize(total)
	# Tres o cuatro lomas dentro de la zona, mas o menos solapadas. Cada loma sube
	# desde el suelo hasta su altura y las intersecciones dan los puntos altos.
	var lomas: Array[Dictionary] = []
	var cuantos := rng.randi_range(3, 4)
	for _n in cuantos:
		lomas.append({
			"x": rng.randf_range(0.15, 0.85) * ancho,
			"z": rng.randf_range(0.15, 0.85) * fondo,
			"r": rng.randf_range(0.2, 0.45) * minf(ancho, fondo),
			"h": rng.randf_range(0.35, 1.0) * altura_maxima,
		})
	# Las coronas van donde la mata es mas alta, que es donde nace de verdad el
	# grosor de un zarzal. Sembrarlas en un punto a ciegas (el centro, por
	# ejemplo) era fallar de antemano: si ahi no cae loma no hay cañas y la
	# corona se queda sin marcar, y una zarza sin coronas no se puede tumbar.
	var base := PackedFloat32Array()
	base.resize(total)
	for j in _filas:
		for i in _lado:
			var p := Vector2((float(i) + 0.5) * PASO, (float(j) + 0.5) * PASO)
			var altura := 0.0
			for loma in lomas:
				var d := p.distance_to(Vector2(loma["x"], loma["z"]))
				var r: float = loma["r"]
				if d < r:
					# Sube hacia el centro de la loma, no con un borde duro, para
					# que el terreno de la zarza tenga relieve y no escalones.
					altura = maxf(altura, float(loma["h"]) * (1.0 - d / r))
			base[j * _lado + i] = altura
	# Las coronas se siembran antes que el follaje, porque el resto de la maraña
	# se cuelga de ellas. Con una sola se deja donde este la mata mas alta: es un
	# zarzal de una mata y se tumba entero de una pasada. Con varias se reparten,
	# para que el jugador tenga que ir a por cada una.
	var coronas := _sembrar_coronas(base)
	_puntos_corona = coronas
	for j in _filas:
		for i in _lado:
			var indice := j * _lado + i
			var mejor := 1.0e9
			for corona in coronas:
				mejor = minf(mejor, _distancia_a_corona(Vector2i(i, j), corona))
			_distancia_corona[indice] = mejor
	for j in _filas:
		for i in _lado:
			var indice := j * _lado + i
			var altura := base[indice]
			# Donde hay loma hay cana, haya follaje o no: la estructura se siembra
			# entera y lo que `densidad` aclara es la hoja, no el tallo. Antes al
			# reves, densidad abria huecos, y cada hueco partia en dos la maraña y
			# se perdia por el camino un tercio de la zarza sin haberla tocado.
			_cana[indice] = 1 if altura > 0.02 else 0
			# Ruido de borde, para que las hojas no caigan en una circunferencia
			# perfecta y se note que es vegetacion y no un circulo.
			altura *= rng.randf_range(0.75, 1.0)
			if rng.randf() > densidad:
				# Sin hoja esta mas bajo, pero el tallo sigue ahi. Un hueco de
				# follaje no es un hueco de cañas: por debajo se ve el hueco.
				altura *= 0.22
			_alturas[indice] = maxf(altura, 0.0)
			_alturas_origen[indice] = maxf(altura, 0.0)
			_cortado[indice] = 0.0
			_coronas[indice] = 0
	# Las coronas se marcan al final, sobre las celdas que ya tienen material: una
	# corona sin cañas encima no seria una mata, seria un tocón.
	for n in coronas.size():
		var corona := coronas[n]
		var celdas := PackedInt32Array()
		for j in _filas:
			for i in _lado:
				var indice := j * _lado + i
				if _alturas[indice] <= MIN_ALTURA:
					continue
				if _distancia_a_corona(Vector2i(i, j), corona) <= RADIO_CORONA:
					_coronas[indice] = 1
					celdas.append(indice)
		_celdas_de_corona.append(celdas)
	_calar_enganches(rng)
	_recalcular_apoyo()


## Donde nacen las matas. Se eligen las celdas mas altas del terreno, con una
## separacion entre ellas, y se devuelven en metros en el sistema de la zarza.
## Los puntos mas altos son donde un zarzal es de verdad mas grueso, y ademas
## asi la corona cae siempre sobre cañas de verdad y no sobre un hueco.
func _sembrar_coronas(base: PackedFloat32Array) -> Array[Vector2]:
	var puntos: Array[Vector2] = []
	var separacion := minf(ancho, fondo) / float(maxi(matas, 1))
	var usadas := {}
	# Se prueban celdas de la mas alta a la mas baja hasta llenar el numero de
	# matas. El tope de intentos es para que una zona que no da para tantas
	# coronas termine en vez de quedarse buscando forever.
	var pedidos := maxi(matas, 1)
	var intentos := 0
	var limite := _lado * _filas
	while puntos.size() < pedidos and intentos < limite:
		intentos += 1
		var elegido := -1
		var mejor := 0.05
		for indice in base.size():
			if usadas.has(indice) or base[indice] <= mejor:
				continue
			mejor = base[indice]
			elegido = indice
		if elegido < 0:
			break
		usadas[elegido] = true
		var p := Vector2((float(elegido % _lado) + 0.5) * PASO,
			(float(elegido / _lado) + 0.5) * PASO)
		# Dos coronas pegadas son una sola mata grande, y ademas no se podria ver
		# en las pruebas cual sostiene a cual.
		var lejos := true
		for otra in puntos:
			if p.distance_to(otra) < separacion:
				lejos = false
				break
		if lejos:
			puntos.append(p)
	return puntos


func _distancia_a_corona(celda: Vector2i, corona: Vector2) -> float:
	var p := Vector2((float(celda.x) + 0.5) * PASO, (float(celda.y) + 0.5) * PASO)
	return p.distance_to(corona) / PASO


## Monta los enganches. Cada celda se agarra a los vecinos que la acercan a una
## corona, que es como se sostiene de verdad: la cana nace de la raiz, se curva y
## se apoya en lo que tiene al lado de camino a la raiz siguiente.
##
## Con `enredio` alto se engancha ademas a las que NO la sostienen. Eso es una
## cana que pasa por encima de otra sin tocarla, y es lo que hace que la copa de
## un zarzal denso aguante: hay lineas de carga cruzadas y por eso hay que dar
## varias pasadas.
func _calar_enganches(rng: RandomNumberGenerator) -> void:
	for j in _filas:
		for i in _lado:
			var indice := j * _lado + i
			_enganche[indice] = 0
			if _cana[indice] == 0:
				continue
			var propia := _distancia_corona[indice]
			for d in DIRECCIONES.size():
				var n := Vector2i(i, j) + DIRECCIONES[d]
				if not _dentro(n):
					continue
				var nindice := n.y * _lado + n.x
				if _cana[nindice] == 0:
					continue
				var del_vecino := _distancia_corona[nindice]
				if del_vecino < propia:
					_enganche[indice] |= 1 << d
				elif is_equal_approx(del_vecino, propia) and rng.randf() < enredio:
					_enganche[indice] |= 1 << d
			# Una celda que no se agarra a nada no tiene de donde sostenerse, y se
			# caeria sola en la primera inundacion, quitando vegetacion que el
			# jugador no ha tocado. En una maraña real seria una cana suelta
			# apoyada de lado en otra; aqui se engancha al vecino con mas raiz
			# debajo, que es el apoyo mas sensato que se le puede dar.
			if _enganche[indice] == 0:
				var mejor := -1
				var mejor_distancia := 1.0e9
				for d in DIRECCIONES.size():
					var n := Vector2i(i, j) + DIRECCIONES[d]
					if not _dentro(n):
						continue
					var nindice := n.y * _lado + n.x
					if _cana[nindice] == 0:
						continue
					if _distancia_corona[nindice] < mejor_distancia:
						mejor_distancia = _distancia_corona[nindice]
						mejor = d
				if mejor >= 0:
					_enganche[indice] = 1 << mejor


func _dentro(celda: Vector2i) -> bool:
	return celda.x >= 0 and celda.x < _lado and celda.y >= 0 and celda.y < _filas


## Dibuja la zarza con el mismo shader que la hierba, que ya sabe encoger la hoja
## con el_custom.x y le pone el viento. Se reaprovecha en vez de escribir otro
## shader: si se rompe el contrato de INSTANCE_CUSTOM, se rompe en los dos sitios.
func _crear_malla() -> void:
	var hoja := _hoja()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = hoja
	mm.use_custom_data = true
	mm.instance_count = _instancias_totales()
	_malla = MultiMeshInstance3D.new()
	_malla.name = "Zarza"
	_malla.multimesh = mm
	# Solo se pondrian los dos colores: el resto de parametros (viento, tiempo,
	# fuerza) los asigna Viento por el grupo, igual que a la hierba.
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/hierba.gdshader")
	mat.set_shader_parameter("color_pie", Color(0.10, 0.20, 0.06))
	mat.set_shader_parameter("color_punta", Color(0.22, 0.34, 0.09))
	mat.set_shader_parameter("fuerza", 0.18)
	_malla.material_override = mat
	add_child(_malla)
	add_to_group("hierba")
	_material = mat
	_fijar_volumen()


## Cuantas instancias tiene el MultiMesh: tres hojas por celda, celdas todas.
## Se cuentan todas y no solo las que estan en pie, porque las muertas se
## esconden con una escala de milimasima en vez de quitarse (ver `_dibujar`).
func _instancias_totales() -> int:
	return maxi(1, _lado * _filas * HOJAS_POR_CELDA)


## Coloca una hoja por celda viva. La hoja se estira hasta la altura que le queda
## y se encoge al cortarla, que es lo que hace que se vea desaparecer la zarza
## a medida que pasa la maquina.
##
## OJO con `instance_count`: se pone UNA vez, antes del bucle, y ya no se toca
## dentro. Cada vez que se cambia, Godot rehace el buffer del MultiMesh y borra
## las transformadas y los datos que hubiera escritos, asi que subirlo de uno en
## uno mientras se rellena deja la zarza con una sola hoja en pie, la ultima, y
## las demas en el origen: se sembraba bien, no habia ningun error, y en pantalla
## no se veia nada. La hierba tiene el mismo mounts de instancias y lo hace bien
## (ver `_crear_cuadrante` en `scripts/hierba.gd`).
func _dibujar() -> void:
	if _malla == null:
		return
	var mm := _malla.multimesh
	mm.instance_count = _instancias_totales()
	var instancias := 0
	for j in _filas:
		for i in _lado:
			var indice := j * _lado + i
			var altura := _alturas[indice]
			var viva := altura > MIN_ALTURA
			for h in HOJAS_POR_CELDA:
				var p := Vector2((float(i) + 0.5) * PASO - ancho * 0.5,
					(float(j) + 0.5) * PASO - fondo * 0.5)
				# Las hojas de una celda se reparten un poco alrededor, para que la
				# zarza tenga grosor y no se lea como un campo de postes.
				var desplazamiento := Vector3(
					cos(float(h) * 2.1 + float(i)) * ANCHO_HOJA * 0.7,
					0.0,
					sin(float(h) * 1.7 + float(j)) * ANCHO_HOJA * 0.7)
				var escala := 1.0
				var alto := altura
				if not viva:
					# Celda vacia: se esconde en vez de quitar la instancia, para no
					# tener que recounts el MultiMesh entero en cada corte.
					escala = 0.0
					alto = 0.0
				mm.set_instance_transform(instancias, Transform3D(
					Basis().scaled(Vector3(ANCHO_HOJA, maxf(alto, 0.001),
						ANCHO_HOJA) * (escala if escala > 0.0 else 0.001)),
					Vector3(p.x, 0.0, p.y) + desplazamiento))
				# r = proporcion de altura que le queda a la celda, sobre lo que
				# media cuando se sembro. En vez de 1 o 0 se manda el alto real
				# dividido por el suyo, asi el shader deja un tocon proporcional y
				# se nota que la cosa esta a medio quitar.
				var proporcion := clampf(
					alto / maxf(_alturas_origen[indice], 0.001), 0.0, 1.0)
				mm.set_instance_custom_data(instancias, Color(proporcion,
					float(i) / float(_lado), float(j) / float(_filas),
					randf() * 0.2 + 0.4))
				instancias += 1
	# Por si el MultiMesh venia de otra siembra mas corta: las que sobren se
	# encogen en vez de quitarse, para no volver a tocar `instance_count`.
	for k in range(instancias, mm.instance_count):
		mm.set_instance_transform(k, Transform3D(Basis().scaled(
			Vector3(0.001, 0.001, 0.001)), Vector3.ZERO))


## Volumen que ocupa la zarza. Sin esto, Godot no sabe cuanto ocupa un MultiMesh
## lleno de hojas sueltas y puede recortarlo entero: la zarza se sembraba bien y
## no se veia nada en pantalla. La hierba hace lo mismo por cuadrante.
func _fijar_volumen() -> void:
	var caja := AABB(
		Vector3(-ancho * 0.5, 0.0, -fondo * 0.5),
		Vector3(ancho, altura_maxima + 0.3, fondo))
	_malla.custom_aabb = caja


## Material de referencia, solo para la escena de pruebas: una caja roja donde
## hay corona y una raya blanca por cada enganche. Es lo unico que deja ver que
## sostiene a que sin tener que tumbar medio zarzal para averiguarlo.
func _crear_marcadores() -> void:
	var caja := BoxMesh.new()
	caja.size = Vector3(1.0, 1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = caja
	mm.use_colors = true
	mm.instance_count = 0
	_marcadores = MultiMeshInstance3D.new()
	_marcadores.name = "Anclajes"
	_marcadores.multimesh = mm
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marcadores.material_override = material
	add_child(_marcadores)
	_dibujar_marcadores()


func _dibujar_marcadores() -> void:
	if _marcadores == null:
		return
	var total := 0
	for j in _filas:
		for i in _lado:
			var indice := j * _lado + i
			if _coronas[indice] == 1:
				total += 1
			for d in DIRECCIONES.size():
				if (_enganche[indice] & (1 << d)) != 0:
					total += 1
	if total == 0:
		return
	var mm := _marcadores.multimesh
	mm.instance_count = total
	var n := 0
	for j in _filas:
		for i in _lado:
			var indice := j * _lado + i
			var p := _centro_de_celda(indice)
			if _coronas[indice] == 1:
				mm.set_instance_transform(n, Transform3D(Basis().scaled(
					Vector3(PASO * 0.7, 0.10, PASO * 0.7)),
					Vector3(p.x, 0.04, p.y)))
				mm.set_instance_color(n, Color(0.9, 0.15, 0.1, 0.85))
				n += 1
			for d in DIRECCIONES.size():
				if (_enganche[indice] & (1 << d)) == 0:
					continue
				var largo := PASO * 0.5
				var dir := Vector2(float(DIRECCIONES[d].x), float(DIRECCIONES[d].y))
				# La raya va desde el centro de la celda hacia el vecino, y la caja
				# es larga en su eje Z, asi que se gira para que ese Z apunte ahi.
				var centro := Vector3(p.x + dir.x * largo * 0.5, 0.10,
					p.y + dir.y * largo * 0.5).rotated(Vector3.UP,
						atan2(dir.x, dir.y))
				mm.set_instance_transform(n, Transform3D(
					Basis().scaled(Vector3(0.03, 0.03, largo)), centro))
				mm.set_instance_color(n, Color(0.95, 0.95, 0.4, 0.8))
				n += 1


## El material de la zarza, para que Viento le pase el mapa del viento igual que
## a la hierba. Viento recorre el grupo "hierba", asi que la zarza se apunta ahi.
func material_compartido() -> ShaderMaterial:
	return _material


## Hoja triangulada, la misma forma que usa la hierba.
func _hoja() -> ArrayMesh:
	var t := SurfaceTool.new()
	t.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tramos := 3
	for i in tramos + 1:
		var u := float(i) / float(tramos)
		var ancho := (1.0 - u * 0.88) * 0.5
		var curva := u * u * 0.09
		var giro := deg_to_rad(12.0) * u
		var dx := cos(giro) * ancho
		var dz := sin(giro) * ancho
		t.set_normal(Vector3(0.0, 0.0, 1.0))
		t.set_uv(Vector2(0.0, u))
		t.add_vertex(Vector3(-dx, u, curva - dz))
		t.set_normal(Vector3(0.0, 0.0, 1.0))
		t.set_uv(Vector2(1.0, u))
		t.add_vertex(Vector3(dx, u, curva + dz))
	for i in tramos:
		var a := i * 2
		t.add_index(a)
		t.add_index(a + 1)
		t.add_index(a + 2)
		t.add_index(a)
		t.add_index(a + 2)
		t.add_index(a + 3)
	return t.commit()


## La zarza la corta quien tenga una herramienta que valga. Se busca en el grupo
## "herramienta" en cada fotograma y no se guarda, porque el grupo solo lo tiene
## la que va en la mano: al cambiar de herramienta en el inventario, con la
## referencia guardada la zarza seguiria mirando por la desbrozadora aunque
## lleves la hoz delante.
func _physics_process(_delta: float) -> void:
	var herramienta := get_tree().get_first_node_in_group("herramienta")
	if herramienta == null or not herramienta.has_method("cabezal_puede_cortar"):
		return
	if herramienta.cortando and herramienta.cabezal_puede_cortar(TIPO):
		var centro: Vector3 = herramienta.punto_de_corte()
		var cortadas := cortar_en(centro, herramienta.radio_corte_actual())
		if cortadas > 0:
			herramienta.registrar_corte(TIPO, cortadas, dureza)


## Marca que celda se sostiene desde alguna corona y devuelve cuantas han caido.
## Los indices de las caidas quedan en `_caidas`, con su altura en `_alturas_caida`,
## porque en cuanto una celda cae su altura es cero y si se recogeran despues no
## habria manera de saber ni cuales son ni cuanto material era.
##
## Es una inundacion desde las coronas: empiezan por si mismas todas las que
## siguen having material, y de ahi se propaga a las vecinas que se agarran a
## ellas. Lo que no aparece es material colgando de la nada, y cae.
##
## El recorrido es una pila sobre un array plano, sin objetos por celda ni
## llamadas recursivas: son dos mil celdas y esto se llama en cada corte, con la
## particula de fisica corriendo, asi que tiene que ser barato de verdad.
func _recalcular_apoyo() -> int:
	var total := _lado * _filas
	_caidas.clear()
	_alturas_caida.clear()
	for indice in total:
		_sostenida[indice] = 0
	var pila := PackedInt32Array()
	for indice in total:
		# La corona sigue viva mientras su cana siga en pie. Un tocon de diez
		# centimetros es una raiz, y de raiz vuelve a brotar: por eso cortar a la
		# altura de la cintura no sirve de nada.
		if _coronas[indice] == 1 and _cana[indice] == 1:
			_sostenida[indice] = 1
			pila.append(indice)
	var leidas := 0
	while leidas < pila.size():
		var indice := pila[leidas]
		leidas += 1
		var celda := Vector2i(indice % _lado, indice / _lado)
		for d in DIRECCIONES.size():
			var n := celda + DIRECCIONES[d]
			if not _dentro(n):
				continue
			var nindice := n.y * _lado + n.x
			# Una celda sin cana no sostiene nada, ni aunque encima tenga hoja:
			# o no hay tallo, o el cabezal ya paso por ahi.
			if _sostenida[nindice] == 1 or _cana[nindice] == 0:
				continue
			# La celda que llega aqui esta sosteniendose con esta. Pregunta a la
			# vecina si se agarra a EL, mirando su bit en la direccion contraria:
			# el enganche va en un solo sentido, y el de la vecina es el que
			# decide si la de aqui se sostiene. Al reves es otra cana distinta.
			if (_enganche[nindice] & (1 << _opuesto(d))) == 0:
				continue
			_sostenida[nindice] = 1
			pila.append(nindice)
	for indice in total:
		if _alturas[indice] > MIN_ALTURA and _sostenida[indice] == 0:
			_caidas.append(indice)
			_alturas_caida.append(_alturas[indice])
			_alturas[indice] = 0.0
			_cana[indice] = 0
	return _caidas.size()


## El bit de la direccion contraria. Con DIRECCIONES en orden +X, -X, +Z, -Z, el
## contrario de cada uno es el del otro signo del mismo eje.
func _opuesto(d: int) -> int:
	return d ^ 1


## Cuantas matas siguen con raiz en pie. Es el trabajo que falta: mientras quede
## una, la zarza vuelve. Una corona cuenta como viva si le queda una sola celda
## celda de cana en pie, porque un tocon de diez centimetros sigue siendo una raiz.
func coronas_en_pie() -> int:
	var total := 0
	for celdas in _celdas_de_corona:
		for indice in celdas:
			if _cana[indice] == 1:
				total += 1
				break
	return total


## Cuantas coronas se sembraron, para saber cuantas quedan. Para el panel.
func coronas_totales() -> int:
	return _puntos_corona.size()


## Corta la franja que barre el cabezal. Todo lo que asome por encima de la
## altura del cabezal queda seccionado, que es lo que hace una cuchilla girando:
## corta a su altura y todo lo de encima se queda sin apoyo. Por debajo no se toca
## nada, y por eso una pasada alta abre paso y una pasada a ras de suelo es la
## unica que llega a la raiz.
##
## Despues recalcula el apoyo, y lo que se caia por perderlo cae aunque el
## cabezal no lo haya tocado. Devuelve cuantas celdas han perdido vegetacion,
## contando las que tumbaron por perder el apoyo, que es lo que de verdad nota
## el jugador.
func cortar_en(centro_mundo: Vector3, radio: float) -> int:
	if radio <= 0.0:
		return 0
	var centro := to_local(centro_mundo)
	var radio2 := radio * radio
	var cortadas := 0
	# Se acumulan las celdas que pierden material y se sueltan de golpe al final.
	# Una caida de verdad son cientos de celdas, y llamar a los montones una por
	# una haria que se redibujase la pila entera cientos de veces en el mismo
	# fotograma.
	var puntos := PackedVector3Array()
	var cantidades := PackedFloat32Array()
	for j in _filas:
		for i in _lado:
			var p := Vector2((float(i) + 0.5) * PASO - ancho * 0.5,
				(float(j) + 0.5) * PASO - fondo * 0.5)
			var dx := p.x - centro.x
			var dz := p.y - centro.z
			if dx * dx + dz * dz > radio2:
				continue
			var indice := j * _lado + i
			var actual := _alturas[indice]
			if actual <= centro.y or actual <= MIN_ALTURA:
				continue
			var queda := centro.y
			if dejar_tocon:
				# El tocon es el palmo que se deja de tallo. Es util para dejar
				# cañas de fruitero, y es la trampa clasica: un tocon con vida
				# sigue siendo una raiz, y de raiz vuelve a brotar.
				queda = maxf(queda, altura_tocon)
			if queda >= actual:
				continue
			_cortado[indice] += actual - queda
			_alturas[indice] = queda
			# El tallo se da por cortado cuando no queda practically nada. Un
			# tocon de diez centimetros todavia aguanta la cana que se apoya ahi,
			# y es justo lo que hace que haya que bajar a rematar despues.
			if queda <= MIN_ALTURA:
				_cana[indice] = 0
			cortadas += 1
			puntos.append(Vector3(p.x, queda, p.y))
			cantidades.append(actual - queda)
	if cortadas == 0:
		return 0
	# Y ahora lo importante: lo que se cortaba quizas no era lo unico que se
	# sostenia con esa franja. Recalcular el apoyo decide que mas cae por debajo.
	var caidas := _recalcular_apoyo()
	for n in _caidas.size():
		var p := _centro_de_celda(_caidas[n])
		puntos.append(Vector3(p.x, 0.0, p.y))
		cantidades.append(_alturas_caida[n])
	_soltar_caida(puntos, cantidades)
	_dibujar()
	if _marcadores != null:
		_dibujar_marcadores()
	return cortadas + caidas


## Donde estan las coronas, una por mata y en el mismo sistema que las celdas.
## Para las pruebas y para el interfaz: es lo unico que hay que atacar, y hay que
## saber donde esta sin buscarlo a ojo.
func posiciones_de_coronas() -> Array[Vector2]:
	var puntos: Array[Vector2] = []
	for corona in _puntos_corona:
		puntos.append(corona - Vector2(ancho * 0.5, fondo * 0.5))
	return puntos


## El centro de una celda, en el sistema de la zarza.
func _centro_de_celda(indice: int) -> Vector2:
	var i := indice % _lado
	var j := indice / _lado
	return Vector2((float(i) + 0.5) * PASO - ancho * 0.5,
		(float(j) + 0.5) * PASO - fondo * 0.5)


## Lo que cae va al suelo como monton, que es lo que tapa despues y obliga a
## rodear. Los trozos finos salen como particulas.
func _soltar_caida(puntos: PackedVector3Array, cantidades: PackedFloat32Array) -> void:
	if puntos.is_empty():
		return
	if _montones != null:
		var mundo := PackedVector3Array()
		mundo.resize(puntos.size())
		for n in puntos.size():
			mundo[n] = to_global(puntos[n])
		_montones.aportar_varios(mundo, cantidades)
	var restos := Restos.obtener(get_tree())
	for n in puntos.size():
		var cantidad: float = cantidades[n]
		if cantidad < 0.05:
			continue
		restos.soltar(to_global(puntos[n]), clampi(int(round(cantidad * 2.0)), 1, 6),
			Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6)),
			Color(0.15, 0.26, 0.08), 1.3)


## Cuanta vegetacion queda en pie en total, en metros. Para las pruebas.
func altura_total() -> float:
	var total := 0.0
	for h in _alturas:
		total += h
	return total


## Celdas con algo de vegetacion en pie.
func columnas_en_pie() -> int:
	var total := 0
	for h in _alturas:
		if h > MIN_ALTURA:
			total += 1
	return total


## Celdas que ya no tienen nada. Para las pruebas.
func columnas_limpias() -> int:
	return _alturas.size() - columnas_en_pie()


## Cuanto queda por encima de una altura, en celdas. Sirve para comprobar que el
## corte quita la parte de arriba y respeta el tocón de abajo.
func columnas_sobre(altura: float) -> int:
	var total := 0
	for h in _alturas:
		if h > altura + MIN_ALTURA:
			total += 1
	return total


## La zarza es el tipo 3. Una hoz no entra aqui, y con razon: el filo de una
## hoz no arranca una mata en pie.
func tipo_vegetacion() -> int:
	return TIPO


## La puerta de entrada del contrato comun. Para la zarza, cortar por banda es
## exactamente lo que ya hacia el cabezal: la franja que barre, y despues lo que
## se caiga por perder el apoyo.
func cortar_por_banda(centro_mundo: Vector3, radio: float) -> int:
	return cortar_en(centro_mundo, radio)


func densidad_bajo(centro_mundo: Vector3, radio: float) -> float:
	if radio <= 0.0:
		return 0.0
	var centro := to_local(centro_mundo)
	var radio2 := radio * radio
	var peso := 0.0
	for j in _filas:
		for i in _lado:
			var p := Vector2((float(i) + 0.5) * PASO - ancho * 0.5,
				(float(j) + 0.5) * PASO - fondo * 0.5)
			var dx := p.x - centro.x
			var dz := p.y - centro.z
			if dx * dx + dz * dz > radio2:
				continue
			peso += _alturas[j * _lado + i]
	return peso / maxf(PI * radio2, 0.0001)


func coste_maleza() -> float:
	return dureza
