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
## `presupuesto` acota cuanto se puede quitar en esta llamada: menos de cero
## significa "sin limite", que es lo que quiere la hoz y lo que usan las pruebas
## para mirar la geometria del corte. Los cabezales de la desbrozadora SI pasan
## presupuesto, porque su eficacia se nota en el tiempo: un nylon no barre la
## banda entera de golpe, se la come a su ritmo.
##
## La base devuelve cero a proposito: una vegetacion que no se sabe cortar no
## tiene que inventar un sistema, tiene que decir que no. Cada forma de vida
## reescribe esta funcion con la suya.
func cortar_por_banda(_centro: Vector3, _radio: float, _presupuesto: float = -1.0) -> int:
	return 0


func densidad_bajo(_centro: Vector3, _radio: float) -> float:
	return 0.0


func coste_maleza() -> float:
	return 1.0


## Cuantas hojas o celdas por segundo se quitan de esta planta con un cabezal de
## eficacia 1. El cabezal multiplica este numero por su eficacia, y ahi esta
## toda la diferencia entre cortar con nylon y cortar con un disco de tres puntas.
##
## El numero sale de medir lo que se tarda en cortar el campo andando. A 2 m/s con
## un cabezal de 0,78 m de radio se barren unos 2,4 m2 por segundo, que con las
## 60 hojas por m2 del campo son unas 150 hojas por segundo. Asi que:
##
## - 50 es un tercio de eso. Con eficacia 1 (el disco de tres puntas) NO se
##   llega a lo que pisas: vas dejando un reguero por delante y hay que volver.
## - Con eficacia 3 (la cuchilla de serie y el disco de dos puntas) se justa.
## - Con eficacia 5 (el nylon) se va por delante de lo que pisas, limpiando.
##
## Cuando esta base estaba en 200, TODO se cortaba en siete fotogramas y los
## cuatro cabezales se sentian igual. El numero tiene que estar por debajo de lo
## que se pisa andando, o la eficacia no decide nada.
##
## La hierba va por hojas sueltas y la maleza con la misma planta, asi que
## comparten base. La zarza va por celdas de tallo, que pesan mas, y por eso
## necesita la suya.
func tasa_corte_base() -> float:
	return 50.0
