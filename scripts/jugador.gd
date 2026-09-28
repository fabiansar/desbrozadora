class_name Jugador
extends CharacterBody3D

## El desbrozador. Camara en la cabeza, WASD, raton para mirar.
##
## No lleva camara como hijo suyo a proposito: la camara esta colgando de una
## "_cabeza" aparte para que `CamaraGopro` pueda anadir el bamboleo, el balanceo
## y el retardo de la mirada sin que el jugador tenga que enterarse.

## Velocidad de andar, en metros por segundo.
@export var velocidad_andar := 3.0
## Velocidad corriendo (con Shift).
@export var velocidad_correr := 5.8
## Aceleracion: cuanto tarda en coger velocidad. Se nota al arrancar y al
## frenar, que es lo que hace que no se deslice.
@export var aceleracion := 14.0
## Freno en el aire, Mucho menor: en el aire se manda poco.
@export var control_aire := 2.5
## Salto.
@export var fuerza_salto := 5.2
## Gravedad.
@export var gravedad := 18.0
## Velocidad del raton en grados por pixel.
@export var sensibilidad := 0.16
## Hasta donde se puede mirar ABAJO, en grados.
@export var limite_pitch := 85.0
## Hasta donde se puede mirar ARRIBA, en grados, con el raton.
##
## Este limite NO es lo que mantiene el cabezal en la foto: de eso se encarga
## la camara, que se baja sola lo justo (ver _pitch_limitado). Aqui solo se
## corta el giro de cabeza en vertical, para que no se pueda dar la vuelta
## mirando al techo. Se deja bastante margen arriba porque mirando arriba es
## justo lo que hara falta con la zarza alta, y la camara ya responde de eso.
@export_range(0.0, 85.0, 1.0) var limite_pitch_arriba := 55.0
## Con que angulo se empieza mirando, en grados. El mismo motivo: hay que
## encuadrar el trabajo de salida, no el horizonte.
@export_range(-85.0, 0.0, 1.0) var pitch_inicial := -40.0
## Cuanto se agacha la camara, en metros.
@export var altura_agachado := -0.55
## Velocidad con la que la camara vuelve a su sitio al agacharse.
@export var rapidez_agachado := 9.0
## Cuanto tarda el cuerpo en volverse hacia donde caminas, en 1/segundo. Va
## bastante rapido, porque si el cuerpo se demora el jugador nota que al andar
## en curva va de lado.
@export var rapidez_cuerpo := 4.0
## Nodo de la cabeza: de aqui cuelga la camara.
@export var cabeza: Node3D
## Cuanto baja la cabeza por causa de la maqueta, y no por agacharse. Lo escribe
## la desbrozadora cuando el cabezal esta en el suelo, porque los ojos van
## detras de las manos. Es un export y no una variable a proposito: asi la
## cabeza solo se coloca en un sitio, en _agacharse().
@export var agachado_extra := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _offset_agachado := 0.0
var _cabeza_base := 1.62
var _raton_cogido := false
var _andando := false
var _correr := false


