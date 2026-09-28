class_name Desbrozadora
extends Node3D

signal telemetria_actualizada(rpm_sin_carga: float, rpm_bajo_carga: float,
		resistencia: float)

## La desbrozadora del operario: va colgada del arnes, no en las manos.
##
## No esta pegada a la camara. Cuelga de un nodo "Caderas", que esta entre el
## cuerpo y la maqueta, y el arnes esta en la HIPERECHA DEL OPERARIO. De ahi
## sale casi todo lo que se siente al usarla:
##
## - El barrido NO es simetrico. A la izquierda el brazo y el torso se cruzan y
##   el cabezal describe un arco largo por delante del cuerpo. A la derecha el
##   cuerpo se atraviesa, el hombro estorba y la maquina topa antes. Por eso
##   max_left_angle y max_right_angle no son el mismo numero, y el tope derecho
##   se nota mas: es el cuerpo, no un tope de software.
##
## - La maquina tiene PESO. No llega donde se le pide, llega despues; cuando
##   frenas sigue yendo; y al cambiar de sentido tiene que pasar por parado. De
##   ahi inertia_smoothness y sweep_speed.
##
## - Las CADERAS van detras de la maquina. Al girar de golpe la herramienta sale
##   disparada y las caderas van a lo suyo, que es como se nota el peso de las
##   manos.
##
## - La VERTICAL sale de la mirada. Bajas la cabeza y la maquina baja; bajas mas
##   y el cabezal APOYA en el suelo y se queda ahi, sin hundirse, porque el
##   angulo se para en el punto exacto en que el cabezal toca tierra. El sitio
##   del suelo se busca con un rayo, asi que funciona en las pendientes.
##
## El acelerador es el boton izquierdo, como en una de verdad: con el motor
## parado el cabezal no corta, y con el motor echado el operario echa el peso
## del cuerpo sobre la maquina. El corte lo busca la hierba en punto_de_corte().

## Modelo de la desbrozadora.
@export var modelo: Node3D
## Nodo que gira: el carrete de hilo.
@export var giro: Node3D
## Empty en el centro del cabezal. Es donde habra que buscar la hierba.
@export var corte: Node3D
## Sonido del motor.
@export var motor_sonido: AudioStreamPlayer3D
## Revoluciones por minuto maxima.
@export var rpm_maximas := 9000.0
## Cuanto tarda en llegar de parado a tope, en segundos.
@export var subida_rpm := 0.85
## Cuanto tarda en apagarse.
@export var bajada_rpm := 0.6
## Frecuencia maxima de giro del carrete, en vueltas por segundo.
@export var vueltas_maximas := 130.0

# --- Las caderas ----------------------------------------------------------

## Altura a la que van las manos, en metros.
@export var altura_cadera := 0.88
## Lo que se separa el arnes del centro del cuerpo, en metros. Es la cadera
## derecha: la maquina se lleva en el lado derecho, y este numero es el
## responsable de que el barrido no sea simetrico.
@export var lateral_cadera := 0.26
## Cuanto tardan las caderas en seguir a la maquina, en 1/segundo. Cuanto mas
## bajo, mas dura el twist y mas se nota que la maquina va por delante. A 2,6 se
## tarda algo mas de medio segundo.
@export var rapidez_caderas := 2.6
## Alcance horizontal del cabezal desde el operario, en metros. Se mantiene
## separado de la geometría del modelo para que al alargar la barra el código
## pueda compensar la posición del conjunto y conservar los agarres.
@export var alcance := 1.56
# --- El arnes y el barrido -------------------------------------------------

## La maquina no se lleva en las manos: va colgada de un arnes en la cadera
## DERECHA. De ahi sale todo lo que viene: el pivote esta a la derecha, asi que
## el barrido no es simetrico y el arco de un lado es mas largo que el del otro.
##
## El angulo lleva el signo de Godot, que es el giro alrededor de Y: positivo
## es hacia la IZQUIERDA del operario y negativo hacia la DERECHA. Los topes
## estan en grados porque en el Inspector se ajustan mucho mejor en grados que
## en radianes.
##
## Hacia la izquierda se puede barrer mucho mas: el brazo y el torso se cruzan
## y el cabezal describe un arco largo por delante del cuerpo. Hacia la derecha
## el cuerpo se atraviesa y la maquina topa antes, con el hombro en medio. Por
## eso los dos topes no son el mismo numero.
@export var max_left_angle := 96.0
@export var max_right_angle := 38.0
## Rapidez maxima del barrido, en radianes por segundo. Es la velocidad a la
## que la maquina llega mas lejos de lado, no lo que tarda: el peso se lleva
## inertia_smoothness.
@export var sweep_speed := 2.4
## Cuanto pesa la maquina, en segundos. Es el tiempo que tarda en responder, y
## por eso tambien se nota al frenar y al cambiar de sentido: si sube, la
## maquina llega mas tarde y se para mas despacio. A 0,24 va con buen peso; por
## debajo de 0,12 empieza a ir elastica y por encima de 0,5 se arrastra.
@export var inertia_smoothness := 0.24
## Cuanto barre la maquina a proposito con A y D, en grados. Es un extra: se
## suma a lo que ya barre el hecho de mirar a un lado. Con 26 se nota el
## barrido sin que se salga del arco ergonomicico.
@export var barrido_teclado := 26.0
## Cuanto manda la mirada en el barrido, o sea, quantas veces mas barre la
## maquina de lo que gira la vista. Con 1 era metro a metro y se notaba poco:
## la maquina iba tan pegada a los muslos que casi no se veia el efecto de
## mirar a un lado, que es justo lo que tiene que pasar. Con 1,8, 20 grados de
## raton echan la maquina 36, que ya se ve claro sin que se vaya sola.
@export_range(0.0, 3.0, 0.05) var seguimiento_ojos := 1.8
## Cuanto mas pesa la maquina hacia la IZQUIERDA, de 1 a mas. Multiplica el
## peso del muelle, y el peso es lo que de verdad marca como se mueve (la
## rigidez se cancela, esta explicado en _avanzar_hacia_el_objetivo). Con 1,6 el
## barrido largo de la izquierda va pesado: arranca con calma, recorre los 96
## grados y le cuesta pararse, que es como se siente de verdad.
@export var masa_izquierda := 1.6
## Cuanto se pone rigida al acercarse al tope DERECHO, de 0 a mas. El cuerpo hace
## de tope y no cede. Divide el peso del muelle hacia la derecha, o sea que
## la maquina va seca de ese lado: recorre los 38 grados en menos de la mitad de
## tiempo que la izquierda y frena en seco. Con 2,2 el tope derecho se nota
## como un tope de verdad y no como un tope blando. En la izquierda no hace
## nada, porque alla el arco se acaba de verdad y no hay nada contra lo que
## empujar.
@export var rigidez_derecha := 2.2
## Ladeo fijo de la herramienta en grados.
@export var ladeo := 3.8
## Cuanto grado de ladeo de la vista se gana por grado de barrido de la maquina.
## Es un factor y no un multiplicador sobre el barrido ya en grados, y el orden
## importa muchisimo: antes era rad_to_deg(_barrido * 6.0), o sea la ganancia
## de seis grados por cada grado de barrido. Un barrido normal de 30 grados se
## convertia en 180 y el tope de 8 grados de la camara se clavaba con 1,3
## grados de barrido. El mundo se quedaba torcido en un tope constante
## mientras se trabajado y al salir de ahi el rodillo se caia de golpe, que es
## justo el corte raro que se notaba al girar de lado. Con 0,07 el barrido
## entero cabe dentro del tope y el rodillo va siguiendo al barrido.
@export_range(0.0, 0.5, 0.005) var ganancia_ladeo := 0.07

