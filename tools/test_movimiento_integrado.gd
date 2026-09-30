extends SceneTree

## Pruebas integradas del movimiento base en combinaciones de uso real.
##
## Ejecutar solo este recorrido, sin la suite completa:
##   flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
##     --headless --path . --script res://tools/test_movimiento_integrado.gd

var _empezado := false
var _correctas := 0
var _fallos := 0
var _mundo: Node3D
var _jugador: Jugador
var _camara: CamaraGopro
var _herramienta: Desbrozadora


func _process(_delta: float) -> bool:
	if not _empezado:
		_empezado = true
		_ejecutar()
	return false


func _ejecutar() -> void:
	print("== prueba integrada de movimiento ==")
	_mundo = load("res://scenes/main.tscn").instantiate()
	root.add_child(_mundo)
	await physics_frame
	_jugador = _mundo.get_node_or_null("Player") as Jugador
	_camara = _mundo.get_node_or_null("Player/Cabeza/Camara") as CamaraGopro
	_herramienta = _buscar_herramienta()
	_comprobar(_jugador != null and _camara != null and _herramienta != null,
		"escena con jugador, camara y herramienta")
	if _jugador == null or _camara == null or _herramienta == null:
		_finalizar()
		return

	_soltar_todo()
	await _esperar(1.5)
	_comprobar(_jugador.is_on_floor(), "inicio apoyado en el suelo")
	_comprobar(absf(_camara.global_position.y - 1.62) < 0.08,
		"altura inicial de camara estable")
	_probar_radio_corte_compartido()
	_probar_cabezales_y_desgaste()
	await _probar_tier3()

	await _probar_paneo_y_barrido()
	await _probar_wasd_carrera_y_motor()
	await _probar_estrafes()
	await _probar_reversa()
	await _probar_agachado_en_marcha()
	await _probar_salto_mientras_corta()

	_soltar_todo()
	await _esperar(1.2)
	_comprobar(_jugador.is_on_floor(), "fin de recorrido estable en el suelo")
	_comprobar(_vector_finito(_jugador.global_position), "posicion final finita")
	_comprobar(_barrido_en_rango(), "barrido final dentro de los topes del arnes")
	_finalizar()


func _probar_radio_corte_compartido() -> void:
	print("-- radio del cabezal compartido por los campos --")
	_comprobar(_herramienta.radio_corte > 0.5,
		"el radio efectivo deja un ancho de pasada visible (%.2f m)"
		% _herramienta.radio_corte)
	for nombre in ["Cesped", "MalezaAlta", "Zarza"]:
		var campo := _mundo.get_node_or_null(nombre) as Hierba
		_comprobar(campo != null, "%s está disponible para cortar" % nombre)
		if campo == null or campo.total() == 0:
			continue
		var punto := campo.to_global(campo.posicion_hoja(campo.total() / 2))
		var de_pie_antes := campo.total_de_pie()
		var cortadas := campo.cortar(punto, _herramienta.radio_corte)
		_comprobar(cortadas > 1,
			"el mismo cabezal deja un parche visible en %s (%d hojas)"
			% [nombre, cortadas])
		_comprobar(campo.total_de_pie() == de_pie_antes - cortadas,
			"el corte se registra correctamente en %s" % nombre)


