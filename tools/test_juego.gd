extends SceneTree

## Pruebas automaticas de la base: movimiento, camara "en la cabeza" y
## desbrozadora. Se ejecuta sin ventana:
##
##     godot --headless --path . --script tools/test_juego.gd
##
## Sale con el codigo 1 si algo falla, para poder encadenarlo con &&.
##
## Se comprueban numeros, no imagenes. Al final se toma una captura y se mide
## con que porcentaje de pixeles no es negro, que es la forma barata de
## detectar que se ha dibujado el mundo y no solo el fondo.

var _empezado := false
var _ok := 0
var _fallos := 0
var _avisos := 0
var _fase := 0
var _t := 0.0

var mundo: Node3D
var jugador: Jugador
var camara: CamaraGopro
var herramienta: Desbrozadora
var _telemetrias_recibidas := 0
var _altura_maleza_probada := 0.0


func _process(_d: float) -> bool:
	if not _empezado:
		_empezado = true
		_correr()
	return false


func _correr() -> void:
	await _cargar()
	await _quedarse_en_el_suelo()
	await _andar()
	await _mirar()
	await _correr_prueba()
	await _bosque()
	await _giro_suave()
	# La hierba se mira antes que el acelerador: despues de encender el motor
	# ya hay hojas cortadas y no se puede comprobar que empiezan de pie.
	await _hierba_prueba()
	await _maleza_prueba()
	await _uv_prueba()
	await _regenerar_hierba()
	await _suelo_prueba()
	await _acelerador()
	await _cabezal_visible()
	await _movimiento_de_la_maquina()
	await _resistencia_prueba()
	await _mirar_arriba_prueba()
	await _tecla_atras()
	await _captura()
	_resumen()


# --- Utilidades -------------------------------------------------------

func _cargar() -> void:
	print("\n== carga de la escena ==")
	mundo = load("res://scenes/main.tscn").instantiate()
	root.add_child(mundo)
	await physics_frame
	await process_frame
	jugador = mundo.get_node_or_null("Player") as Jugador
	camara = mundo.get_node_or_null("Player/Cabeza/Camara") as CamaraGopro
	# La maquina cuelga de las caderas, no de la camara: la busca por el grupo
	# que ella misma se pone, para que moverla en la escena no rompa el test.
	herramienta = _primera_herramienta(mundo)
	_ok_si(jugador != null, "el jugador existe")
	_ok_si(camara != null, "la camara existe")
	_ok_si(herramienta != null, "la desbrozadora esta a mano")
	if herramienta != null:
		_ok_si(herramienta.modelo != null, "el modelo esta cargado")
		_ok_si(herramienta.giro != null, "el carrete giratorio existe")
		_ok_si(herramienta.corte != null, "el punto de corte existe")
		_ok_si(herramienta.has_signal("telemetria_actualizada"),
			"la herramienta publica telemetria para la futura interfaz")
		herramienta.telemetria_actualizada.connect(_recibir_telemetria)
	var modelo := jugador.get_node_or_null("Cuerpo/Modelo") as Node
	var torso := _nodo_por_nombre(modelo, "Torso") as Node3D
	var cuerpo := _nodo_por_nombre(modelo, "Personaje") as Node3D
	_ok_si(torso != null and torso.is_visible_in_tree(),
		"el torso del operario se ve desde la camara")
	_ok_si(cuerpo != null and cuerpo.is_visible_in_tree(),
		"las piernas y el cuerpo inferior se ven desde la camara")
	# El input map: si una accion no existe, Input.is_action_pressed avisa en
	# vez de fallar, y el juego se queda quieto sin avisar.
	for accion in ["mover_adelante", "mover_atras", "mover_izquierda",
			"mover_derecha", "correr", "saltar", "agacharse", "acelerador"]:
		_ok_si(InputMap.has_action(accion), "la accion %s existe" % accion)


func _quedarse_en_el_suelo() -> void:
	print("\n== gravedad y suelo ==")
	for _i in 90:
		await physics_frame
	_ok_si(jugador.is_on_floor(), "el jugador se apoya en el suelo")
	# El origen del jugador esta a los pies, asi que en el suelo es y = 0. Lo
	# que importa es que la cabeza quede a 1,62 m: la camara no puede estar
	# medio metro por el suelo.
	var altura_cabeza := camara.global_position.y
	print("   depuracion: jugador y=%.3f, cabeza y=%.3f, camara y=%.3f, camara local=%v"
		% [jugador.global_position.y, camara.get_parent().global_position.y,
		altura_cabeza, camara.position])
	_ok_si(absf(altura_cabeza - 1.62) < 0.05,
		"la camara queda a la altura de la cabeza (y = %.2f)" % altura_cabeza)


func _andar() -> void:
	print("\n== andar hacia delante ==")
	var antes := jugador.global_position
	var t0 := Time.get_ticks_msec()
	Input.action_press("mover_adelante")
	# Medio segundo andando, mirando al frente (yaw 0, o sea hacia -Z).
	for _i in 30:
		await physics_frame
	Input.action_release("mover_adelante")
	# Se frena con aceleracion, no de golpe: hay que darle tiempo.
	await _esperar(0.35)
	var d := jugador.global_position - antes
	# La camara mira hacia -Z, asi que andar es z negativa.
	_ok_si(d.z < -0.3, "W va hacia delante (dz = %.2f)" % d.z)
	_ok_si(absf(d.x) < 0.05, "no se va de lado (dx = %.2f)" % d.x)
	_ok_si(jugador.get_velocidad_plano() < 0.6, "se para al soltar")
	# Y la velocidad real: no teleportarse, acelerar.
	Input.action_press("mover_adelante")
	var vmax := 0.0
	for _i in 60:
		await physics_frame
		vmax = maxf(vmax, jugador.get_velocidad_plano())
	Input.action_release("mover_adelante")
	_ok_si(vmax > 2.5 and vmax < 3.4,
		"la velocidad es la de andar (%.2f m/s, esperado ~3.0)" % vmax)
	_ok_si(_sin_atasco(), "no se atraviesa el suelo")
	print("   (%.0f ms de pruebas de movimiento)" % (Time.get_ticks_msec() - t0))


func _mirar() -> void:
	print("\n== mirada con retardo ==")
	_raton(120, 0)
	# Un instante de nada: el retardo tarda en notarse. Con dos fotogramas
	# (que en headless son microsegundos) la camara casi no se ha movido.
	await _esperar(0.05)
	# El retardo se mide en el mundo, no en la rotacion local de la camara. La
	# camara cuelga del CUERPO, y el cuerpo no siempre mira donde el jugador (se
	# vuelve hacia donde camina), asi que su rotacion local no es la correccion:
	# lo que importa es cuanto se ha quedado atras la DIRECCION de la camara
	# respecto a la direccion de la mirada.
	var correccion := _error_de_camara(jugador.get_yaw())
	_ok_si(jugador.get_yaw() < -0.2,
		"el raton gira la cabeza (%.2f rad)" % jugador.get_yaw())
	_ok_si(correccion > 0.01,
		"la camara va con retraso (correccion %.2f grados)" % correccion)
	# Tras un tiempo debe llegar. Se le deja 1,5 s y no 0,6: tras un giro de
	# 120 grados de golpe la correccion baja a medias geometricas, y a 0,6 s
	# todavia le quedan un par de grados, que no es que la camara se quede
	# astrayada sino que aun esta llegando.
	await _esperar(1.5)
	var correccion_final := _error_de_camara(jugador.get_yaw())
	_ok_si(correccion_final < 1.0,
		"la camara alcanza la mirada (error %.2f grados)" % correccion_final)


func _correr_prueba() -> void:
	print("\n== correr y angular ==")
	await _asentar()
	var fov_andando: float = camara.fov
	var fov_caminando := fov_andando
	Input.action_press("mover_adelante")
	await _esperar(0.7)
	fov_caminando = camara.fov
	Input.action_press("correr")
	await _esperar(0.3)
	_ok_si(jugador.get_correr(), "el jugador sabe que esta corriendo")
	_ok_si(jugador.get_velocidad_plano() > 5.0,
		"corre mas rapido que andando (%.2f m/s)" % jugador.get_velocidad_plano())
	# El angular se abre al correr: eso es parte del efecto GoPro.
	await _esperar(0.7)
	_ok_si(camara.fov > fov_caminando + 5.0,
		"el angular se abre al correr (%.1f -> %.1f)" % [fov_caminando, camara.fov])

	# El bamboleo se mide sobre la altura de la camara, que es donde va el
	# bamboleo; si la camara estuviera clavada al cuerpo no se moveria nada.
	var minimo := 99.0
	var maximo := -99.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 400:
		await process_frame
		minimo = minf(minimo, camara.position.y)
		maximo = maxf(maximo, camara.position.y)
	_ok_si(maximo - minimo > 0.01,
		"la cabeza bambolea al correr (recorrido %.4f m)" % (maximo - minimo))
	Input.action_release("correr")
	Input.action_release("mover_adelante")


func _acelerador() -> void:
	print("\n== acelerador ==")
	await _asentar()
	_ok_si(herramienta.rpm < 1.0, "el motor empieza parado")
	Input.action_press("acelerador")
	# Con el acelerador el motor sube de vueltas y el carrete gira.
	var giro0 := herramienta.giro_carrete_acumulado()
	for _i in 60:
		await physics_frame
	var rpm := herramienta.rpm
	_ok_si(rpm > 3000.0, "las rpm suben con el acelerador (%.0f)" % rpm)
	_ok_si(herramienta.cortando, "con el motor en marcha dice que corta")
	_ok_si(_telemetrias_recibidas > 0,
		"la interfaz futura recibe actualizaciones mientras cambia el motor")
	var giro_acumulado := herramienta.giro_carrete_acumulado() - giro0
	_ok_si(giro_acumulado > 0.5,
		"el carrete gira (%.2f rad acumulados)" % giro_acumulado)
	# El eje importa mas que el giro. Este asset tiene el eje de la cuchilla en Y.
	# Se miran los tres ejes para que la prueba no pase leyendo un valor fijo.
	_ok_si(absf(herramienta.giro.rotation.z) < 0.001 and absf(herramienta.giro.rotation.x) < 0.001,
		"el carrete gira en Y, el eje de la cuchilla (z=%.3f x=%.3f)" % [
			herramienta.giro.rotation.z, herramienta.giro.rotation.x])
	# Y al parar el motor, baja.
	Input.action_release("acelerador")
	for _i in 90:
		await physics_frame
	_ok_si(herramienta.rpm < 50.0, "el motor se para (%.0f rpm)" % herramienta.rpm)
	_ok_si(not herramienta.cortando, "sin motor no corta")

	# El sonido. El fallo era que el WAV no venia en bucle: play() lo sonaba una
	# vez, se acababan los 2 segundos de sample y el motor se quedaba mudo para
	# siempre. Y como el codigo usaba una bandera propia en vez de preguntar si
	# seguia sonando, no lo volvia a arrancar nunca.
	var motor_sonido: AudioStreamPlayer3D = herramienta.motor_sonido
	_ok_si(motor_sonido != null, "la desbrozadora tiene reproductor de sonido")
	if motor_sonido != null:
		var flujo := motor_sonido.stream as AudioStreamWAV
		_ok_si(flujo != null, "y tiene el pitido del motor asignado")
		if flujo != null:
			_ok_si(flujo.loop_mode != AudioStreamWAV.LOOP_DISABLED,
				"el pitido se repite en bucle (modo %d, el 0 seria solo una vez)"
				% flujo.loop_mode)
			# El bucle tiene que cubrir el sample ENTERO, no un trozo. Con
			# data.size() en vez de la duracion salen 17.864 frames en vez de
			# 44.100 y el bucle se come solo el primer segundo.
			var frames := int(round(flujo.get_length() * flujo.mix_rate))
			_ok_si(flujo.loop_begin == 0 and flujo.loop_end >= frames - 2,
				"y el bucle cubre el sample entero (%.2f s, %d de %d frames)"
				% [flujo.get_length(), flujo.loop_end, frames])
		# Y con el motor en marcha tiene que estar sonando de verdad.
		Input.action_press("acelerador")
		for _i in 30:
			await physics_frame
		_ok_si(motor_sonido.playing, "con el acelerador el motor suena")
		Input.action_release("acelerador")


