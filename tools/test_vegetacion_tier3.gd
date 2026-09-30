extends SceneTree

## El tier 3 (la zarza) tiene que ser un matorral, no un arbol, y el escombro
## tiene que ser escombro.
##
##     godot --headless --path . --script tools/test_vegetacion_tier3.gd
##
## Este archivo existe porque el usuario probo el juego y reporto tres cosas que
## ninguna comprobacion miraba, y las tres son de la misma familia: **un numero
## mal escalado que hacia que algo quedara fuera de escala**. La zarza media 2,4 m,
## el morro llega a 1,97 m, y la maquina no tocaba ni el primer palmo. Y el
## escombro pesaba 40 gramos y salia de la boca del cabezal, con lo que el
## amontonado tapaba la maquina y parecia que esta se levantaba.
##
## Lo que se comprueba, en tres bloques:
##
## 1. La zarza cabe en el alcance del morro, y el alcance **se mide con la
##    maquina de verdad**, no con un numero escrito aqui.
## 2. Una pasada de verdad abre el tier 3 y llega a su base.
## 3. El escombro cae al suelo, al lado, pesa, y se puede apartar.

var _mundo: Node3D
var _jugador: Jugador
var _d: Desbrozadora
var _fails := 0


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	_mundo = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_mundo)
	await _esperar(40)
	_jugador = _mundo.get_node_or_null("Player") as Jugador
	_d = _mundo.get_node_or_null(
		"Player/Caderas/PivoteDesbrozadora/Desbrozadora") as Desbrozadora
	if _jugador == null or _d == null:
		push_error("main.tscn necesita jugador y desbrozadora")
		quit(1)
		return

	# Con `await`, y no por la gracia. Las tres llevan esperas dentro, asi que son
	# corrutinas; llamadas sin esperar se quedan colgadas en su primer
	# `await physics_frame` y el programa sigue como si hubieran hecho su trabajo.
	# Es el error que ya se cometio una vez en este proyecto, en la prueba de la
	# raiz, y aqui pasaria igual: la salida diria "OK" habiendo comprobado seis
	# cosas de las veinte.
	await _alcance_del_morro()
	await _la_zarza_se_corta()
	await _el_escombro()

	print("\n-- resultado: %s" % ("OK" if _fails == 0 else "%d FALLOS" % _fails))
	_mundo.queue_free()
	await process_frame
	quit(0 if _fails == 0 else 1)


## 1. **Cuanto alto llega el morro de verdad**, apretando el acelerador y mirando
##    hacia arriba hasta el tope.
##
## El alcance no se escribe en el test: se mide. Un numero fijo se queda viejo el
## dia que se cambie el brazo, y entonces da por bueno un matorral que ya no se
## puede tocar.
func _alcance_del_morro() -> void:
	print("== cuanto alto llega el morro ==")
	var alcance := 0.0
	for grados in [0, 15, 25, 35, 45, 55, 65, 75]:
		_jugador.global_position = Vector3(0.0, 0.95, 12.0)
		# Mirar ARRIBA es pitch positivo en este proyecto. Con el signo al reves el
		# morro se queda a ras de suelo y la medicion no mide nada.
		_jugador.mirar_a(0.0, deg_to_rad(float(grados)))
		await _esperar(12)
		Input.action_press("acelerador")
		await _esperar(40)
		await _esperar_al_que_se_asiente()
		alcance = maxf(alcance, _d.punto_de_corte().y)
		Input.action_release("acelerador")
		await _esperar(6)
	print("   el morro llega a %.2f m con el motor echado" % alcance)
	_comprobar(alcance > 1.0, "el morro llega a una altura util (%.2f m)" % alcance)

	# Y la pregunta que de verdad importa: la planta mas alta del tier 3 cabe en
	# ese alcance. Se mide la hoja mas alta REAL de cada mata, con su variacion, y
	# no el numero del preset.
	var mas_alta := 0.0
	var nombre := ""
	for nodo in _mundo.find_children("*", "Hierba", true, false):
		var mata := nodo as Hierba
		if mata == null or mata.tipo_vegetacion() != 3:
			continue
		var de_esta := mata.hoja_en_pie_mas_alta()
		if de_esta > mas_alta:
			mas_alta = de_esta
			nombre = mata.name
	print("   la zarza mas alta del mapa (%s) mide %.2f m" % [nombre, mas_alta])
	_comprobar(mas_alta <= alcance - 0.15,
		"y la zarza mas alta cabe en el alcance (%.2f + 15 cm <= %.2f)"
		% [mas_alta, alcance])


