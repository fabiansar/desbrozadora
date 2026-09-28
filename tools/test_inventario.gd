extends SceneTree

## La prueba del inventario, con la secuencia que pidio el jugador de punta a
## punta:
##
##   1. La desbrozadora esta equipada de salida, en el hueco 1.
##   2. Soltarla (G) la deja en el suelo y deja las manos vacias.
##   3. Recogerla (E) la devuelve a la mano, en el primer hueco libre.
##   4. Con la rueda se pasa a la hoz, y a un hueco vacio, que son las manos
##      vacias.
##   5. Soltar la hoz y recogerla, igual que la desbrozadora.
##   6. Soltar las dos, recogerlas en orden DISTINTO al que se soltaron, y
##      comprobar que cada una vuelve al hueco que le toca y no al primero.
##
##     godot --headless --path . --script tools/test_inventario.gd
##
## La ultima comprobacion es la que importa de verdad. Con el "primer hueco
## libre", soltar las dos y recogerlas al reves tiene que SWAPEAR los huecos y
## no limitarse a meterlo todo en el 1: si el sistema no distinguiera una cosa de
## la otra, el orden de recogida no contaria para nada.

var _fails := 0
var _mundo: Node3D
var _inventario: Inventario


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	_mundo = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_mundo)
	for _i in 20:
		await physics_frame
	_inventario = _mundo.get_node_or_null("Player/Inventario") as Inventario
	if _inventario == null:
		push_error("el jugador no tiene inventario")
		quit(1)
		return

	_salida()
	await _soltar_y_recoger_una(&"desbrozadora")
	_rueda()
	await _corta_la_hoz()
	await _soltar_y_recoger_una(&"hoz")
	await _orden_invertido()

	print("-- resultado: %s" % ("OK" if _fails == 0 else "%d FALLOS" % _fails))
	_mundo.queue_free()
	await process_frame
	quit(0 if _fails == 0 else 1)


# --- 1. La salida ---------------------------------------------------------

func _salida() -> void:
	print("== de salida ==")
	_comprobar(_inventario.hay_algo(0), "el hueco 1 lleva algo de salida")
	_comprobar(_inventario.herramienta_de(0).id == &"desbrozadora",
		"el hueco 1 es la desbrozadora")
	_comprobar(_inventario.herramienta_equipada() is Desbrozadora,
		"la desbrozadora esta en la mano")
	_comprobar(_inventario.hay_algo(1), "el hueco 2 lleva la hoz")
	_comprobar(_inventario.hay_hueco_libre(), "hay huecos libres")
	# La desbrozadora tiene que seguir siendo la de siempre: motor, colision y
	# el grupo. Si el inventario la creara sin su escena, esto seria null.
	var en_mano := _inventario.herramienta_equipada()
	var maquina := en_mano as Desbrozadora
	if maquina != null:
		_comprobar(maquina.get_node_or_null("Modelo") != null,
			"la desbrozadora lleva su modelo")
		_comprobar(maquina.corte != null, "la desbrozadora tiene su cabezal")
	_comprobar(en_mano.get_parent().name == "PivoteDesbrozadora",
		"la herramienta cuelga del arnes, no de la camara (padre: %s)"
		% en_mano.get_parent().name)


# --- 2 y 3. Soltar y recoger ---------------------------------------------

func _soltar_y_recoger_una(id: StringName) -> void:
	print("== soltar y recoger: %s ==" % id)
	# Se elige el hueco de esa herramienta y se comprueba que la herramienta
	# cambia de sitio al girar la rueda, no solo el numero.
	_inventario.seleccionar(0 if id == &"desbrozadora" else 1)
	var antes := _inventario.herramienta_equipada()
	_comprobar(antes != null, "se puede elegir el hueco del %s" % id)

	var suelo := _soltar()
	_comprobar(suelo != null, "G suelta la herramienta al suelo")
	_comprobar(not _inventario.hay_algo(_inventario.seleccion()),
		"el hueco queda vacio al soltar")
	_comprobar(_inventario.herramienta_equipada() == null,
		"las manos quedan vacias")
	_comprobar(_inventario.hay_hueco_libre(),
		"el hueco se cuenta como libre otra vez")
	if suelo == null:
		return
	# Se espera a que caiga y se pare en el suelo. Sin esto el rigid body
	# todavia esta en el aire, y el rayo de la mirada lo veria igual, pero la
	# prueba estaria midiendo una caida y no un objeto en el suelo.
	for _i in 90:
		await physics_frame
	_comprobar(suelo.global_position.y < 1.4,
		"la herramienta ha caído al suelo (y=%.2f)" % suelo.global_position.y)
	_comprobar(not suelo.is_queued_for_deletion(),
		"la herramienta sigue en el mundo, no se ha perdido")

	# Para recoger hay que MIRARLA. Se pone al jugador enfrente y se mira.
	await _apuntar_a(suelo)
	for _i in 4:
		await physics_frame
	_comprobar(_inventario.objeto_bajo_mirada() == suelo,
		"con la mirada encima se ve que se puede coger")
	var cogida := _inventario.recoger()
	_comprobar(cogida, "E recoge lo que se mira")
	_comprobar(_inventario.herramienta_equipada() != null,
		"la herramienta recogida va a la mano")
	_comprobar(_inventario.herramienta_de(_inventario.seleccion()).id == id,
		"vuelve al hueco que estaba mirando")
	_comprobar(suelo.is_queued_for_deletion(),
		"el cuerpo del suelo desaparece al recogerla")