func _bosque() -> void:
	print("\n== bosque ==")
	var bosque := mundo.get_node_or_null("Bosque")
	_ok_si(bosque != null, "el bosque esta en la escena")
	if bosque == null:
		return
	var arboles := bosque.get_children()
	_ok_si(arboles.size() >= 30,
		"hay arboles de sobra para tener referencias (%d)" % arboles.size())
	# Ni pegados al punto de aparicion ni amontonados: para eso esta el radio
	# minimo y la separacion del generador.
	var cerca := 0
	var minimo := 1e9
	var previa := Vector2.ZERO
	for i in arboles.size():
		var p := Vector2((arboles[i] as Node3D).position.x, (arboles[i] as Node3D).position.z)
		if p.length() < 9.0:
			cerca += 1
		if i > 0:
			minimo = minf(minimo, p.distance_to(previa))
		previa = p
	_ok_si(cerca == 0, "no hay arboles encima del punto de aparicion")
	_ok_si(minimo > 0.5, "los arboles no se amontonan (separacion %.2f m)" % minimo)
	# Y que esten a distintas alturas: si fueran copias exactas se notaria que
	# son el mismo arbol repetido.
	var altas := {}
	for a in arboles:
		altas[snappedf((a as Node3D).scale.y, 0.01)] = true
	_ok_si(altas.size() >= 5, "los arboles tienen alturas distintas (%d)" % altas.size())
	# Colision: los arboles van en la capa 4, asi que el jugador tiene que
	# tenerla en la mascara o se atraviesa los troncos como si fueran humo.
	var arbol := arboles[0] as StaticBody3D
	_ok_si((jugador.collision_mask & arbol.collision_layer) != 0,
		"el jugador choca con los arboles (capa %d)" % arbol.collision_layer)


func _giro_suave() -> void:
	print("\n== el giro no pega un tirón ==")
	# Esto es lo que decia el usuario: al girar el raton a un lado, la camara se
	# colocaba recta de golpe. El ladeo salia del retraso de la mirada con un
	# multiplicador tan alto que se quedaba clavado en el tope, y en cuanto la
	# camara alcanzaba la mira se caia a cero en dos o tres fotogramas.
	# Se mide el rodillo cada 16 ms, pero el salto se mide en GRADOS POR SEGUNDO
	# y no por fotograma. Si se midiera por fotograma, la comprobacion solo
	# valdria a 60 fps: con el campo entero de hierba la maquina puede bajar de
	# 30, y entonces cada fotograma cubre mas tiempo y el salto sale mas grande
	# sin que el ladeo sea peor. Lo que hay que mirar es la velocidad, que es la
	# misma vaya como vaya la maquina.
	var medidas: Array[float] = []
	var tiempos: Array[int] = []
	_raton(90, 0)
	var t0 := Time.get_ticks_msec()
	var ultimo := -99
	while Time.get_ticks_msec() - t0 < 1400:
		await process_frame
		var t := Time.get_ticks_msec() - t0
		if t >= ultimo + 16:
			ultimo = t
			medidas.append(camara.ladeo_de_mirada())
			tiempos.append(t)
		# A mitad del recorrido se gira al reves, que es el peor caso: el signo
		# del ladeo tendria que dar la vuelta entera.
		if t > 600 and ultimo < 700:
			_raton(-160, 0)
			ultimo = 700
	var maximo := 0.0
	var alcance := 0.0
	for i in medidas.size():
		alcance = maxf(alcance, absf(medidas[i]))
		if i > 0:
			var dt := float(tiempos[i] - tiempos[i - 1]) / 1000.0
			if dt > 0.0:
				maximo = maxf(maximo, absf(medidas[i] - medidas[i - 1]) / dt)
	var durado := 1
	if not tiempos.is_empty():
		durado = maxi(1, tiempos[tiempos.size() - 1])
	print("   el rodillo llega a %.2f grados y va a %.0f grados por segundo"
		% [alcance, maximo])
	print("   medido a %d fotogramas por segundo"
		% int(float(medidas.size()) * 1000.0 / float(durado)))
	# Primero que se use el ladeo: si no se usa, el salto valdria cero y la
	# comprobacion de abajo no significaria nada.
	_ok_si(alcance > 0.5, "el ladeo acompaña al giro (%.2f grados)" % alcance)
	# Y que no de un tirón. El tope del ladeo son 2,4 grados, asi que un tirón de
	# verdad serian grados de golpe en un solo fotograma, con lo cual la
	# velocidad se va por las nubes. Con el arreglo va a unas decenas por
	# segundo; antes eran mas de 400 al deshacerse el ladeo.
	_ok_si(maximo < 150.0,
		"el ladeo se pone recto poco a poco (%.0f grados por segundo)" % maximo)


## El campo partido en cuadrantes. Lo que se mira aqui no es que se vea bien,
## que eso no se ve en headless, sino que al partirlo no se ha perdido ni
## duplicado ninguna hoja y que las cajas han salido lo bastante pequenas para
## que el culling sirva de algo.


func _cuadrantes_de_la_hierba(h: Hierba) -> void:
	var cuantos: int = h.num_cuadrantes()
	# El techo sale de como esta partido el campo, no de un numero escrito aqui.
	# El radio y el lado se ajustan en el Inspector, y con el 81 de antes la
	# prueba se rompia sola en cuanto se agrandaba el campo, sin que hubiera
	# cambiado nada de la siembra.
	var casillas: int = h.casillas_totales()
	_ok_si(cuantos > 20, "el campo se parte en varios cuadrantes (%d)" % cuantos)
	_ok_si(cuantos <= casillas,
		"y no en demasiados (%d de %d casillas, que es %d x %d de %.0f m)"
		% [cuantos, casillas, h.lado_de_casillas(), h.lado_de_casillas(),
			h.lado_cuadrante])

	# El invariante que de verdad importa: al repartir no se puede perder ni
	# duplicar ninguna hoja. Si aqui no cuadra, el campo tiene un agujero o una
	# hoja dibujada dos veces, y por mucho culling que se haga esta todo roto.
	var sumadas: int = 0
	var vacios: int = 0
	for n in cuantos:
		var h_en_este: int = h.hojas_de_cuadrante(n)
		sumadas += h_en_este
		if h_en_este == 0:
			vacios += 1
	_ok_si(sumadas == h.total(),
		"no se ha perdido ninguna hoja al partir (%d en los cuadrados, %d en total)"
		% [sumadas, h.total()])
	_ok_si(vacios == 0, "ningun cuadrado se ha quedado vacio (%d vacios)" % vacios)

	# Y que el corte sigue funcionando con las hojas repartidas: si el indice
	# local de cada hoja se calculara mal, al cortar se escribiria en el sitio
	# equivocado y el rastro saldria en un sitio y se cortaria en otro.
	var antes: int = h.total_de_pie()
	var sitio := Vector3.ZERO
	for i in h.total():
		if h.altura_hoja(i) > 0.99:
			sitio = h.posicion_hoja(i)
			break
	var cortadas: int = h.cortar(sitio, herramienta.radio_corte)
	_ok_si(cortadas > 0 and h.total_de_pie() == antes - cortadas,
		"cortar sigue bajando el recuento de las que quedan de pie (%d -> %d)"
		% [antes, h.total_de_pie()])
	_ok_si(h.de_pie(sitio, herramienta.radio_corte) == 0,
		"y ya no queda ninguna de pie en el sitio")

	# La caja de cada cuadrado. Con un solo MultiMesh para todo el campo la caja
	# seria tan grande que el motor no podria descartar nada. Con los cuadrados,
	# cada caja tiene que ser manejable: si un cuadrado
	# midiera casi el campo entero, el culling no habria servido de nada.
	var mayor: float = 0.0
	for n in cuantos:
		var caja: AABB = h.caja_de_cuadrante(n)
		mayor = maxf(mayor, maxf(caja.size.x, caja.size.z))
	_ok_si(mayor < h.lado_cuadrante * 2.0,
		"las cajas son manejables (la mayor mide %.1f m, el cuadrado es de %.0f)"
		% [mayor, h.lado_cuadrante])

	# Y el recorte por distancia, que filtra cuadrantes lejanos además del culling
	# de la vista.
	h.forzar_recorte(Vector3.ZERO)
	var sin_recorte: int = h.cuadrantes_visibles()
	var recorte_antes: float = h.distancia_maxima
	h.distancia_maxima = 10.0
	h.forzar_recorte(Vector3.ZERO)
	var con_recorte: int = h.cuadrantes_visibles()
	_ok_si(con_recorte < sin_recorte and con_recorte > 0,
		"con el recorte puesto se apagan los de lejos (%d de %d)"
		% [con_recorte, sin_recorte])
	h.distancia_maxima = recorte_antes
	# Ojo: la camara se pone en el centro, no "lejos". Si se pusiera muy lejos,
	# todos los cuadrados saldrian descartados y no se recuperaria ninguno.
	h.forzar_recorte(Vector3.ZERO)
	_ok_si(h.cuadrantes_visibles() == sin_recorte,
		"y volviendo a dejarlos todos se recuperan")


