class_name Herramienta
extends Resource

## Que es una herramienta: lo minimo para poder llevarla, soltarla, recogerla y
## dibujarla en la rueda del inventario.
##
## Es un Resource y no un script del nodo porque lo que el inventario necesita
## saber de una herramienta (que escena instantiate, como se llama, que caja tiene
## en el suelo) se puede mirar SIN instanciarla. Y el mismo recurso sirve para las
## dos: la desbrozadora y la hoz no se parecen en nada mas.
##
## El nodo que hay en la mano es otra cosa. Cada herramienta tiene el suyo, con
## su logica: la desbrozadora es un motor con barrido y resistencia, y la hoz es
## un palo con un filo. Lo unico que el juego les exige es la misma lista de
## metodos, que el inventario y la vegetacion consultan sin preguntar de que
## clase son.

## Con que nombre la busca el inventario. Es la clave de los huecos.
@export var id: StringName = &""
## Lo que sale escrito en la rueda.
@export var nombre := "Herramienta"
## La escena del nodo que se lleva en la mano.
@export var escena: PackedScene
## Tamano de la caja de colision cuando se suelta y cae al suelo, en metros.
## Es una caja y no la malla del modelo: la malla lleva los rotulos de colision
## del modelo entero y aqui solo hace falta que la herramienta se pare en el
## suelo y se pueda mirar.
@export var caja := Vector3(0.6, 0.4, 0.6)
## Tipos de vegetacion que corta. 1 y 2 son cesped y maleza alta, 3 es la zarza.
@export var tipos_compatibles: Array[int] = [1]
## Radio de corte en metros, para la resistencia del motor y lo que mide la
## vegetacion que tiene delante.
@export var radio_corte := 0.5
## Una linea para la rueda, de la herramienta concreta.
@export var descripcion := ""