func _probar_cabezales_y_desgaste() -> void:
	print("-- cabezales compatibles y desgaste --")
	var nombre_inicial := _herramienta.nombre_cabezal
	var desgaste_inicial := _herramienta.desgaste_cabezal
	_comprobar(_herramienta.cabezal_puede_cortar(1)
		and _herramienta.cabezal_puede_cortar(2)
		and _herramienta.cabezal_puede_cortar(3),
		"la cuchilla de serie corta cesped, maleza y zarza")
	var cab: CabezalDesbrozadora = _herramienta.cabezales_disponibles[0]
	var desgaste_esperado := 1000.0 * _herramienta.desgaste_por_hoja \
		* cab.desgaste_por_hoja_para(1)
	_herramienta.registrar_corte(1, 1000)
	_comprobar(_herramienta.desgaste_cabezal < desgaste_inicial,
		"cortar hojas reduce el filo del cabezal")
	_comprobar(is_equal_approx(desgaste_inicial - _herramienta.desgaste_cabezal,
			desgaste_esperado),
		"y lo que gasta sale de la resistencia de ese cabezal contra esa planta")
	_comprobar(_herramienta.cambiar_cabezal_siguiente(),
		"se puede cambiar de cabezal con el motor parado")
	# El nylon corta de todo, pero contra la maleza y la zarza es el mas lento y
	# el que mas se come. Antes tenia una lista de "esto no lo puedes cortar" y
	# con el montado no se podia ni rozar la maleza, cuando el nylon la abre de
	# pena: la pregunta ya no es si puede, sino cuanto.
	var nylon: CabezalDesbrozadora = _herramienta.cabezales_disponibles[1]
	_comprobar(_herramienta.nombre_cabezal.contains("nylon")
		and _herramienta.nombre_cabezal.contains(str(nylon.nivel)),
		"el cabezal de hilo sale con su nivel")
	_comprobar(_herramienta.cabezal_puede_cortar(1)
		and _herramienta.cabezal_puede_cortar(2)
		and _herramienta.cabezal_puede_cortar(3),
		"el cabezal de hilo puede con cualquier vegetacion")
	_comprobar(nylon.eficacia_de(2) <= nylon.eficacia_de(1)
		and nylon.resistencia_de(3) > nylon.resistencia_de(1),
		"pero contra la maleza y la zarza es el mas flojo")
	_herramienta.cambiar_cabezal_siguiente()
	_comprobar(_herramienta.cabezales_disponibles[2].eficacia_de(2)
		> nylon.eficacia_de(2),
		"el disco de dos puntas abre mas maleza que el hilo")
	_herramienta.cambiar_cabezal_siguiente()
	_comprobar(_herramienta.cabezales_disponibles[3].nivel == 3
		and _herramienta.cabezales_disponibles[3].eficacia_de(3) > nylon.eficacia_de(3),
		"el disco de tres puntas es el mejor con la zarza")
	_herramienta.cambiar_cabezal_siguiente()
	_comprobar(_herramienta.nombre_cabezal == nombre_inicial,
		"el ciclo vuelve a la cuchilla de serie")
	# El desgaste se guarda por cabezal, asi que se conserva el de cada uno al
	# desmontarlo. Se mira contra lo que la formula dice, no contra un numero
	# fijo: un numero fijo aqui se quedo viejo la vez pasada y no lo vio nadie.
	_comprobar(is_equal_approx(_herramienta.desgaste_cabezal, desgaste_inicial - desgaste_esperado),
		"el desgaste se conserva al desmontar y volver a montar un cabezal")


## La zarza ahora es el tier 3 de la misma hoja que el cesped, y esta prueba lo
## comprueba en la escena real: que hay matas, que se cortan a la altura del
## cabezal, y que al cortar sueltan rafagas de restos.
func _descendientes(nodo: Node) -> Array[Node]:
	var fuera: Array[Node] = []
	if nodo == null:
		return fuera
	for c in nodo.get_children():
		fuera.append(c)
		fuera.append_array(_descendientes(c))
	return fuera