# --- La vertical ---------------------------------------------------------

## Inclinacion del tubo en reposo, en grados. Negativa = morro hacia abajo.
## -22 grados orienta el eje hacia delante y abajo como en la referencia.
@export var inclinacion_reposo := -22.0
## Cuanto baja el morro al acelerar, en grados. El motor a fondo es cuando la
## maquina se echa sobre el terreno.
@export var inclinacion_acelerando := 22.0
## Pitch, en grados, al que el cabezal apoya en el suelo. A partir de aqui sigue
## bajando la mirada, pero la maquina no se hunde mas: ya esta en tierra.
@export var mirar_suelo := 44.0
## Pitch, en grados, al que la maquina llega a su altura maxima de trabajo. Es
## la mitad de arriba, y antes no existia: mirando arriba el morro se quedaba
## clavado en inclinacion_reposo y el cabezal no subia de 0,35 m, con lo cual
## no se podia cortar nada mas alto que la rodilla. Con esto, mirando arriba se
## levanta el tubo y el cabezal sube a la altura de la cabeza, que es lo que
## hace falta parazarza alta.
@export var mirar_alto := 45.0
## Cuanto sube el morro al mirar del todo hacia arriba, en grados. No se puede
## poner lo que se quiera porque el cabezal esta a solo 0,79 m de las manos:
## pasado el punto mas alto del arco (unos 116 grados) el tubo se echa para
## atras y el cabezal BAJA en vez de subir. Con 95 el cabezal llega a 1,51 m,
## por encima de la cabeza del operario y de casi toda la zarza.
@export_range(0.0, 110.0, 1.0) var inclinacion_alta := 95.0
## Rapidez con la que el morro sube y baja, en grados por segundo. Antes era un
## 120 clavado en el codigo, y eso en un movimiento de 110 grados de recorrido
## se nota como un latigazo: el morro llegaba arriba de golpe. Con 50 el tubo
## pesa, que es lo que se busca, y sigue llegando antes de un segundo.
@export_range(5.0, 200.0, 1.0) var rapidez_inclinacion := 50.0
## Cuanto bajan las manos del cuerpo al trabajar, en metros.
@export var caida_max := 0.26
## Cuanto baja la vista cuando la maquina esta trabajando, en metros. Es el
## inclinarse sobre el terreno: los ojos van detras de las manos.
@export var vista_baja := 0.30

# --- La resistencia de la maleza -------------------------------------------

## Cuantas hojas por metro cuadrado (contando lo que cuesta cada tipo) para que
## la maleza se note AL MAXIMO.
##
## Va deliberadamente por encima de la densidad con la que se siembra, para que
## el tope no se alcance nunca en un cesped normal y haya recorrido de verdad
## entre un claro y un zarzal. Con el cesped a 60 por m2 esto da 0,55 en el
## cesped y se va a 1 sobre la maleza alta; si se pusiera a 45 el cesped entero
## estaria siempre al tope y el frenao no diria nada.
@export_range(5.0, 300.0, 1.0) var densidad_corte := 110.0
## Cuanto frena el motor la maleza mas densa, de 0 a 1. Con 0,22 el tope son
## unas 2.000 rpm de menos de 9.000: se oyen, pero la maquina no se para.
@export_range(0.0, 1.0, 0.01) var frenao_motor := 0.22
## Cuanto frena el barrido la maleza mas densa, de 0 a 1. El barrido es lo que
## mas se nota, porque es el movimiento grande: con 0,30 la maquina va por la
## maleza cerrada como por barro y por el cesped normal casi igual de deprisa.
@export_range(0.0, 1.0, 0.01) var frenao_barrido := 0.30
## Cada cuanto se mira cuanta maleza hay debajo, en segundos. Mirarlo cada
## fotograma es recorrer la rejilla de corte sin parar, y la respuesta es
## lentisima de todos modos: a 0,15 s el motor entra y sale del frenao de
## golpe y no se nota el escalon.
@export_range(0.05, 1.0, 0.01) var intervalo_resistencia := 0.15
## Cuanto por delante del cabezal se mira la maleza, en metros.
##
## Esto no es un detalle: la desbrozadora corta en el punto donde esta el
## cabezal, asi que si se pregunta la densidad justo ahi, siempre sale cero,
## porque la hierba de ese punto acaba de caer en el mismo fotograma. La maquina
## no notaria nunca resistencia en un cesped entero. Preguntando un poco por
## delante se mide lo que va a encontrar, que es lo que de verdad frena: es el
## mismo truco que lleva mirando el porvenir un pelo antes deMeter la cuchilla.
@export_range(0.0, 2.0, 0.05) var anticipacion_resistencia := 0.40
## Cuanto tarda el motor en entrar y salir del frenao, en segundos. Es el
## suavizado, y va aparte de intervalo_resistencia: este es el ritmo con el que
## se DECIDE cuando mirar, y este otro el ritmo con el que se MUYVE el motor.
@export_range(0.05, 2.0, 0.05) var constante_resistencia := 0.45