func _hierba_prueba() -> void:
	print("\n== hierba ==")
	var hierba := mundo.get_node_or_null("Hierba") as Hierba
	var maleza := mundo.get_node_or_null("MalezaAlta") as Hierba
	_ok_si(hierba != null, "la hierba esta en la escena")
	if hierba == null:
		return
	_ok_si(not _tiene_propiedad(hierba, "radio_corte")
		and (maleza == null or not _tiene_propiedad(maleza, "radio_corte")),
		"ningún campo de hierba define su propio radio de corte")
	_ok_si(hierba.total() > 10000, "hay hierba de verdad (%d hojas)" % hierba.total())
	_ok_si(hierba.total_de_pie() == hierba.total(), "al empezar esta toda de pie")
	_ok_si(herramienta.radio_corte > 0.0,
		"el cabezal define el ancho de corte común (radio %.2f m, %.0f cm)"
		% [herramienta.radio_corte, herramienta.radio_corte * 200.0])

	# Cortar en una hoja sembrada, no en una coordenada fija que puede caer en uno
	# de los claros del campo agrupado.
	var sitio := hierba.posicion_hoja(hierba.total() / 2)
	var cerca := hierba.de_pie(sitio, 1.0)
	var sitio_lejos := Vector3.ZERO
	for i in hierba.total():
		var candidata := hierba.posicion_hoja(i)
		if Vector2(candidata.x, candidata.z).distance_to(Vector2(sitio.x, sitio.z)) > 4.0:
			sitio_lejos = candidata
			break
	var lejos := hierba.de_pie(sitio_lejos, 1.0)
	_ok_si(cerca > 0, "la prueba toma un parche sembrado (%d hojas cerca)" % cerca)
	_ok_si(lejos > 0, "hay otro parche sembrado a mas de 4 m (%d hojas)" % lejos)
	# El techo se mide ANTES de cortar, y se mide con un disco mas ancho que el
	# cabezal. Asi el reparto en rejilla con azar puede dar hojas de mas sin que
	# la prueba se rompa, pero sigue valiendo si el cutter se pasa de largo y se
	# lleva medio campo: tendria que cortar muchisimas mas de las que hay ahi.
	# Ojo: de_pie cuenta las que siguen en pie, asi que esto va antes del corte,
	# o las hojas ya cortadas no contarian y la comparacion daria false.
	var alrededor := hierba.de_pie(sitio, herramienta.radio_corte * 1.6)
	var tumbadas := hierba.cortar(sitio, herramienta.radio_corte)
	print("   el cabezal en medio del parche tumba %d hojas" % tumbadas)
	_ok_si(tumbadas > 0, "el cabezal corta hierba de verdad")
	_ok_si(tumbadas <= alrededor,
		"y solo las de debajo suyo, no de mas (%d cortadas, y en el disco amplio habia %d)"
		% [tumbadas, alrededor])
	_ok_si(hierba.de_pie(sitio, herramienta.radio_corte) == 0,
		"dentro del radio del cabezal no queda hierba de pie")
	# Y que el ancho de corte sea el que dice el cabezal, ni mas ni menos. Se
	# mide contra el valor del cabezal y no contra un numero repetido en la prueba.
	var ancho := herramienta.radio_corte * 0.9
	var dentro_ancho := hierba.de_pie(sitio, ancho)
	_ok_si(dentro_ancho == 0,
		"dentro del ancho del cabezal no queda ni una hoja de pie (radio %.2f m)"
		% ancho)
	_ok_si(hierba.de_pie(sitio, 1.0) < cerca, "y queda un hueco en el cesped")
	_ok_si(hierba.de_pie(sitio_lejos, 1.0) == lejos,
		"el cesped de al lado no se ha tocado")
	_ok_si(hierba.cortar(sitio, herramienta.radio_corte) == 0,
		"volver a cortar lo mismo no cuenta dos veces")

	_cuadrantes_de_la_hierba(hierba)


	# La malla tiene que estar bien construida. Una malla sin lista de indices
	# se dibuja como triangulos sueltos, y si el numero de vertices no es
	# multiplo de 3 el servidor de desenho rechaza la llamada y no sale nada.
	# Ni peta ningun error ni aviso, asi que esto se mira a mano.
	var malla := hierba.malla() as ArrayMesh
	_ok_si(malla != null and malla.get_surface_count() == 1,
		"la hoja es una sola superficie")
	if malla != null and malla.get_surface_count() == 1:
		var arrays := malla.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		_ok_si(vertices.size() > 0, "la hoja tiene vertices (%d)" % vertices.size())
		if indices.is_empty():
			_ok_si(vertices.size() % 3 == 0,
				"sin indices, los %d vertices son triangulos enteros" % vertices.size())
		else:
			_ok_si(indices.size() % 3 == 0 and indices.size() / 3 >= 4,
				"con indices: %d vertices y %d triangulos"
				% [vertices.size(), indices.size() / 3])
			var maximo := 0
			for i in indices:
				maximo = maxi(maximo, i)
			_ok_si(maximo < vertices.size(),
				"y ningun indice se sale del(vertex %d de %d)"
				% [maximo, vertices.size()])
		# Ademas, la hoja tiene que medir de verdad: si la escala se perdiera,
		# el campo entero se dibujaria de un tamanho ridiculo.
		var alto := 0.0
		for v in vertices:
			alto = maxf(alto, v.y)
		_ok_si(alto > 0.5, "la hoja llega arriba (%.2f)" % alto)

	# Los datos que van a la GPU. instance_count se fija una sola vez porque
	# tocarlo otra vez borra el MultiMesh entero: si el campo se sembrara dos
	# veces, el recuento casaria y no se veria ni una hoja. Aqui se mira que las
	# hojas tienen alto, grosor y sitio de verdad, y que el recuento del
	# MultiMesh es el de las hojas buenas.
	# Lo que va a la GPU son los instance_count de cada MultiMesh. Antes de
	# partir el campo esto era una sola cifra; ahora hay que sumarlos, y si la
	# suma no cuadra con las hojas buenas es que al repartir se ha perdido o
	# duplicado alguna por el camino.
	var reservadas := 0
	for n in hierba.num_cuadrantes():
		reservadas += hierba.hojas_de_cuadrante(n)
	_ok_si(reservadas == hierba.total(),
		"los multimesh reservan exactamente las %d hojas (%d repartidas)"
		% [hierba.total(), reservadas])
	var alto_min := 99.0
	var alto_max := 0.0
	var gordo_min := 99.0
	var gordo_max := 0.0
	var dentro := 0
	var muestra := 0
	for i in range(0, hierba.total(), 977):
		muestra += 1
		alto_min = minf(alto_min, hierba.alto_de(i))
		alto_max = maxf(alto_max, hierba.alto_de(i))
		gordo_min = minf(gordo_min, hierba.gordo_de(i))
		gordo_max = maxf(gordo_max, hierba.gordo_de(i))
		var p := hierba.posicion_hoja(i)
		if p.x * p.x + p.z * p.z <= hierba.radio * hierba.radio:
			dentro += 1
	_ok_si(muestra > 20, "se pueden mirar hojas de verdad (%d)" % muestra)
	_ok_si(alto_min >= 0.02 and alto_max > alto_min * 1.3,
		"las hojas van de %.2f a %.2f de alto, no todas iguales" % [alto_min, alto_max])
	_ok_si(gordo_min > 0.0 and gordo_max > gordo_min,
		"y tambien de %.3f a %.3f de grosor" % [gordo_min, gordo_max])
	_ok_si(dentro == muestra, "y ninguna se ha quedado fuera del campo")

	# El viento. El mapa tiene que estar cambiando: si fuera fijo la hierba se
	# quedaria quieta y pareceria de papel.
	# Se busca por toda la escena y no en un sitio fijo: el viento es UNO para
	# todo el prado, no uno por campo de hierba, y hay que comprobar que vale
	# para los dos.
	var viento := _viento_de(mundo)
	_ok_si(viento != null, "el viento esta en la escena")
	if viento != null:
		# OJO: esto se mide en un TROZO del mapa y no en una celda suelta. Una
		# celda es un seno, y hay instantes en los que esta justo en un maximo o
		# en un minimo, donde en 1,5 s no se mueve casi nada: la prueba pasaba la
		# mitad de las veces y fallaba la otra sin que hubiera cambiado el viento.
		# La media de como se mueve un trozo entero es estable y dice lo mismo:
		# que el mapa se esta repintando.
		var celdas := viento.celdas
		var antes := PackedFloat32Array()
		for j in 12:
			for i in 12:
				antes.append(viento.fuerza_en(i, j))
		await _esperar(1.5)
		var movido := 0.0
		var mayor_cambio := 0.0
		var n := 0
		for j in 12:
			for i in 12:
				var ahora := viento.fuerza_en(i, j)
				var d: float = absf(ahora - antes[n])
				movido += d
				mayor_cambio = maxf(mayor_cambio, d)
				n += 1
		var medio := movido / maxf(float(n), 1.0)
		print("   el viento del mapa se mueve: %.4f de media, %.3f de golpe (celdas %d)"
			% [medio, mayor_cambio, celdas])
		_ok_si(medio > 0.005 and mayor_cambio > 0.05,
			"el viento de cada zona va cambiando (%.4f de media, %.3f de golpe)"
			% [medio, mayor_cambio])
		var mat := hierba.material_compartido()
		_ok_si(mat != null and mat.shader != null, "la hierba tiene su shader")
		_ok_si(mat != null and mat.get_shader_parameter("viento") != null,
			"el mapa del viento esta conectado a la hierba")
		# El mapa tiene que medir lo mismo que el campo, porque la UV de cada
		# hoja sale de ahi. Si no, cada hoja busca su celda en otro sitio.
		var radio_mayor := hierba.radio
		if maleza != null:
			radio_mayor = maxf(radio_mayor, maleza.radio)
		_ok_si(is_equal_approx(viento.lado_celda * viento.celdas,
			radio_mayor * 2.0),
			"el mapa del viento mide lo mismo que el campo (%.1f m)"
			% (viento.lado_celda * viento.celdas))
		var uv := hierba.uv_de_hoja(0)
		_ok_si(uv.x > 0.0 and uv.x < 1.0 and uv.y > 0.0 and uv.y < 1.0,
			"la hoja 0 tiene su sitio en el mapa (%.2f, %.2f)" % [uv.x, uv.y])

	# Y lo de verdad: andar con la desbrozadora encendida dejando rastro. Si el
	# jugador se queda quieto solo se cortan las dos o tres hojas que tiene
	# debajo, que no dice nada del sistema.
	jugador.global_position = Vector3.ZERO
	jugador.velocity = Vector3.ZERO
	await _asentar()
	var antes_total := hierba.total_de_pie()
	Input.action_press("acelerador")
	Input.action_press("mover_adelante")
	Input.action_press("correr")
	await _esperar(2.5)
	Input.action_release("correr")
	Input.action_release("mover_adelante")
	Input.action_release("acelerador")
	await _asentar()
	var rastro := antes_total - hierba.total_de_pie()
	print("   andando 2,5 s con el motor en marcha: %d hojas cortadas" % rastro)
	_ok_si(rastro > 30, "andar con la desbrozadora encendida deja rastro (%d)" % rastro)
	# El rastro tiene que estar en el camino que ha hecho el jugador, no por
	# cualquier sitio. Se mira un punto 6 m por delante de donde empezo.
	var por_delante := Vector3(0.0, 0.0, -6.0)
	_ok_si(hierba.de_pie(por_delante, 0.4) < hierba.total() * 0.02,
		"y el rastro esta en el camino que lleva")


