"""
Desbrozadora "estilo 100X": una STIHL de bajas prestaciones, en low poly.

Uso:
    flatpak run org.blender.Blender --background --python tools/crear_desbrozadora_100x.py

Que cambia respecto al modelo viejo:
  - Es una FS 25 y no una FS 55: mas corta (1,27 m en vez de 1,47), con el
    motor mas abultado y menos piezas. Una maquina de gama baja se reconoce
    por el deposito cuadrado y el carrete de nailon, no por los adornos.
  - Flat shading en todas las piezas. El modelo viejo iba con use_smooth=True,
    que quita el aire de bloque tocho y encima encarece el export: al
    suavizar, las caras se parten y salen many mas vertices. El presupuesto de
    mallas se decide aqui, no bajando el numero de lados.
  - 6 a 10 lados por pieza y triangulos por debajo de 500. La de antes iba en
    860 con 12 a 20 lados.
  - Colores de fabrica de STIHL: naranja, negro y gris, con una pegatina
    amarilla de aviso y el nailon crudo.

El aire de "How to Fish" (plastico liso, sin texturas, formas tochas y colores
planos) sale de las tres cosas de aqui: pocas caras, sin suavizar y colores
planos. No hace falta mas.

Contrato con el juego, que no se puede cambiar:
  - El nodo raiz se llama "Desbrozadora".
  - "Giro" va en el centro de la cabeza y el codigo le mete giro.rotation.y,
    asi que el carrete tiene que ser hijo suyo y ir centrado en su Y local.
  - "Corte" es hijo de "Giro" y esta en su origen (0, 0, 0). Es donde se
    busca la hierba que hay que cortar.
  - La escena lo gira 180 grados en Y porque el modelo sale mirando hacia -Z.

El origen de la maquina NO se baja a la base: aqui esta donde se sujetan las
dos manos, que es el punto del arnes. Por eso este script no llama a
exportar_blender.preparar(), que si bajaria el motor al suelo. De
exportar_blender solo se usa exportar(), que es la parte de verdad comun.
"""

import math
import os
import sys

import bpy

_AQUI = os.path.dirname(os.path.abspath(__file__))
if _AQUI not in sys.path:
    sys.path.insert(0, _AQUI)
import exportar_blender  # noqa: E402

OUT_DIR = os.path.expanduser("~/Documentos/desarrollos/desbrozadora/models")
OUT_FILE = os.path.join(OUT_DIR, "desbrozadora_100x.glb")

# Medidas en metros. Mas cortas que la anterior porque la de gama baja es mas
# corta, y el encuadre en primera persona se elige con estos numeros.
LONG_TUBO = 0.92
RADIO_TUBO = 0.026
Y_CABEZA = -1.02
Z_CABEZA = -0.30
RADIO_CABEZA = 0.095

# Coste de la maquina en cara de Godot. Se comprueba al final para que un
# cambio en el numero de lados no se cuele sin que nadie se entere.
TRIANGULOS_MAX = 500
LADO_MAX = 10

# Los rangos son los mismos que comprueba tools/ver_modelo.py, para que los dos
# scripts den el mismo veredicto sobre la misma maquina.
ESPERADO_LARGO = (1.0, 1.5)
ESPERADO_ANCHO = (0.15, 0.60)
ESPERADO_CORTE_Y = (-1.25, -0.95)


def material(nombre, rgb, metal=0.0, rugosidad=0.6):
    # Sin use_nodes: en Blender 5 los materiales ya son de nodos y ponerlo
    # avisa de que se va en la 6.0. El Principled se busca igual.
    mat = bpy.data.materials.new(nombre)
    bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rugosidad
    mat.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    return mat


def _apilar(ob, lados, eje):
    """Mete el cilindro en su eje y le quita el suavizado.

    El suavizado se quita a proposito: las caras planas son lo que da el aire de
    juego de bloques tocho, y ademas un 8 lados suavizado se ve como un tubo
    de verdad, que es justo lo que no queremos.
    """
    if lados > LADO_MAX:
        raise ValueError("%s se ha pasado a %d lados: el presupuesto es %d"
                         % (ob.name, lados, LADO_MAX))
    if eje == "X":
        ob.rotation_euler = (0.0, math.radians(90.0), math.radians(90.0))
    elif eje == "Y":
        ob.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    ob.data.name = ob.name
    for poly in ob.data.polygons:
        poly.use_smooth = False


