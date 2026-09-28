extends RefCounted

## Simulacion del motor separada de la posicion y el barrido de la herramienta.
## Mantiene por separado las RPM que pide el acelerador y las que quedan bajo
## carga; el combustible se consume segun la demanda y aumenta con la carga.

var rpm_sin_carga := 0.0
var rpm_efectivas := 0.0
var combustible_litros := 0.0
var capacidad_combustible_litros := 0.0

var _rpm_maximas := 9000.0
var _subida_rpm := 0.85
var _bajada_rpm := 0.6
var _caida_rpm_carga := 0.22
var _consumo_base_l_h := 0.85
var _consumo_extra_carga_l_h := 0.55


func configurar(rpm_maximas: float, subida_rpm: float, bajada_rpm: float,
		caida_rpm_carga: float, capacidad_litros: float, inicial_litros: float,
		consumo_base_l_h: float, consumo_extra_carga_l_h: float) -> void:
	_rpm_maximas = maxf(rpm_maximas, 1.0)
	_subida_rpm = maxf(subida_rpm, 0.01)
	_bajada_rpm = maxf(bajada_rpm, 0.01)
	_caida_rpm_carga = clampf(caida_rpm_carga, 0.0, 0.9)
	capacidad_combustible_litros = maxf(capacidad_litros, 0.0)
	combustible_litros = clampf(inicial_litros, 0.0, capacidad_combustible_litros)
	_consumo_base_l_h = maxf(consumo_base_l_h, 0.0)
	_consumo_extra_carga_l_h = maxf(consumo_extra_carga_l_h, 0.0)
	_actualizar_rpm_efectivas(0.0)


func avanzar(delta: float, acelerador: bool, carga: float) -> void:
	var carga_actual := clampf(carga, 0.0, 1.0)
	var hay_combustible := combustible_litros > 0.000001
	var acelerado := acelerador and hay_combustible
	var objetivo := _rpm_maximas if acelerado else 0.0
	var duracion := _subida_rpm if acelerado else _bajada_rpm
	var paso := _rpm_maximas / duracion
	rpm_sin_carga = move_toward(rpm_sin_carga, objetivo, paso * delta)
	_actualizar_rpm_efectivas(carga_actual)
	_consumir(delta, carga_actual)


func repostar(litros: float) -> float:
	var antes := combustible_litros
	combustible_litros = minf(capacidad_combustible_litros,
		combustible_litros + maxf(litros, 0.0))
	return combustible_litros - antes


func _actualizar_rpm_efectivas(carga: float) -> void:
	rpm_efectivas = rpm_sin_carga * (1.0 - _caida_rpm_carga * carga)


func _consumir(delta: float, carga: float) -> void:
	if delta <= 0.0 or combustible_litros <= 0.0:
		return
	# Se usa la demanda del acelerador, no las RPM ya caidas: una carga alta
	# baja las revoluciones disponibles, pero exige mas mezcla al motor.
	var demanda := clampf(rpm_sin_carga / _rpm_maximas, 0.0, 1.0)
	var litros_por_hora := demanda * (_consumo_base_l_h
		+ _consumo_extra_carga_l_h * carga)
	combustible_litros = maxf(0.0,
		combustible_litros - litros_por_hora * delta / 3600.0)
	if combustible_litros < 0.000001:
		combustible_litros = 0.0