## RPM en vacío, de solo lectura para los consumidores.
var _rpm := 0.0
var rpm: float:
	get:
		return _rpm
## Estado de corte derivado de las RPM; no se almacena por separado para evitar
## que el booleano y la velocidad del motor puedan divergir.
var cortando: bool:
	get:
		return _rpm > rpm_maximas * 0.15

var _girado := 0.0
var _giro_carrete_acumulado := 0.0
## El barrido de la maquina, en radianes, ya con inercia. Este es el estado:
## el objetivo es lo que se le pide, esto es lo que hace de verdad.
var _barrido := 0.0
## Lo rapido que va ahora mismo. Es lo que da la sensacion de peso: al acelerar
## sube, al frenar baja, y al cambiar de sentido tiene que pasar por cero.
var _velocidad_barrido := 0.0
## El barrido de las caderas, que va detras del de la maquina.
var _barrido_caderas := 0.0
var _inclinacion_actual := 0.0
var _caida := 0.0
var _trabajando := 0.0
## Del punto de las manos al cabezal, y lo que de ahi sale para el tope del
## suelo. Se miden una vez en _medir_maquina().
var _cabeza_local := Vector3.ZERO
var _radio := 1.0
var _angulo_cabeza := 0.0
var _maquina_medida := false
var _caderas: Node3D
var _camara: Camera3D
var _jugador: Jugador
## Cuanto se resiente la maleza ahora mismo, de 0 a 1. 0 es un claro y 1 es
## maleza cerrada. Se guarda ya suavizado: el valor crudo sale a saltos al
## entrar y salir del filo del cabezal, y eso haria oscilar el motor.
var _resistencia := 0.0
## Ultima vez que se pregunto por la maleza de debajo, y lo que se contesto.
var _resistencia_t := 0.0
var _densidad_debajo := 0.0
## La ultima resistencia medida, sin suavizar. El filtro va aparte, en
## _suavizar_resistencia(), porque si no el motor tardaria varios segundos en
## llegar al tope.
var _bruta := 0.0
## La maleza que hay en el campo, para preguntarle por la densidad. Se busca una
## vez por el grupo "hierba", como hace la hierba con la herramienta.
var _campos: Array[Hierba] = []
var _campos_buscados := false


func _ready() -> void:
	# La hierba la busca por este grupo para poder cortarla. Se apunta aqui y
	# no en la escena para que siga funcionando aunque se mueva de sitio.
	add_to_group("herramienta")
	if modelo == null:
		modelo = get_node_or_null("Modelo") as Node3D
	if giro == null and modelo != null:
		giro = _buscar(modelo, "Giro") as Node3D
	if corte == null and giro != null:
		corte = _buscar(giro, "Corte") as Node3D
	if motor_sonido == null:
		motor_sonido = get_node_or_null("Motor") as AudioStreamPlayer3D
	# Las caderas son el padre de este nodo: la maquina cuelga de ahi, no de la
	# camara. Se sube por el arbol porque la escena lo pone en medio y el nombre
	# exacto podria cambiar sin que se entere nadie.
	# Las caderas NO son el padre directo: el padre es el pivote de las manos.
	# Las caderas estan un nivel mas arriba, y es ese nodo el que tiene que
	# girar con retardo. Antes se cogia el padre y el retardo se aplicaba al
	# pivote, con lo que el nodo "Caderas" se quedaba quieto siempre.
	_caderas = _subir_buscando(self, "Caderas") as Node3D
	if _caderas == null:
		_caderas = get_parent() as Node3D
	_jugador = _subir_buscando(self, "Player") as Jugador
	# La camara NO se busca subiendo: cuelga de Cabeza, que es otra rama del
	# arbol, y subiendo desde aqui no se llega nunca. Se busca bajando desde el
	# jugador. Antes se buscaba mal, salia null, y como la funcion de las caderas
	# se salia cuando no encontraba camara, el retardo no existia: la maquina
	# iba clavada al cuerpo. Por eso el yaw va con la mirada del jugador y no
	# con el nodo Camara.
	_camara = _buscar_camara(_jugador) if _jugador != null else null
	# El barrido arranca mirando a donde mira el operario, no en cero: si
	# arrancara en cero, al cargar la escena con la vista ya girada la maquina
	# haria un barrido de golpe.
	_barrido = _limitar(_yaw_mirada() - _jugador.rotation.y) if _jugador != null else 0.0
	_barrido_caderas = _barrido


func _process(delta: float) -> void:
	_acelerador(delta)
	_medir_maquina()
	_mide_resistencia(delta)
	_suavizar_resistencia(delta)
	_mover_barrido(delta)
	_colocar(delta)
	telemetria_actualizada.emit(_rpm, rpm_efectiva(), _resistencia)


## Se mide la maqueta una vez y se guarda el resultado.
##
## Lo que hay que medir es donde esta el cabezal respecto al punto donde se
## sujetan las manos, y eso NO es la posicion del nodo "Corte": ese nodo esta en
## el centro del carrete, y el carrete esta a 1,1 m de las manos. Ademas el
## cabezal no esta en linea recta con las manos, cuelga 0,35 m mas abajo, asi
## que un angulo calculated con la distancia sola se equivoca.
##
## De ahi los dos numeros que se guardan:
##
## - _radio: lo lejos que esta el cabezal de las manos.
## - _angulo_cabeza: hacia que lado cae el cabezal respecto a la horizontal.
##   Con eso el tope del suelo se resuelve en una linea, sin ir probando.
func _medir_maquina() -> void:
	if corte == null or _maquina_medida:
		return
	_maquina_medida = true
	_cabeza_local = _offset_del_cabezal()
	_radio = maxf(_cabeza_local.length(), 0.05)
	_angulo_cabeza = atan2(-_cabeza_local.z, _cabeza_local.y)


