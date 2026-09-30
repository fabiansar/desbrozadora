class_name Restos
extends Node3D

## Restos de vegetacion cortada: **particulas, sin fisica**, con modelos de
## verdad.
##
## Al cortar no se conserva la forma de la planta: salen rafagas de trozos que
## vuelan, caen y se apagan solos. Los trozos ya no son una cinta construida a
## codigo con SurfaceTool: son ocho modelos low poly de `models/restos.glb`
## (los genera y los mide `tools/crear_restos.py`), repartidos en tres familias
## que se piden con el tipo de planta:
##
##     cesped (tipo 1)  HojaCesped1..3   laminas de 8-16 cm
##     maleza (tipo 2)  TalloMaleza1..2  tallos de 12-24 cm
##     zarza  (tipo 3)  CanaZarza1..3    canas de 10-20 cm, corte aplastado
##
## Cada emisor del pool lleva UNA pieza (la malla de una particula no se puede
## cambiar por particula sin shader custom), y la variedad sale por dos sitios:
## cada rafaga reparte sus trozos entre `piezas_por_rafaga` emisores, y a cada
## uno le toca una pieza AL AZAR de la familia. Asi un corte de zarza mezcla
## canas distintas en la misma nube, que es lo que evita el aire de copia.
##
## ## Un solo sitio para ajustar el escombro
##
## TODO lo tuneable esta aqui, con @export y @export_range, y se lee **en cada
## rafaga**: se puede tocar en caliente desde el arbol Remote con el juego en
## marcha. El sistema viejo repartia los numeros entre `hierba.gd` y
## `restos.gd`, mezclaba const con exports que solo se leian en `_ready()` y
## escondia un multiplicador en el codigo de corte; aqui no hay nada de eso.
## `hierba.gd` solo llama a `soltar()` con las hojas que ha cortado.
##
## ## Coherencia del pool (la cuenta, hecha)
##
## Cada rafaga ocupa `piezas_por_rafaga` emisores durante `vida` segundos, asi
## que el pool sostiene como mucho:
##
##     rafagas_por_segundo = emisores / (piezas_por_rafaga * vida)
##
## Con los valores por defecto (48, 3 y 2,0 s) son **8 rafagas por segundo**. El
## corte, con `densidad` 2 y unas 50 hojas por segundo, pide unos 100 trozos por
## segundo, o sea una rafaga cada ~10 trozos: el pool va justo y las rafagas mas
## viejas se recortan un poco a media caida, que es justo lo que mantiene el
## chorro continuo sin que se acumule nada.
##
## Para MAS escombro, por orden y sin romper el ritmo:
##
##   1. `densidad` — mas trozos por hoja. No toca el pool: mas material con el
##      mismo ritmo de rafagas.
##   2. `piezas_min_rafaga` — menos trozos por rafaga: rafagas mas gordas y
##      menos veces. Por debajo de 6 el chorro se parte en motas.
##   3. `vida` — mas tiempo en el aire. Sube las rafagas vivas a la vez: si se
##      toca, tocar tambien `emisores` con la cuenta de arriba.
##   4. `emisores` — mas pool. Es el techo real: si `rafagas_por_segundo` se
##      queda corto, lo que se ve NO es "menos escombro", es una rafaga que se
##      corta a media caida y el vuelo se nota raro.
##
## ## Por que CPUParticles3D y no GPU
##
## El color va con la planta cortada y se pide **por rafaga**: en CPU es una
## propiedad del nodo, y ademas todo el sistema se puede medir en headless (los
## contadores de `recuento()` son de CPU y no dependen de que haya render). En
## GPU haria falta un material con atributos custom duplicado por emisor y no
## habria manera de comprobarlo sin pantalla.

## Ruta del modelo de las piezas. Lo genera `tools/crear_restos.py`.
const RUTA_PIEZAS := "res://models/restos.glb"
## Prefijos de nombre de las piezas de cada familia, tal y como salen del .glb.
const PREFIJOS := {1: "hojacesped", 2: "tallomaleza", 3: "canazarza"}