func _ready() -> void:
	if cabeza == null:
		cabeza = get_node_or_null("Cabeza") as Node3D
	if cabeza != null:
		# La cabeza ya viene colocada en la escena (a 1,62 m). Aqui se guarda
		# esa altura para poder bajarla al agacharse. Si se escribiera
		# position.y = 0 sin mas, la camara se caia al suelo.
		_cabeza_base = cabeza.position.y
	# Se arranca mirando al trabajo, no al horizonte. Con el cabezal 47 grados
	# por debajo del eje de la mira, mirando recto no se ve, y el jugador
	# tendria que bajar la vista a mano solo para empezar.
	_pitch = deg_to_rad(pitch_inicial)
	_agarrar_raton()


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion and _raton_cogido:
		var mov := (evento as InputEventMouseMotion).relative
		_yaw = wrapf(_yaw - deg_to_rad(mov.x * sensibilidad), -PI, PI)
		_pitch -= deg_to_rad(mov.y * sensibilidad)
		# Se limita el pitch y no el yaw: mirando al techo no se da la vuelta
		# entera, pero horizontalmente se puede dar vueltas las veces que sea.
		_limitar_pitch()
	elif evento.is_action_pressed("soltar_raton"):
		_soltar_raton()
	elif evento is InputEventMouseButton and not _raton_cogido:
		_agarrar_raton()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravedad * delta
	elif Input.is_action_just_pressed("saltar"):
		velocity.y = fuerza_salto

	var wish := _direccion_deseada()
	var objetivo := wish * (_velocidad_actual())
	var control := aceleracion if is_on_floor() else control_aire
	# Acelerar hacia el objetivo, no poner la velocidad directamente: por eso
	# el personaje tiene inercia y se nota el peso.
	var eje := Vector3(velocity.x, 0.0, velocity.z)
	eje = eje.move_toward(Vector3(objetivo.x, 0.0, objetivo.z), control * delta)
	velocity.x = eje.x
	velocity.z = eje.z
	move_and_slide()

	_andando = wish.length() > 0.1 and is_on_floor()
	_correr = Input.is_action_pressed("correr") and _andando
	_girar(delta)
	_agacharse(delta)


## Direccion de entrada en el espacio del mundo. W va hacia donde se mira.
func _direccion_deseada() -> Vector3:
	var entrada := _entrada_local()
	# OJO con el signo: el tercer parametro de get_vector es la accion de Y
	# NEGATIVO, y ahi va "mover_adelante". Asi que W da y = -1, que ya es
	# hacia donde mira la camara (-Z). Poner "mover_atras" en ese sitio haria
	# que W fuese hacia atras.
	return Basis(Vector3.UP, _yaw) * Vector3(entrada.x, 0.0, entrada.y)


## La entrada en el espacio del jugador: x lateral (D positivo), y adelante
## (W negativo). Sin normalizar en exceso, para poder distinguir un paso de lado
## de un paso hacia delante.
func _entrada_local() -> Vector2:
	var entrada := Input.get_vector("mover_izquierda", "mover_derecha",
		"mover_adelante", "mover_atras")
	if entrada.length() > 1.0:
		entrada = entrada.normalized()
	return entrada


func _velocidad_actual() -> float:
	return velocidad_correr if _correr else velocidad_andar


## El cuerpo NO gira con la mirada. Gira hacia donde caminas, y si te quedas
## quieto se queda donde estaba.
##
## Esto es lo que hace que la maquina tenga sentido. Si el cuerpo girase con el
## raton, al girar la vista seoserian todo a la vez y las caderas no tendrian
## nada que seguir. Y si el cuerpo no girase nunca, darias vueltas con el
## cuello. Con esto pasa lo de verdad: te paras, miras a un lado, y el cuerpo se
## queda mirando al frente mientras los brazos se cruzan para trabajar de
## lado. Luego das un paso y el cuerpo se vuelve a la direccion de la marcha.
func _girar(delta: float) -> void:
	var andando := _direccion_deseada()
	if andando.length_squared() > 0.0001:
		# El cuerpo se vuelve hacia donde se AVANZA, no hacia donde se esquiva.
		# Esto no es un detalle: A y D sirven tambien para barrer la maquina a
		# proposito, y la maquina se mide respecto al cuerpo. Si el cuerpo se
		# girase al esquivar, al pulsar D para echarla a la derecha el cuerpo
		# daria media vuelta y la maquina se iria al lado contrario del pedido.
		# Dos efectos opuestos en la misma tecla, y el barrido a proposito
		# Seria inusable. En la vida real esquivar de lado no te hace girar el
		# torso tanto como avanzar.
		var local := _entrada_local()
		if absf(local.y) < absf(local.x):
			return
		# Y hacia atras el cuerpo NO se vuelve. Ojo al signo: en _entrada_local()
		# W es negativo y S positivo, asi que andar hacia atras es local.y > 0.
		#
		# Esto era un fallo gordo: la maquina se mide respecto al cuerpo, asi que
		# al pulsar S el cuerpo se daba media vuelta y el objetivo de barrido se
		# le iba 180 grados de golpe. Solo de pulsar S, la maquina se echaba al
		# tope de un lado, y como el cuerpo seguia girando, no paraba: el
		# jugador andaba hacia atras y la maquina barria como si estuviera
		# trabajando al lado. Andar hacia atras tiene que ser solo eso: el
		# jugador se va hacia atras y la maquina se queda donde estaba, que es
		# ademas lo que hace una de verdad, que no se le teletransporta de un
		# lado al otro de las caderas.
		if local.y > 0.0:
			return
		# atan2 con el signo cambiado: en Godot -Z es delante, y el yaw de un
		# nodo es el giro alrededor de Y, asi que sale con los dos signos
		# cambiados.
		var hacia := atan2(-andando.x, -andando.z)
		rotation.y = lerp_angle(rotation.y, hacia,
			minf(1.0, delta * rapidez_cuerpo))