## Del punto donde se sujetan las manos al cabezal, en el sistema de la propia
## maqueta. Se sube desde el nodo "Corte" summing transforms hasta llegar a esta
## maqueta, y para justo antes, porque a partir de aqui ya entra el giro que le
## ponemos nosotros y ese si cambia. Asi el vector sale siempre igual, aunque la
## maquina se mueva.
func _offset_del_cabezal() -> Vector3:
	var acum := Transform3D.IDENTITY
	var n := corte
	while n != null and n != self:
		acum = n.transform * acum
		n = n.get_parent()
	return acum.origin


## El acelerador. El boton izquierdo, como en una de verdad: con el motor parado
## el cabezal no corta. Ademas el motor echado echa el peso del cuerpo sobre la
## maquina, asi que el punto de trabajo va con el acelerador.
func _acelerador(delta: float) -> void:
	var acelerado := Input.is_action_pressed("acelerador")
	var objetivo := rpm_maximas if acelerado else 0.0
	var paso := (rpm_maximas / maxf(subida_rpm, 0.01)) if acelerado \
		else (rpm_maximas / maxf(bajada_rpm, 0.01))
	_rpm = move_toward(_rpm, objetivo, paso * delta)
	# El peso del cuerpo sobre la maqueta. Antes la maqueta se movia sola, sin
	# relacion con el motor; esto es lo que la hace trabajar.
	_trabajando = clampf(_rpm / maxf(rpm_maximas, 1.0), 0.0, 1.0)
	if giro != null:
		var incremento := TAU * vueltas_maximas \
			* (_rpm / maxf(rpm_maximas, 1.0)) * delta
		_giro_carrete_acumulado += incremento
		_girado = fmod(_girado + incremento, TAU)
		# Este modelo nuevo tiene el eje de la cuchilla en Y. El modelo anterior
		# usaba Z, por eso el eje no se puede asumir solo por el nombre del nodo.
		# El nodo Giro va sin inclinacion para que la rotacion quede plana.
		giro.rotation.y = _girado
	_sonido()


## El barrido horizontal. Aqui esta casi todo el sentimiento de la maquina, asi
## que va por partes y con las partes nombradas.
##
## El orden de las dos cosas que se mueven:
##
##   1. La MAQUINA barre. Es la que va por delante de todo, y es la que lleva el
##      peso y los topes.
##   2. Las CADERAS van detras de la maquina. Ese retardo es lo que hacia que al
##      girar de golpe la maquina saliera disparada y las caderas a lo suyo.
##
## El barrido se pide de dos maneras, y las dos se suman antes de los topes:
##
##   - Mirar a un lado. El operario gira la cabeza y los ojos, y la maquina que
##     lleva colgada va con ellos. Se mide contra el CUERPO y no contra la
##     camara, porque el cuerpo es justo lo que no se mueve.
##   - A y D, que mueven la maquina a proposito para trabajar el lado que toca.
##
## Y despues el peso: la maquina no llega donde se le pide, llega despues, y
## cuando frenas sigue yendo. Eso es lo que la hace sentir como una
## desbrozadora y no como un brazo.
func _mover_barrido(delta: float) -> void:
	if _jugador == null:
		return
	# 1) Lo que se le pide: mirar de lado mas el barrido a proposito con A y D.
	var entrada := Input.get_axis("mover_izquierda", "mover_derecha")
	# La mirada manda MAS que metro a metro. Antes iba con seguimiento_ojos = 1 y
	# la maquina apenas se movia al mover el raton: el ojo pedia 20 grados y
	# la maquina acababa casi en la linea del cuerpo. Con el multiplicador, la
	# misma mirada la echa el doble de lado, que es lo que se busca: que el
	# raton lleve la herramienta.
	var diferencia_mirada := _envolver(_yaw_mirada() - _jugador.rotation.y)
	var por_ojos := diferencia_mirada * seguimiento_ojos
	# Al reves del signo del eje: D (mover_derecha = 1) echa la maquina a la
	# derecha, que es el lado corto. El valor del export esta en GRADOS, asi que
	# hay que pasarlo a radianes: sin esto, 26 se leia como 26 radianes, que son
	# casi 3 vueltas, y el barrido a proposito se iba a parar al tope siempre.
	var por_teclas := -entrada * deg_to_rad(barrido_teclado)
	# 2) Los topes del cuerpo, antes de darle nada de inercia: si el objetivo ya
	# esta fuera, el tope tiene que estar en el objetivo y no en la posicion
	# actual, o la maquina se quedaria empujando contra un muro invisible.
	var objetivo := _limitar(por_ojos + por_teclas)
	# 3) El peso.
	_avanzar_hacia_el_objetivo(objetivo, delta)
	# 4) Y el tope duro, por si la inercia se ha pasado. Al tocarlo se anula la
	# velocidad, que es lo que hace que el tope se note como un tope y no como una
	# pared blanda a la que se llegue flotando.
	_aplicar_topes()
	# 5) Las caderas, detras. Van con retardo hacia el barrido de la maquina, y
	# como comparten tope tampoco se salen del arco.
	_barrido_caderas = lerp_angle(_barrido_caderas, _barrido,
		minf(1.0, delta * rapidez_caderas))
	if _caderas != null:
		_caderas.rotation.y = _barrido_caderas


## El tope del arco, asimetrico a proposito. El arnes esta en la cadera derecha,
## asi que a la izquierda hay arco de sobra y a la derecha el cuerpo estorba.
func _limitar(angulo: float) -> float:
	return clampf(angulo, -deg_to_rad(max_right_angle), deg_to_rad(max_left_angle))


