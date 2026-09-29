class_name CabezalDesbrozadora
extends Resource

## Datos de un cabezal. El desgaste activo se guarda en la desbrozadora, no en
## este recurso compartido, para que varias herramientas puedan usar la misma
## definicion sin compartir su estado.
##
## Cada cabezal tiene dos numeros contra cada tipo de vegetacion, y son cosas
## distintas que a menudo van en direcciones opuestas:
##
## - **eficacia** (1 a 5): lo rapido que lo corta.
## - **resistencia** (0 a 5): lo que la vegetacion le hace al cabezal. Cuesta
##   desgaste al filo y frena el motor.
##
## La logica del juego esta en que subir de nivel NO es "mejor en todo". El
## nylon es el mas rapido contra la hierba y el mas fragil contra todo lo demas:
## contra la zarza la corta, pero se la come y frena el motor a tope. Los discos
## Duran mas y abren la maleza y la zarza, pero se arrastran por el cesped. Por
## eso elegir cabezal es elegir trabajo, y no hay uno que gane siempre.

@export var id: StringName = &""
@export var nombre := "Cabezal"
## Null representa la cuchilla que viene montada en el modelo de serie.
@export var modelo: PackedScene
## Peldaño de mejora. 1 es el mas barato y fragil, 3 el mas duro y caro.
@export_range(1, 3, 1) var nivel := 1
@export_range(0.05, 1.5, 0.01) var radio_corte := 1.0

@export_group("Eficacia (1 a 5)")
## Cuanto mas rapido corta el cesped. El nylon gana aqui y solo aqui.
@export_range(1, 5, 1) var eficacia_hierba := 3
## Cuanto mas rapido abre la maleza alta.
@export_range(1, 5, 1) var eficacia_maleza := 3
## Cuanto mas rapido tumba la zarza.
@export_range(1, 5, 1) var eficacia_zarza := 3

@export_group("Resistencia (0 a 5)")
## Cuanto desgaste le hace el cesped al filo.
@export_range(0, 5, 1) var resistencia_hierba := 1
## Cuanto desgaste hace la maleza y cuanto frena el motor.
@export_range(0, 5, 1) var resistencia_maleza := 2
## Cuanto desgaste hace la zarza y cuanto frena. El 5 es "la corta pero aguanta
## poco y frena muchisimo", que es justo el nylon.
@export_range(0, 5, 1) var resistencia_zarza := 3


## Eficacia de este cabezal contra un tipo de vegetacion.
func eficacia_de(tipo: int) -> int:
	match tipo:
		1: return eficacia_hierba
		2: return eficacia_maleza
		3: return eficacia_zarza
	return 0


## Resistencia de este cabezal contra un tipo de vegetacion, de 0 a 5.
func resistencia_de(tipo: int) -> int:
	match tipo:
		1: return resistencia_hierba
		2: return resistencia_maleza
		3: return resistencia_zarza
	return 0


## Todo cabezal corta cualquier vegetacion: no hay una lista de "con esto no
## puedes". Antes si la habia, y era una trampa: con el nylon puesto no se podia
## ni rozar la maleza, cuando el nylon la abre de pena. Ahora la pregunta
## "¿puede?" no tiene sentido y la unica que importa es "cuanto de resultado".
func puede_cortar(_tipo: int) -> bool:
	return true


## Cuanto se consume el filo por cada hoja cortada, ya con la resistencia de
## este cabezal contra esa planta. Se divide entre 5 para que un 0 no gaste nada
## y un 5 gaste lo que gastaba la planta entera.
func desgaste_por_hoja_para(tipo: int) -> float:
	return float(resistencia_de(tipo)) / 5.0


## Con que fuerza frena este cabezal la vegetacion que toca, de 0 a 1. Multiplica
## al coste de la planta, que es el numero que de verdad pesa en el motor.
func frenado_para(tipo: int) -> float:
	return float(resistencia_de(tipo)) / 5.0


## Hojas o celdas por segundo que este cabezal puede quitar. La base la pone la
## planta, porque unas se cortan de hoja en hoja y la zarza va por celdas.
func tasa_corte_para(tipo: int, tasa_base: float) -> float:
	return tasa_base * float(eficacia_de(tipo))


## Como se ve en la rueda de inventario: el nombre y el peldaño.
func descripcion_corta() -> String:
	return "%s  ·  nivel %d" % [nombre, nivel]
