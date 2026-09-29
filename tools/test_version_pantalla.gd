extends SceneTree

## Que el cartel de arranque exista, diga la version de la configuracion y se
## quite solo.
##
##     flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot \
##         --headless --path . --script tools/test_version_pantalla.gd
##
## Estas pruebas **no comprueban que la version sea una en concreto**, y es a
## proposito. Si comprobaran `0.1.0`, fallarian en cuanto la subieras, y
## acabarias viendo un fallo rojo cada vez que versionaras, con lo que enseñas
## a no mirar los fallos. Lo que se comprueba es lo que estaba mal: que el
## numero sale de `project.godot` y no de un segundo sitio escrito a mano.

var _fails := 0


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	_version_existe()
	_el_cartel_sigue_a_la_configuracion()
	_va_arriba_y_se_quita_solo()
	print("\n-- resultado: %s" % ("OK" if _fails == 0 else "%d FALLOS" % _fails))
	quit(0 if _fails == 0 else 1)


## El ajuste tiene que existir y tener algo dentro. Sin el, el ejecutable
## arrancaba igual, sin version y sin avisar de nada, que es como se escapa
## este fallo.
func _version_existe() -> void:
	print("== el numero tiene que existir en la configuracion ==")
	var hay := ProjectSettings.has_setting("application/config/version")
	_ok(hay, "esta la linea en project.godot")
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	_ok(not v.is_empty(), 'y no esta vacia ("%s")' % v)


## Lo importante: el cartel **sigue** a la configuracion. Se cambia el ajuste a
## un numero imposible en caliente y el cartel tiene que cambiar con el. Asi se
## demuestra sin leer el codigo que el numero no esta escrito a mano, que es la
## forma que adoptaria cualquiera que subiera la version una vez y se olvidara
## de actualizar el cartel.
func _el_cartel_sigue_a_la_configuracion() -> void:
	print("\n== el cartel saca el numero de la configuracion ==")
	var original := str(ProjectSettings.get_setting("application/config/version", ""))
	_ok(original != "", "partimos de una version que existe")

	ProjectSettings.set_setting("application/config/version", "987.654.321")
	var durante := _texto_del_cartel()
	_ok(durante.contains("987.654.321"),
		"al cambiar la configuracion, el cartel cambia con ella (\"%s\")" % durante)

	ProjectSettings.set_setting("application/config/version", original)
	var despues := _texto_del_cartel()
	_ok(despues.contains(original),
		"y vuelve al numero bueno cuando se restaura (\"%s\")" % despues)

	# Y el caso que no se puede ver jugando: sin version, el cartel tiene que
	# decirlo en vez de enseñar una linea vacia.
	ProjectSettings.set_setting("application/config/version", "")
	var sin := _texto_del_cartel()
	_ok(sin.contains("sin version"),
		"sin version el cartel lo dice, no sale en blanco (\"%s\")" % sin)
	ProjectSettings.set_setting("application/config/version", original)


## El texto del cartel sin montarlo en la escena. Se monta y se tira acto
## seguido porque `VersionPantalla` es un `Node` y no un `RefCounted`: si se
## creara con `.new()` y se dejara, Godot avisaria de una fuga al salir y
## mediria mas de lo que mide.
func _texto_del_cartel() -> String:
	var cartel := VersionPantalla.new()
	var texto: String = cartel.texto_del_cartel()
	cartel.free()
	return texto


## El reloj va suelto del `_process` justamente para poder saltarlo sin esperar
## los dos segundos y medio de reloj de verdad.
func _va_arriba_y_se_quita_solo() -> void:
	print("\n== el cartel ==")
	var cartel := VersionPantalla.new()
	root.add_child(cartel)
	_ok(cartel.esta_visible(), "sale al arrancar")

	# Un poco antes de tiempo sigue, que si no el cartel parpadea.
	cartel._avanzar(VersionPantalla.SEGUNDOS - 0.2)
	_ok(cartel.esta_visible(), "no desaparece antes de %.1f s" % VersionPantalla.SEGUNDOS)

	cartel._avanzar(0.3)
	_ok(not cartel.esta_visible(), "se quita pasado el tiempo")
	_ok(not cartel.is_processing(),
		"y deja de procesar, que si no gasta un fotograma entero en nada")

	# Y una vez fuera, seguir avanzando no lo rompe.
	cartel._avanzar(50.0)
	_ok(not cartel.esta_visible(), "avanzar mas no lo hace volver")
	cartel.queue_free()


func _ok(ok: bool, que: String) -> void:
	if ok:
		print("  OK   %s" % que)
	else:
		_fails += 1
		print("  FAIL %s" % que)