## El tope de este barrido en el sentido en que va. Se usa para saber cuanto de
## cerca esta de toparse.
func _limite_hacia(angulo: float) -> float:
	return deg_to_rad(max_left_angle if angulo >= 0.0 else max_right_angle)


## Avanza el barrido hacia el objetivo con peso.
##
## Es un muelle amortiguado, y los dos numeros salen de los dos exports:
##
##   rigidez = 1 / inercia^2   (tirar de la maquina hacia donde se le pide)
##   freno   = 2 / inercia     (parar la velocidad que lleva)
##
## El amortiguamiento queda justo (2 por raiz de la rigidez) para que llegue sin
## rebasar, que es lo que quiere una maquina pesada: se para en su sitio, no
## como un muelle de juguete.
func _avanzar_hacia_el_objetivo(objetivo: float, delta: float) -> void:
	var error := _envolver(objetivo - _barrido)
	# OJO con la asimetria: en este muelle la frecuencia vale
	#     w = rigidez / freno = 1 / (2 * peso)
	# porque el freno es justo el critico (2 * rigidez * peso). O sea que
	# multiplicar la rigidez NO cambia nada de como se mueve: se cancela. La
	# unica palanca real para que un lado pese mas que el otro es el peso.
	var peso := maxf(inertia_smoothness, 0.01)
	var hacia := signf(error)
	if hacia < 0.0:
		# A la derecha el arco es corto y el hombro se pone rigido: la maquina
		# va seca, llega pronto y frena en seco.
		peso /= maxf(rigidez_derecha, 1.0)
	else:
		# A la izquierda el aparato va mas cargado: tarda mas en arrancar y
		# le cuesta mas pararse, que es lo que da la sensacion de peso.
		peso *= maxf(masa_izquierda, 1.0)
	var rigidez := 1.0 / (peso * peso)
	var freno := 2.0 * rigidez * peso
	_velocidad_barrido += (error * rigidez - _velocidad_barrido * freno) * delta
	# Tope de velocidad. Tambien evita que se note el muelle: sin el, un salto
	# grande de objetivo daria un latigazo. Y es aqui donde entra la maleza: con
	# frenao_barrido la velocidad maxima baja cuando el cabezal esta en maleja
	# cerrada, y el barrido sale mas lento y con mas peso por la misma palanca.
	var tope := sweep_speed * _factor_barrido()
	_velocidad_barrido = clampf(_velocidad_barrido, -tope, tope)
	_barrido += _velocidad_barrido * delta


# --- La resistencia de la maleza -------------------------------------------

## Cuanto se frena el barrido ahora mismo, de 0 a 1 de lo que se frenaria del
## todo. Sin maleza es 0 y el barrido va igual de rapido que siempre.
func _factor_barrido() -> float:
	return 1.0 - frenao_barrido * _resistencia


## Estimación de las RPM disponibles después de aplicar la carga de maleza.
## `rpm` sigue la demanda del acelerador y alimenta el sonido actual. Esta
## estimación se publica para telemetría; todavía no modifica el sonido ni la
## rotación del carrete mientras se calibra el modelo de carga.
func rpm_efectiva() -> float:
	return _rpm * (1.0 - frenao_motor * _resistencia)


## Que frenao se nota ahora mismo, de 0 a 1. 0 es un claro y 1 es maleza
## cerrada. Lo piden las pruebas.
func resistencia() -> float:
	return _resistencia


## Cuantas hojas por metro cuadrado hay DE PIE bajo el cabezal ahora mismo, en
## todos los tipos de hierba del campo, yagendoles el coste de cada tipo. Solo
## para las pruebas: leerlo cada fotograma es justo lo que hace _mide_resistencia.
func densidad_debajo() -> float:
	return _densidad_debajo


## La direccion horizontal a la que mira el operario, sin altura. Se usa para
## mirar la maleza un poco por delante del cabezal en vez de encima.
func _adelante() -> Vector3:
	var d := Vector3(-sin(_yaw_mirada()), 0.0, -cos(_yaw_mirada()))
	return d if d.length() > 0.001 else Vector3.FORWARD


## Pregunta a la maleza de delante cuanto cuesta. Solo mide; el suavizado esta
## en _suavizar_resistencia(), que va aparte.
##
## Se pregunta cada intervalo_resistencia segundos: consultar la rejilla de
## corte en cada fotograma no aporta información útil y además la
## respuesta va lentisima de todos modos. Y solo con el motor echado, que con el
## motor parado no se esta cortando nada.
func _mide_resistencia(delta: float) -> void:
	# Los campos de hierba se buscan UNA vez, y lo primero del todo. Ojo al
	# orden: antes el "¿no hay campos? pues no hay resistencia" estaba ANTES de
	# la busqueda, con lo que la lista se quedaba vacia para siempre y el frenao
	# no subia nunca, por mas cesped que hubiera.
	if not _campos_buscados:
		_campos.clear()
		for n in get_tree().get_nodes_in_group("hierba"):
			if n is Hierba:
				_campos.append(n as Hierba)
		_campos_buscados = not _campos.is_empty()
	if not cortando or _campos.is_empty():
		_resistencia_t = 0.0
		return
	_resistencia_t += delta
	if _resistencia_t < intervalo_resistencia:
		return
	_resistencia_t = 0.0
	# Un poco POR DELANTE del cabezal, no encima: la hierba de justo debajo ya
	# la ha cortado la maquina en este mismo fotograma, con lo que medir ahi
	# daria siempre cero. Y la distancia no es un numero fijo: tiene que pasar
	# del ancho del cabezal, o el punto caeria dentro de lo recien cortado y
	# seguiria dando cero. Ver anticipacion_resistencia.
	var punto := punto_de_corte()
	var coste := 0.0
	# Se suma la densidad de TODOS los tipos, cada uno con su coste: donde se
	# juntan el cesped y la zarza la maleza es mas cerrada que en cualquiera de
	# los dos por separado, y el frenao tiene que notarlo. densidad_bajo() ya
	# divide por el area del disco, asi que lo que sale son hojas por m2 y la
	# cuenta de los dos tipos se puede sumar tal cual.
	for c in _campos:
		var r := maxf(c.radio_corte, 0.05)
		var d := maxf(anticipacion_resistencia, r + 0.20)
		coste += c.densidad_bajo(punto + _adelante() * d, r) * c.coste_maleza()
	_densidad_debajo = coste
	_bruta = clampf(coste / maxf(densidad_corte, 1.0), 0.0, 1.0)