## --- La maleza (segundo tipo de hierba) ---------------------------------
##
## El cesped corto es lo que hay por defecto. La maleza alta es un SEGUNDO
## campo, con su propia semilla y su propio material, y tiene que cumplir tres
## cosas: sembrarse en matas y no a pelo suelto, ser mas alta que el cesped
## (y que la cintura del operario, que es lo que hace que sea maleza y no
## hierba), y cortar con la misma maquina. Lo ultimo es lo importante: si la
## maleza salta por encima del radio de corte y no se corta, es decorado, y un
## decorado que no se puede cortar es un fallo, no un detalle.
func _maleza_prueba() -> void:
	print("\n== la maleza alta (segundo tipo) ==")
	var maleza := mundo.get_node_or_null("MalezaAlta") as Hierba
	_ok_si(maleza != null, "el segundo tipo de hierba esta en la escena")
	if maleza == null:
		return
	var cesped := mundo.get_node_or_null("Hierba") as Hierba
	_ok_si(maleza.total() > 1000,
		"la maleza se ha sembrado (%d hojas)" % maleza.total())
	_ok_si(cesped != null and maleza != cesped,
		"y es un campo aparte, no el cesped con otro nombre")
	_ok_si(maleza.tipo == 2, "lleva su propio tipo (2)")
	_ok_si(maleza.coste_maleza() > 1.0,
		"y cuesta mas que el cesped (x%.2f)" % maleza.coste_maleza())
	_ok_si(cesped != null and maleza.coste_maleza() > cesped.coste_maleza(),
		"el cesped sigue siendo el barato de cortar")

	# Mas alta que el cesped, y mas alta que el operario. Si la maleza le
	# llegaba a la cara habria que revisar el encuadre de la camara.
	# Se mide con las hojas de verdad, no con el alto del Inspector: lo que
	# importa es lo que se ve, y lo que se ve es lo que salio de la siembra.
	var alta_maleza := 0.0
	var alta_cesped := 0.0
	for i in maleza.total():
		if i % 53 == 0:
			alta_maleza = maxf(alta_maleza, maleza.alto_de(i))
	_altura_maleza_probada = alta_maleza
	if cesped != null:
		for i in cesped.total():
			if i % 53 == 0:
				alta_cesped = maxf(alta_cesped, cesped.alto_de(i))
	var alta_cadera: float = herramienta.altura_cadera
	print("   la maleza llega a %.2f m, el cesped a %.2f m y la cadera a %.2f m"
		% [alta_maleza, alta_cesped, alta_cadera])
	_ok_si(alta_maleza > alta_cesped * 1.4,
		"la maleza es bastante mas alta que el cesped (%.2f m)" % alta_maleza)
	_ok_si(alta_maleza > alta_cadera,
		"y le pasa la altura del operario (%.2f m)" % alta_maleza)

	# Y tiene que ser alcanzable. Si el cabezal no llega a cortarla, el jugador
	# puede dar con un muro verde y no hay manera de pasar. Se mide lo que el
	# cabezal saca con la inclinacion maxima.
	var morro_requerido := herramienta.morro_para_altura(
		alta_maleza, herramienta.altura_cadera)
	var altura_reproducida := herramienta.altura_del_cabezal(
		morro_requerido, herramienta.altura_cadera)
	var morro_maximo := deg_to_rad(
		herramienta.inclinacion_reposo + herramienta.inclinacion_alta)
	print("   morro requerido %.1f°, maximo %.1f°; altura %.2f m"
		% [rad_to_deg(morro_requerido), rad_to_deg(morro_maximo), altura_reproducida])
	_ok_si(morro_requerido <= morro_maximo
		and absf(altura_reproducida - alta_maleza) < 0.02,
		"el cabezal puede alcanzar la altura muestreada de la maleza")

	# Ambos tipos de vegetación se cortan con el mismo radio de la herramienta.
	_ok_si(herramienta.radio_corte > 0.0,
		"el cabezal proporciona el radio común para césped y maleza (%.2f m)"
		% herramienta.radio_corte)

	# Las matas. Con formacion alta la maleza sale a pedazos, no como una
	# alfombra: si saliera repartida por igual seria otro cesped, y entonces no
	# haria falta un segundo tipo.
	#
	# Se mide con una rejilla de puntos sueltos por el campo, preguntando si hay
	# maleza ahi, y contando la proporcion que sale vacia. Se comparan con los
	# numeros de la siembra y no con un umbral puesto aqui, porque asi la prueba
	# sigue diciendo algo verdad si alguien cambia formacion o densidad.
	_ok_si(maleza.formacion > 0.5, "la maleza viene en matas (formacion %.2f)"
		% maleza.formacion)
	var con_maleza := 0
	var probados := 0
	for gz in 60:
		for gx in 60:
			var p := Vector3(
				lerpf(-45.0, 45.0, float(gx) / 59.0), 0.0,
				lerpf(-45.0, 45.0, float(gz) / 59.0))
			probados += 1
			if maleza.de_pie(p, 0.30) > 0:
				con_maleza += 1
	var relleno := float(con_maleza) / float(probados)
	print("   el %d %% del campo tiene maleza a la altura del knee (0,3 m)"
		% int(relleno * 100.0))
	_ok_si(relleno < 0.9,
		"hay huecos de verdad entre mata y mata (lleno el %d %%)"
		% int(relleno * 100.0))
	_ok_si(relleno > 0.15,
		"pero el campo esta de verdad sembrado, no es un raton de mata (lleno el %d %%)"
		% int(relleno * 100.0))

	# Recuento por cuadrantes: el campo grande esta troceado y asi se dibuja.
	_ok_si(maleza.num_cuadrantes() > 0,
		"la maleza va troceada en %d cuadrantes de %d m"
		% [maleza.num_cuadrantes(), maleza.lado_de_casillas()])
	_ok_si(maleza.num_cuadrantes() < maleza.casillas_totales(),
		"y algunos quadrantes salen vacios, que es lo de las matas")

	# Y que el viento llega a los DOS materiales. Con la hierba partida en dos,
	# si el viento se queda colgado del primero la maleza se queda tiesa como
	# papel mientras el cesped ondea, y se nota muchísimo.
	var viento := _viento_de(mundo)
	_ok_si(viento != null, "sigue habiendo un solo nodo de viento")
	if viento != null:
		_ok_si(viento.campos_conectados() == 2,
			"el viento llega a los dos campos (%d)" % viento.campos_conectados())
		var m1 := maleza.material_compartido()
		var m2 := cesped.material_compartido() if cesped != null else null
		_ok_si(m1 != null and m2 != null and m1 != m2,
			"cada tipo tiene su material, si no serian la misma hierba")
		_ok_si(m1 != null and m1.get_shader_parameter("viento") != null
			and m1.get_shader_parameter("viento") == m2.get_shader_parameter("viento"),
			"y los dos mueven con el MISMO mapa de viento")
		# Los nombres del shader son color_pie y color_punta, no los del
		# Inspector (tono_pie, tono_punta): el uniform que consume el material se
		# llama distinto que la variable que lo rellena, y con el nombre mal
		# puesto get_shader_parameter() devuelve null en vez de avisar.
		var pie_maleza = m1.get_shader_parameter("color_pie") if m1 != null else null
		var pie_cesped = m2.get_shader_parameter("color_pie") if m2 != null else null
		_ok_si(pie_maleza != null and pie_cesped != null
			and not pie_maleza.is_equal_approx(pie_cesped),
			"pero cada uno con su color: la maleza es mas seca")
		var punta_maleza = m1.get_shader_parameter("color_punta") if m1 != null else null
		var punta_cesped = m2.get_shader_parameter("color_punta") if m2 != null else null
		_ok_si(punta_maleza != null and punta_cesped != null
			and not punta_maleza.is_equal_approx(punta_cesped),
			"y mas seca todavia en la punta")

	# Y por fin lo de verdad: se corta andando por encima.
	if cesped == null:
		return
	var hoja_objetivo := maleza.posicion_hoja(maleza.total() / 2)
	jugador.global_position = hoja_objetivo + Vector3(0.0, 0.0, 3.0)
	jugador.velocity = Vector3.ZERO
	await _asentar()
	var de_pie_antes := maleza.total_de_pie()
	Input.action_press("acelerador")
	Input.action_press("mover_adelante")
	await _esperar(2.5)
	Input.action_release("mover_adelante")
	Input.action_release("acelerador")
	await _asentar()
	var cortadas := de_pie_antes - maleza.total_de_pie()
	print("   andando por la maleza: %d de %d hojas cortadas"
		% [cortadas, de_pie_antes])
	_ok_si(cortadas > 0, "la maleza se corta andando por encima (%d)" % cortadas)
	# Lo cortado no desaparece: se queda pisado. Si se borrara, se notaria un
	# agujero en el cesped al levantar la vista.
	_ok_si(maleza.total_de_pie() < de_pie_antes,
		"y donde ha pasado el cabezal queda menos maleza (%d -> %d)"
		% [de_pie_antes, maleza.total_de_pie()])


## El recorte de UV cuando el radio cambia.
##
## Cada hoja lleva su sitio en el mapa del viento metido en el shader. Si el
## radio se cambia despues de sembrar y no se recalcula, las hojas que ya
## estaban siguen apuntando a la casilla que les tocaba con el radio viejo, y
## se ve un corrimiento en diagonal de la onda: el viento sopla bien en un
##usitio y en el de al lado va descuadrado.
func _uv_prueba() -> void:
	print("\n== UV del viento cuando cambia el radio ==")
	var maleza := mundo.get_node_or_null("MalezaAlta") as Hierba
	_ok_si(maleza != null, "el segundo tipo de hierba esta en la escena")
	if maleza == null:
		return
	var total := maleza.total()

	# Una hoja del CENTRO del campo, que es donde la UV esta bien metida en el
	# mapa. Con una de la periferia, al encoger el radio su UV se sale de 0..1
	# y no hay forma de distinguir un fallo de una hoja que simplemente ha
	# quedado fuera del mapa nuevo.
	var i := -1
	for j in total:
		if maleza.posicion_hoja(j).length() < 10.0:
			i = j
			break
	_ok_si(i >= 0, "hay hojas de prueba cerca del centro")
	if i < 0:
		return
	var p := maleza.posicion_hoja(i)
	var uv_antes := maleza.uv_de_hoja(i)
	print("   la hoja %d esta en (%.1f, %.1f) y su uv es (%.4f, %.4f)"
		% [i, p.x, p.z, uv_antes.x, uv_antes.y])
	_ok_si(uv_antes.x > 0.4 and uv_antes.x < 0.6 and uv_antes.y > 0.4 and uv_antes.y < 0.6,
		"y cae por el centro del mapa del viento")

	# Lo que se reescribe son los dos canales de la UV. Ni la altura que le
	# queda a la hoja ni el tono, que van con la hoja y no con el sitio donde se
	# busca su viento. Si al cambiar el radio se tocaran, se veria el cesped
	# cambiar de color o las hojas cortadas volver a levantarse.
	var antes := maleza.datos_de_hoja(i)
	var tono_esperado: float = maleza.tono_de(i)
	maleza.radio = maleza.radio * 0.5
	maleza.refresca_uv_de_viento()
	await _esperar(0.2)
	_ok_si(maleza.uv_rehechas() == total,
		"el refresco reescribe TODAS las hojas (%d de %d)"
		% [maleza.uv_rehechas(), total])
	var uv_medio := maleza.uv_de_hoja(i)
	print("   con el radio a la mitad, la uv pasa a (%.4f, %.4f)"
		% [uv_medio.x, uv_medio.y])
	_ok_si(p.distance_to(maleza.posicion_hoja(i)) < 0.001,
		"encoger el campo no mueve ni una hoja de sitio")
	_ok_si(not is_equal_approx(uv_medio.x, uv_antes.x),
		"pero si mueve la uv del viento, que si no va descuadrada")
	_ok_si(uv_medio.x > 0.4 and uv_medio.x < 0.6,
		"y la hoja del centro se queda en el centro del mapa nuevo")
	var despues := maleza.datos_de_hoja(i)
	_ok_si(is_equal_approx(despues.r, antes.r),
		"la altura que le queda a la hoja no se toca (%.3f)" % despues.r)
	_ok_si(is_equal_approx(despues.a, tono_esperado),
		"ni el tono, que va con la hoja y no con el mapa (%.3f)" % despues.a)
	_ok_si(absf(despues.g - uv_medio.x) < 0.0001
		and absf(despues.b - uv_medio.y) < 0.0001,
		"y lo que se reescribe es la uv y solo la uv")

	# Al devolver el radio, cada hoja vuelve a su sitio en el mapa.
	maleza.radio = maleza.radio * 2.0
	maleza.refresca_uv_de_viento()
	await _esperar(0.2)
	var uv_final := maleza.uv_de_hoja(i)
	_ok_si(absf(uv_final.x - uv_antes.x) < 0.0001
		and absf(uv_final.y - uv_antes.y) < 0.0001,
		"al devolver el radio cada hoja vuelve a su sitio en el mapa")

	# Y lo importante: que se rehace SOLO. Si esto no estuviera, el radio se
	# podria cambiar desde el Inspector con el juego en marcha y las uv se
	# quedarian viejas, sin avisar nadie. Esto es justo lo que hacia la
	# trampa de REVISION.md.
	maleza.radio = maleza.radio * 0.5
	await _esperar(0.5)
	var rehechas_solo := maleza.uv_rehechas()
	print("   sin llamar a mano, se han reescrito %d hojas" % rehechas_solo)
	_ok_si(rehechas_solo == total,
		"el campo se avisa solo y rehace las uv cuando el radio se mueve")
	_ok_si(not is_equal_approx(maleza.uv_de_hoja(i).x, uv_final.x),
		"y la uv de verdad ha cambiado, no solo el contador")
	maleza.radio = maleza.radio * 2.0
	await _esperar(0.5)