# --- 4. La rueda ----------------------------------------------------------

func _rueda() -> void:
	print("== la rueda ==")
	_inventario.seleccionar(1)
	_comprobar(_inventario.herramienta_equipada() is Hoz,
		"el hueco 2 trae la hoz a la mano")
	# Un hueco vacio son las manos vacias. Se llega desde el 1 con la rueda.
	_inventario.seleccionar(0)
	_inventario.mover_seleccion(4)
	_comprobar(_inventario.seleccion() == 4, "la rueda avanza cuatro huecos")
	_comprobar(_inventario.herramienta_equipada() == null,
		"elegir un hueco vacio deja las manos sin nada")
	_inventario.mover_seleccion(-4)
	_comprobar(_inventario.seleccion() == 0, "y se vuelve")
	# El rodeo: de la rueda no se sale por un extremo.
	_inventario.mover_seleccion(-1)
	_comprobar(_inventario.seleccion() == 8, "la rueda da la vuelta por el 9")
	_inventario.mover_seleccion(1)
	_comprobar(_inventario.seleccion() == 0, "y vuelve a empezar por el 1")


# --- 5. La hoz corta de verdad -------------------------------------------

## Lo unico que hace la hoz es cortar cesped, asi que si esto no funciona la
## herramienta es un palo. Se mira el cesped de cerca, se echa el acelerador y se
## comprueba que ha cortado algo, y que la desbrozadora con la misma vegetacion
## tampoco lo hacia.
func _corta_la_hoz() -> void:
	print("== la hoz corta ==")
	_inventario.seleccionar(1)
	var hoz := _inventario.herramienta_equipada() as Hoz
	if hoz == null:
		_comprobar(false, "la hoz esta en la mano")
		return
	_comprobar(hoz.cabezal_puede_cortar(1), "el filo corta cesped")
	_comprobar(not hoz.cabezal_puede_cortar(3),
		"pero no entra en la zarza, que es lo de verdad")
	# Se busca el campo de cesped y se mira cuanto tiene en pie delante.
	var cesped := _mundo.get_node_or_null("Hierba") as Hierba
	if cesped == null:
		_comprobar(false, "esta el campo de cesped en la escena")
		return
	# El jugador se pone en un claro, mirando al cesped, y mira un poco hacia
	# abajo para que la hoja caiga donde hay.
	var jugador := _mundo.get_node_or_null("Player") as Jugador
	jugador.global_position = Vector3(0.0, 0.95, 0.0)
	jugador.mirar_a(0.0, deg_to_rad(-55.0))
	for _i in 6:
		await physics_frame
	# La altura se mide RELATIVA a los pies del jugador y no sobre el suelo: al
	# empezar el jugador cae desde donde le pusieron en la escena, y midiendo en
	# absoluto la comprobacion dependia de si el jugador ya se habia dejado caer.
	var sobre_pies := hoz.punto_de_corte().y - jugador.global_position.y
	_comprobar(sobre_pies < 0.85 and sobre_pies > 0.1,
		"la hoja baja a la maleza al mirar al suelo (%.2f m sobre los pies)"
		% sobre_pies)
	var antes := cesped.hojas_en_pie()
	Input.action_press("acelerador")
	for _i in 45:
		await physics_frame
	# La cuenta se mira con el acelerador PULSADO, porque al soltar la hoja
	# pone su contador a cero: es la cuenta del fotograma, no un total.
	var contadas := hoz.cortadas_ultimo
	# Solo hay una herramienta montada. Si se quedara la anterior en el grupo
	# tambien cortaria, y el jugador tendria dos herramientas cortando a la vez
	# sin saber por que: la desbrozadora escondida se enteraria del acelerador
	# igual que la de la mano.
	_comprobar(get_nodes_in_group("herramienta").size() == 1,
		"solo hay una herramienta montada, no dos")
	_comprobar(get_first_node_in_group("herramienta") == hoz,
		"y es la de la mano")
	Input.action_release("acelerador")
	var despues := cesped.hojas_en_pie()
	_comprobar(despues < antes, "la hoz recorta el cesped (%d -> %d hojas de pie)"
		% [antes, despues])
	_comprobar(contadas > 0, "y la hoja sabe cuantas hojas ha tumbado (%d)" % contadas)


# --- 6. Orden invertido ---------------------------------------------------

