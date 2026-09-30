extends SceneTree

## Prueba rapida del sistema de restos nuevo, sin render.
##
##     flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
##         --headless --path . --script tools/probar_restos.gd
##
## Comprueba lo que se puede medir de un pool de particulas: que las piezas
## cargan del .glb, que soltar() acumula y dispara rafagas, que los contadores
## cuadran y que limpiar() deja todo a cero.

var _fallos := 0


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	var restos := Restos.obtener(self)
	_comprobar(restos != null, "el singleton se crea solo en la raiz")
	var cargadas := restos.piezas_cargadas()
	print("  piezas cargadas: %s" % str(cargadas))
	_comprobar(int(cargadas.get(1, 0)) == 3, "3 hojas de cesped")
	_comprobar(int(cargadas.get(2, 0)) == 2, "2 tallos de maleza")
	_comprobar(int(cargadas.get(3, 0)) == 3, "3 canas de zarza")

	restos.limpiar()
	# Un corte de 30 hojas de zarza: con densidad 2 son 60 trozos; la rafaga
	# sale de max_por_rafaga (24) y el resto queda pendiente.
	var salidos := restos.soltar(Vector3(0.0, 0.5, 0.0), 30, Vector3.FORWARD,
		Color(0.2, 0.4, 0.1), 1.2, 3)
	var recuento := restos.recuento()
	print("  recuento: %s" % str(recuento))
	_comprobar(salidos == 24, "la rafaga sale de 24 trozos (max_por_rafaga)")
	_comprobar(int(recuento["soltados"]) == 24, "soltados cuadra con la rafaga")
	_comprobar(int(recuento["pendientes"]) == 36, "los otros 36 quedan pendientes")
	_comprobar(int(recuento["emisores"]) == 48, "el pool tiene 48 emisores")

	# Un corte pequeño CON cola pendiente vuelve a disparar en el acto: es la
	# misma regla que el sistema viejo (si el backlog no baja del minimo, cada
	# corte tira otra rafaga), y es lo que mantiene el chorro continuo.
	var otro := restos.soltar(Vector3(0.0, 0.5, 0.0), 1, Vector3.FORWARD,
		Color(0.2, 0.4, 0.1), 0.7, 1)
	_comprobar(otro == 24, "con cola pendiente, el corte vuelve a disparar")
	_comprobar(int(restos.recuento()["pendientes"]) == 14, "y la cola baja a 14")

	# El drenaje por tiempo: esperando mas de espera_max sale otra rafaga.
	await _esperar(45)
	var tras_espera := restos.recuento()
	_comprobar(int(tras_espera["soltados"]) > 24,
		"pasado espera_max sale la rafaga pendiente (%d)" % int(tras_espera["soltados"]))

	restos.limpiar()
	_comprobar(int(restos.recuento()["soltados"]) == 0, "limpiar pone a cero")
	_comprobar(int(restos.recuento()["pendientes"]) == 0, "y tambien lo pendiente")

	print("---")
	print("RESULTADO: %s" % ("todo correcto" if _fallos == 0
		else "%d fallo(s)" % _fallos))
	quit(0 if _fallos == 0 else 1)


func _esperar(cuadros: int) -> void:
	for _i in cuadros:
		await physics_frame


func _comprobar(ok: bool, que: String) -> void:
	if ok:
		print("  OK   %s" % que)
	else:
		print("  FAIL %s" % que)
		_fallos += 1