func _regenerar_hierba() -> void:
	print("\n== regenerar un campo de hierba ==")
	var hierba := mundo.get_node_or_null("Hierba") as Hierba
	_ok_si(hierba != null, "el campo de césped sigue disponible")
	if hierba == null:
		return
	var hojas_antes := hierba.total()
	hierba.regenerar()
	await process_frame
	_ok_si(hierba.total() == hojas_antes,
		"la regeneración conserva el reparto determinista (%d hojas)"
		% hierba.total())
	_ok_si(hierba.get_child_count() == hierba.num_cuadrantes(),
		"no deja cuadrantes antiguos duplicados (%d hijos, %d cuadrantes)"
		% [hierba.get_child_count(), hierba.num_cuadrantes()])
	_ok_si(hierba.total_de_pie() == hierba.total(),
		"el campo regenerado empieza sin hojas cortadas")
	var punto := hierba.posicion_hoja(hierba.total() / 2)
	var cortadas := hierba.cortar(punto, herramienta.radio_corte)
	_ok_si(cortadas > 0 and hierba.total_de_pie() == hierba.total() - cortadas,
		"la rejilla de corte se reconstruye con la siembra")


func _suelo_prueba() -> void:
	print("\n== suelo plano de pruebas ==")
	_ok_si(mundo.get_node_or_null("Terreno") == null
		and mundo.get_node_or_null("Aldea") == null,
		"no hay terreno procedural ni layout de aldea activos")
	var suelo := mundo.get_node_or_null("Suelo") as StaticBody3D
	_ok_si(suelo != null, "hay un cuerpo físico para el suelo plano")
	if suelo == null:
		return
	var suelo_malla := suelo.get_node_or_null("Malla") as MeshInstance3D
	_ok_si(suelo_malla != null and suelo_malla.mesh is PlaneMesh,
		"el suelo visible usa una malla plana")
	if suelo_malla == null or not suelo_malla.mesh is PlaneMesh:
		return
	var plano := suelo_malla.mesh as PlaneMesh
	_ok_si(is_equal_approx(plano.size.x, 160.0)
		and is_equal_approx(plano.size.y, 160.0),
		"el plano de pruebas mide 160 × 160 m")
	var colision := suelo.get_node_or_null("Colision") as CollisionShape3D
	_ok_si(colision != null and colision.shape is CylinderShape3D,
		"el suelo tiene una superficie física amplia")
	if colision == null or not colision.shape is CylinderShape3D:
		return
	var cilindro := colision.shape as CylinderShape3D
	_ok_si(is_equal_approx(cilindro.radius, 80.0)
		and is_equal_approx(cilindro.height, 0.4),
		"la colisión cubre el campo de pruebas")
	var altura_suelo := _suelo_fisico_en(Vector3.ZERO)
	_ok_si(absf(altura_suelo) < 0.01,
		"la superficie física está en Y=0 (%.3f m)" % altura_suelo)
	var mat := suelo_malla.material_override as ShaderMaterial
	_ok_si(mat != null, "el suelo lleva shader, no un color plano")
	if mat == null:
		return
	_ok_si(mat.shader != null, "y el shader esta cargado")
	# La superficie plana mantiene el material de tierra del prototipo inicial.
	var seca: Color = mat.get_shader_parameter("tierra_seca")
	var humeda: Color = mat.get_shader_parameter("tierra_humeda")
	_ok_si(seca.r > seca.b and humeda.r > humeda.b,
		"los tonos son tierra, no verde (%.2f, %.2f, %.2f)"
		% [seca.r, seca.g, seca.b])
	_ok_si(humeda.r < seca.r, "y hay una tierra mas oscura que la clara")


## La primera desbrozadora de la escena. Se busca por el grupo y no por la ruta
## de nodos, porque la maquina se movio de la camara a las caderas y asi el test
## no depende de donde cuelgue.
func _primera_herramienta(mundo: Node) -> Desbrozadora:
	for n in mundo.get_tree().get_nodes_in_group("herramienta"):
		if n is Desbrozadora:
			return n
	return null


func _cabezal_visible() -> void:
	print("\n== donde se ve la desbrozadora ==")
	# Las pruebas anteriores pueden mover al jugador para buscar maleza. Este
	# bloque mide la herramienta en el punto de aparicion, no en esa ladera.
	jugador.global_position = Vector3.ZERO
	jugador.velocity = Vector3.ZERO
	await _asentar()
	# mirar_a() en vez de raton: parse_input_event escala el "relative" de una
	# forma distinta segun el servidor de entrada, asi que los pixeles no son
	# fiables para colocar la mirada en un angulo exacto. El raton se prueba
	# aparte, en el bloque de "mirada con retardo".

	# 1) Mirando al horizonte, con la maquina colgada de la cadera. El motor esta
	# a la altura de la cintura, que es donde lo llevas de verdad, y desde ahi cae
	# mas de 60 grados por debajo de la linea de mira: con un encuadre de 100
	# grados no cabe. NO es un fallo: asi se ve cuando estas de pie mirando al
	# frente. Lo que se comprueba es que el motor este abajo a la derecha, que es
	# donde tiene que estar, y que el cabezal siga delante.
	jugador.mirar_a(jugador.get_yaw(), 0.0)
	await _esperar(0.5)
	var motor := _malla_de(herramienta, "Motor")
	_ok_si(herramienta.giro != null, "la herramienta tiene su nodo de giro montado")
	# Las coordenadas locales de la camara si valen: x positivo es derecha, y
	# negativo es por debajo del eje. No se usa unproject_position: con el
	# servidor de graficos dummy devuelve numeros disparatados aunque el punto
	# este dentro del encuadre.
	if motor != null:
		var dir := (motor.global_position - camara.global_position).normalized()
		var grados := rad_to_deg((-camara.global_transform.basis.z).angle_to(dir))
		var local: Vector3 = camara.to_local(motor.global_position)
		print("   el motor esta a %.1f grados del centro de la mira" % grados)
		_ok_si(local.x > 0.05, "el motor sale a la derecha (x = %.2f m)" % local.x)
		_ok_si(local.y < -0.2, "el motor va a la altura de la cintura (y = %.2f m)" % local.y)

	# 2) Mirando al suelo, que es la postura de trabajo: ahi la maquina se ve
	# entera, y es donde se corta. El motor tiene que entrar en el encuadre.
	jugador.mirar_a(jugador.get_yaw(), deg_to_rad(-50.0))
	await _esperar(0.5)
	_ok_si(jugador.get_pitch() < -0.5,
		"la mirada baja hacia el suelo (%.2f rad)" % jugador.get_pitch())
	var corte := herramienta.punto_de_corte()
	var suelo_corte := _suelo_fisico_en(corte)
	_ok_si(absf(corte.y - suelo_corte) < 0.06,
		"el cabezal apoya en el collider del suelo (y = %.2f, suelo %.2f)"
		% [corte.y, suelo_corte])
	# Lo que importa para el encuadre es lo lejos que va por delante, no la
	# distancia en linea recta: con la cabeza a 1,6 m y el cabezal en el suelo
	# la distancia total siempre es grande.
	var por_delante := (corte - camara.global_position).dot(-camara.global_transform.basis.z)
	_ok_si(por_delante > herramienta.alcance * 0.7
		and por_delante < herramienta.alcance * 1.4,
		"el cabezal queda dentro de su alcance de trabajo (%.2f / %.2f m)"
		% [por_delante, herramienta.alcance])
	if motor != null:
		_ok_si(camara.is_position_in_frustum(corte),
			"al trabajar se ve el cabezal")

	# 3) El cabezal NO se puede perder de vista. La posición depende de la pose y
	# del alcance; la cámara debe comprobar el punto real y mantenerlo en pantalla.
	# Se recorre TODA la gama de inclinacion que se le puede pedir.
	_soltar_todo()
	var perdidos := 0
	var mirados := 0
	for grados in [-80.0, -55.0, -42.0, -25.0, -10.0, 0.0, 15.0, 30.0, 45.0, 60.0]:
		jugador.mirar_a(jugador.get_yaw(), deg_to_rad(grados))
		await _esperar(0.35)
		mirados += 1
		if not camara.is_position_in_frustum(herramienta.punto_de_corte()):
			perdidos += 1
			print("   el cabezal se pierde mirando a %.0f grados" % grados)
	_ok_si(perdidos == 0,
		"el cabezal se ve en toda la gama de inclinacion (%d de %d)"
		% [mirados - perdidos, mirados])
	# Y mirando al tope de arriba, que es el caso dificil.
	jugador.mirar_a(jugador.get_yaw(), deg_to_rad(90.0))
	await _esperar(0.4)
	_ok_si(jugador.get_pitch() <= deg_to_rad(jugador.limite_pitch_arriba) + 0.01,
		"mirando arriba se para en el tope (%.0f de %.0f)"
		% [rad_to_deg(jugador.get_pitch()), jugador.limite_pitch_arriba])
	_ok_si(camara.is_position_in_frustum(herramienta.punto_de_corte()),
		"y aun asi el cabezal sigue en la foto")


## La tecla S. Andar hacia atras es lo mas tonto que hay y no puede salir raro.
##
## Antes salia rarísimo: la camara cuelga del CUERPO, y como el cuerpo se vuelve
## de espaldas al andar de espaldas, la camara se veia arrastrada y el mundo
## daba un tiron de 180 grados al pulsar S. Va en su propia prueba y despues de
## la de la maquina, porque deja al cuerpo de espaldas y eso torcia las medidas.