@export_group("Rafagas")
## Cuantos emisores tiene el pool. Es el TECHO de rafagas simultaneas: con la
## cuenta del encabezado, 48 emisores y 3 por rafaga aguantan 8 rafagas por
## segundo con vida 2. Subirlo da mas margen (y mas nodos); bajarlo recorta
## rafagas viejas antes de tiempo.
@export_range(6, 96, 1) var emisores := 48
## Cuantos emisores se reparten cada rafaga. Con 1, la rafaga entera sale con
## la MISMA pieza y se nota copiada; con 3 o 4 salen canas distintas mezcladas.
@export_range(1, 6, 1) var piezas_por_rafaga := 3
## Trozos acumulados que hacen falta para disparar una rafaga. Mas bajo, chorro
## mas continuo y a motas; mas alto, rafagas mas gordas y menos veces.
@export_range(1, 48, 1) var piezas_min_rafaga := 10
## Techo de trozos por rafaga (por corte). Es el tope duro de una sola nube:
## por encima de 24 el monton se ve como una explosion, no como escombro.
@export_range(1, 48, 1) var max_por_rafaga := 24
## Segundos de espera para tirar lo que quede suelto cuando el corte es lento
## (nylon contra zarza: un bulto cada mas de un minuto). Sin esto, los ultimos
## trozos de una pasada corta se quedarian acumulados para siempre.
@export_range(0.1, 2.0, 0.05) var espera_max := 0.6
## Trozos por hoja cortada. Es el mando del "mucho mas escombro": subirlo llena
## sin tocar el ritmo del pool; con 2 cada hoja deja dos trozos, y con 4 el
## suelo se ve desaparecer bajo el material.
@export_range(0.0, 6.0, 0.1) var densidad := 2.0

@export_group("Vuelo")
## Cuanto vive un trozo desde que sale, en segundos. Corto a proposito: la
## rafaga tiene que verse nacer, caer y apagarse; si dura, se nota que nada se
## retira del suelo. OJO: subirlo sube las rafagas vivas (ver la cuenta).
@export_range(0.5, 5.0, 0.05) var vida := 2.0
## Velocidad horizontal al salir despedida la rafaga, en metros por segundo.
## Un salto corto y seco, de hoja, no de piedra.
@export_range(0.0, 3.0, 0.05) var velocidad_saltar := 0.7
## Cuanto se levanta el chorro al nacer, en metros por segundo. Junto con la
## anterior forma el angulo del disparo: el eje de la rafaga es la suma.
@export_range(0.0, 1.5, 0.05) var alza := 0.4
## Caida, en metros por segundo al cuadrado, MAS SUAVE que la real. Una hoja no
## cae como una piedra: el aire la frena, y aqui eso lo hacen este numero y el
## amortiguamiento. Con 20 caen como tornillos.
@export_range(0.0, 20.0, 0.5) var gravedad := 7.0
## Amortiguamiento del aire, de menos a mas frenazo. Con valores altos las
## hojas se quedan flotando y bajan como en camara lenta.
@export_range(0.0, 4.0, 0.05) var amortiguacion_min := 0.9
@export_range(0.0, 4.0, 0.05) var amortiguacion_max := 1.6
## Tamano de los trozos, de menor a mayor, multiplicando el tamano del modelo.
## La variacion de un 55 % a un 135 % mete finos y gruesos en la misma rafaga;
## con los dos iguales, el escombro se ve fabricado.
@export_range(0.05, 2.0, 0.05) var tamano_min := 0.55
@export_range(0.05, 2.0, 0.05) var tamano_max := 1.35
## Dispersor del cono de salida, en grados. Estrecho parece un canon; ancho
## parece una explosion. Setenta y tantos es "saltan cada uno por su lado".
@export_range(0.0, 180.0, 5.0) var dispersion := 70.0
## Giro inicial de cada trozo, en grados, para cada lado. Orientacion libre:
## con todo recto el escombro parece confeti cayendo en paracaidas.
@export_range(0.0, 360.0, 5.0) var giro_inicial := 180.0
## Bamboleo del trozo mientras vuela, en grados por segundo. Es lo que hace que
## una cana gire al caer en vez de bajar tiesa.
@export_range(0.0, 90.0, 1.0) var bamboleo := 30.0

@export_group("Color")
## Variacion del tono por rafaga, de 0 a 0,5. Cada corte aclara u oscurece el
## suyo: con cortes seguidos el conjunto tiembla, que es lo que evita el charco
## de pintura. Con 0 todas las rafagas salen del mismo tono exacto.
@export_range(0.0, 0.5, 0.01) var variacion_tono := 0.26

@export_group("Familia por escala")
## Cuando la llamada no dice el tipo (tipo < 1), la familia se elige por la
## escala: hasta este valor, cesped.
@export_range(0.0, 2.0, 0.05) var corte_cesped := 0.9
## Y a partir de este, zarza. Entre los dos, maleza.
@export_range(0.0, 2.0, 0.05) var corte_zarza := 1.2