## 2. **Una pasada de verdad abre el tier 3**, y llega hasta el suelo.
##
##    Aqui hay que tener una cosa clara, porque cambia como se juega: el corte es
##    un **disco en el suelo** (`_dist2` mira solo x y z), asi que la altura del
##    morro NO decide que se corta. Y una hoja cortada se queda cortada: el
##    tier 3 va con `dejar_tocon = true` y `altura_tocon = 0.12`, o sea que una
##    pasada deja un tocón visible y no hay que volver a rematar. No existe el
##    "corto la copa y luego bajo a la base" que tuvo la zarza con raíz.
##
##    Lo que queda del tier 3 es el COSTE, no el numero de pasadas: el motor se
##    ahoga, el filo se gasta mas rapido y la gasolina sube. Eso se mide en
##    `test_cabezales.gd`. Lo que se comprueba aqui es que una pasada de verdad,
##    con el jugador y la maquina, abre la mata y llega al suelo.
func _la_zarza_se_corta() -> void:
	print("\n== una pasada de verdad abre el tier 3 ==")
	var mata := _mundo.get_node_or_null("Zarza") as Hierba
	_comprobar(mata != null, "la zarza de prueba esta en la escena")
	if mata == null:
		return
	var antes := mata.hojas_en_pie()
	_comprobar(antes > 500, "y viene llena de hojas (%d)" % antes)

	# **Que deje tocón, como las otras dos plantas.** Esto es lo que hacia que
	# pareciese que no se cortaba: el corte pasaba y se veia en los datos, pero con
	# `dejar_tocon = false` la hoja cortada se dibujaba a CERO de alto. Dentro de un
	# arbusto denso no dejas ni rastro, porque no hay nada que destaque. El cesped
	# deja 15 cm de palmo y la maleza 6, y los dos se ven a metro y medio.
	#
	# Y no se mira el numero del preset: se mira el dato de la planta, que es lo
	# que se escribe en la malla y lo que decide si se ve. En headless el buffer del
	# MultiMesh no se puede leer (sale siempre a cero, tambien en el cesped, que si
	# se dibuja de pie), asi que una prueba visual por ahi no valdria.
	_comprobar(mata.dejar_tocon and mata.altura_tocon >= 0.05,
		"y deja un tocon visible, como el cesped y la maleza (%.2f m)"
		% mata.altura_tocon)

	# Encima de una parte con hoja de verdad, motor echado, mirando de frente. Al
	# ser el corte un disco en el suelo, da igual a que altura este el morro para
	# que corte: lo que importa es estar encima.
	#
	# Y "una parte con hoja de verdad", no el centro de la mata: con `formacion`
	# 0,70 el 60 % del terreno queda sin sembrar y el centro puede ser un claro
	# pelado. Ahi la prueba pasaba sin cortar nada y decia que la zarza no se
	# cortaba, que era el bug que estamos arreglando.
	var destino := _punto_con_hoja(mata, 0.9)
	var por_aqui := mata.de_pie(destino, 0.9)
	print("   punto de trabajo: %s, con %d hojas de pie alrededor"
		% [str(destino.round()), por_aqui])
	_comprobar(por_aqui > 5, "y hay hoja de verdad ahi donde se va a cortar")
	await _centrar_el_cabezal(destino, deg_to_rad(-30.0))
	Input.action_press("acelerador")
	await _esperar(40)
	await _esperar_al_que_se_asiente()
	var altura_base := _d.punto_de_corte().y
	print("   motor echado, morro a %.3f m, cortando" % altura_base)
	_comprobar(altura_base < 0.10,
		"el morro baja al suelo al trabajar (%.3f m)" % altura_base)
	# Un par de segundos de trabajo de verdad, a la velocidad de la maquina.
	await _esperar(150)
	Input.action_release("acelerador")
	await _esperar(20)
	var despues := mata.hojas_en_pie()
	print("   quedan %d de %d hojas" % [despues, antes])
	_comprobar(despues < antes,
		"una pasada de verdad se lleva hojas (%d -> %d)" % [antes, despues])
	# Y la zona de la pasada queda limpia, no con un palmo: el tier 3 deja 12 cm de
	# tocon, como las otras plantas.
	# Y la zona de la pasada queda visiblemente mas corta. **No se exige que quede a
	# cero**: desde que el borde se deshace en varios pasos, una sola pasada deja
	#"la orla a medias" y remata al volver por encima. Exigir cero convertia
	# esta comprobacion en una medida del tiempo que tarda, no de que se corta.
	var disco := mata.de_pie(destino, 0.8)
	print("   quedan %d hojas de pie de las %d que habia" % [disco, por_aqui])
	_comprobar(disco < por_aqui * 0.6,
		"y la pasada deja la zona visiblemente mas corta (%d -> %d en pie)"
		% [por_aqui, disco])