## --- La resistencia ------------------------------------------------------
##
## El motor y el barrido tienen quenotarse al meterse en la maleza. No es
## una prueba de numeros cerrados, que lo de la fuerza exacta va a querer
## cambiarse mil veces: lo que se mira es que el orden sea el de verdad. En un
## claro va mas rapido que en el cesped, y en el cesped mas rapido que en la
## maleza cerrada. Si eso se cumple, el sistema esta haciendo su trabajo.
func _resistencia_prueba() -> void:
	print("\n== la resistencia de la maleza ==")
	_ok_si(herramienta.densidad_corte > 0.0,
		"hay una densidad de referencia (%.0f por m2)" % herramienta.densidad_corte)
	_ok_si(herramienta.frenao_motor > 0.0 and herramienta.frenao_barrido > 0.0,
		"y frena algo de verdad (motor %.2f, barrido %.2f)"
		% [herramienta.frenao_motor, herramienta.frenao_barrido])
	# Con el motor parado no hay frenao. Ni que la maleza sea un muro: mientras
	# no corta, la maquina esta quieta y no se nota nada.
	jugador.global_position = Vector3.ZERO
	jugador.velocity = Vector3.ZERO
	await _asentar()
	Input.action_release("acelerador")
	await _esperar(0.6)
	_ok_si(not herramienta.cortando and herramienta.resistencia() < 0.02,
		"con el motor parado no se nota el peso (%.2f)" % herramienta.resistencia())

	# Y ahora en marcha, por el cesped, que es lo que pisa el jugador primero.
	Input.action_press("acelerador")
	Input.action_press("mover_adelante")
	await _esperar(1.6)
	var en_cesped := herramienta.resistencia()
	var barrido_cesped: float = herramienta.rpm_efectiva()
	print("   por el cesped: densidad %.0f por m2, resistencia %.2f, %d rpm"
		% [herramienta.densidad_debajo(), en_cesped, barrido_cesped])
	_ok_si(herramienta.densidad_debajo() > 5.0,
		"la maquina nota donde pisa (%.0f por m2 de maleza debajo)"
		% herramienta.densidad_debajo())
	_ok_si(en_cesped > 0.05,
		"y el cesped frena de verdad, no solo de nombre (%.2f)" % en_cesped)
	_ok_si(barrido_cesped > 0.0 and barrido_cesped < 9000.0,
		"y las rpm bajan por debajo de las libres (%d de 9000)" % barrido_cesped)
	await _esperar(1.0)
	Input.action_release("mover_adelante")
	Input.action_release("acelerador")
	await _asentar()

	# En un claro tiene que ir mas suelta que en la maleza. Se usa el metodo que
	# cuenta las hojas por debajo del cabezal, que es el mismo que usa el juego,
	# para comparar los dos sitios sin tener que esperar a estar en un sitio
	# concreto del mapa.
	var maleza := mundo.get_node_or_null("MalezaAlta") as Hierba
	_ok_si(maleza != null, "con la maleza a mano para comparar")
	if maleza == null:
		return
	var d_claro: float = maleza.densidad_bajo(Vector3(0.0, 0.0, 5000.0), 0.73)
	var d_maleza: float = maleza.densidad_bajo(
		maleza.posicion_hoja(0), herramienta.radio_corte)
	print("   un claro %.1f por m2, dentro de la maleza %.1f por m2"
		% [d_claro, d_maleza])
	_ok_si(d_maleza > d_claro,
		"dentro de la maleza hay mas hojas que en un claro (%.1f contra %.1f)"
		% [d_maleza, d_claro])
	# Y el coste: dos hojas de maleza valen mas que dos de cesped. Sin esto, la
	# maleza seria solo "mas densa" y se comportaria igual de cara, que es
	# justo lo que no se quiere.
	_ok_si(maleza.coste_maleza() > 1.0,
		"y ademas cada hoja suya cuesta mas (x%.2f)" % maleza.coste_maleza())
	_ok_si(herramienta.anticipacion_resistencia > herramienta.radio_corte * 0.4,
		"mira por delante del cabezal, no debajo (%.2f m de anticipacion)"
		% herramienta.anticipacion_resistencia)


## --- Mirar para arriba ----------------------------------------------------
##
## Antes de la fase 2 el morro se quedaba clavado en su Angulo de reposo para
## cualquier mirar, con lo cual el cabezal no pasaba de 0,35 m: no habia forma
## de cortar nada por encima de la rodilla. Ahora, mirando arriba, la maquina
## sube. Y lo que se mira es la altura de verdad del cabezal en el mundo, no el
## angulo, que puede subir y que el cabezal se hunda igualmente.
func _mirar_arriba_prueba() -> void:
	print("\n== mirar para arriba ==")
	var altura_manos: float = herramienta.altura_cadera
	# Con el motor echado y la vista al frente, el cabezal esta donde siempre,
	# abajo, y eso no se ha tocado.
	Input.action_release("acelerador")
	jugador.global_position = Vector3.ZERO
	jugador.velocity = Vector3.ZERO
	await _asentar()
	jugador.mirar_a(0.0, herramienta.mirar_alto)
	await _esperar(1.0)
	var arriba_parado: float = herramienta.altura_del_cabezal(
		herramienta.inclinacion_actual(), altura_manos)
	_ok_si(arriba_parado > 0.6,
		"mirando arriba el cabezal sube aunque el motor este parado (%.2f m)"
		% arriba_parado)
	jugador.mirar_a(0.0, 0.0)
	await _esperar(0.6)
	Input.action_press("acelerador")
	await _esperar(0.5)
	var baja: float = herramienta.altura_del_cabezal(
		herramienta.inclinacion_actual(), altura_manos)
	print("   con la vista al frente, el cabezal esta a %.2f m" % baja)
	_ok_si(baja < 0.6, "con la vista al frente el cabezal sigue abajo (%.2f m)" % baja)

	# Y mirando arriba tiene que subir de verdad, y llegar a la maleza.
	jugador.mirar_a(0.0, herramienta.mirar_alto)
	await _esperar(1.5)
	var arriba: float = herramienta.altura_del_cabezal(
		herramienta.inclinacion_actual(), altura_manos)
	print("   mirando arriba, el cabezal llega a %.2f m" % arriba)
	_ok_si(arriba > baja + 0.6,
		"mirando arriba el cabezal sube de verdad (de %.2f a %.2f m)"
		% [baja, arriba])
	var maleza := mundo.get_node_or_null("MalezaAlta") as Hierba
	if maleza != null:
		_ok_si(arriba >= _altura_maleza_probada * 0.9,
			"y llega a la parte alta muestreada de la maleza (%.2f m, hoja %.2f m)"
			% [arriba, _altura_maleza_probada])
		# Y el cabezal no se sale de la pantalla, que es el otro fallo: subirlo
		# tanto que disappears de la camara no es cortarlo, es no verlo.
		var cabeza := _punta_del_cabezal(herramienta)
		_ok_si(cabeza != Vector3.ZERO
			and camara.is_position_in_frustum(cabeza),
			"y se ve la punta del cabezal (%.2f, %.2f, %.2f), que si no parece que no hace nada"
			% [cabeza.x, cabeza.y, cabeza.z])
	Input.action_release("acelerador")
	jugador.mirar_a(0.0, 0.0)
	await _esperar(2.5)
	_ok_si(herramienta.altura_del_cabezal(
			herramienta.inclinacion_actual(), altura_manos) < arriba,
		"y al volver la vista al frente el cabezal baja otra vez")


func _tecla_atras() -> void:
	print("\n== la tecla S ==")
	_soltar_todo()
	await _esperar(0.6)
	var antes := jugador.global_position
	# Se mira a un sitio fijo antes de medir, para que el angulo que se compara
	# sea el de la marcha y no el del raton.
	jugador.mirar_a(jugador.get_yaw(), deg_to_rad(-25.0))
	await _esperar(0.4)
	var mira_antes := -camara.global_transform.basis.z
	Input.action_press("mover_atras")
	await _esperar(0.9)
	var andado := jugador.global_position - antes
	_ok_si(andado.length() > 0.05,
		"con S el jugador se mueve (%.2f m)" % andado.length())
	# Hacia atras es hacia detras de donde mira, no hacia delante.
	_ok_si(andado.normalized().dot(mira_antes) < -0.7,
		"y va hacia atras de la mira (%.2f, -1 es justo atras)"
		% andado.normalized().dot(mira_antes))
	# Y aqui esta lo importante: la camara no se ha dado la vuelta.
	var gira := rad_to_deg(mira_antes.angle_to(-camara.global_transform.basis.z))
	_ok_si(absf(gira) < 12.0,
		"la camara no se da la vuelta al pulsar S (%.1f grados)" % gira)
	# Y tampoco se ha caído del plano: el jugador sigue en el suelo.
	_ok_si(jugador.is_on_floor(),
		"y sigue en el suelo y no se ha ido por las ramas")
	# Se deja todo como estaba para no molestar a las pruebas siguientes.
	_soltar_todo()
	jugador.mirar_a(0.0, deg_to_rad(-25.0))
	await _esperar(1.2)


