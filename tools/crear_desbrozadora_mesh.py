"""
Desbrozadora de gasolina, low poly, en 4 piezas. El modelo simple.

Uso:
    flatpak run --filesystem=$HOME/Documentos org.blender.Blender --background \
        --python tools/crear_desbrozadora_mesh.py
    Las rutas van absolutas: el flatpak arranca Blender en su propio directorio
    y no encuentra el proyecto con rutas relativas.

Las cuatro piezas, y solo cuatro, en models/desbrozadora.glb:
  Motor       caja de esquinas redondeadas en el extremo trasero. Naranja.
  Barra       cilindro recto, de punta a punta, sobre el eje Y. Plateado.
  Manillar    travesano horizontal con los dos agarres VERTICALES y el
              acelerador. Los agarres no van tumbados como en un manillar de
              bicicleta: suben y bajan por el origen, que es donde el juego
              pone las manos.
  Cabezal_Corta  caja de engranajes, protector naranja y cuchilla horizontal.
              Va en su propio objeto, con el origen en el centro de giro.

Y los tres cabezales intercambiables, cada uno en SU PROPIO .glb:
  models/cabezal_hilo.glb      carrete negro con el hilo saliendo por los lados
  models/cabezal_disco_2p.glb  cuchilla recta de dos puntas
  models/cabezal_disco_3p.glb  cuchilla de tres puntas

Por que van en ficheros aparte y no en la maquina:
  El juego es cambiar de cabezal, y ademas poner el mismo cabezal en otra
  desbrozadora. Si los tres vinieran dentro de desbrozadora.glb, la maquina
  llevaria los tres montados a la vez, que es lo que se veia antes.
  Con un .glb por cabezal, el juego instancia el que quiere bajo el nodo "Giro"
  de la maquina que tenga delante y oculta el anterior. Como todos tienen el
  origen en el centro de giro, da igual que maquina sea: encajan igual.

Las tres reglas de alineacion que importan, y como se comprueban:
  1. La Barra es un cilindro recto en Y. Se comprueba que todos sus vertices
      estan a la misma distancia del eje Y y que el eje cae en x=0, z=0: si la
      barra doblara o saliera torcida, dejarian de cumplirse las dos cosas.
  2. El disco va HORIZONTAL, paralelo al suelo. Se comprueba que la pieza de
     corte es plana en Z. Esto es lo que cambia respecto al modelo anterior,
     que lo llevaba vertical.
  3. Todas las piezas pasan por transform_apply antes de exportarse, para que
     no se queden rotaciones ni escalas sin aplicar en el .glb.

El truco del giro, que es lo importante de este archivo:
  El disco es HORIZONTAL, o sea que su eje es la VERTICAL. Y el nodo que gira
  tiene que girar sobre la vertical, no sobre el eje de la maquina.
  Aqui esta la cuenta, que es donde easy se equivoca:
    - Godot compone en YXZ, asi que rotation = (x, y, z) da Ry * Rx * Rz.
    - Si el nodo Gio no tiene inclinacion propia, escribir rotation.z mete
      exactamente un giro sobre su Z, y su Z es la vertical: la escena le da al
      modelo un giro de 180 grados en Y, que no cambia el Z. El disco gira plano.
    - Escribir rotation.y, en cambio, mete un giro sobre el Y de la maquina, que
      es el eje a lo largo del tubo. El disco horizontal daria una vuelta de lado
      a lado, y eso es justo lo que se veía antes.
    - Y una inclinacion propia en X (90 grados) NO arregla nada: en YXZ se
      combina con la Y y el resultado deja de ser un giro sobre la vertical.
      Por eso Giro va sin rotacion ninguna.
  O sea: el disco tumbado obliga a girar sobre Z, y el juego escribe Z.

Y el truco del enganche, que arregla un error que arrastraba el modelo viejo:
  Las piezas se crean en coordenadas de mundo y se enganchan al padre con
  ob.matrix_parent_inverse = padre.matrix_world.inverted(). Si solo se pone
  ob.parent, las coordenadas del hijo se suman al padre y la pieza se va dos
  metros mas abajo. Por eso el modelo viejo llevaba un comentario olyan largo.

Origen: el (0, 0, 0) esta en el centro de agarre, que es donde el manillar
cruza la barra. De ahi cuelga el arnes.
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
OUT_FILE = os.path.join(OUT_DIR, "desbrozadora.glb")

# --- Medidas, en metros ---------------------------------------------------
# El motor va en +Y y el cabezal en -Y. La maquina cuelga del (0, 0, 0), que
# esta en el manillar, y el cabezal queda por debajo y por delante.
Y_MOTOR = 0.30
Y_CABEZA = -0.88
Z_CORTE = -0.222
RADIO_TUBO = 0.022
# El tubo llega hasta dentro del codo del cabezal (-0.91) y hasta la caja de
# engranajes del motor (0.105). Si se queda corto, se ve un hueco en las dos
# uniones, que es justo lo que hay que evitar.
LARGO_TUBO = 1.06
Y_TUBO = -0.36
# Los agarres van de pie y el origen esta en su punto medio, que es donde el
# juego cuelga las manos.
LARGO_EMPUNADURA = 0.180

# Por debajo de esta altura solo hay piezas de corte: el protector, el buje y
# las puntas. El gearbox y el codo cuelgan por encima y no cuentan para medir
# si el disco va tumbado.
Z_PLANO_CORTE = -0.18

LADO_MAX = 12
TRIANGULOS_MAX = 900

# Los mismos rangos que comprueba tools/ver_modelo.py, para que los dos scripts
# den el mismo veredicto sobre la misma maquina. El corte esta donde cae el
# cabezal, unos 0,9 m por delante de las manos; el juego lo mide en tiempo de
# ejecucion, asi que esto es solo una comprobacion de cordura.
ESPERADO_LARGO = (1.0, 1.5)
ESPERADO_ANCHO = (0.15, 0.60)
ESPERADO_CORTE_Y = (-1.05, -0.80)

# Lo que hay que medir para decir que algo esta alineado.
TOLERANCIA = 1e-4
# Un cilindro de 10 lados no es exacto: su radio medido sobre los vertices
# tiene algo de ruido, y la tolerancia de la barra tiene que estar por encima
# de ese ruido o el modelo saldria siempre como fallido.
REDONDEO_TOLERANCIA = 1e-3
GROSOR_MAX = 0.09


def material(nombre, rgb, metal=0.0, rugosidad=0.6):
    # Sin use_nodes: en Blender 5 los materiales ya son de nodos y ponerlo
    # avisa de que se va en la 6.0.
    mat = bpy.data.materials.new(nombre)
    bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rugosidad
    mat.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    return mat


# --- Piezas sueltas -------------------------------------------------------
def _plano(ob, lados, eje="Z"):
    """Sin rotacion si el eje ya esta bien, y sin suavizado.

    El suavizado se quita a proposito: las caras planas son el aire del juego y
    ademas abaratan el export, porque al suavizar Blender parte las caras.
    """
    if lados > LADO_MAX:
        raise ValueError("%s se ha pasado a %d lados: el presupuesto es %d"
                         % (ob.name, lados, LADO_MAX))
    if eje == "X":
        ob.rotation_euler = (0.0, math.radians(90.0), 0.0)
    elif eje == "Y":
        ob.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    ob.data.name = ob.name
    for poly in ob.data.polygons:
        poly.use_smooth = False
    return ob


def cilindro(nombre, radio, largo, posicion, mat, lados=10, eje="Z"):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=lados, radius=radio, depth=largo, end_fill_type="NGON"
    )
    ob = bpy.context.active_object
    ob.name = nombre
    _plano(ob, lados, eje)
    ob.location = posicion
    ob.data.materials.append(mat)
    return ob


def caja(nombre, tamano, posicion, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    ob = bpy.context.active_object
    ob.name = nombre
    ob.scale = tamano
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.location = posicion
    ob.data.name = ob.name
    ob.data.materials.append(mat)
    return ob


def toro(nombre, radio_mayor, radio_menor, posicion, mat, lados=12, seccion=4):
    # El toro nace con su eje en Z, o sea tumbado: justo lo que se le pide al
    # protector, que es un aro horizontal. No hay que girarlo.
    bpy.ops.mesh.primitive_torus_add(
        major_radius=radio_mayor, minor_radius=radio_menor,
        major_segments=lados, minor_segments=seccion,
    )
    ob = bpy.context.active_object
    ob.name = nombre
    ob.location = posicion
    ob.data.name = ob.name
    ob.data.materials.append(mat)
    for poly in ob.data.polygons:
        poly.use_smooth = False
    return ob


def malla_propia(nombre, vertices, caras, mat):
    me = bpy.data.meshes.new(nombre)
    me.from_pydata(vertices, [], caras)
    me.validate()
    me.update()
    ob = bpy.data.objects.new(nombre, me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(mat)
    for poly in me.polygons:
        poly.use_smooth = False
    _caras_hacia_fuera(ob)
    return ob


def _caras_hacia_fuera(ob):
    """Normales hacia fuera.

    Las mallas escritas a mano pueden salir con las caras del reves, y eso en
    Godot se ve como una pieza negra por un lado. Si el operador no existe en
    esta version, se avisa y se sigue.
    """
    try:
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")
    except Exception as exc:  # noqa: BLE001
        print("  aviso: no se han recalculado las normales de %s (%s)"
              % (ob.name, exc))


def punta(nombre, r_in, r_out, ancho_in, ancho_out, grosor, mat, angulo=0.0):
    """Una punta de cuchilla, TUMBADA: en el plano XY, con el grosor en Z.

    Sale en el origen mirando al +X, y de ahi la coloca el giro. Es lo
    contrario que el modelo anterior, que las hacia de pie en el plano XZ.
    """
    v = []
    for x, ancho in ((r_in, ancho_in), (r_out, ancho_out)):
        for z in (-grosor / 2.0, grosor / 2.0):
            for y in (-ancho / 2.0, ancho / 2.0):
                v.append((x, y, z))
    # 0-3 raiz (z-, z+), 4-7 punta. Las seis caras del solido.
    caras = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4),
             (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    ob = malla_propia(nombre, v, caras, mat)
    if angulo:
        ob.rotation_euler = (0.0, 0.0, math.radians(angulo))
    return ob


def unir(nombre, piezas, origen=None):
    """Junta las piezas en un objeto, y opcionalmente le pone el origen."""
    bpy.ops.object.select_all(action="DESELECT")
    for ob in piezas:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = piezas[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = nombre
    ob.data.name = nombre
    if origen is not None:
        bpy.context.scene.cursor.location = origen
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return ob


def aplicar(ob):
    """transform_apply de rotacion y escala, que es la regla del proyecto."""
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def redondear(ob, ancho=0.026, segmentos=2):
    """Esquinas del motor suavizadas, y el modificador aplicado."""
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    mod = ob.modifiers.new("Esquinas", "BEVEL")
    mod.width = ancho
    mod.segments = segmentos
    mod.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=mod.name)


def empty(nombre, posicion, tamano=0.1):
    ob = bpy.data.objects.new(nombre, None)
    ob.empty_display_type = "ARROWS"
    ob.empty_display_size = tamano
    bpy.context.collection.objects.link(ob)
    ob.location = posicion
    return ob


# --- Las cuatro piezas ----------------------------------------------------
def pieza_motor(naranja, oscuro):
    bloque = caja("Motor", (0.145, 0.220, 0.130), (0.0, Y_MOTOR, 0.045), naranja)
    redondear(bloque)
    # La caja de engranajes es del motor, no de la barra. Asi la Barra queda
    # como un unico cilindro recto y se puede medir sin ruido.
    caja_motor = cilindro("CajaMotor", 0.048, 0.090, (0.0, 0.150, 0.010),
                          oscuro, 10, "Y")
    return unir("Motor", [bloque, caja_motor])


def pieza_barra(plateado):
    tubo = cilindro("Barra", RADIO_TUBO, LARGO_TUBO, (0.0, Y_TUBO, 0.0),
                    plateado, 10, "Y")
    return unir("Barra", [tubo])


def pieza_manillar(negro, naranja, oscuro):
    """Travesano horizontal y los dos agarres VERTICALES.

    Los agarres van de pie, no tumbados en el eje del travesano. Un manillar de
    bicicleta los lleva tumbados, y ademas el juego cuelga las manos del
    origen, que aqui es justo el punto donde se cruzan las dos cosas.
    """
    traversano = cilindro("Travesano", 0.018, 0.440, (0.0, 0.0, 0.0),
                          negro, 8, "X")
    izquierda = cilindro("EmpuñaduraIzq", 0.026, LARGO_EMPUNADURA,
                          (-0.200, 0.0, 0.0), negro, 8, "Z")
    derecha = cilindro("EmpuñaduraDer", 0.026, LARGO_EMPUNADURA,
                        (0.200, 0.0, 0.0), negro, 8, "Z")
    # La abrazadera rodea la barra, que pasa por el origen en Y.
    abrazadera = cilindro("Abrazadera", 0.036, 0.050, (0.0, 0.0, 0.0),
                          oscuro, 10, "Y")
    # El acelerador, por delante del agarre derecho.
    gatillo = caja("Acelerador", (0.038, 0.040, 0.110),
                   (0.196, -0.040, 0.020), naranja)
    return unir("Manillar", [traversano, izquierda, derecha, abrazadera, gatillo])


def pieza_cabezal(plateado, naranja, oscuro, negro):
    """El fijo: gearbox, protector y cuchilla. Origen en el centro de giro."""
    codo = cilindro("Codo", 0.030, 0.100, (0.0, Y_CABEZA, -0.030),
                    plateado, 10, "Z")
    engranajes = caja("CajaEngranajes", (0.115, 0.120, 0.100),
                      (0.0, Y_CABEZA, -0.125), plateado)
    protector = toro("Protector", 0.150, 0.024, (0.0, Y_CABEZA, -0.195), naranja)
    porta = cilindro("PortaDisco", 0.055, 0.012, (0.0, Y_CABEZA, -0.215),
                     oscuro, 10, "Z")
    cuchilla = caja("Cuchilla", (0.260, 0.048, 0.006),
                    (0.0, Y_CABEZA, Z_CORTE), negro)
    piezas = [codo, engranajes, protector, porta, cuchilla]
    return unir("Cabezal_Corta", piezas, origen=(0.0, Y_CABEZA, Z_CORTE))


def pieza_hilo(negro, nailon, oscuro):
    """Carrete negro con el hilo saliendo por los lados.

    Se queda en el origen, que ya es el centro de giro: asi el .glb se puede
    soltar bajo el nodo "Giro" de cualquier maquina.
    """
    spool = cilindro("Carrete", 0.055, 0.050, (0.0, 0.0, 0.0), negro, 10, "Z")
    tapa = cilindro("TapaCarrete", 0.040, 0.062, (0.0, 0.0, 0.0), oscuro, 8, "Z")
    lineas = [caja("Hilo%s" % lado, (0.170, 0.009, 0.009),
                   (0.115 * signo, 0.0, 0.0), nailon)
              for lado, signo in (("Izq", -1.0), ("Der", 1.0))]
    return unir("cabezal_hilo", [spool, tapa] + lineas)


def pieza_disco(nombre, puntas, plateado, negro):
    """Cuchilla de n puntas, tumbada, con su buje en el centro.

    Como el carrete, se queda en el origen para poder ir a cualquier maquina.
    """
    buje = cilindro("Buje", 0.050, 0.016, (0.0, 0.0, 0.0), plateado, 10, "Z")
    filo = caja("Filo", (0.030, 0.030, 0.008), (0.0, 0.0, 0.010), negro)
    tips = [punta("Punta%d" % (i + 1), 0.030, 0.130, 0.060, 0.022, 0.006,
                  negro, angulo=360.0 / puntas * i) for i in range(puntas)]
    return unir(nombre, [buje, filo] + tips)


# --- Montaje --------------------------------------------------------------
# Los tres cabezales de repuesto, con cuantas puntas lleva cada uno. El 0 es el
# carrete de hilo, que no tiene puntas.
CABEZALES = (("cabezal_hilo", 0), ("cabezal_disco_2p", 2), ("cabezal_disco_3p", 3))


def _materiales():
    return {
        "naranja": material("Naranja", (0.90, 0.33, 0.04), 0.0, 0.40),
        "negro": material("Negro", (0.10, 0.10, 0.11), 0.0, 0.60),
        "plateado": material("Metal_Plateado", (0.70, 0.72, 0.75), 0.35, 0.55),
        "oscuro": material("Metal_Oscuro", (0.26, 0.27, 0.29), 0.70, 0.45),
        "nailon": material("Nailon", (0.82, 0.79, 0.68), 0.0, 0.70),
    }


def _montar_maquina(mats):
    """La desbrozadora con su cuchilla de serie. Sin cabezales de repuesto."""
    motor = pieza_motor(mats["naranja"], mats["oscuro"])
    barra = pieza_barra(mats["plateado"])
    manillar = pieza_manillar(mats["negro"], mats["naranja"], mats["oscuro"])
    cabezal = pieza_cabezal(mats["plateado"], mats["naranja"], mats["oscuro"],
                             mats["negro"])

    # Regla 3: nada se exporta con rotacion ni escala sin aplicar.
    for ob in (motor, barra, manillar, cabezal):
        aplicar(ob)

    # Giro SIN rotacion: el disco va tumbado y el juego lo hace girar sobre su
    # Z, que es la vertical. Any inclinacion aqui se combinaria con la del
    # juego en YXZ y el disco dejaria de girar plano.
    giro = empty("Giro", (0.0, Y_CABEZA, Z_CORTE), 0.06)
    root = empty("Desbrozadora", (0.0, 0.0, 0.0), 0.3)

    # Sin esto matrix_world sale sin calcular y se leeria la identidad, con lo
    # que los hijos del Giro se quedarian girados y desplazados al exportar.
    bpy.context.view_layer.update()

    for ob in (motor, barra, manillar):
        ob.parent = root
    giro.parent = root

    # El cabezal se crea en coordenadas de mundo, asi que se engancha con la
    # inversa del padre para que no se mueva. Sin esto las coordenadas del hijo
    # se suman al padre y la pieza se va dos metros mas abajo: es el error que
    # arrastraba el modelo viejo.
    cabezal.parent = giro
    cabezal.matrix_parent_inverse = giro.matrix_world.inverted()

    # El pivote va SIN inversa, al reves que las piezas: tiene que caer donde
    # esta Giro, que ya es el centro de giro. En local no se mueve.
    corte = empty("Corte", (0.0, 0.0, 0.0), 0.08)
    corte.parent = giro

    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.context.view_layer.update()

    fallos = _informe()
    if fallos:
        print("no se exporta: la maquina no cumple el presupuesto")
        return fallos

    os.makedirs(OUT_DIR, exist_ok=True)
    exportar_blender.exportar(OUT_FILE)
    print("exportado:", OUT_FILE)
    return 0


def _montar_cabezal(nombre, puntas):
    """Un cabezal suelto, con el origen en el centro de giro.

    Va en su propio .glb para que el juego lo pueda montar en cualquier
    maquina, no solo en esta.
    """
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Los materiales se crean DESPUES de limpiar: read_factory_settings borra
    # los datablocks, y un material de antes queda apuntando a nada.
    mats = _materiales()
    if puntas:
        ob = pieza_disco(nombre, puntas, mats["plateado"], mats["negro"])
    else:
        ob = pieza_hilo(mats["negro"], mats["nailon"], mats["oscuro"])
    aplicar(ob)

    fallos = _informe_cabezal(nombre, ob)
    if fallos:
        print("no se exporta:", nombre)
        return fallos

    ruta = os.path.join(OUT_DIR, nombre + ".glb")
    exportar_blender.exportar(ruta)
    print("exportado:", ruta)
    return 0


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    fallos = _montar_maquina(_materiales())
    for nombre, puntas in CABEZALES:
        fallos += _montar_cabezal(nombre, puntas)
    print("---")
    print("RESULTADO: %s" % ("todo correcto" if fallos == 0
                             else "%d problema(s)" % fallos))
    return fallos


def _informe():
    """Mide la maquina y comprueba las tres reglas de alineacion."""
    objetos = bpy.context.scene.objects
    nombres = [o.name for o in objetos]
    print("nodos (%d): %s" % (len(nombres), ", ".join(sorted(nombres))))

    mn = [1e9, 1e9, 1e9]
    mx = [-1e9, -1e9, -1e9]
    triangulos = 0
    for ob in objetos:
        if ob.type != "MESH":
            continue
        triangulos += sum(max(1, len(p.vertices) - 2) for p in ob.data.polygons)
        for v in ob.data.vertices:
            mundo = ob.matrix_world @ v.co
            for i in range(3):
                mn[i] = min(mn[i], mundo[i])
                mx[i] = max(mx[i], mundo[i])
    print("caja: x[%.3f, %.3f] y[%.3f, %.3f] z[%.3f, %.3f]"
          % (mn[0], mx[0], mn[1], mx[1], mn[2], mx[2]))

    fallos = 0
    fallos += _ok("largo", mx[1] - mn[1], *ESPERADO_LARGO)
    fallos += _ok("ancho", mx[0] - mn[0], *ESPERADO_ANCHO)
    print("  %d triangulos (el presupuesto es %d)" % (triangulos, TRIANGULOS_MAX))
    fallos += _ok("triangulos", triangulos, 0, TRIANGULOS_MAX)

    # --- Regla 1: la Barra es un cilindro recto en Y ----------------------
    barra = objetos.get("Barra")
    if barra is None:
        print("  [FALLO] no esta la pieza Barra")
        fallos += 1
    else:
        # Que sea recto no es que no tenga grosor, es que TODOS sus vertices
        # estan a la misma distancia del eje Y. Se mide eso, que es lo que se
        # romperia si la barra doblara o saliera torcida.
        ejes = [(barra.matrix_world @ v.co) for v in barra.data.vertices]
        radios = [math.hypot(p.x, p.z) for p in ejes]
        desviacion = max(radios) - min(radios)
        centro_x = (max(p.x for p in ejes) + min(p.x for p in ejes)) / 2.0
        centro_z = (max(p.z for p in ejes) + min(p.z for p in ejes)) / 2.0
        desfase = math.hypot(centro_x, centro_z)
        print("  Barra: largo %.4f m, radio %.4f-%.4f m, eje descentrado %.4f m"
              % (_rango(barra, 1), min(radios), max(radios), desfase))
        fallos += _sin(desviacion, "la barra se tuerce",
                       minimo=0.0, maximo=REDONDEO_TOLERANCIA)
        fallos += _sin(desfase, "la barra no esta centrada en el eje Y",
                       minimo=0.0, maximo=REDONDEO_TOLERANCIA)
        fallos += _ok("largo de la barra", _rango(barra, 1),
                      LARGO_TUBO - 0.01, LARGO_TUBO + 0.01)

    # --- Regla 2: la pieza de corte va horizontal --------------------------
    # Los cabezales de repuesto van en su propio .glb, asi que aqui solo se
    # mira la cuchilla de serie. Cada uno se mide en _informe_cabezal.
    cabezal = objetos.get("Cabezal_Corta")
    if cabezal is None:
        print("  [FALLO] no esta la pieza Cabezal_Corta")
        fallos += 1
    else:
        # El cabezal lleva el gearbox colgando, asi que solo se mide el espesor
        # del conjunto de corte: un disco tumbado es plano en Z.
        plano = _grosor_de_corte(cabezal)
        print("  Cabezal_Corta   plano en Z: %.4f m de canto (el presupuesto es %.2f)"
              % (plano, GROSOR_MAX))
        fallos += _sin(plano, "Cabezal_Corta no va horizontal",
                       minimo=0.0, maximo=GROSOR_MAX)

    # --- Regla 4: el manillar es el de una desbrozadora --------------------
    manillar = objetos.get("Manillar")
    if manillar is None:
        print("  [FALLO] no esta la pieza Manillar")
        fallos += 1
    else:
        # Los agarres de pie: en las puntas del travesano, mas altos que
        # hondos. Un manillar de bicycle los lleva tumbados a lo largo del
        # travesano, y entonces esto falla. Se mira solo la zona de los
        # agarres (x>0,15) porque el travesano es ancho por diseño.
        puntos = [manillar.matrix_world @ v.co for v in manillar.data.vertices]
        agarres = [p for p in puntos if abs(p.x) > 0.15]
        alto = max(p.z for p in agarres) - min(p.z for p in agarres)
        hondo = max(p.y for p in agarres) - min(p.y for p in agarres)
        print("  agarres: %.3f m de alto por %.3f m de fondo"
              % (alto, hondo))
        if alto < 0.12 or alto <= hondo:
            print("  [FALLO] los agarres no van verticales: parecen los de una"
                  " bicicleta")
            fallos += 1
        else:
            print("  [OK] manillar con los agarres verticales")
        mundo = manillar.matrix_world.translation
        if math.hypot(mundo.x, mundo.y) > TOLERANCIA or abs(mundo.z) > TOLERANCIA:
            print("  [FALLO] el manillar no esta centrado en el origen, que es"
                  " donde van las manos")
            fallos += 1
        else:
            print("  [OK] el manillar cruza el origen: ahi van las manos")

    # Y el disco tiene que quedar por debajo de la barra, no al lado.
    corte = objetos.get("Corte")
    if corte is None:
        print("  [FALLO] falta el nodo Corte")
        fallos += 1
    else:
        mundo = corte.matrix_world.translation
        print("  punto de corte en (%.2f, %.2f, %.2f)"
              % (mundo.x, mundo.y, mundo.z))
        fallos += _ok("altura del corte", mundo.y, *ESPERADO_CORTE_Y)
        if abs(mundo.x) > TOLERANCIA or mundo.z > -0.05:
            print("  [FALLO] el corte tiene que estar centrado y por debajo")
            fallos += 1

    for clave in ("Corte", "Giro", "Desbrozadora", "Motor", "Barra", "Manillar"):
        if clave not in nombres:
            print("  [FALLO] falta el nodo", clave)
            fallos += 1

    # El giro: Giro tiene que estar SIN rotacion. El juego escribe
    # giro.rotation.z, que es la vertical, y cualquier inclinacion previa se le
    # sumaria en YXZ y tumbaria el disco.
    giro = objetos.get("Giro")
    if giro is not None:
        if any(abs(a) > 1e-6 for a in giro.rotation_euler):
            print("  [FALLO] Giro tiene que ir sin rotacion, para que el giro del"
                  " juego sea sobre la vertical")
            fallos += 1
        else:
            print("  [OK] Giro sin rotacion: el juego lo gira sobre su Z vertical")
        # El origen del cabezal tiene que estar en el centro de giro.
        cabeza = objetos.get("Cabezal_Corta")
        if cabeza is not None:
            org = cabeza.matrix_world.translation
            if (abs(org.y - Y_CABEZA) > 1e-3 or abs(org.z - Z_CORTE) > 1e-3):
                print("  [FALLO] el origen del cabezal no esta en el centro de giro")
                fallos += 1
            else:
                print("  [OK] el origen del cabezal esta en el centro de giro")

    # Nada se va a exportar con rotacion ni escala sin aplicar.
    sucias = [o.name for o in objetos if o.type == "MESH"
              and (any(abs(a) > 1e-6 for a in o.rotation_euler)
                   or any(abs(a - 1.0) > 1e-6 for a in o.scale))]
    if sucias:
        print("  [FALLO] sin transform_apply:", ", ".join(sucias))
        fallos += 1
    else:
        print("  [OK] todas las mallas con transform aplicado")

    print("---")
    print("RESULTADO: %s" % ("todo correcto" if fallos == 0
                             else "%d problema(s)" % fallos))
    return fallos


def _informe_cabezal(nombre, ob):
    """Comprueba un cabezal suelto, antes de exportarlo a su propio .glb.

    Tres cosas, y las tres son el contrato con el juego:
      1. El origen en el (0, 0, 0), que es el centro de giro. Asi el mismo
         .glb vale para cualquier maquina: se cuelga del nodo "Giro" y ya esta.
      2. Horizontal, plano en Z, para que gire tumbado.
      3. Sin rotacion ni escala sin aplicar.
    """
    print("cabezal %s" % nombre)
    fallos = 0

    mundo = ob.matrix_world.translation
    if mundo.length > TOLERANCIA:
        print("  [FALLO] el origen esta en (%.3f, %.3f, %.3f) y tiene que estar"
              " en el (0, 0, 0), que es el centro de giro"
              % (mundo.x, mundo.y, mundo.z))
        fallos += 1
    else:
        print("  [OK] origen en el centro de giro")

    # Aqui no hay gearbox colgando, asi que se mide el canto entero.
    alto = _rango(ob, 2)
    print("  canto en Z: %.4f m (el presupuesto es %.2f)" % (alto, GROSOR_MAX))
    fallos += _sin(alto, "%s no va horizontal" % nombre,
                   minimo=0.0, maximo=GROSOR_MAX)

    triangulos = sum(max(1, len(p.vertices) - 2) for p in ob.data.polygons)
    fallos += _ok("triangulos", triangulos, 0, TRIANGULOS_MAX)

    if (any(abs(a) > 1e-6 for a in ob.rotation_euler)
            or any(abs(a - 1.0) > 1e-6 for a in ob.scale)):
        print("  [FALLO] sin transform_apply")
        fallos += 1
    else:
        print("  [OK] transform aplicado")
    return fallos


def _valores(ob, eje):
    return [(ob.matrix_world @ v.co)[eje] for v in ob.data.vertices]


def _rango(ob, eje):
    valores = _valores(ob, eje)
    return max(valores) - min(valores)


def _grosor_de_corte(ob):
    """Altura del conjunto de corte, sin el gearbox que cuelga encima."""
    z = [v for v in _valores(ob, 2) if v < Z_PLANO_CORTE]
    return (max(z) - min(z)) if z else 9.9


def _sin(valor, etiqueta, minimo=TOLERANCIA, maximo=9.9):
    bien = minimo <= valor <= maximo
    print("  [%s] %s: %.4f" % ("OK" if bien else "FALLO", etiqueta, valor))
    return 0 if bien else 1


def _ok(etiqueta, valor, minimo, maximo):
    bien = minimo <= valor <= maximo
    print("  [%s] %s = %.2f (se espera entre %.2f y %.2f)"
          % ("OK" if bien else "FALLO", etiqueta, valor, minimo, maximo))
    return 0 if bien else 1


if __name__ == "__main__":
    main()
