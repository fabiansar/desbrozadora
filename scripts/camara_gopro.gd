class_name CamaraGopro
extends Camera3D

## Camara "en la cabeza", al estilo GoPro.
##
## Una camara en primera persona normal se siente como un ojo flotante: se gira
## instantanea y al andar no se nota el cuerpo. La de una GoPro va atada a la
## cabeza, y eso se nota en tres cosas:
##   1. Al andar, la cabeza bambolea: sube y baja, rueda un poco de lado y da
##      un paso por cada zancada.
##   2. La mirada va con retardo: giras rapido y la camara llega despues.
##   3. Corriendo se abre el angular, como cuando levantas la accion.
##
## OJO con las transformadas: la camara cuelga de la cabeza, que a su vez cuelga
## del jugador, y el jugador ya gira con el yaw. Asi que aqui NO se pone el yaw
## entero, sino solo la diferencia entre donde mira el jugador y donde "ha
## llegado" la camara. Si se pusiera el yaw entero, se doblaria.

## Amplitud del bamboleo vertical al andar, en metros.
@export var bamboleo_vertical := 0.045
## Amplitud del balanceo lateral al andar, en metros.
@export var bamboleo_lateral := 0.030
## Cuanto rueda la cabeza al andar, en grados.
@export var bamboleo_rodada := 1.7
## Cuanto se ladea al girar la mirada, en grados.
@export var ladeo_giro := 2.4
## Tope del ladeo que mete la desbrozadora, en grados. Es un tope de seguridad,
## no el normal: con la ganancia de 0,07 por grado de barrido y el arco entero
## (96 grados a la izquierda) sale 6,7, o sea que con la maqueta trabajando el
## tope no llega a tocarse y el rodillo sigue al barrido de verdad. Antes la
## ganancia era seis veces mayor y este tope se clavaba siempre.
@export var tope_ladeo_herramienta := 8.0
## Retardo de la mirada, en segundos. Es el tiempo que tarda la camara en
## alcanzar la cabeza. A 0 es instantanea; con 0,12 la cabeza se adelanta y la
## camara la alcanza despacio, que es lo que quita el aspecto de rigida.
@export_range(0.0, 0.5, 0.005) var retardo_mirada := 0.12
## Retardo del ladeo, en segundos. Va aparte del de la mirada porque el
## ladeo viene de a saltos (depende de lo rapido que gires el raton) y sin
## esto la camara se ponia recta de golpe al dejar de girar.
@export_range(0.0, 1.0, 0.01) var retardo_ladeo := 0.30
## Aumento de FOV que se suma al correr, en grados.
@export var angular_correr := 12.0
## FOV horizontal base. El de una GoPro muy angular es de 90 grados o mas.
@export_range(40.0, 140.0, 1.0) var angular := 100.0
## Ajuste adicional del FOV horizontal, en grados. Cero conserva el encuadre.
@export_range(-20.0, 20.0, 1.0) var ajuste_fov := 0.0
## Cuanto se le perdona al cabezal, en grados, para que no quede justo en el
## borde de la foto. Ver _pitch_limitado().
@export var margen_cabezal := 8.0
## Jugador al que se sigue. Si es null se busca en la escena.
@export var jugador: Jugador
## Nodo "cabeza" del jugador: de aqui cuelga la camara.
@export var cabeza: Node3D
## Ladeo extra, en grados, que le pone la desbrozadora cuando el cuerpo se echa
## sobre el terreno. Va aparte del ladeo de la mirada y del rodillo del paso, y
## los tres se suman en _colocar().
##
## A proposito NO es un @export: lo escribe desbrozadora.gd en cada fotograma,
## asi que en el Inspector se veria como un campo editable que se pisa sixty
## veces por segundo y en el que cualquier valor puesto a mano dura un
## fotograma. Se deja como variable normal a proposito, para que en el Inspector
## no aparezca.
var ladeo_herramienta := 0.0

var _yaw_suave := 0.0
var _pitch_suave := 0.0
var _fase := 0.0
var _ladeo_suave := 0.0
var _peso := 0.0
var _primer_fotograma := true
## La desbrozadora, para no perder el cabezal de vista al mirar arriba.
var herramienta: Desbrozadora


func _ready() -> void:
	if jugador == null:
		jugador = _buscar_jugador()
	if cabeza == null and jugador != null:
		cabeza = jugador.get_node_or_null("Cabeza") as Node3D
	herramienta = _buscar_herramienta()
	# KEEP_WIDTH para que el angular sea el horizontal: es como se mide el de
	# una camara de accion y como se ve el campo de vision al jugar.
	keep_aspect = Camera3D.KEEP_WIDTH
	fov = angular + ajuste_fov
	if jugador != null:
		_yaw_suave = jugador.get_yaw()
		_pitch_suave = jugador.get_pitch()


