class_name Vegetacion
extends Node3D

## Contrato comun para vegetacion que afecta a la maquina. Cada forma de vida
## conserva sus datos y su sistema de corte propios, pero las herramientas
## pueden medirlas y cortarlas con la misma API.
##
## Esta clase es la que permite que la desbrozadora y la hoz se comporten igual
## con el cesped. Antes el corte era una llamada distinta por herramienta, y
## acababa pasando lo de siempre: una herramienta que cortaba y otra que no, sin
## que nadie supiera por que. Con `tipo_vegetacion` y `cortar_por_banda` las dos
## preguntan exactamente lo mismo.


## Que tipo de vegetacion es. 1 es cesped, 2 maleza alta y 3 zarza. Lo consulta
## la herramienta para decidir si su cabezal puede con esto o no.
func tipo_vegetacion() -> int:
	return 1


## Corta lo que haya en un disco alrededor de `centro`. Devuelve cuantas celdas
## han perdido material.
##
## La base devuelve cero a proposito: una vegetacion que no se sabe cortar no
## tiene que inventar un sistema, tiene que decir que no. Cada forma de vida
## reescribe esta funcion con la suya.
func cortar_por_banda(_centro: Vector3, _radio: float) -> int:
	return 0


func densidad_bajo(_centro: Vector3, _radio: float) -> float:
	return 0.0


func coste_maleza() -> float:
	return 1.0