@export_group("Suelo")
## Nacer a la altura del suelo bajo el punto de corte. En el punto de corte
## exacto la rafaga aparece dentro del cabezal, y a traves del suelo no se ve
## nacer nada.
@export var elevar_al_suelo := true
## Cuanto por encima del suelo nace la rafaga, en metros.
@export_range(0.0, 0.5, 0.01) var altura_sobre_suelo := 0.05


var _emisores: Array[CPUParticles3D] = []
## Las mallas de cada familia, por tipo (1 cesped, 2 maleza, 3 zarza).
var _familias := {}
var _material: StandardMaterial3D
## Proximo emisor a usar. Rotatorio: la rafaga que mas tiempo lleva sin disparar
## es la que dispara, y una rafaga nueva siempre interrumpe a una casi apagada.
var _turno := 0
## Trozos pedidos que aun no han salido. Se acumulan aqui y salen en rafaga.
var _pendientes := 0.0
## Tiempo desde la ultima rafaga, para que el ultimo bulto no se quede fuera.
var _tiempo := 0.0
## Los datos de la ULTIMA llamada a soltar(): la rafaga acumulada sale de ahi.
## El origen es el ultimo corte y no la media: lo que se quiere ver es escombro
## donde estuvo el filo hace dos fotogramas.
var _origen := Vector3.ZERO
var _direccion := Vector3.FORWARD
var _tono := Color.WHITE
var _escala := 1.0
var _tipo := 1
## Cuantos trozos se han puesto en vuelo en toda la partida. Para las pruebas.
var _soltados := 0


func _ready() -> void:
	add_to_group("restos")
	_material = _crear_material()
	_cargar_piezas()
	for indice in emisores:
		var emisor := CPUParticles3D.new()
		emisor.name = "Rafaga%d" % indice
		# Rafaga de a un golpe: dispara todo de una vez, se apaga sola, y no
		# vuelve a emitir hasta que `soltar` la reinicie.
		emisor.one_shot = true
		emisor.explosiveness = 1.0
		emisor.emitting = false
		emisor.amount = max_por_rafaga
		emisor.lifetime = vida
		emisor.lifetime_randomness = 0.35
		# Reparto en un disco de medio metro: la rafaga nace en el suelo del
		# corte, no en un punto. Un aro pintado se ve; un disco de trozos no.
		emisor.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		emisor.emission_sphere_radius = 0.45
		# El AABB de visibilidad va amplio a proposito: por defecto se calcula
		# alrededor del emisor, y una rafaga que vuela un metro la cuela el
		# culling y desaparece en mitad del aire.
		emisor.visibility_aabb = AABB(Vector3(-1.5, -1.0, -1.5),
			Vector3(3.0, 3.0, 3.0))
		emisor.mesh = _pieza_de(1)
		add_child(emisor)
		_emisores.append(emisor)


func _physics_process(delta: float) -> void:
	# El temporizador corre SIEMPRE, corte o no: si no, los ultimos trozos de
	# una pasada corta se quedarian acumulados para siempre.
	if _pendientes >= 1.0:
		_tiempo += delta
		if _tiempo >= espera_max:
			_soltar_rafaga()


## Carga las mallas de la familia desde el .glb y las reparte por tipo.
##
## Si el .glb no esta importado, avisa y el pool se queda sin piezas: `soltar`
## devuelve 0 y las pruebas lo ven. Es mejor eso que arrancar con el sistema a
## medias sin decir nada.
func _cargar_piezas() -> void:
	_familias = {1: [], 2: [], 3: []}
	if not ResourceLoader.exists(RUTA_PIEZAS):
		push_error("Restos: no existe %s; importa el modelo en Godot" % RUTA_PIEZAS)
		return
	var escena := load(RUTA_PIEZAS) as PackedScene
	if escena == null:
		push_error("Restos: %s no es una escena" % RUTA_PIEZAS)
		return
	var raiz := escena.instantiate()
	for nodo in raiz.find_children("*", "MeshInstance3D", true, false):
		var malla: Mesh = (nodo as MeshInstance3D).mesh
		if malla == null:
			continue
		var nombre := nodo.name.to_lower()
		for tipo in PREFIJOS:
			if nombre.begins_with(PREFIJOS[tipo]):
				# El material de las piezas lo pone el juego, no el .glb: se
				# cose a la malla (y no en material_override) porque es lo que
				# garantiza que la particula lo use en todas las versiones.
				malla.surface_set_material(0, _material)
				_familias[tipo].append(malla)
				break
	raiz.free()
	var cuantas := []
	for tipo in _familias:
		cuantas.append("%d=%d" % [tipo, _familias[tipo].size()])
	print("Restos: piezas cargadas (%s)" % ", ".join(cuantas))