func _process(delta: float) -> void:
	if jugador == null:
		return
	# La camara esta antes que la desbrozadora en el arbol (Cabeza va antes que
	# Caderas), asi que al su _ready todavia no hay nada en el grupo y la
	# herramienta sale nula. Se reintenta hasta que aparezca; mientras no
	# aparezca, el limite de pitch no se puede aplicar.
	if herramienta == null:
		herramienta = _buscar_herramienta()
	if _primer_fotograma:
		# El primer fotograma pone la camara ya en su sitio, sin un tirón desde
		# el origen que se ve como un salto al empezar la partida.
		_yaw_suave = jugador.get_yaw()
		_pitch_suave = jugador.get_pitch()
		_primer_fotograma = false

	var giro_tras_lag := _mirada(delta)
	var bamboleo := _bamboleo(delta)
	_colocar(giro_tras_lag, bamboleo, delta)
	_angular(delta)


## Cuanto se puede levantar la vista sin que el cabezal se salga de la foto.
##
## La posicion del cabezal cambia con el alcance y la inclinacion de la maquina,
## por lo que no se usa una distancia o un angulo fijo. Se consulta el punto de
## corte actual: mirar recto o arriba no debe dejarlo fuera de la imagen. Se van
## a cortar zarza alta y hay que ver donde corta la hoja SIEMPRE.
##
## En vez de taparle el raton al jugador, que se nota fatal, lo que hace la
## camara es bajarse sola lo justo para que el cabezal no se salga. El jugador
## puede mirar todo lo arriba que quiera, y la vista se abre hacia las copas de
## la zarza mientras el cabezal se queda asomando por abajo.
##
## El limite sale de la geometria de ahora mismo, no de un numero fijo: si la
## maquina se echa, el cabezal baja y la camara puede subir mas.
func _pitch_limitado(pitch: float) -> float:
	if herramienta == null or not is_inside_tree():
		return pitch
	var punto := herramienta.punto_de_corte()
	var desde := global_position - punto
	var horiz := Vector2(desde.x, desde.z).length()
	if horiz < 0.001:
		return pitch
	# Cuanto esta el cabezal por debajo de la camara, en grados y en positivo.
	# "desde" va de la camara al cabezal en vertical, asi que si la camara esta
	# encima (lo normal) desde.y sale positivo y atan2 da el angulo para abajo.
	var abajo := rad_to_deg(atan2(maxf(desde.y, 0.0), horiz))
	# El tope: el cabezal queda a "abajo + pitch" por debajo del eje (el pitch
	# es negativo mirando abajo), y eso no puede pasar del medio angular vertical.
	var tope := _medio_vertical() - margen_cabezal - abajo
	return minf(pitch, deg_to_rad(tope))


## La mitad del angular en vertical. Con KEEP_WIDTH el "fov" es el horizontal, y
## el vertical sale de la proporcion de la pantalla.
func _medio_vertical() -> float:
	var aspecto := 16.0 / 9.0
	var vp := get_viewport()
	if vp != null:
		var r := vp.get_visible_rect()
		if r.size.y > 0.0:
			aspecto = r.size.x / r.size.y
	var medio := tan(deg_to_rad(fov) * 0.5) / maxf(aspecto, 0.01)
	return rad_to_deg(atan(maxf(medio, 0.0)))


## Devuelve cuantos radianos se ha quedado "atras" la mirada.
func _mirada(delta: float) -> float:
	var objetivo := jugador.get_yaw()
	var objetivo_pitch := jugador.get_pitch()
	# Exponencial, para que el retardo no dependa de los fotogramas: a 30 o a
	# 144 fps se nota igual. Antes se hacia con pow(0.22, delta*60), que
	# guardaba solo el 22 % del error POR FOTOGRAMA, con lo que la camara se
	# pegaba a la cabeza en dos frames y el retardo no se notaba nada.
	var k := 1.0
	if retardo_mirada > 0.0:
		k = 1.0 - exp(-delta / retardo_mirada)
	_yaw_suave = lerp_angle(_yaw_suave, objetivo, k)
	# El pitch se limita DESPUES de suavizar, no antes: si se limitara antes,
	# la camara se quedaria persiguiendo un objetivo que no puede alcanzar y
	# el cabezal se sairia igualmente al subir la vista.
	_pitch_suave = lerpf(_pitch_suave, objetivo_pitch, k)
	_pitch_suave = _pitch_limitado(_pitch_suave)
	return wrapf(_yaw_suave - objetivo, -PI, PI)


## El paso. Devuelve (vertical, lateral, rodada) en un Vector3.
func _bamboleo(delta: float) -> Vector3:
	var rapidez := jugador.get_velocidad_plano()
	var andando := jugador.get_andando()
	var objetivo := 0.0
	if andando and rapidez > 0.3:
		objetivo = clampf(rapidez / 6.0, 0.0, 1.0)
		# Un ciclo por zancada. Cuanto mas rapido, mas corto el paso: no es solo
		# mas alto, tambien mas seguido, que es lo que pasa de verdad al correr.
		var duracion := clampf(1.7 / maxf(rapidez, 0.5), 0.22, 0.60)
		# La fase tiene que correr libre. Antes solo alternaba entre 0 y PI, y
		# como sin(0) y sin(PI) son los dos cero, el bamboleo vertical salia
		# siempre a cero y solo se notaba el balanceo lateral.
		_fase = wrapf(_fase + TAU * delta / duracion, 0.0, TAU)
	# El peso del paso entra rapido y se calma despacio. Antes el peso salia
	# directo de la fase, con lo que al parar de andar caia a cero en dos
	# fotogramas: el bamboleo daba un tirón al frenar, igual que daba el ladeo
	# al girar.
	var ritmo := 6.0 if objetivo > _peso else 2.2
	_peso = move_toward(_peso, objetivo, delta * ritmo)
	var vertical := sin(_fase) * bamboleo_vertical * _peso
	var lateral := cos(_fase) * bamboleo_lateral * _peso
	return Vector3(vertical, lateral, sin(_fase) * bamboleo_rodada * _peso)