## El filtro del frenao, cada fotograma y fuera de la medida.
##
## Esto va APARTE a proposito. Si el suavizado se hiciera solo en los fotogramas
## en los que se pregunta (uno cada intervalo_resistencia, unas 6 por segundo),
## el motor tardaria varios segundos en llegar al frenao y en un cesped de 60
## por m2 se quedaba a media carga siempre, sin que se notara nunca el tope. Con
## la medida quieta entre preguntas y el filtro cada fotograma, el motor llega en
## medio segundo y se nota el peso, no el retardo del programa.
func _suavizar_resistencia(delta: float) -> void:
	# Sin motor no hay frenao que notar, y baja a cero sola para que al volver
	# a arrancar no haya un escalon de golpe.
	var objetivo := _bruta if cortando else 0.0
	_resistencia = move_toward(_resistencia, objetivo,
		delta / maxf(constante_resistencia, 0.01))


## Como de cerca esta el barrido de su tope en el sentido dado, de 0 a 1.
func _cercania_al_tope(sentido: float) -> float:
	if sentido == 0.0:
		return 0.0
	return clampf(absf(_barrido) / maxf(_limite_hacia(sentido), 0.001), 0.0, 1.0)


## El tope duro. Si la inercia se ha pasado, se para aqui y se anula la
## velocidad.
func _aplicar_topes() -> void:
	var limite := _limitar(_barrido)
	if not is_equal_approx(_barrido, limite):
		_barrido = limite
		_velocidad_barrido = 0.0
	# Y el tope de las caderas, que comparte arco con el de la maquina.
	_barrido_caderas = clampf(_barrido_caderas,
		-deg_to_rad(max_right_angle), deg_to_rad(max_left_angle))


## Aqui se coloca la maqueta de verdad, en el espacio de las caderas.
func _colocar(delta: float) -> void:
	# La maquina va por delante de las caderas, y su giro es la diferencia entre
	# las dos: asi el angulo que tiene en el mundo es el del barrido, y las
	# caderas se quedan atras girando.
	var giro := _envolver(_barrido - _barrido_caderas)

	# La inclinacion sale de la mirada, y por los DOS lados. Bajas la cabeza y
	# baja el morro, y a partir de mirar_suelo el cabezal esta en el suelo: de ahi
	# en adelante se sigue ni mas, que si no se hunde en tierra. Y si SUBRES la
	# cabeza, el morro sube tambien: antes esta parte no existia y el morro se
	# quedaba clavado en inclinacion_reposo con elpitch a cero, con lo cual el
	# cabezal no pasaba de 0,35 m y no habia forma de cortar nada mas alto que la
	# rodilla por mas arriba que se mirase.
	var hasta_suelo := clampf(_pitch_mirada() / deg_to_rad(maxf(mirar_suelo, 1.0)),
		0.0, 1.0)
	# La subida es el mismo reparto del otro lado, con el signo al reves. Con
	# mirar_alto se llega a toda la altura con el mismo gesture que con
	# mirar_suelo se llega al suelo.
	var hasta_alto := clampf(-_pitch_real() / deg_to_rad(maxf(mirar_alto, 1.0)),
		0.0, 1.0)
	var objetivo_incl := deg_to_rad(inclinacion_reposo
		- _trabajando * inclinacion_acelerando * hasta_suelo
		+ inclinacion_alta * hasta_alto)
	_inclinacion_actual = move_toward(_inclinacion_actual, objetivo_incl,
		deg_to_rad(rapidez_inclinacion) * delta)
	_caida = move_toward(_caida, _trabajando * caida_max * hasta_suelo,
		caida_max * delta * 2.0)

	# El APOYO en el suelo. Se busca el angulo al que el cabezal queda a la
	# altura del suelo, y si el morro queria pasar de ahi se le para. Sin esto la
	# maquina se hunde en la tierra en cuanto bajas la mirada del todo.
	var altura_manos := maxf(altura_cadera - _caida, 0.0)
	var suelo := _altura_del_suelo(altura_manos)
	_inclinacion_actual = maxf(_inclinacion_actual,
		angulo_del_suelo(altura_manos, suelo))

	# El arnes esta a la derecha del cuerpo y el alcance es fijo, porque la
	# maquina va atada y no la sostiene nadie en el aire. Lo que sale de aqui es
	# el arco: al girar, el cabezal no describe un circulo centrado en el cuerpo
	# sino alrededor del arnes, y por eso a la izquierda barre mas recorrido que
	# a la derecha.
	var avance := -(_cabeza_local.y * sin(_inclinacion_actual)
		+ _cabeza_local.z * cos(_inclinacion_actual))
	var manos := Vector3(lateral_cadera, altura_manos, -alcance + avance)

	rotation = Vector3(_inclinacion_actual, giro, deg_to_rad(ladeo))
	position = manos
	_avisar_a_la_camara()


## El barrido de la maquina ahora mismo, en radianes. Lo piden las pruebas.
func angulo_barrido() -> float:
	return _barrido


## Lo lejos que esta el cabezal de las manos, en metros. Se mide una vez, al
## arrancar, y no cambia. Lo piden las pruebas para saber cuanto tiene que
## subir el morro para que el cabezal llegue a una altura dada, que es lo que
## hace falta para comprobar que se puede cortar zarza por encima de la cabeza.
func radio_cabezal() -> float:
	return _radio


## Hacia que lado cae el cabezal respecto a la horizontal, en radianes. Con
## esto y con radio_cabezal() la altura del cabezal sale en linea:
##
##     altura = altura_manos + radio * cos(morro - angulo)
##
## que es la misma cuenta que usa angulo_del_suelo(), puesta al reves.
func angulo_cabeza() -> float:
	return _angulo_cabeza