func _probar_tier3() -> void:
	print("-- el tier 3 (zarza) es la misma hoja que el cesped --")
	# La zarza es un nodo mas al mismo nivel que `Cesped` y `MalezaAlta`: uno por
	# planta, la misma estructura, y se distingue solo por su `tipo`. Es la que
	# hay delante del jugador al arrancar.
	var mata := _mundo.get_node_or_null("Zarza") as Hierba
	_comprobar(mata != null, "la zarza de prueba esta en la escena")
	if mata == null:
		return
	_comprobar(mata.tipo_vegetacion() == 3, "y es el tier 3")
	_comprobar(mata.hojas_en_pie() > 500,
		"la mata se siembra con muchas hojas (%d)" % mata.hojas_en_pie())
	# Y tiene que ser una hoja de verdad, no una brizna como el cesped: si la
	# forma no se parametriza, el tier 3 sale identico al cesped y la "otra skin"
	# no existe.
	var cesped := _mundo.get_node_or_null("Cesped") as Hierba
	_comprobar(cesped != null and mata.hoja_estrecha < cesped.hoja_estrecha,
		"la hoja del tier 3 se ensancha menos que la del cesped (%.2f < %.2f)"
		% [mata.hoja_estrecha, cesped.hoja_estrecha if cesped != null else 0.0])

	var donde := mata.global_position
	# Un punto con hoja de verdad, no el centro de la mata: con `formacion` 0,70
	# el 60 % del terreno queda sin sembrar y el centro puede ser un claro pelado.
	# Ahi la prueba "pasaba" sin cortar nada, que es peor que fallar.
	var destino := _punto_con_hoja(mata, 0.9)
	_comprobar(mata.de_pie(destino, 0.9) > 5,
		"y hay hoja de verdad donde se va a cortar (%d alrededor)"
		% mata.de_pie(destino, 0.9))
	var corte_alto := mata.cortar_y_soltar(destino + Vector3(0.0, 0.4, 0.0), 1.5)
	_comprobar(corte_alto > 0,
		"se puede cortar en una franja a la altura del cabezal")
	# La zarza va con `dejar_tocon = false`: a diferencia del cesped, que deja un
	# palmo para que se vea por donde has pasado, aqui se corta a ras. Asi que
	# después de la pasada no queda nada en pie en ese disco.
	_comprobar(mata.hojas_en_pie() < mata.total(),
		"una pasada deja el disco pelado")

	# Y los restos: al cortar sale una rafaga de particulas. Ya no tienen cuerpo,
	# asi que aqui solo se puede comprobar lo que de verdad pasa: que se piden al
	# cortar, y que **no queda ningun cuerpo fisico tirado por el suelo**, que era
	# la firma del sistema viejo. Si alguien revive el pool de rigidos, esto lo caza.
	var restos := Restos.obtener(_mundo.get_tree())
	restos.limpiar()
	# En un trozo donde no se ha cortado todavia: si se repite el disco de
	# arriba, ya no quedan hojas de pie y no sale ni un resto, y parece que
	# los restos no funcionan.
	var donde_resto := _punto_con_hoja(mata, 0.9) + Vector3(0.0, 0.4, 0.0)
	mata.cortar_y_soltar(donde_resto, 1.2, 40.0)
	_comprobar(int(restos.recuento()["soltados"]) > 0,
		"al cortar salen rafagas de restos (%d trozos pedidos)"
		% int(restos.recuento()["soltados"]))
	for _i in 15:
		await physics_frame
	var cuerpos := 0
	for n in _descendientes(restos):
		if n is RigidBody3D:
			cuerpos += 1
	_comprobar(cuerpos == 0,
		"y en el suelo no queda cuerpos de restos, que ya no los hay (%d)" % cuerpos)


func _probar_paneo_y_barrido() -> void:
	print("-- paneo, pitch y barrido --")
	_soltar_todo()
	_jugador.rotation.y = 0.0
	_jugador.mirar_a(0.0, 0.0)
	await _esperar(0.6)
	_jugador.mirar_a(deg_to_rad(28.0), deg_to_rad(-30.0))
	await _esperar(0.8)
	_comprobar(_error_camara(deg_to_rad(28.0)) < 2.0,
		"camara panea y alcanza la direccion pedida")
	_comprobar(_camara.is_position_in_frustum(_herramienta.punto_de_corte()),
		"cabezal dentro del encuadre durante paneo y pitch abajo")
	_comprobar(_herramienta.angulo_barrido() > deg_to_rad(20.0),
		"paneo a la izquierda inicia el barrido de la maquina")
	_comprobar(_barrido_en_rango(), "paneo izquierdo respeta el tope del arnes")

	_jugador.mirar_a(deg_to_rad(-35.0), deg_to_rad(15.0))
	await _esperar(1.0)
	_comprobar(_herramienta.angulo_barrido() < -deg_to_rad(20.0),
		"paneo inverso lleva la maquina al lado derecho")
	_comprobar(_barrido_en_rango(), "paneo inverso respeta el tope derecho")
	_comprobar(_camara.is_position_in_frustum(_herramienta.punto_de_corte()),
		"cabezal visible al paneo inverso y mirar arriba")

	print("-- mirar arriba con el motor en marcha --")
	Input.action_press("acelerador")
	_jugador.mirar_a(deg_to_rad(-35.0), deg_to_rad(45.0))
	await _esperar(1.0)
	_comprobar(_herramienta.cortando,
		"el motor sigue activo al levantar la mirada")
	_comprobar(_camara.is_position_in_frustum(_herramienta.punto_de_corte()),
		"el cabezal no desaparece con motor encendido y mirada alta")
	var agarre_i := _herramienta.get_node_or_null("AgarreIzquierdo") as Marker3D
	var agarre_d := _herramienta.get_node_or_null("AgarreDerecho") as Marker3D
	_comprobar(agarre_i != null and _vector_finito(agarre_i.global_position)
		and agarre_d != null and _vector_finito(agarre_d.global_position),
		"ambos objetivos de manos siguen finitos al elevar la maquina")
	_comprobar(_barrido_en_rango(), "mirar arriba con motor no rompe el tope de barrido")
	Input.action_release("acelerador")
	_jugador.mirar_a(0.0, deg_to_rad(-25.0))
	await _esperar(0.8)