## La maquina colgada del arnes: topes asimetricos, peso, retardo de las caderas
## y apoyo en el suelo.
func _movimiento_de_la_maquina() -> void:
	print("\n== como se mueve la maquina ==")

	# Se sueltan las teclas antes de empezar: el cuerpo gira hacia donde caminas,
	# asi que una tecla pulsada del bloque anterior lo lleva girando solo y todas
	# las medidas de aqui salen torcidas.
	_soltar_todo()
	await _esperar(1.0)
	var caderas := herramienta.get_parent().get_parent() as Node3D

	# 1) Va colgada de las caderas, no de la camara.
	_ok_si(caderas != null and caderas.name == "Caderas",
		"la maquina cuelga de las caderas")
	_ok_si(camara.get_parent().get_node_or_null("PivoteDesbrozadora") == null,
		"y ya no cuelga de la camara")

	# 2) La maquina va por delante de las caderas. Se mira de golpe a un lado y se
	# mira quien va mas cerca de la mira. Al rato tienen que estar los tres.
	var cuerpo_antes := jugador.rotation.y
	jugador.mirar_a(jugador.get_yaw() + deg_to_rad(60.0), 0.0)
	await _esperar(0.12)
	var e_maquina := _error_de_mirada(herramienta, jugador.get_yaw())
	var e_caderas := _error_de_mirada(caderas, jugador.get_yaw())
	var e_cuerpo := _error_de_mirada(jugador, jugador.get_yaw())
	print("   al girar de golpe: maquina %.1f, caderas %.1f, cuerpo %.1f grados"
		% [rad_to_deg(e_maquina), rad_to_deg(e_caderas), rad_to_deg(e_cuerpo)])
	_ok_si(e_maquina < e_caderas - deg_to_rad(1.0),
		"la maquina va por delante de las caderas (%.1f de %.1f)"
		% [rad_to_deg(e_maquina), rad_to_deg(e_caderas)])
	# Y el cuerpo NO se gira con la mirada. Es a proposito: si se girara, las
	# caderas no tendrian nada que seguir y el arnes no pareceria un arnes. El
	# cuerpo solo se vuelve hacia donde caminas, que se comprueba mas abajo.
	_ok_si(is_equal_approx(jugador.rotation.y, cuerpo_antes),
		"el cuerpo no se ha movido de donde estaba (%.1f -> %.1f grados)"
		% [rad_to_deg(cuerpo_antes), rad_to_deg(jugador.rotation.y)])

	# 3) LOS TOPES DEL ARNES. Es lo nuevo y lo importante: no es simetrico. Con el
	# arnes en la cadera derecha se puede barrer mucho mas a la izquierda que a
	# la derecha. Se mira muy de lado y se mide hasta donde llega la maquina en
	# cada sentido.
	# El cuerpo se queda mirando donde lo dejo el ultimo paseo, y si no se
	# recentra las medidas salen mal: habria que estar midiendo el arco que se
	# puede desde un cuerpo mirando a un lado cualquiera. Se recentra a proposito.
	jugador.rotation.y = 0.0
	jugador.mirar_a(0.0, 0.0)
	await _esperar(2.0)
	_ok_si(absf(herramienta.angulo_barrido()) < deg_to_rad(2.0),
		"con el cuerpo al frente el barrido vuelve a cero (%.1f grados)"
		% rad_to_deg(herramienta.angulo_barrido()))
	var t0 := Time.get_ticks_msec()
	var tope_izq := await _empujar_barrido(1.0)
	var tardo_izq := (Time.get_ticks_msec() - t0) / 1000.0
	t0 = Time.get_ticks_msec()
	var tope_der := await _empujar_barrido(-1.0)
	var tardo_der := (Time.get_ticks_msec() - t0) / 1000.0
	jugador.rotation.y = 0.0
	print("   tope: izquierda %.0f, derecha %.0f grados"
		% [rad_to_deg(tope_izq), rad_to_deg(tope_der)])
	# Y cuanto tarda en recorrerlo: el lado derecho es corto y topa antes, asi que
	# se llega antes. El izquierdo es largo, y aunque pesa mas tiene que
	# recorrer bastante mas.
	print("   tardado: izquierda %.2f s, derecha %.2f s"
		% [tardo_izq, tardo_der])
	_ok_si(tope_izq > deg_to_rad(60.0),
		"a la izquierda se barre lejos (%.0f grados)" % rad_to_deg(tope_izq))
	_ok_si(tope_der > -deg_to_rad(50.0) and tope_der < -deg_to_rad(20.0),
		"a la derecha topa antes (%.0f grados)" % rad_to_deg(tope_der))
	_ok_si(tope_izq > -tope_der + deg_to_rad(30.0),
		"y el arco es mas largo a la izquierda que a la derecha")
	# Con margen: el muelle se acerca al tope de forma asintotica, asi que llega
	# a una fraccion de grado del tope, no exactamente al tope.
	var margen := deg_to_rad(1.0)
	_ok_si(absf(tope_izq - deg_to_rad(herramienta.max_left_angle)) < margen,
		"el tope izquierdo es el que se ha puesto (%.1f de %.0f)"
		% [rad_to_deg(tope_izq), herramienta.max_left_angle])
	_ok_si(absf(tope_der + deg_to_rad(herramienta.max_right_angle)) < margen,
		"y el derecho tambien (%.1f de -%.0f)"
		% [rad_to_deg(tope_der), herramienta.max_right_angle])

	# 3b) EL BARRIDO A PROPOSITO CON A Y D. Mirando al frente, sin mover la
	# cabeza, A y D tambien barren: es la misma tecla que sirve para andar de
	# lado. El valor del export esta en grados, y esta comprobacion es la que
	# vigila que no se lea como radianes por error.
	jugador.rotation.y = 0.0
	jugador.mirar_a(0.0, 0.0)
	await _esperar(2.0)
	_ok_si(absf(herramienta.angulo_barrido()) < deg_to_rad(2.0),
		"mirando al frente la maquina esta en el centro (%.1f grados)"
		% rad_to_deg(herramienta.angulo_barrido()))
	var pedido := deg_to_rad(herramienta.barrido_teclado)
	Input.action_press("mover_derecha")
	await _esperar(3.0)
	var con_d := herramienta.angulo_barrido()
	Input.action_release("mover_derecha")
	_ok_si(con_d < -pedido * 0.7 and con_d > -pedido * 1.3,
		"D echa la maquina a la derecha unos %.0f grados (%.1f)"
		% [herramienta.barrido_teclado, rad_to_deg(con_d)])
	await _esperar(2.0)
	Input.action_press("mover_izquierda")
	await _esperar(3.0)
	var con_a := herramienta.angulo_barrido()
	Input.action_release("mover_izquierda")
	_ok_si(con_a > pedido * 0.7 and con_a < pedido * 1.3,
		"A echa la maquina a la izquierda unos %.0f grados (%.1f)"
		% [herramienta.barrido_teclado, rad_to_deg(con_a)])
	# Y al soltar vuelve al centro, que es donde esta la cabeza mirando al frente.
	await _esperar(3.0)
	_ok_si(absf(herramienta.angulo_barrido()) < deg_to_rad(2.0),
		"al soltar vuelve al centro (%.1f grados)"
		% rad_to_deg(herramienta.angulo_barrido()))

	# 3c) A Y D NO GIRAN EL CUERPO. Es la regla que hace posible lo de arriba:
	# si el cuerpo se girase al esquivar, la maquina se mediria respecto a un
	# cuerpo que acaba de dar media vuelta y D barreria hacia el lado contrario
	# del pedido. Esquivar de lado no gira el torso; avanzar, si.
	jugador.rotation.y = 0.0
	jugador.mirar_a(0.0, 0.0)
	Input.action_press("mover_derecha")
	await _esperar(1.0)
	_ok_si(is_equal_approx(jugador.rotation.y, 0.0),
		"esquivar a la derecha no gira el cuerpo (%.1f grados)"
		% rad_to_deg(jugador.rotation.y))
	Input.action_release("mover_derecha")
	await _esperar(1.0)
	jugador.mirar_a(0.0, 0.0)
	Input.action_press("mover_adelante")
	await _esperar(1.0)
	_ok_si(absf(jugador.rotation.y) < deg_to_rad(5.0),
		"pero avanzar si lo gira (%.1f grados)" % rad_to_deg(jugador.rotation.y))
	Input.action_release("mover_adelante")
	await _esperar(1.0)
	jugador.rotation.y = 0.0
	jugador.mirar_a(0.0, 0.0)
	await _esperar(2.0)

	# 4) EL PESO. La maquina no llega de golpe: hay un retardo medible entre
	# pedir el barrido y que llegue. Y si la pide en un solo paso, el arranque
	# tiene que ser mas lento que la velocidad de crucero, que es lo que pesa.
	jugador.mirar_a(0.0, 0.0)
	await _esperar(2.0)
	var antes := herramienta.angulo_barrido()
	jugador.mirar_a(deg_to_rad(70.0), 0.0)
	await _esperar(0.10)
	var a_los_100ms := absf(herramienta.angulo_barrido() - antes)
	await _esperar(2.5)
	var al_final := absf(herramienta.angulo_barrido() - antes)
	_ok_si(a_los_100ms > 0.0, "la maquina arranca a moverse (%.0f grados a 0,1 s)"
		% rad_to_deg(a_los_100ms))
	_ok_si(a_los_100ms < al_final * 0.5,
		"pero despacio: a los 0,1 s solo lleva el %.0f%% del recorrido"
		% (100.0 * a_los_100ms / maxf(al_final, 0.001)))

	# 5) Y frena con inercia: si se le manda al otro lado, no se para en seco.
	var antes_freno := herramienta.angulo_barrido()
	jugador.mirar_a(deg_to_rad(-30.0), 0.0)
	await _esperar(0.08)
	_ok_si(absf(herramienta.angulo_barrido() - antes_freno) > 0.0,
		"al cambiar de sentido sigue yendo un poco (se para en %.0f grados)"
		% rad_to_deg(herramienta.angulo_barrido()))

	# 6) El tope derecho se frena en seco: al pegarse al cuerpo, la velocidad se
	# muere. Es lo que lo hace sentir como un tope y no como un tope blando.
	jugador.mirar_a(0.0, 0.0)
	await _esperar(2.5)
	var justo_antes := herramienta.angulo_barrido()
	jugador.mirar_a(deg_to_rad(-80.0), 0.0)
	# Se espera a que se pare. Con el peso de la maquina no llega en un momento
	# fijo: hay que darle margen y luego comprobar que se ha quedado quieta.
	await _esperar(4.0)
	var al_llegar := herramienta.angulo_barrido()
	await _esperar(1.5)
	var despues := herramienta.angulo_barrido()
	_ok_si(absf(despues - al_llegar) < 0.01,
		"en el tope derecho no rebasa (%.0f -> %.0f -> %.0f)"
		% [rad_to_deg(justo_antes), rad_to_deg(al_llegar), rad_to_deg(despues)])
	_ok_si(al_llegar >= -deg_to_rad(herramienta.max_right_angle) - 0.02,
		"y se queda en el tope, sin pasarse (%.0f grados)"
		% rad_to_deg(al_llegar))

	# 7) Al caminar, el cuerpo se vuelve hacia donde vas y el barrido se abre
	# otra vez. Es lo que hace que la maquina vuelva sola a su sitio.
	jugador.mirar_a(0.0, 0.0)
	await _esperar(1.5)
	var con_cuerpo_a_un_lado := herramienta.angulo_barrido()
	Input.action_press("mover_adelante")
	await _esperar(2.5)
	Input.action_release("mover_adelante")
	await _esperar(2.0)
	_ok_si(absf(herramienta.angulo_barrido()) < absf(con_cuerpo_a_un_lado),
		"al caminar el cuerpo se vuelve y el barrido se abre (%.0f -> %.0f)"
		% [rad_to_deg(con_cuerpo_a_un_lado), rad_to_deg(herramienta.angulo_barrido())])

	# 8) El apoyo en el suelo. Durante el trabajo, al mirar mas abajo de lo que
	# cabe, el cabezal apoya y se queda ahi: no se hunde en el suelo.
	Input.action_press("acelerador")
	await _esperar(0.6)
	jugador.mirar_a(0.0, deg_to_rad(-42.0))
	await _esperar(1.2)
	var corte_1 := herramienta.punto_de_corte()
	var suelo_1 := corte_1.y
	var altura_colision_1 := _suelo_fisico_en(corte_1)
	jugador.mirar_a(0.0, deg_to_rad(-80.0))
	await _esperar(1.2)
	var corte_2 := herramienta.punto_de_corte()
	var suelo_2 := corte_2.y
	var altura_colision_2 := _suelo_fisico_en(corte_2)
	_ok_si(absf(suelo_1 - altura_colision_1) < 0.06,
		"al mirar al suelo apoya en la superficie plana (y = %.2f, suelo %.2f)"
		% [suelo_1, altura_colision_1])
	_ok_si(absf(suelo_2 - altura_colision_2) < 0.06,
		"y bajando mas la vista sigue apoyado (y = %.2f, suelo %.2f)"
		% [suelo_2, altura_colision_2])
	Input.action_release("acelerador")
	jugador.mirar_a(0.0, 0.0)
	await _esperar(1.0)


## Empuja el barrido hacia un lado hasta que se para en el tope, y devuelve
## hasta donde llego. Se hace con la mirada, que es como se mueve de verdad, y no
## tocando el estado por dentro.
func _empujar_barrido(sentido: float) -> float:
	var t0 := Time.get_ticks_msec()
	# Se mira muy lejos a un lado, a proposito: asi el objetivo se sale del tope
	# y la maquina se queda pegada al tope, que es lo que hay que medir. El tope
	# de la herramienta es el objetivo real, no el yaw de la mirada.
	# Se parte siempre de la misma situacion: mirada al frente y maquina en el
	# centro. Si no, el segundo lado se mide desde donde dejo al primero y los
	# dos tiempos no se pueden comparar.
	jugador.mirar_a(0.0, 0.0)
	for i in 120:
		await _esperar(0.05)
		if absf(herramienta.angulo_barrido()) < deg_to_rad(0.5):
			break
	var desde := herramienta.angulo_barrido()
	jugador.mirar_a(deg_to_rad(170.0 * sentido), 0.0)
	var objetivo := clampf(wrapf(deg_to_rad(170.0 * sentido), -PI, PI),
		-deg_to_rad(herramienta.max_right_angle), deg_to_rad(herramienta.max_left_angle))
	# Se espera a que llegue y se pare. Comparar con el objetivo y no con el yaw
	# de la mirada es lo que hace que el tiempo medido sea real: si se compara
	# con el yaw nunca se cumple y el bucle se agota siempre entero.
	for i in 120:
		await _esperar(0.05)
		if absf(herramienta.angulo_barrido() - objetivo) < deg_to_rad(0.5):
			break
	print("     (desde %.0f hasta %.0f en %.2f s)" % [
		rad_to_deg(desde), rad_to_deg(herramienta.angulo_barrido()),
		(Time.get_ticks_msec() - t0) / 1000.0])
	return herramienta.angulo_barrido()