## A que altura llega el cabezal con el morro en el angulo que se le pase, en
## el sistema de las caderas. No es un numero magico: es la cuenta de arriba con
## el morro que hay puesto ahora mismo y las manos a la altura que tienen. La
## usan las pruebas para medir de verdad hasta donde sube la maquina, en vez de
## mirar el angulo del morro y suponer cuanto sube.
func altura_del_cabezal(morro: float, altura_manos: float) -> float:
	return altura_manos + _radio * cos(morro - _angulo_cabeza)


## La inclinacion que tiene la maqueta ahora mismo, en radianes. Lo piden las
## pruebas, que comparan la altura que dice la cuenta con la que de verdad tiene
## el cabezal.
func inclinacion_actual() -> float:
	return _inclinacion_actual


## El morro que hace falta para que el cabezal llegue a una altura dada, en
## radianes. Hay dos soluciones porque la cabeza describe un arco: una por
## delante y otra por detras. Se devuelve la de POR DELANTE, que es la que usa
## el juego al subir la maquina.
##
## El signo es menos, y no un azar. La cuenta de arriba es:
##
##     altura = altura_manos + radio * cos(morro - angulo)
##
## y al despejar sale morro = angulo +- acos(caida). Con el MAS, para una
## maleza de 1,45 m salia un morro de unos -0,3 rad: el morro apuntando hacia
## atras y el cabezal en el suelo, que es justo la solucion que nunca se usa
## porque nadie levanta la maqueta kicking hacia atras. Con el menos sale el
## morro de frente y dentro del recorrido real.
func morro_para_altura(altura: float, altura_manos: float) -> float:
	var caida := (altura - altura_manos) / maxf(_radio, 0.001)
	return _angulo_cabeza - acos(clampf(caida, -1.0, 1.0))


## La camara se entera de como esta la maqueta: baja la vista cuando toca
## trabajar y se ladea hacia el lado en el que esta la maquina.
##
## La vista baja porque los ojos van detras de las manos: si el cabezal esta en
## el suelo, hay que inclinar el cuello para llegar. El ladeo va hacia el lado
## de la maqueta, como cuando uno se ladea sobre el trabajo.
func _avisar_a_la_camara() -> void:
	if _jugador != null:
		_jugador.agachado_extra = -vista_baja * _trabajando
	if _camara != null:
		_camara.ladeo_herramienta = _ladeo_herramienta()


## Cuanto se ladea la vista hacia donde esta la maquina, en grados. Positivo es
## ladearse a la derecha, que es hacia donde esta la maquina.
func _ladeo_herramienta() -> float:
	# Solo se ladea cuando se esta trabajando, que es cuando el cuerpo se echa
	# encima. Con la maqueta en reposo la vista se queda quieta.
	# El barrido esta en radianes y el ladeo sale en grados, con lo que primero
	# se pasa de unos a otros y despues se aplica la ganancia. Multiplicar antes
	# de convertir multiplicaba radianes por 6 y salia un numero sin sentido.
	return rad_to_deg(_barrido) * ganancia_ladeo * _trabajando


func _sonido() -> void:
	if motor_sonido == null or motor_sonido.stream == null:
		return
	_asegurar_bucle()
	# Se pregunta si esta sonando DE VERDAD, y no con una bandera propia. Con la
	# bandera, si el sonido se acababa por lo que fuera, el motor se callaba
	# para siempre sin que nadie lo volviera a arrancar. Preguntando al propio
	# reproductor, si se para, se rearranca solo.
	if _rpm > 60.0:
		if not motor_sonido.playing:
			motor_sonido.play()
	elif motor_sonido.playing:
		motor_sonido.stop()
	# El tono sube con las revoluciones: eso es lo que se oye cuando acelera, y
	# no solo que esta encendido.
	motor_sonido.pitch_scale = clampf(0.55 + 1.15 * (_rpm / maxf(rpm_maximas, 1.0)),
		0.4, 2.2)
	if _rpm > 1.0:
		motor_sonido.volume_db = linear_to_db(
			clampf(_rpm / maxf(rpm_maximas, 1.0), 0.05, 1.0))
	else:
		motor_sonido.volume_db = -60.0


## El motor tiene que repetir en bucle, y el WAV no viene asi.
##
## Sin esto el pitido suena una vez, se acaban los 2 segundos de sample y el
## motor se queda mudo para siempre, que es exactamente lo que hacia: el
## reproductor ya habia terminado y nadie lo volvia a llamar.
##
## El numero de frames sale de la duracion y de la frecuencia, y NO de
## data.size(), porque el WAV se importa comprimido y los bytes no son frames.
## Con data.size() salen 17.864 frames en vez de 44.100, y el bucle se
## comeria solo el primer segundo.
func _asegurar_bucle() -> void:
	var flujo := motor_sonido.stream as AudioStreamWAV
	if flujo == null or flujo.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		return
	flujo.loop_mode = AudioStreamWAV.LOOP_FORWARD
	# El rango solo se toca si no viene uno bueno, que es lo que deja el
	# importador cuando el WAV no lleva los puntos de bucle dentro.
	if flujo.loop_end <= flujo.loop_begin:
		flujo.loop_begin = 0
		flujo.loop_end = int(round(flujo.get_length() * flujo.mix_rate))


# --- Para el sistema de corte (futuro) y para las pruebas ---------------

## Punto donde corta el cabezal, en coordenadas de mundo.
func punto_de_corte() -> Vector3:
	return corte.global_position if corte != null else global_position


## Velocidad del hilo en el punto de corte, en metros por segundo. Ahora mismo
## es solo la velocidad de giro; cuando haya hierba habra que sumar la del
## jugador.
func velocidad_corte() -> float:
	return vueltas_maximas * (_rpm / maxf(rpm_maximas, 1.0)) * TAU * 0.05