func _probar_wasd_carrera_y_motor() -> void:
	print("-- W+D, carrera, acelerador y herramienta --")
	_soltar_todo()
	_jugador.rotation.y = 0.0
	_jugador.mirar_a(0.0, deg_to_rad(-25.0))
	await _esperar(0.7)
	var antes := _jugador.global_position
	var fov_antes := _camara.fov
	var combustible_antes := _herramienta.combustible_litros
	Input.action_press("mover_adelante")
	Input.action_press("mover_derecha")
	Input.action_press("correr")
	Input.action_press("acelerador")
	await _esperar(0.9)
	var desplazamiento := _jugador.global_position - antes
	_comprobar(desplazamiento.length() > 1.8,
		"W+D con Shift desplaza al jugador (%.2f m)" % desplazamiento.length())
	_comprobar(_jugador.get_correr() and _jugador.get_velocidad_plano() > 4.5,
		"la carrera diagonal mantiene la velocidad de carrera")
	_comprobar(_camara.fov > fov_antes + 5.0,
		"el FOV responde a la carrera durante la diagonal")
	_comprobar(_herramienta.rpm > 5000.0 and _herramienta.cortando,
		"el acelerador mantiene el motor cortando mientras se mueve")
	_comprobar(not _herramienta.cambiar_cabezal_siguiente(),
		"no se permite cambiar el cabezal con el motor en marcha")
	_comprobar(_herramienta.combustible_litros < combustible_antes,
		"el motor consume combustible mientras trabaja")
	_comprobar(_barrido_en_rango(), "W+D no saca la maquina del arco de cadera")
	_comprobar(_error_camara(_jugador.get_yaw()) < 4.0,
		"la camara mantiene la mirada mientras el cuerpo gira con W+D")
	_comprobar(_vector_finito(_jugador.global_position)
		and _vector_finito(_herramienta.punto_de_corte()),
		"W+D y acelerador no producen transformaciones invalidas")
	_soltar_todo()
	await _esperar(0.8)


func _probar_estrafes() -> void:
	print("-- A y D con motor encendido --")
	_jugador.rotation.y = 0.0
	_jugador.mirar_a(0.0, deg_to_rad(-25.0))
	await _esperar(0.6)
	var antes_a := _jugador.global_position
	Input.action_press("mover_izquierda")
	Input.action_press("acelerador")
	await _esperar(0.5)
	var dx_a := _jugador.global_position.x - antes_a.x
	_comprobar(dx_a < -0.2, "A desplaza hacia la izquierda (dx=%.2f)" % dx_a)
	_comprobar(_jugador.rotation.y == 0.0,
		"A no gira el torso mientras barre")
	_comprobar(_herramienta.angulo_barrido() > 0.0,
		"A barre la herramienta hacia la izquierda")
	_comprobar(_barrido_en_rango(), "A respeta el tope izquierdo")
	_soltar_todo()
	await _esperar(0.7)

	var antes_d := _jugador.global_position
	Input.action_press("mover_derecha")
	Input.action_press("acelerador")
	await _esperar(0.5)
	var dx_d := _jugador.global_position.x - antes_d.x
	_comprobar(dx_d > 0.2, "D desplaza hacia la derecha (dx=%.2f)" % dx_d)
	_comprobar(_jugador.rotation.y == 0.0,
		"D no gira el torso mientras barre")
	_comprobar(_herramienta.angulo_barrido() < 0.0,
		"D barre la herramienta hacia la derecha")
	_comprobar(_barrido_en_rango(), "D respeta el tope derecho")
	_soltar_todo()
	await _esperar(0.8)