## El material de las particulas: mate, doble cara y con el color de vertice
## encendido, que es lo que hace que el pie de la pieza tire a verde y la punta
## a pajizo. El tono de la planta lo pone la rafaga por encima.
func _crear_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.92
	# Sin cull: los trozos giran libres y desde media vuelta se tienen que ver.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Blanco: el color LO PONE la particula (`color` del emisor), que es lo que
	# hace que cada rafaga salga del verde de SU planta.
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	mat.vertex_color_use_as_albedo = true
	return mat


## Una pieza al azar de la familia del tipo. Si esa familia no ha cargado (o el
## tipo es raro), tira de cualquier pieza antes que no soltar nada.
func _pieza_de(tipo: int) -> Mesh:
	var lista: Array = _familias.get(clampi(tipo, 1, 3), [])
	if lista.is_empty():
		for otro in [1, 2, 3]:
			var alternativa: Array = _familias.get(otro, [])
			if not alternativa.is_empty():
				return alternativa[randi() % alternativa.size()]
		return null
	return lista[randi() % lista.size()]


## Devuelve el unico gestor de restos de la partida, creandolo si la escena aun
## no lo tiene. Cualquier vegetacion puede llamarlo al cortar y no necesita
## saber donde esta colgado, que es lo que evita cablear el nodo en cada escena.
static func obtener(arbol: SceneTree) -> Restos:
	for nodo in arbol.get_nodes_in_group("restos"):
		if nodo is Restos:
			return nodo as Restos
	var nuevo := Restos.new()
	nuevo.name = "Restos"
	arbol.root.add_child(nuevo)
	return nuevo


## Suelta escombro de un corte. `cantidad` son las HOJAS cortadas (la cuenta de
## trozos la hace `densidad`), `direccion` hacia donde salen despedidos, `tono`
## el color de la planta, `escala` el tamano y `tipo` la familia (1 cesped,
## 2 maleza, 3 zarza; con menos de 1 se elige por la escala).
##
## No dispara siempre: acumula, y cuando hay monte (`piezas_min_rafaga`) sale
## la rafaga. Devuelve los trozos que han salido en ESTA llamada (0 si solo se
## ha acumulado), y deja el total en `recuento()`.
func soltar(origen: Vector3, cantidad: int, direccion: Vector3, tono: Color,
		escala: float = 1.0, tipo: int = -1) -> int:
	if not is_inside_tree() or _emisores.is_empty():
		return 0
	var trozos := int(round(float(cantidad) * densidad))
	if trozos <= 0:
		return 0
	# Los datos de la rafaga que se esta acumulando: el ultimo corte manda.
	_origen = origen
	_direccion = direccion
	_tono = tono
	_escala = escala
	_tipo = tipo if tipo > 0 else _familia_por_escala(escala)
	_pendientes += float(trozos)
	if _pendientes >= float(piezas_min_rafaga):
		return _soltar_rafaga()
	return 0


## Con que familia se tira cuando la llamada no dice el tipo. La escala del
## corte ya distingue una brizna de una cana (una hoja de 4,5 mm no puede
## dejar el mismo trozo que un tallo de 26), asi que sirve de respaldo.
func _familia_por_escala(escala: float) -> int:
	if escala <= corte_cesped:
		return 1
	if escala >= corte_zarza:
		return 3
	return 2


## Suelta la rafaga acumulada. Devuelve los trozos que han salido (0 si no
## habia nada). Aqui se leen TODOS los exports, que es lo que los hace
## ajustables en caliente.
func _soltar_rafaga() -> int:
	var cuantos := mini(int(_pendientes), max_por_rafaga)
	if cuantos <= 0:
		return 0
	_pendientes -= float(cuantos)
	_tiempo = 0.0
	var plano := Vector3(_direccion.x, 0.0, _direccion.z)
	if plano.length() > 0.01:
		plano = plano.normalized()
	else:
		plano = Vector3.FORWARD
	# El eje del chorro es la suma del salto horizontal y del alzamiento.
	var bote := plano * velocidad_saltar + Vector3.UP * alza
	if bote.length() < 0.01:
		bote = Vector3.UP
	var base := _origen
	if elevar_al_suelo:
		base.y = _suelo_bajo(_origen) + altura_sobre_suelo
	# La rafaga se reparte entre varios emisores para mezclar piezas.
	var reparto := mini(piezas_por_rafaga, _emisores.size())
	var por_emisor := int(ceil(float(cuantos) / float(reparto)))
	var quedan := cuantos
	for i in reparto:
		var emisor := _emisores[_turno]
		_turno = (_turno + 1) % _emisores.size()
		var suyos := mini(por_emisor, quedan)
		quedan -= suyos
		if suyos <= 0:
			break
		_disparar(emisor, base, bote, suyos)
	_soltados += cuantos
	return cuantos