def cilindro(nombre, radio, largo, posicion, mat, lados=8, eje="Z"):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=lados, radius=radio, depth=largo, end_fill_type="NGON"
    )
    ob = bpy.context.active_object
    ob.name = nombre
    _apilar(ob, lados, eje)
    ob.location = posicion
    ob.data.materials.append(mat)
    return ob


def caja(nombre, tamano, posicion, mat, rotacion=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    ob = bpy.context.active_object
    ob.name = nombre
    ob.scale = tamano
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.location = posicion
    ob.rotation_euler = rotacion
    ob.data.name = ob.name
    ob.data.materials.append(mat)
    return ob


def toro(nombre, radio_mayor, radio_menor, posicion, mat, lados=10, seccion=4):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=radio_mayor, minor_radius=radio_menor,
        major_segments=lados, minor_segments=seccion,
    )
    ob = bpy.context.active_object
    ob.name = nombre
    ob.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    ob.location = posicion
    ob.data.name = ob.name
    ob.data.materials.append(mat)
    for poly in ob.data.polygons:
        poly.use_smooth = False
    return ob


def empty(nombre, posicion, tamano=0.1):
    ob = bpy.data.objects.new(nombre, None)
    ob.empty_display_type = "ARROWS"
    ob.empty_display_size = tamano
    bpy.context.collection.objects.link(ob)
    ob.location = posicion
    return ob


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    naranja = material("Naranja", (0.90, 0.33, 0.04), 0.0, 0.45)
    negro = material("Negro", (0.10, 0.10, 0.11), 0.1, 0.55)
    gris = material("Gris", (0.40, 0.41, 0.43), 0.5, 0.40)
    nailon = material("Nailon", (0.82, 0.79, 0.68), 0.0, 0.70)
    amarillo = material("Amarillo", (0.93, 0.74, 0.10), 0.0, 0.50)

    root = empty("Desbrozadora", (0.0, 0.0, 0.0), 0.3)

    # --- Motor: el cacharro gordo de donde sale el tubo ----------------------
    motor = cilindro("Motor", 0.082, 0.24, (0.0, -0.10, -0.12), naranja, 10, "Z")
    # El deposito cuadrado es lo que mas dice "gama baja": en las STIHL caras es
    # redondeado y lleva mas molduras.
    deposito = caja("Deposito", (0.115, 0.105, 0.135), (0.0, 0.015, -0.30), naranja)
    tapa = cilindro("Tapa", 0.030, 0.018, (0.0, 0.015, -0.378), negro, 6, "Z")
    pegatina = caja("Pegatina", (0.001, 0.045, 0.030), (0.084, -0.10, -0.12), amarillo)
    cuello = cilindro("Cuello", 0.046, 0.10, (0.0, -0.115, -0.30), gris, 8, "Z")

    # --- Manos: el arco de la derecha, como en una FS 31 ---------------------
    barra = caja("Barra", (0.26, 0.036, 0.036), (0.125, -0.13, -0.07), negro,
                 rotacion=(0.0, math.radians(-12.0), 0.0))
    mando = cilindro("Mando", 0.030, 0.050, (0.235, -0.150, -0.045), naranja, 8, "Z")

    # --- Tubo: de 6 lados, que es como se ve el tubo de un juego de bloques --
    tubo = cilindro("Tubo", RADIO_TUBO, LONG_TUBO, (0.0, -0.60, Z_CABEZA),
                    negro, 6, "Y")

    # --- Cabezal: el carrete de nailon de las baratas -----------------------
    cabeza = cilindro("Cabeza", RADIO_CABEZA, 0.070, (0.0, Y_CABEZA, Z_CABEZA),
                      gris, 8, "Z")
    reborde = toro("Reborde", RADIO_CABEZA + 0.014, 0.013,
                   (0.0, Y_CABEZA + 0.075, Z_CABEZA), negro, 10, 4)

    # El carrete gira: cuelga de "Giro", no de la raiz. Estas tres van en
    # coordenadas RELATIVAS al centro de la cabeza, porque "Giro" esta
    # desplazado y en absolutas el carrete salia dos metros mas abajo.
    carrete_a = cilindro("CarreteA", 0.058, 0.010, (0.0, -0.068, 0.0), negro, 8, "Z")
    carrete_b = cilindro("CarreteB", 0.058, 0.010, (0.0, 0.068, 0.0), negro, 8, "Z")
    bobina = cilindro("Bobina", 0.046, 0.126, (0.0, 0.0, 0.0), nailon, 8, "Z")
    pomo = cilindro("Pomo", 0.020, 0.030, (0.0, 0.092, 0.0), naranja, 6, "Z")

    # --- Puntos de referencia ----------------------------------------------
    # El centro del carrete: es donde luego se buscara que hay que cortar.
    corte = empty("Corte", (0.0, 0.0, 0.0), 0.08)
    giro = empty("Giro", (0.0, Y_CABEZA, Z_CABEZA), 0.05)

    piezas = [motor, deposito, tapa, pegatina, cuello, barra, mando, tubo, cabeza,
              reborde]
    for ob in piezas:
        ob.parent = root
    for ob in (carrete_a, carrete_b, bobina, pomo, corte):
        ob.parent = giro
    giro.parent = root

    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    bpy.context.view_layer.objects.active = root

    bpy.context.view_layer.update()
    fallos = _informe()
    if fallos:
        print("no se exporta: el modelo no cumple el presupuesto")
        return

    os.makedirs(OUT_DIR, exist_ok=True)
    exportar_blender.exportar(OUT_FILE)
    print("exportado:", OUT_FILE)