func _probar_reversa() -> void:
	print("-- S, motor y carrera --")
	_jugador.rotation.y = 0.0
	_jugador.mirar_a(0.0, 0.0)
	await _esperar(0.5)
	var yaw_camara := _yaw_camara()
	var z_antes := _jugador.global_position.z
	Input.action_press("mover_atras")
	Input.action_press("correr")
	Input.action_press("acelerador")
	await _esperar(0.6)
	_comprobar(_jugador.global_position.z > z_antes + 0.5,
		"S mueve hacia atras corriendo")
	_comprobar(_jugador.rotation.y == 0.0,
		"S no da la vuelta al cuerpo")
	_comprobar(_error_camara(yaw_camara) < 2.0,
		"la camara no pega un giro de 180 grados con S")
	_comprobar(_herramienta.cortando,
		"la herramienta sigue acelerada durante la marcha atras")
	_soltar_todo()
	await _esperar(0.8)


func _probar_agachado_en_marcha() -> void:
	print("-- agacharse y correr mientras corta --")
	_jugador.rotation.y = 0.0
	_jugador.mirar_a(0.0, deg_to_rad(-25.0))
	await _esperar(0.6)
	var altura_parado := _altura_camara_relativa()
	Input.action_press("acelerador")
	await _esperar(0.9)
	var altura_motor := _altura_camara_relativa()
	var z_antes := _jugador.global_position.z
	Input.action_press("mover_adelante")
	Input.action_press("correr")
	Input.action_press("agacharse")
	await _esperar(0.65)
	await _esperar_a_inclinacion()
	var bajada := altura_motor - _altura_camara_relativa()
	_comprobar(bajada > 0.40 and bajada < 0.70,
		"agacharse baja la camara una altura (%.2f m)" % bajada)
	_comprobar(_jugador.get_correr() and _jugador.get_velocidad_plano() > 4.5,
		"W+Shift+Ctrl conserva carrera y avance")
	_comprobar(_jugador.global_position.z < z_antes - 1.0,
		"W+Shift+Ctrl avanza mientras se agacha")
	_comprobar(_herramienta.cortando,
		"se puede seguir cortando mientras se agacha y corre")
	_comprobar(_barrido_en_rango(), "agachado corriendo mantiene el barrido limitado")
	_comprobar(_camara.is_position_in_frustum(_herramienta.punto_de_corte()),
		"el cabezal sigue visible agachado, corriendo y cortando")
	Input.action_release("mover_adelante")
	Input.action_release("correr")
	Input.action_release("agacharse")
	await _esperar(0.7)
	_comprobar(absf(_altura_camara_relativa() - altura_motor) < 0.12,
		"la camara vuelve al nivel de motor encendido al levantarse")
	Input.action_release("acelerador")
	await _esperar(0.9)
	_comprobar(absf(_altura_camara_relativa() - altura_parado) < 0.12,
		"la camara vuelve a la altura normal al soltar el acelerador")


func _probar_salto_mientras_corta() -> void:
	print("-- salto, avance y acelerador --")
	_jugador.rotation.y = 0.0
	_jugador.mirar_a(0.0, 0.0)
	await _esperar(0.5)
	Input.action_press("mover_adelante")
	Input.action_press("saltar")
	Input.action_press("acelerador")
	await _esperar(0.18)
	_comprobar(_jugador.velocity.y > 0.0, "Espacio salta mientras avanza")
	_comprobar(_herramienta.cortando, "la maquina no se para al saltar")
	Input.action_release("saltar")
	await _esperar(0.8)
	Input.action_release("mover_adelante")
	Input.action_release("acelerador")
	await _esperar(1.0)
	_comprobar(_jugador.is_on_floor(), "aterriza sin quedarse atascado")
	_comprobar(_vector_finito(_jugador.global_position), "el salto no genera NaN")


func _buscar_herramienta() -> Desbrozadora:
	for nodo in get_nodes_in_group("herramienta"):
		if nodo is Desbrozadora:
			return nodo as Desbrozadora
	return null