## Rotación acumulada del carrete desde que arrancó la escena, en radianes.
## Se conserva aparte de `_girado`, que es la fase envuelta que escribe el nodo.
func giro_carrete_acumulado() -> float:
	return _giro_carrete_acumulado


## Hacia donde mira el jugador, en radianes. Se le pregunta al jugador, que es
## quien guarda la mira de verdad, y no a la camara: el retardo de la camara es
## otra cosa y aqui solo interesa la intencion de donde se mira.
func _yaw_mirada() -> float:
	return _jugador.get_yaw() if _jugador != null else 0.0


## Cuanto se ha bajado la vista, en radianes y siempre positivo. El jugador
## guarda el pitch con el signo invertido (subir el raton lo baja), asi que aqui
## se le da la vuelta.
##
## OJO: esto se queda solo con la mitad de ABAJO. Para subir el morro hace falta
## el signo entero, y para eso esta _pitch_real() de aqui al lado. Si se
## reutilizase esta para la subida, -_pitch_mirada() daria siempre cero o
## menos y la maquina no subiria nunca.
func _pitch_mirada() -> float:
	return maxf(_pitch_real(), 0.0)


## El pitch de verdad, con su signo: mirando abajo sale positivo y mirando
## arriba negativo. Se separa de _pitch_mirada() porque las dos mitades hacen
## falta y la de arriba no es un "max" sino un "clamp" con el signo al reves.
func _pitch_real() -> float:
	return -(_jugador.get_pitch() if _jugador != null else 0.0)


## El angulo al que el cabezal queda justa y exactamente a la altura "suelo",
## en el sistema de las caderas. El morro no puede pasar de ahi para mas abajo.
##
## El truco esta en que el cabezal no cuelga en linea recta con las manos, sino
## por detras y mas abajo, asi que al bajar el morro el cabezal baja todavia
## mas rapido. Con _angulo_cabeza ya se sabe cuanto se desplaza hacia abajo por
## cada grado, y la cuenta sale sola:
##
##   altura del cabezal = altura de las manos + radio * cos(morro - angulo)
##
## Poniendo eso a la altura del suelo y despejando el morro queda la linea de
## abajo. Da igual que el suelo suba o baje: solo entra por "suelo".
func angulo_del_suelo(altura_manos: float, suelo: float) -> float:
	# Donde tiene que acabar el cabezal, medido desde las manos: si el suelo
	# esta mas abajo que las manos, el cabezal tiene que bajar (y al bajar el
	# morro baja todavia mas rapido, que es lo que dice _angulo_cabeza).
	var caida := (suelo - altura_manos) / _radio
	return _angulo_cabeza - acos(clampf(caida, -1.0, 1.0))


## A que altura esta el suelo bajo el cabezal, en el sistema de las caderas.
##
## Esto no puede ser un numero fijo, y por un motivo concreto: las caderas estan
## a 0,88 m del suelo SOLO cuando el terreno es llano. El suelo de este juego
## es ondulado y el jugador se para en cualquier pendiente, asi que la misma
## maquina tiene que apoyar a distintas alturas. Por eso se lanza un rayo
## hacia abajo y se pregunta.
##
## El rayo sale de la columna del cabezal, no de las manos, porque lo que toca
## el terreno es el cabezal. Si no toca nada (ruido de hierarchical o jugador
## en el aire) se devuelve 0, que es el suelo en terreno llano.
func _altura_del_suelo(altura_manos: float) -> float:
	# Mirando al frente el suelo esta lejos y cualquier valor vale. Se evita el
	# rayo entero, que son unos nanos, pero sobre todo porque en campo abierto
	# se compararia con el punto de partida y daria igual.
	if _pitch_mirada() < deg_to_rad(8.0):
		return 0.0
	var espacio := get_world_3d().direct_space_state
	# Se lanza bajo el centro de corte de la pose del fotograma anterior. Usar
	# una coordenada fija de alcance fallaba al alargar la barra o barrer de lado:
	# el rayo consultaba otra columna del terreno y dejaba el cabezal flotando.
	var corte_actual := punto_de_corte()
	var caderas := _caderas if _caderas != null else self
	var origen := Vector3(corte_actual.x,
		maxf(corte_actual.y, altura_manos) + 1.0, corte_actual.z)
	var q := PhysicsRayQueryParameters3D.create(origen, origen + Vector3.DOWN * 4.0)
	# Se aparta al jugador del rayo. La capsula del jugador es alta y en una
	# pendiente el rayo la puede rozar, y si la Roquea la maquina se apoya en el
	# aire, por encima del terreno.
	if _jugador != null:
		q.exclude = [_jugador.get_rid()]
	var golpe: Dictionary = espacio.intersect_ray(q)
	if golpe.is_empty():
		return 0.0
	return caderas.to_local(golpe["position"]).y


## La primera camara que cuelga de n, buscando por todo su subarbol. Se usa
## para encontrar la camara del jugador, que esta en una rama distinta a la de
## esta maquina y a la que no se llega subiendo.
func _buscar_camara(n: Node) -> Camera3D:
	if n == null:
		return null
	if n is Camera3D:
		return n
	for hijo in n.get_children():
		var hallada := _buscar_camara(hijo)
		if hallada != null:
			return hallada
	return null


## Un angulo metido en el rango de -180 a 180 grados. Los angulos se restan y se
## comparan mucho, y si se dejan sin envolver un giro de 359 grados parece un
## giro de 1, que daria un twist de 358 en vez de 2.
func _envolver(angulo: float) -> float:
	return wrapf(angulo, -PI, PI)


## Sube por el arbol desde n hasta encontrar un nodo con ese nombre. Mas seguro
## que get_node("../.."), que se rompe en cuanto alguien mete un nodo en medio.
func _subir_buscando(n: Node, nombre: String) -> Node:
	var p := n.get_parent()
	while p != null:
		if p.name == nombre:
			return p
		p = p.get_parent()
	return null


func _buscar(root: Node, nombre: String) -> Node:
	if root == null:
		return null
	if root.name == nombre:
		return root
	return root.find_child(nombre, true, false)