## Suelta las teclas que se puedan haber quedado pulsadas. Entre bloques hay que
## hacerlo a mano: el motor y el acelerador tambien, que si no la maquina sigue
## trabajando.
func _soltar_todo() -> void:
	for accion in ["mover_adelante", "mover_atras", "mover_izquierda",
			"mover_derecha", "acelerador", "agacharse", "correr"]:
		if InputMap.has_action(accion):
			Input.action_release(accion)


## Cuantos grados le faltan a un nodo para mirar a donde se le ha dicho. Se
## comparan en el mundo, asi que vale para la maquina, las caderas y el cuerpo.
func _error_de_mirada(n: Node3D, yaw_objetivo: float) -> float:
	return absf(wrapf(n.global_rotation.y - yaw_objetivo, -PI, PI))


## Cuantos grados se ha quedado "atras" la camara respecto a la direccion de la
## mirada, medido en el mundo. No se usa la rotacion local porque la camara
## cuelga del cuerpo, y el cuerpo se vuelve hacia donde camina: su rotacion
## local no es la correccion de la camara, sino la diferencia con el cuerpo.
func _error_de_camara(yaw_objetivo: float) -> float:
	# Solo el guiñada. Si se comparase el vector entero con el de la mira, que
	# es horizontal, saldria el angulo de inclinacion de la camara (unos 25
	# grados mirando al trabajo) mezclado con el de la correccion.
	var f := -camara.global_transform.basis.z
	var yaw_camara := atan2(-f.x, -f.z)
	return absf(rad_to_deg(wrapf(yaw_camara - yaw_objetivo, -PI, PI)))


func _captura() -> void:
	print("\n== captura ==")
	# En headless no hay nada que dibujar (el servidor de graficos va en dummy),
	# asi que la comprobacion de imagen solo tiene sentido con ventana de verdad.
	#
	# Este aviso NO es un fallo pendiente: es el aviso de que aqui no se ha
	# comprobado que la hierba se dibuje. Para cerrarlo hay que lanzar la
	# herramienta de imagen, que va por separado y es mucho mas rapida que
	# repetir toda la suite con ventana, porque mira solo lo que importa:
	#     flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
	#       --path . --script tools/medir_foto.gd --rendering-driver vulkan
	if DisplayServer.get_name() == "headless":
		print("   OMITIDA: sin servidor de graficos (headless)")
		_avisos += 1
		print("   AVISO sin comprobar la imagen; se cierra con tools/medir_foto.gd")
		return
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	if img == null:
		_fallo("no se pudo leer la imagen del viewport")
		return
	var vp := Vector2i(img.get_width(), img.get_height())
	img.save_png("user://captura_test.png")
	var medio := img.get_pixel(vp.x / 2, vp.y / 2)
	# Pixel central: el cielo si no hay nada, o el suelo. Lo que no puede ser es
	# que sea negro puro (no se esta dibujando nada).
	_ok_si(medio.r + medio.g + medio.b > 0.05,
		"el centro de la pantalla no esta negro (%.2f, %.2f, %.2f)"
		% [medio.r, medio.g, medio.b])
	# Cuantos pixeles tienen el mismo color que el fondo del cielo. Si casi
	# todos, la escena esta vacia.
	var iguales := 0
	for y in range(0, vp.y, 8):
		for x in range(0, vp.x, 8):
			if img.get_pixel(x, y).is_equal_approx(medio):
				iguales += 1
	var total := (vp.y / 8) * (vp.x / 8)
	var pct := 100.0 * iguales / float(total)
	print("   tamano %dx%d, %.0f%% de pixeles del color del centro" % [vp.x, vp.y, pct])
	_ok_si(pct < 97.0, "la pantalla no esta vacia (%.0f%% planos)" % pct)


# --- Ayudantes --------------------------------------------------------

## Espera un tiempo de SIMULACION, no de reloj.
##
## Esto antes contaba los milisegundos del reloj del sistema, y con el
## renderizador Vulkan eso es una trampa. Godot solo deja recuperar 8 pasos de
## fisica por fotograma (max_physics_steps_per_frame), asi que cuando un
## fotograma tarda medio segundo --al compilar shaders, o al dibujar el campo
## entero la primera vez-- la simulacion se queda ATRASADA: se han simulado
## 130 ms de los 500 que de verdad han pasado. La espera de reloj se agotaba
## antes de tiempo, las pruebas que miden movimiento veian al jugador a medio
## camino, y el fallo no era de la mecanica sino del reloj. En headless no se
## notaba, porque ahi no hay tirones.
##
## Ahora se cuentan los fotogramas de verdad, que es lo que se quiere esperar. Se
## cuentan LOS DOS, los de fisica (que mueven al jugador) y los de proceso (que
## mueven el retardo de la camara y el angular), y se sale cuando han pasado los
## dos, que es lo que hacia el bucle original. No se sale con el que llegue
## rapido, que si no se pierde el otro.
##
## El tope de reloj queda, pero holgado y de seguridad: si la simulacion se
## atasca del todo, el bucle sale igual y avisa, en vez de colgarse. Con esta
## maquina renderizando por software a un fps, la suite entera con Vulkan
## tardaria doce minutos, asi que el tope no sirve para ir mas rapido: para eso
## esta la comprobacion de imagen, que va por separado.
func _esperar(segundos: float) -> void:
	var objetivo := int(segundos * float(Engine.physics_ticks_per_second))
	var inicio_fisica := Engine.get_physics_frames()
	var inicio_proceso := Engine.get_process_frames()
	var t0 := Time.get_ticks_msec()
	var tope := maxi(int(segundos * 30000.0), 10000)
	while true:
		if Engine.get_physics_frames() - inicio_fisica >= objetivo \
			and Engine.get_process_frames() - inicio_proceso >= objetivo:
			return
		await physics_frame
		if Time.get_ticks_msec() - t0 > tope:
			push_warning("esperando %.2f s solo se han simulado %.2f s"
				% [segundos, float(Engine.get_physics_frames() - inicio_fisica)
					/ float(Engine.physics_ticks_per_second)])
			return


## La punta de arriba del cabezal, en el mundo.
##
## Se saca de la caja de la malla del carrete y no de un numero puesto a mano
## en la prueba, porque si un dia se cambia el modelo, el punto tiene que ir con
## el. Ademas se coge la esquina de ARRIBA y ADELANTE, que es la que primero se
## sale del encuadre cuando la maquina levanta el morro.
func _punta_del_cabezal(herr: Desbrozadora) -> Vector3:
	if herr == null or herr.giro == null:
		return Vector3.ZERO
	var m := _primera_malla(herr.giro)
	if m == null:
		return Vector3.ZERO
	var caja := m.global_transform * m.get_aabb()
	return caja.position + Vector3(0.0, caja.size.y, -caja.size.z)


## La primera malla que encuentre por abajo, del tipo que sea.
func _primera_malla(nodo: Node) -> MeshInstance3D:
	if nodo is MeshInstance3D:
		return nodo as MeshInstance3D
	for h in nodo.get_children():
		var m := _primera_malla(h)
		if m != null:
			return m
	return null


func _nodo_por_nombre(raiz: Node, nombre: String) -> Node:
	if raiz == null:
		return null
	if raiz.name == nombre:
		return raiz
	for hijo in raiz.get_children():
		var encontrado := _nodo_por_nombre(hijo, nombre)
		if encontrado != null:
			return encontrado
	return null


func _tiene_propiedad(objeto: Object, nombre: String) -> bool:
	for entrada in objeto.get_property_list():
		if str(entrada["name"]) == nombre:
			return true
	return false


## Busca el nodo del viento a lo ancho de toda la escena, sin cogerse al nodo
## de un campo en concreto. Con la hierba partida en varios tipos hay mas de un
## campo, y el viento tiene que ser UNO solo para todos: si cada campo llevara
## el suyo, se pelearian por el mismo mapa y cada uno pondria su propio reloj.
func _viento_de(nodo: Node) -> Viento:
	if nodo == null:
		return null
	if nodo is Viento:
		return nodo as Viento
	for h in nodo.get_children():
		var v := _viento_de(h)
		if v != null:
			return v
	return null


## Busca una malla por nombre dentro de una jerarquia, para poder preguntar si
## una pieza concreta esta en el encuadre.
func _malla_de(nodo: Node, nombre: String) -> MeshInstance3D:
	if nodo == null:
		return null
	if nodo is MeshInstance3D and (nodo as Node).name == nombre:
		return nodo as MeshInstance3D
	for h in nodo.get_children():
		var encontrada := _malla_de(h, nombre)
		if encontrada != null:
			return encontrada
	return null


## Espera a que el jugador se quede quieto en el suelo.
func _asentar() -> void:
	Input.action_release("mover_adelante")
	Input.action_release("mover_atras")
	Input.action_release("mover_izquierda")
	Input.action_release("mover_derecha")
	Input.action_release("correr")
	Input.action_release("acelerador")
	for _i in 45:
		await physics_frame


func _raton(dx: int, dy: int) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(dx, dy)
	ev.position = Vector2(400, 300)
	Input.parse_input_event(ev)


## Que no se haya ido de Simple: por encima de todo y por debajo del suelo.
func _sin_atasco() -> bool:
	return jugador.global_position.y > -0.2 and jugador.global_position.y < 1.5


func _suelo_fisico_en(punto: Vector3) -> float:
	var origen := Vector3(punto.x, punto.y + 2.0, punto.z)
	var consulta := PhysicsRayQueryParameters3D.create(
		origen, origen + Vector3.DOWN * 5.0)
	consulta.exclude = [jugador.get_rid()]
	var golpe := jugador.get_world_3d().direct_space_state.intersect_ray(consulta)
	return float(golpe["position"].y) if not golpe.is_empty() else INF


func _ok_si(condicion: bool, texto: String) -> void:
	if condicion:
		_ok += 1
		print("  OK    %s" % texto)
	else:
		_fallo(texto)


func _recibir_telemetria(_rpm_sin_carga: float, _rpm_bajo_carga: float,
		_resistencia: float) -> void:
	_telemetrias_recibidas += 1


func _fallo(texto: String) -> void:
	_fallos += 1
	print("  FALLO %s" % texto)


func _resumen() -> void:
	print("\n=========================================")
	print("  correctas: %d   fallos: %d   avisos: %d" % [_ok, _fallos, _avisos])
	# Con un aviso hay que decir DE QUE es, o el que lee el resultado puede
	# pensar que se ha dejado algo a medias. Aqui solo puede ser la imagen, que
	# en headless no hay forma de mirar, y el modo de cerrarla va en el aviso.
	if _avisos > 0:
		print("  (el aviso es la imagen: en headless no se dibuja nada)")
		print("  para cerrarla:  tools/medir_foto.gd --rendering-driver vulkan")
	print("========================================")
	quit(1 if _fallos > 0 else 0)