## Espera a que la maqueta Y la camara se queden quietas.
##
## Las dos se mueven con retardo y por eso hace falta esto:
##
## - El morro no se coloca de golpe: `_colocar` lo lleva a su inclinacion con
##   `move_toward`, asi que tarda unos cuantos fotogramas en llegar.
## - La camara va con retardo a proposito (es lo que hace que no se note el
##   raton), asi que aunque el morro ya este quieto, la camara todavia esta
##   girando. Y lo que se comprueba aqui es si el morro cae dentro de su
##   encuadre, o sea que depende de las dos.
##
## Esperar un numero FIJO de fotogramas funciona mientras la escena va a una
## velocidad dada, y en cuanto la escena pesa mas (una zarza densa con 14.000
## hojas en vez de 500 celdas) deja de bastar: el morro se queda a medio chemin
## y la prueba mide una foto que el jugador nunca veria. Es el mismo problema que
## las seis comprobaciones que se quedaron viejas, otra vez: un numero fijo en un
## test que depende de cuanto tarda algo en llegar.
## Distancia media de los trozos al punto, en el plano. Para medir que el
## escombro se aparta, que es mejor que contar cuantos hay dentro de un circulo:
## el circulo dice SI o NO justo en el borde, y ahi es donde no se nota nada.
## Un punto del mundo con hoja de verdad alrededor. Con `formacion` 0,70 el 60 %
## del terreno esta vacio, asi que un punto al azar puede no tener nada que cortar.
func _punto_con_hoja(mata: Hierba, r: float) -> Vector3:
	var mejor := Vector3.ZERO
	var cuanta := -1
	for intento in 60:
		var i := (intento * 137) % maxi(mata.total(), 1)
		var punto := mata.to_global(mata.posicion_hoja(i))
		var alrededor := mata.de_pie(punto, r)
		if alrededor > cuanta:
			cuanta = alrededor
			mejor = punto
		if cuanta > 20:
			break
	return mejor


func _esperar_a_inclinacion(limite: float = 0.002, tope: float = 4.0) -> void:
	var quieto := 0
	var anterior := Vector2(_herramienta.angulo_inclinacion(), _camara.rotation.x)
	for _i in int(tope * Engine.physics_ticks_per_second):
		await physics_frame
		var ahora := Vector2(_herramienta.angulo_inclinacion(), _camara.rotation.x)
		if (ahora - anterior).length() < limite:
			quieto += 1
			if quieto > 6:
				return
		else:
			quieto = 0
		anterior = ahora


## La comprobacion de que el cabezal sigue en el encuadre al agacharse corriendo
## esta en ROJO desde el 2026-09-29, y no es cosa de la vegetacion. Cuando el morro
## va con retardo, la prueba lo cogia a medio camino y la cabeza salia dentro por
## casualidad; esperando a que se asiente (ver `_esperar_a_inclinacion`) sale el
## numero de verdad: el cabezal se va **105 grados del eje de la camara** con un
## cono de medio 33 grados. O sea que agachado y corriendo, el morro se sale de la
## foto y `_pitch_limitado` no lo evita. Es un fallo de la camara, no de esta
## prueba, y queda aqui escrito a proposito en vez de relajar la comprobacion.
##
## Lo que falta por decidir: si se arregla la camara (que el limite tenga en
## cuenta la altura del agachado, que es lo mas probable) o si la pose agachada
## y corriendo se considera aceptable. Hasta entonces el test falla a proposito.
func _esperar(segundos: float) -> void:
	var cuadros := maxi(1, int(ceil(segundos * Engine.physics_ticks_per_second)))
	for _i in cuadros:
		await physics_frame
		await process_frame


func _soltar_todo() -> void:
	for accion in ["mover_adelante", "mover_atras", "mover_izquierda",
			"mover_derecha", "correr", "agacharse", "saltar", "acelerador",
			"cambiar_cabezal"]:
		Input.action_release(accion)


func _barrido_en_rango() -> bool:
	var angulo := _herramienta.angulo_barrido()
	return angulo >= -deg_to_rad(_herramienta.max_right_angle) - 0.04 \
		and angulo <= deg_to_rad(_herramienta.max_left_angle) + 0.04


func _yaw_camara() -> float:
	var delante := -_camara.global_transform.basis.z
	return atan2(-delante.x, -delante.z)


func _altura_camara_relativa() -> float:
	return _camara.global_position.y - _jugador.global_position.y


func _error_camara(yaw: float) -> float:
	return absf(rad_to_deg(wrapf(_yaw_camara() - yaw, -PI, PI)))


func _vector_finito(valor: Vector3) -> bool:
	return is_finite(valor.x) and is_finite(valor.y) and is_finite(valor.z)


func _comprobar(condicion: bool, nombre: String) -> void:
	if condicion:
		_correctas += 1
		print("  OK   ", nombre)
	else:
		_fallos += 1
		printerr("  FAIL ", nombre)


func _finalizar() -> void:
	_soltar_todo()
	print("== resultado: %d correctas, %d fallos ==" % [_correctas, _fallos])
	quit(1 if _fallos > 0 else 0)
