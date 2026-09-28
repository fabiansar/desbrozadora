class_name CabezalDesbrozadora
extends Resource

## Datos de un cabezal. El desgaste activo se guarda en la desbrozadora, no en
## este recurso compartido, para que varias herramientas puedan usar la misma
## definicion sin compartir su estado.

@export var id: StringName = &""
@export var nombre := "Cabezal"
## Null representa la cuchilla que viene montada en el modelo de serie.
@export var modelo: PackedScene
## Tipos de vegetacion que este cabezal puede cortar.
@export var tipos_compatibles: Array[int] = [1]
@export_range(0.05, 1.5, 0.01) var radio_corte := 1.0
## Multiplicador del desgaste por hoja cortada.
@export_range(0.1, 4.0, 0.05) var multiplicador_desgaste := 1.0
