class_name EstacionCabezal
extends RefCounted

## Que cabezal esta montado, cuanto le queda de filo y como responde a cada
## planta. Sin nodo, sin escena y sin fisica.
##
## **Por que esto existe.** Todo esto estaba dentro de `desbrozadora.gd`, que
## habia llegado a 1.160 lineas y era el fichero mas grande del proyecto. Y
## estaba en el peor sitio posible: unas reglas puras de datos mezcladas con el
## codigo que instancia el modelo del cabezal y lo cuelga de la maquina.
##
## Aqui esta el corte, y es limpio: **esta clase no toca un solo nodo.** Decide que
## cabezal va, cuanto filo le queda, y cuanto frena o cuanto corta contra cada
## tipo de planta. Lo unico que hace la maquina es coger el modelo que esta
## clase elige y colgarlo de `Giro`, que es una cosa de dibujo y no de reglas.
##
## El motivo por el que sale bien es que el patron ya estaba probado:
## `motor_desbrozadora.gd` es tambien un `RefCounted` con las reglas del motor, y
## la desbrozadora no tiene ni una linea de simulacion del motor. Esto es lo mismo, con el cabezal.
##
## Y el premio es que **las reglas del cabezal se pueden probar sin escena**: antes
## habia que montar la maquina entera en el arbol para comprobar que el nylon
## dura menos que el disco de tres puntas. Ahora se instancia esto y ya.

## Los cabezales disponibles, en orden. El primero es el que se monta al
## empezar.
var _disponibles: Array[CabezalDesbrozadora]
var _actual: CabezalDesbrozadora
var _indice := -1
## Vida util del filo, de 0 a 1. Baja al cortar, nunca sube.
var _desgaste := 1.0
## El desgaste de cada cabezal por separado, para que cambiar a un repuesto y
## volver no te devuelva un filo nuevo. La llave es el `id` del recurso.
var _desgaste_por_id := {}


## Recibe la lista y **monta el primero**.
##
## Se pasa con un metodo y no en el constructor porque el `@export` de la
## desbrozadora no se puede leer en el `_init` de otro objeto: en ese momento la
## escena todavia no ha cargado los recursos.
##
## Que monte aqui y no lo haga quien llama es a proposito, y lo.recorda una
## prueba: cuando `configurar()` solo guardaba la lista, havia que acordarse
## despues de llamar a `montar(0)`, y quien se olvidaba se quedaba con una
## estacion **sin cabezal y sin ningun error**. Una trampa de las que no se ven
## en el juego porque el juego si se acordaba.
func configurar(lista: Array[CabezalDesbrozadora]) -> void:
	_disponibles = lista
	if not _disponibles.is_empty():
		montar(0)


## El cabezal de datos montado ahora mismo, o `null` si no hay ninguno.
func actual() -> CabezalDesbrozadora:
	return _actual


func indice() -> int:
	return _indice


func hay_cabezal() -> bool:
	return _actual != null


## Lo que va al interfaz: el nombre y el peldaño. "Nivel 3" esta para que se vea
## de un vistazo que subir de cabezal es una decision y no un cambio de adorno.
func nombre() -> String:
	if _actual == null:
		return "Sin cabezal"
	return _actual.descripcion_corta()


## Cuanto filo queda, de 0 a 1.
func desgaste() -> float:
	return _desgaste


## Monta el cabezal de indice. Devuelve si se pudo montar.
##
## Antes de montarlo guarda el desgaste del que salia, y al montar recupera el
## suyo. Sin las dos mitades, cambiar de cabezal a mitad de partida te
## rejuvenece el filo cada vez que voltiejas.
func montar(indice: int) -> bool:
	if indice < 0 or indice >= _disponibles.size():
		return false
	if _actual != null:
		_desgaste_por_id[_actual.id] = _desgaste
	_indice = indice
	_actual = _disponibles[_indice]
	_desgaste = float(_desgaste_por_id.get(_actual.id, 1.0)) if _actual != null else 1.0
	return _actual != null


## Pasa al siguiente de la lista y da la vuelta al final. **No comprueba si el
## motor esta parado**: eso es de la maquina, no del cabezal, y aqui no hay motor.
func siguiente() -> bool:
	if _disponibles.size() < 2:
		return false
	return montar((_indice + 1) % _disponibles.size())


## Vuelve a dejar el filo como estaba. Para las pruebas, que montan y desmontan
## cabezales y no quieren que una medida contaminatione la siguiente.
func reiniciar_desgaste() -> void:
	_desgaste = 1.0
	_desgaste_por_id.clear()


## Radio de pasada actual, reducido a medida que el filo se desgasta.
##
## El filo gastado no solo va mas lento: **corta menos**, y por eso el radio
## tambien. Un cabezal sin filo pasa al lado de las hojas.
func radio_corte_actual(base: float) -> float:
	if _actual == null:
		return base
	var eficiencia := lerpf(0.55, 1.0, _desgaste)
	return _actual.radio_corte * eficiencia


## Cuanto frena el cabezal la vegetacion de ese tipo, de 0 a 1. Lo usa la medida
## de carga del motor: la planta manda con su coste, pero el cabezal decide
## cuanto de ese coste se nota.
func frenado_para(tipo_vegetacion: int) -> float:
	if _actual == null:
		return 1.0
	return _actual.frenado_para(tipo_vegetacion)


## Cuantas hojas o celdas por segundo quita el cabezal de esa vegetacion. La base
## la pone la planta y el cabezal la multiplica por su eficacia, que es donde se
## nota la diferencia entre un nylon y un disco de tres puntas.
func tasa_corte_para(tipo_vegetacion: int, tasa_base: float) -> float:
	if _actual == null:
		return tasa_base
	return _actual.tasa_corte_para(tipo_vegetacion, tasa_base)


## Registra desgaste solo por hojas realmente cortadas, y devuelve cuantas hojas
## conto, que es lo que consume el sonido de corte para dar un golpe mas fuerte
## cuanto mas ha mordido el cabezal.
##
## Lo que gasta el filo es la **resistencia de este cabezal contra esa planta**,
## no la dureza de la planta: el nylon contra la maleza se come el hilo, y un
## disco de tres puntas pasa por encima casi sin enterarse.
func registrar_corte(tipo_vegetacion: int, cantidad: int,
		desgaste_por_hoja: float) -> int:
	if cantidad <= 0 or _actual == null:
		return 0
	var factor := _actual.desgaste_por_hoja_para(tipo_vegetacion)
	_desgaste = maxf(0.0, _desgaste - float(cantidad) * desgaste_por_hoja * factor)
	_desgaste_por_id[_actual.id] = _desgaste
	return cantidad