## Lo que de verdad prueba esto: soltar las dos y recogerlas al reves. Si el
## sistema metiera todo en el primer hueco libre, esto no se distinguiria de
## recogerlas en orden.
func _orden_invertido() -> void:
	print("== soltar las dos y recogerlas al reves ==")
	# Se suelta una, se elige la otra, y se suelta. Sin elegir entre medias se
	# soltaria dos veces la misma: G suelta lo de la mano, y la mano no cambia
	# sola.
	_inventario.seleccionar(0)
	var suelo_desbrozadora := _soltar()
	# Se camina unos metros antes de soltar la segunda. Sueltas las dos desde el
	# mismo sitio caen casi en el mismo punto, y entonces al mirar al suelo hay
	# una delante de la otra y el rayo coge la que pilla primero, que no es la
	# que se quiere coger. En juego no pasa: uno se mueve.
	_mover_jugador_a(Vector3(6.0, 0.95, 0.0))
	for _i in 30:
		await physics_frame
	_inventario.seleccionar(1)
	var suelo_hoz := _soltar()
	for _i in 60:
		await physics_frame
	_comprobar(_inventario.hay_hueco_libre(),
		"soltadas las dos hay huecos libres")
	_comprobar(_inventario.herramienta_equipada() == null,
		"nos quedamos sin nada en la mano")

	# Primero la hoz, que era la segunda.
	if suelo_hoz != null:
		await _apuntar_a(suelo_hoz)
		for _i in 4:
			await physics_frame
		_comprobar(_inventario.objeto_bajo_mirada() == suelo_hoz,
			"la mirada esta en la hoz")
		_inventario.recoger()
		_comprobar(_inventario.herramienta_de(_inventario.seleccion()).id == &"hoz",
			"la hoz cogida va al hueco 1")
		_comprobar(_inventario.herramienta_equipada() is Hoz,
			"y a la mano")

	# Y luego la desbrozadora, que era la primera.
	if suelo_desbrozadora != null:
		await _apuntar_a(suelo_desbrozadora)
		for _i in 4:
			await physics_frame
		_comprobar(_inventario.objeto_bajo_mirada() == suelo_desbrozadora,
			"la mirada esta en la desbrozadora")
		_inventario.recoger()
		_comprobar(_inventario.herramienta_de(_inventario.seleccion()).id
			== &"desbrozadora", "la desbrozadora cogida va al hueco 2")
		_comprobar(_inventario.herramienta_equipada() is Desbrozadora,
			"y a la mano")

	# Y el estado final: las dos en su sitio.
	_comprobar(_inventario.hay_algo(0) and _inventario.hay_algo(1),
		"las dos herramientas vuelven al inventario")
	_comprobar(_inventario.hay_hueco_libre(), "y quedan huecos libres")


# --- Utilidades -----------------------------------------------------------

## Coloca al jugador en un punto, para poder soltar las herramientas lejos una
## de otra.
func _mover_jugador_a(destino: Vector3) -> void:
	var jugador := _mundo.get_node_or_null("Player") as Jugador
	if jugador != null:
		jugador.global_position = destino


## Suelta lo de la mano y devuelve el cuerpo que ha aparecido. Se busca por
## diferencia y no por posicion porque el orden de `get_nodes_in_group` no esta
## garantizado, y comparar "el primero de la lista" daria el cuerpo de la
## herramienta que se solto antes.
func _soltar() -> RigidBody3D:
	var antes := _sueltos_en_el_mundo()
	_inventario.soltar_en_mano()
	for cuerpo in _sueltos_en_el_mundo():
		if not antes.has(cuerpo):
			return cuerpo
	return null


func _sueltos_en_el_mundo() -> Array[RigidBody3D]:
	var lista: Array[RigidBody3D] = []
	for nodo in get_nodes_in_group("suelto"):
		if nodo is RigidBody3D:
			lista.append(nodo as RigidBody3D)
	return lista


## Pon al jugador mirando a un objeto del suelo, desde un poco mas lejos, que es
## como se coge una cosa de verdad.
##
## Se apunta desde donde esta la CAMARA y no desde el ojo del personaje, porque
## el rayo de la recogida sale de la camara. Y secalcula el angulo con un
## `atan2` en vez de poner un `-12` a ojo: la camara lleva su propio limite de
## inclinacion (la vista baja sola cuando la maquina trabaja), y con un angulo
## aproximado el rayo se va por encima o por debajo de la caja segun el caso.
func _apuntar_a(objeto: RigidBody3D) -> void:
	var jugador := _mundo.get_node_or_null("Player") as Jugador
	if jugador == null:
		return
	var destino := objeto.global_position
	# A un metro y medio, que es mas o menos donde cae una herramienta que se
	# suelta de las manos.
	jugador.global_position = Vector3(destino.x, 0.95, destino.z + 1.5)
	await physics_frame
	var camara := jugador.get_node_or_null("Cabeza/Camara") as Camera3D
	if camara == null:
		return
	var direccion := (destino - camara.global_position).normalized()
	var yaw := atan2(-direccion.x, -direccion.z)
	var pitch := asin(clampf(direccion.y, -1.0, 1.0))
	jugador.mirar_a(yaw, pitch)


func _comprobar(ok: bool, que: String) -> void:
	if ok:
		print("  OK   %s" % que)
	else:
		print("  FAIL %s" % que)
		_fails += 1
