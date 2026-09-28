class_name Hoz
extends Node3D

## La hoz: la otra herramienta, la de mano.
##
## No lleva motor, ni barrido, ni resistencia, ni combustible. Es un palo con un
## filo, y por eso no se parece en nada a la desbrozadora: no empuja al
## operario ni pesa, y a cambio no llega a la zarza ni a lo alto. Para lo de
## cerca, el cesped de alrededor y la maleza baja, es mejor: mas agile y no
## levanta polvo.
##
## El motor de esta herramienta es una sola pregunta por fotograma: con el
## acelerador echado, que hay dentro del arco de la hoja. Y como la hoja esta
## delante y abajo, la pasada se hace RAZANDO, no de lado como la desbrozadora.
## Por eso `direccion = ABAJO` y no `lado`: la hoz va hacia donde miras.
##
## La hoja se dibuja con la misma `cortar_por_banda` que la hierba ya
## implementa, y no con logica propia: el filo tiene que notar lo mismo que
## nota la desbrozadora, porque si no el jugador ve que una herramienta sirve y
## la otra no, y eso no es un detalle de la mecanica, es un fallo.
##
## Aqui no se corta nada desde la hoja. Corta cada campo de vegetacion, en su
## propio `_physics_process`, al estilo de siempre. La hoja solo contesta a las
## cuatro preguntas que le hacen: si esta cortando, si su filo da para ese tipo
## de planta, donde esta la punta, y cuanto mide la pasada. Si la hoz cortara
## por su cuenta Y el campo cortara tambien, cada hoja se contaria dos veces.

## Marcador en la punta de la hoja. Es donde se busca que hay que cortar.
@export var corte: Node3D
## Donde se agarra con la mano. Lo usa el sistema de brazos.
@export var agarre: Node3D
## Radio de la pasada de la hoja, en metros. Mas pequeño que el de la
## desbrozadora, y con razon: aqui no hay un cabezal girando de un metro.
@export_range(0.1, 1.5, 0.01) var radio_corte := 0.45
## Cuanto se adelanta la hoja de las manos. Es la inclinacion de la muneca, no
## un barrido. La hoja va a la altura del pecho y un poco a la derecha, que es
## como se lleva una herramienta de una mano y como se ve: a la altura de las
## caderas queda debajo del encuadre, entre la maleza, y no se ve ni el mango ni
## el filo.
@export var alcance := 0.55
## Altura de la mano sobre el suelo, en metros. Ver la nota de `_pose`: el
## pivote de las manos esta a los pies del personaje, no a su cintura.
const ALTURA_MANOS := 0.82
## Tipos de vegetacion que corta. El cesped y la maleza, y nada mas: una hoz no
## entra en una zarza, y tampoco tiene por que.
@export var tipos_compatibles: Array[int] = [1, 2]

## Si esta cortando. Lo lee la vegetacion, igual que en la desbrozadora.
var cortando := false
## Cuantas celdas ha cortado en el ultimo fotograma. Para las pruebas.
var cortadas_ultimo := 0

var _jugador: Jugador
var _camara: Camera3D
var _inclinacion := 0.0


func _ready() -> void:
	add_to_group("herramienta")
	if corte == null:
		corte = get_node_or_null("Corte") as Node3D
	if agarre == null:
		agarre = get_node_or_null("Agarre") as Node3D
	_jugador = _subir_buscando(self, "Player") as Jugador
	if _jugador != null:
		_camara = _jugador.get_node_or_null("Cabeza/Camara") as Camera3D


func _process(delta: float) -> void:
	_pose(delta)
	# El acelerador es el mismo boton que en la desbrozadora. Con las manos
	# vacias no hay nada que acelerar, asi que el boton no hace nada: el
	# jugador tiene que mirar al suelo para ver donde va la hoja.
	cortando = Input.is_action_pressed("acelerador") and corte != null
	if not cortando:
		cortadas_ultimo = 0


## La pose: la hoja va delante y un poco a la derecha, y baja con la mirada. Sin
## motor no hay inercia ni retardo, asi que va directa; lo que si lleva es un
## balanceo suave con el tiempo, para que no parezca clavada.
func _pose(delta: float) -> void:
	var objetivo := deg_to_rad(-30.0) - (_pitch_mirada() * 0.70)
	_inclinacion = lerp_angle(_inclinacion, objetivo, 1.0 - exp(-8.0 * delta))
	var balanceo := sin(float(Time.get_ticks_msec()) * 0.0016) * 0.012
	rotation = Vector3(_inclinacion, deg_to_rad(20.0), balanceo)
	# OJO con la altura: el pivote de las manos cuelga de "Caderas", y ese nodo
	# esta en el ORIGEN del jugador, que esta a los pies, no a la cintura. Las
	# alturas de aqui son desde el suelo, no desde la cadera: la mano va a
	# ochenta y tantos centimetros, que es donde esta la cintura de un operario de 1,7,
	# y el filo baja de ahi otros cuarenta. Con offsets pequenos la hoz se
	# quedaba enterrada en la maleza sin llegar a verse.
	position = Vector3(0.26, ALTURA_MANOS, -alcance)


# --- Lo que le preguntan los campos de vegetacion -------------------------

# Cuatro preguntas, las mismas que le hacen a la desbrozadora. No hay una quinta
# y no hara falta: mientras las dos herramientas contesten esto, el cesped, la
# maleza y la zarza no necesitan saber cual de las dos lleva el operario.

## Si el filo de la hoja da para ese tipo de planta.
func cabezal_puede_cortar(tipo_vegetacion: int) -> bool:
	return tipos_compatibles.has(tipo_vegetacion)


## Radio de la pasada. Con la hoja quieta no cambia, pero se consulta igual que
## a la desbrozadora para que la vegetacion tenga una sola forma de preguntar.
func radio_corte_actual() -> float:
	return radio_corte


## Anota el trabajo hecho. En la desbrozadora esto gasta el filo y echa humo; en
## una hoja de acero solo lleva la cuenta, que es lo que mira la prueba.
func registrar_corte(tipo_vegetacion: int, cantidad: int, _dureza: float) -> void:
	if cantidad > 0 and cabezal_puede_cortar(tipo_vegetacion):
		cortadas_ultimo += cantidad


## Donde esta la hoja ahora mismo, en el mundo. Lo lee la vegetacion y lo
## muestran las pruebas.
func punto_de_corte() -> Vector3:
	if corte != null:
		return corte.global_position
	return global_position


## Hacia donde mira el operario, en radianes. Se busca en el jugador y no en la
## camara porque la camara tambien cabecea cuando trabaja la maquina, y la hoja
## tiene que ir con la mirada y no con eso.
func _pitch_mirada() -> float:
	if _jugador == null:
		return 0.0
	return -_jugador.get_pitch()


func _subir_buscando(desde: Node, nombre: String) -> Node:
	var n := desde
	while n != null:
		if n.name == nombre:
			return n
		n = n.get_parent()
	return null