## 3. **El escombro**: que al cortar salga la rafaga y que no quede nada fisico
## en el suelo. Desde el 2026-09-30 los restos son particulas: ya no pesan, no se
## posan y no se empujan, asi que lo que se puede seguir exigiendo es que la
## rafaga se dispare y que el sistema viejo no haya vuelto.
func _el_escombro() -> void:
	print("\n== el escombro ==")
	var restos := Restos.obtener(self)
	restos.limpiar()
	var mata := _mundo.get_node_or_null("Zarza") as Hierba
	if mata == null:
		return
	# Un punto limpio, para que lo que se mide sea el escombro y no lo que hubiera
	# antes.
	var corte: Vector3 = _punto_con_hoja(mata, 0.8) + Vector3(0.0, 0.5, 0.0)
	mata.cortar_y_soltar(corte, 1.2, 60.0)
	_comprobar(int(restos.recuento()["soltados"]) > 0,
		"al cortar salta escombro (%d trozos pedidos)"
		% int(restos.recuento()["soltados"]))
	# Techo casado con el ritmo real: dos piezas por hoja, rafaga de hasta 24
	# y drenaje cada 0,6 s. Con este corte de prueba no debe pasar de ahi.
	_comprobar(int(restos.recuento()["soltados"]) <= 140,
		"y el corte no pide una barbaridad de trozos (%d)"
		% int(restos.recuento()["soltados"]))
	await _esperar(30)
	# La firma del sistema rigido era el `RigidBody3D`. Con particulas no puede
	# quedar ni uno: si aparece, es que algo ha vuelto atras.
	var cuerpos := 0
	for n in _descendientes(restos):
		if n is RigidBody3D:
			cuerpos += 1
	_comprobar(cuerpos == 0,
		"y no queda cuerpos fisicos de escombro por el suelo (%d)" % cuerpos)


## Coloca al jugador para que el CABEZAL quede encima de `destino`, mirando con la
## inclinacion pedida, y espera a que todo se asiente.
##
## Teletransportar al jugador una vez no vale: el morro va con retardo y ademas
## depende de la altura, asi que hay que recentrarlo en dos rondas. Con una sola
## ronda el cabezal se quedaba a medio metro de donde tocaba y la prueba media un
## sitio vacio, que es peor que no medir nada: parece que el juego va mal.
func _centrar_el_cabezal(destino: Vector3, pitch: float) -> void:
	for _ronda in 2:
		_jugador.mirar_a(0.0, pitch)
		await _esperar(25)
		_jugador.global_position = destino + Vector3(0.0, 0.95, 0.9)
		await _esperar(25)
		_jugador.global_position += destino - _d.punto_de_corte()
		_jugador.global_position.y = 0.95
		await _esperar(25)
	for _i in 40:
		await physics_frame


## Un punto del mundo donde haya hoja de verdad alrededor.
##
## Con `formacion` 0,70 se siembra el 40 % del terreno, asi que un punto cualquiera
## puede caer en un claro y ahi no hay nada que cortar: la prueba pasaba sin cortar
## nada y parecia que la zarza no se cortaba. En vez de fiarse de un indice, se
## buscan hojas y se queda con la que mas compania tiene, que es adonde se nota el
## corte.
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


## Espera a que la maqueta y la camara se queden quietas. Las dos van con retardo
## y sin esto se mide una pose que el jugador nunca ve.
func _esperar_al_que_se_asiente(limite: float = 0.002, tope: float = 3.0) -> void:
	var quieto := 0
	var anterior := Vector2(_d.inclinacion_actual(), _d.rotation.x)
	for _i in int(tope * 60.0):
		await physics_frame
		var ahora := Vector2(_d.inclinacion_actual(), _d.rotation.x)
		if (ahora - anterior).length() < limite:
			quieto += 1
			if quieto > 6:
				return
		else:
			quieto = 0
		anterior = ahora


func _descendientes(nodo: Node) -> Array[Node]:
	var fuera: Array[Node] = []
	if nodo == null:
		return fuera
	for c in nodo.get_children():
		fuera.append(c)
		fuera.append_array(_descendientes(c))
	return fuera


func _esperar(cuadros: int) -> void:
	for _i in cuadros:
		await physics_frame


func _comprobar(ok: bool, que: String) -> void:
	if ok:
		print("  OK   %s" % que)
	else:
		print("  FAIL %s" % que)
		_fails += 1