func _agacharse(delta: float) -> void:
	var quiere := 1.0 if Input.is_action_pressed("agacharse") else 0.0
	_offset_agachado = move_toward(_offset_agachado, quiere * altura_agachado,
		rapidez_agachado * absf(altura_agachado) * delta)
	if cabeza != null:
		# Agacharse y el inclinarse sobre la maqueta se suman aqui, en un solo
		# sitio. Si cada uno escribiera cabeza.position.y por su cuenta, el
		# ultimo en escribir dejaria al otro fuera.
		cabeza.position.y = _cabeza_base + _offset_agachado + agachado_extra


func _agarrar_raton() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_raton_cogido = true


func _soltar_raton() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_raton_cogido = false


# --- Lo que consulta el resto del juego y las pruebas -------------------

## Gira la mirada directamente, sin raton. Lo usa el sistema de corte (para
## mirar al objetivo) y las pruebas.
func mirar_a(yaw: float, pitch: float) -> void:
	_yaw = wrapf(yaw, -PI, PI)
	_pitch = pitch
	_limitar_pitch()


## Deja la mirada dentro de lo que se puede ver. Hacia abajo hay mucho margen
## porque es donde se trabaja; hacia arriba se para antes, para que el cabezal
## siga en la foto. Va en un sitio solo porque el raton y las pruebas tienen que
## limitado igual, o el encuadre que se comprueba en las pruebas no seria el de
## verdad.
func _limitar_pitch() -> void:
	# OJO CON EL SIGNO, que es la trampa de este limite: mirando ABAJO el pitch
	# es NEGATIVO y mirando ARRIBA es POSITIVO. Asi que el tope de abajo es el
	# mas negativo de los dos, y no el mas grande. Al revés, mirando a -85
	# grados se acababa en +85, que es mirar al cielo.
	var hacia_abajo := -deg_to_rad(limite_pitch)
	var hacia_arriba := deg_to_rad(limite_pitch_arriba)
	if hacia_arriba < 0.0:
		hacia_arriba = 0.0
	if hacia_abajo > 0.0:
		hacia_abajo = 0.0
	_pitch = clampf(_pitch, hacia_abajo, hacia_arriba)


## Rumbo al que mira la cabeza, en radianes.
func get_yaw() -> float:
	return _yaw


## Elevacion de la mirada, en radianes (negativo es hacia abajo).
func get_pitch() -> float:
	return _pitch


## Velocidad a la que se mueve en el plano, sin la caida.
func get_velocidad_plano() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Ademas de la velocidad: si va pegado al suelo y sin correr.
func get_andando() -> bool:
	return _andando


func get_correr() -> bool:
	return _correr


## Cuanto ha girado en total. Lo usa la camara para el retardo de la mirada.
func get_giro_total() -> float:
	return _yaw