func _colocar(giro_tras_lag: float, bamboleo: Vector3, delta: float) -> void:
	var vertical := bamboleo.x
	var lateral := bamboleo.y
	var rodada := bamboleo.z
	# La rodada combina el paso con el ladeo de la mirada. El ladeo sale de la
	# misma diferencia de yaw que el retardo: si la camara va tarde, la cabeza
	# queda ladeada, como cuando giras el cuello. Se corta en ladeo_giro para
	# que un giro brutal no de la vuelta al mundo.
	#
	# El ladeo necesita su propio retardo. Antes se tomaba directo del retraso
	# de la mirada y eso hacia que la camara se pusiera recta de golpe: el
	# multiplicador de 6 grados por grado saturaba el tope con medio grado de
	# retraso, asi que el rodillo se quedaba clavado en el tope mientras
	# girabas y en cuanto la camara alcanzaba la mira se caia a cero en dos o
	# tres fotogramas. Al cambiar de sentido de giro el signo volcaba y eran
	# casi 5 grados de golpe. Suavizandolo por separado, el ladeo entra y sale
	# poco a poco.
	var grados_retraso := rad_to_deg(giro_tras_lag)
	var ladeo_objetivo := clampf(-grados_retraso * 3.0, -ladeo_giro, ladeo_giro)
	if retardo_ladeo > 0.0:
		_ladeo_suave = lerpf(_ladeo_suave, ladeo_objetivo,
			minf(1.0, delta / retardo_ladeo))
	else:
		_ladeo_suave = ladeo_objetivo
	# El ladeo de la herramienta se suma a los otros dos. Se limita porque si la
	# maquina se va mucho de lado el rodillo se va con ella y el mundo parece
	# caido.
	#
	# OJO con el yaw de aqui, que es lo mas facil de romper: la camara cuelga de
	# la cabeza, que a su vez cuelga del JUGADOR, y el cuerpo gira con la marcha
	# (al pulsar S se vuelve de espaldas). Si aqui se pusiera la diferencia con
	# la MIRA, al dar media vuelta el cuerpo se llevaria la camara delante y el
	# mundo daria un tiron de 180 grados. Por eso lo que se pone no es la
	# diferencia con la mira, sino la diferencia con el CUERPO: asi la camara
	# mira siempre a donde mira la cabeza, vaya el cuerpo como vaya.
	var cuerpo := jugador.rotation.y
	rotation = Vector3(_pitch_suave, wrapf(_yaw_suave - cuerpo, -PI, PI),
		deg_to_rad(_ladeo_suave + clampf(ladeo_herramienta, -tope_ladeo_herramienta,
			tope_ladeo_herramienta))
		+ deg_to_rad(rodada))
	# La altura de agachado la aplica Jugador sobre el pivote Cabeza. Aqui solo
	# se suma el bamboleo: bajarla tambien en este nodo duplicaba el crouch.
	position = Vector3(lateral, vertical, 0.0)


func _angular(delta: float) -> void:
	var objetivo := angular + ajuste_fov
	if jugador.get_correr():
		objetivo += angular_correr
	fov = lerpf(fov, objetivo, minf(1.0, delta * 4.5))


## La desbrozadora se mira desde aqui: el modelo va colgado de este nodo.
## Se exporta para que las pruebas puedan preguntar donde se ve el cabezal.
func get_cabeza() -> Node3D:
	return cabeza


## Solo el ladeo que viene del retraso de la mirada, en grados, sin el del
## paso. Lo usan las pruebas para mirar el giro por separado: el rodillo de la
## camara es la suma de los dos, y al andar los dos se mueven.
func ladeo_de_mirada() -> float:
	return _ladeo_suave


## Sube por el arbol hasta encontrar al jugador. Es mas seguro que buscar
## "Player" en la escena actual: asi funciona aunque la escena se meta a mano
## en el arbol, que es justo lo que hacen las pruebas.
func _buscar_jugador() -> Jugador:
	var n: Node = self
	while n != null:
		if n is Jugador:
			return n as Jugador
		n = n.get_parent()
	var escena := get_tree().current_scene
	if escena == null:
		return null
	return escena.get_node_or_null("Player") as Jugador


## La desbrozadora que hay que tener delante de los ojos. Va por el grupo, que
## es como la busca tambien la hierba para cortarse.
func _buscar_herramienta() -> Desbrozadora:
	for n in get_tree().get_nodes_in_group("herramienta"):
		if n is Desbrozadora:
			return n as Desbrozadora
	return null