def _informe():
    """Mide la maquina y comprueba que no se ha ido de presupuesto."""
    nombres = [o.name for o in bpy.context.scene.objects]
    print("nodos (%d): %s" % (len(nombres), ", ".join(sorted(nombres))))

    mn = [1e9, 1e9, 1e9]
    mx = [-1e9, -1e9, -1e9]
    triangulos = 0
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        triangulos += sum(max(1, len(poly.vertices) - 2)
                          for poly in ob.data.polygons)
        for v in ob.data.vertices:
            mundo = ob.matrix_world @ v.co
            for i in range(3):
                mn[i] = min(mn[i], mundo[i])
                mx[i] = max(mx[i], mundo[i])
    print("caja: x[%.2f, %.2f] y[%.2f, %.2f] z[%.2f, %.2f]"
          % (mn[0], mx[0], mn[1], mx[1], mn[2], mx[2]))

    fallos = 0
    fallos += _ok("largo", mx[1] - mn[1], *ESPERADO_LARGO)
    fallos += _ok("ancho", mx[0] - mn[0], *ESPERADO_ANCHO)
    print("  %d triangulos (el presupuesto es %d)" % (triangulos, TRIANGULOS_MAX))
    fallos += _ok("triangulos", triangulos, 0, TRIANGULOS_MAX)

    # Los dos nodos de los que depende el juego. Si faltan, la escena se
    # queda sin herramienta y no se ve hasta que se juega.
    corte = bpy.context.scene.objects.get("Corte")
    if corte is None:
        print("  [FALLO] falta el nodo Corte")
        fallos += 1
    else:
        # La altura del corte se mide en el nodo "Corte", no en el fondo de la
        # caja: la barra de las manos asoma hacia arriba y ese fondo no
        # significa nada.
        mundo = corte.matrix_world.translation
        print("  punto de corte en (%.2f, %.2f, %.2f)"
              % (mundo.x, mundo.y, mundo.z))
        fallos += _ok("altura del corte", mundo.y, *ESPERADO_CORTE_Y)
        if abs(mundo.x) > 1e-4 or abs(mundo.z - Z_CABEZA) > 1e-4:
            print("  [FALLO] el corte tiene que estar centrado en el cabezal")
            fallos += 1
    for clave in ("Corte", "Giro", "Desbrozadora"):
        if clave not in nombres:
            print("  [FALLO] falta el nodo", clave)
            fallos += 1
    # Los nombres con guion bajo son de Blender ("Cube.001"); la escena y el
    # codigo los buscan por su nombre, asi que se avisa.
    for hijo in nombres:
        if "_" in hijo:
            print("  [AVISO] %s parece un nombre de Blender, no del juego" % hijo)

    print("---")
    print("RESULTADO: %s" % ("todo correcto" if fallos == 0
                             else "%d problema(s)" % fallos))
    return fallos


def _ok(etiqueta, valor, minimo, maximo):
    bien = minimo <= valor <= maximo
    print("  [%s] %s = %.2f (se espera entre %.2f y %.2f)"
          % ("OK" if bien else "FALLO", etiqueta, valor, minimo, maximo))
    return 0 if bien else 1


if __name__ == "__main__":
    main()