## Prepara un emisor para una rafaga: posicion, direccion, vuelo, color y una
## pieza al azar de la familia. Se lee todo aqui, en caliente.
func _disparar(emisor: CPUParticles3D, base: Vector3, bote: Vector3,
		cuantos: int) -> void:
	emisor.global_position = base
	emisor.mesh = _pieza_de(_tipo)
	emisor.amount = cuantos
	emisor.lifetime = vida
	emisor.direction = bote.normalized()
	# Con la misma fuerza para las dos mitades del rango, las piezas salen como
	# un chorro compacto; con dispersion, unas se quedan cerca y otras se
	# sueltan, que es como se abre un escombro de verdad.
	emisor.initial_velocity_min = bote.length() * 0.7
	emisor.initial_velocity_max = bote.length() * 1.3
	emisor.gravity = Vector3(0.0, -gravedad, 0.0)
	emisor.damping_min = amortiguacion_min
	emisor.damping_max = amortiguacion_max
	emisor.spread = dispersion
	emisor.angle_min = -giro_inicial
	emisor.angle_max = giro_inicial
	emisor.angular_velocity_min = -bamboleo
	emisor.angular_velocity_max = bamboleo
	# El tamano va con el de la planta: una brizna deja trozos pequenos y una
	# cana deja trozos grandes. Con tamano fijo el amontonado de la maleza
	# parecia el de un cesped corto.
	emisor.scale_amount_min = tamano_min * _escala
	emisor.scale_amount_max = tamano_max * _escala
	# El color es lo que hace que se note de que planta salio cada rafaga. La
	# variacion va POR RAFAGA porque CPUParticles3D no tiene color_variance:
	# como los cortes son rapidos y seguidos, el conjunto se aclara y se
	# oscurece hoja a hoja, que es lo que evita el charco de pintura.
	var claro := randf_range(1.0 - variacion_tono, 1.0 + variacion_tono)
	emisor.color = Color(
		clampf(_tono.r * claro, 0.0, 1.0),
		clampf(_tono.g * claro, 0.0, 1.0),
		clampf(_tono.b * claro, 0.0, 1.0))
	emisor.restart()


## A que altura esta el suelo bajo un punto, en coordenadas de mundo.
##
## Se lanza un rayo por rafaga, que son pocos por fotograma. La mascara ve
## suelo, jugador y arboles. La misma mascara la usa la maquina para su apoyo.
func _suelo_bajo(punto: Vector3) -> float:
	if not is_inside_tree():
		return punto.y
	var espacio := get_world_3d().direct_space_state
	var origen := Vector3(punto.x, punto.y + 1.5, punto.z)
	var consulta := PhysicsRayQueryParameters3D.create(origen,
		origen + Vector3.DOWN * 6.0)
	consulta.collision_mask = 1 | 2 | 4
	var golpe: Dictionary = espacio.intersect_ray(consulta)
	return punto.y if golpe.is_empty() else float(golpe["position"].y)


## Para las pruebas y para el interfaz: cuantos trozos se han puesto en vuelo,
## cuantas rafagas estan emitiendo, cuantos trozos esperan su rafaga y cuantos
## emisores tiene el pool. Son contadores de CPU: funcionan en headless.
func recuento() -> Dictionary:
	var activos := 0
	for emisor in _emisores:
		if emisor.emitting:
			activos += 1
	return {"soltados": _soltados, "activos": activos,
		"pendientes": int(_pendientes), "emisores": _emisores.size()}


## Cuantas piezas ha cargado de cada familia. Para las pruebas.
func piezas_cargadas() -> Dictionary:
	var cuantas := {}
	for tipo in _familias:
		cuantas[tipo] = _familias[tipo].size()
	return cuantas


## Corta toda la actividad de restos en curso. Ojo: no hay `clear_particles` en
## esta version de Godot, asi que lo que ya volaba se apaga cuando cumple su
## vida; lo que se corta en seco es la emision nueva.
func limpiar() -> void:
	_soltados = 0
	_pendientes = 0.0
	_tiempo = 0.0
	for emisor in _emisores:
		emisor.emitting = false
