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

El contrato del giro:
  El disco se construye horizontal en Blender. `export_yup=True` lo convierte en
  un disco horizontal en Godot, cuyo eje vertical es Y. Por eso el juego anima
  `Giro.rotation.y`. El nodo `Giro` debe exportarse sin inclinación propia para
  que esa rotación siga siendo un giro plano y no se mezcle con otra orientación.

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
from mathutils import Vector

_AQUI = os.path.dirname(os.path.abspath(__file__))
if _AQUI not in sys.path:
    sys.path.insert(0, _AQUI)
import exportar_blender  # noqa: E402

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(PROJECT_DIR, "models")
OUT_FILE = os.path.join(OUT_DIR, "desbrozadora.glb")

# --- Medidas, en metros ---------------------------------------------------
# El motor va en +Y y el cabezal en -Y. La máquina cuelga del (0, 0, 0), que
# está en el manillar. Se alarga el tramo de trabajo para llevar motor/caja hacia
# la cadera y dejar el cabezal a una distancia más realista del cuerpo.
Y_MOTOR = 0.62
Y_CABEZA = -1.56
Z_CORTE = -0.222
# La barra mide 50 mm de grosor y 2,06 m de largo para duplicar aproximadamente
# el tramo de trabajo y dejar el motor detrás del operario.
RADIO_TUBO = 0.025
# El tubo llega hasta dentro del codo del cabezal y hasta la caja de
# engranajes del motor. Si se queda corto, se ve un hueco en las dos uniones.
LARGO_TUBO = 2.06
Y_TUBO = -0.53
Y_CAJA_MOTOR = 0.47

# El manillar es un tubo que sale de la abrazadera, se abre en U y sube por los
# dos lados. El camino va de un puño al otro pasando por el origen, que es la
# abrazadera y el punto donde el juego cuelga las manos.
# Los puntos que suben son los que hacen la curva: un manillar de verdad se dobla
# al final, no se dobla todo recto y luego pega dos palos.
#
# Y_MA es cuanto se separa la abrazadera del origen, hacia el CABEZAL (Y
# negativo). El manillar va mas hacia el centro de la barra que antes, que estaba
# pegado al motor y dejaba toda la barra por delante para la anilla.
Y_MA = -0.100
MANILLAR = (
    (-0.200, Y_MA + 0.045, 0.210),   # puño izquierdo, arriba y atras
    (-0.222, Y_MA - 0.010, 0.125),
    (-0.198, Y_MA - 0.022, 0.038),
    (-0.105, Y_MA - 0.008, 0.000),
    (0.000, Y_MA, 0.000),           # la abrazadera
    (0.105, Y_MA - 0.008, 0.000),
    (0.198, Y_MA - 0.022, 0.038),
    (0.222, Y_MA - 0.010, 0.125),
    (0.200, Y_MA + 0.045, 0.210),    # puño derecho
)
RADIO_BARRA = 0.017
RADIO_PUNO = 0.024
LARGO_PUNO = 0.100

# La anilla del arnes: un collar en la barra con una argolla colgando por
# debajo. Es el punto donde se cuelga el operario.
#
# Va ENTRE el manillar y el cabezal, y separada del manillar. Antes estaba en
# Y_ANILLA = -0.120, o sea practicamente debajo del manillar, y decia "por
# delante" cuando en realidad estaba al lado. Ahora se mide desde el manillar,
# hacia el cabezal, para que la separacion este escrita y no sea casualidad: si
# se mueve el manillar, la anilla le sigue guardando el hueco.
SEPARACION_ANILLA = 0.190
Y_ANILLA = Y_MA - SEPARACION_ANILLA

# El cable del acelerador, del mando del puño derecho al motor. Arranca en el
# gatillo (el punto se calcula ahi, no aqui, para que le siga si se mueve).
#
# Va PEGADO, no cerca: cada punto esta a la distancia justa para que el cable
# toque el tubo, ni mas ni menos. Primero sigue la curva del manillar por fuera,
# gira en la esquina y luego baja por delante de la barra hasta la caja de
# engranajes. La holura de cada tramo se comprueba despues, por tramos, porque
# un cable que se separa se ve que va por el aire.
CABLE = (
    # (punto, tramo, tubo al que tiene que ir pegado)
    (None, None, None),          # el gatillo, se rellena en la funcion
    ((0.2324, Y_MA - 0.0100, 0.1440), "manillar", "manillar"),
    ((0.2170, Y_MA - 0.0220, 0.0430), "manillar", "manillar"),
    ((0.1444, Y_MA - 0.0100, -0.0020), "manillar", "manillar"),
    ((0.0780, Y_MA - 0.0040, -0.0200), "manillar", "manillar"),
    # la esquina: gira del manillar a la barra, sin ir pegado a ninguna de las
    # dos, que ahi no cabe.
    ((0.0500, Y_MA + 0.0140, -0.0200), None, None),
    # y ya por la barra, hacia la caja de engranajes del motor.
    ((0.0243, 0.0400, -0.0060), "barra", "barra"),
    ((0.0250, 0.0900, 0.0000), "barra", "barra"),
    ((0.0250, 0.1450, 0.0000), "barra", "barra"),
    ((0.0250, 0.2300, 0.0000), "barra", "barra"),
    ((0.0250, 0.3150, 0.0000), "barra", "barra"),
    ((0.0250, 0.4000, 0.0000), "barra", "barra"),
    ((0.0250, 0.4650, 0.0000), "barra", "barra"),
)
RADIO_CABLE = 0.007

# El tramo de barra, de la abrazadera a la caja de engranajes. Se usa para
# comprobar que el cable va pegado ahi.
BARRA = ((0.0, Y_TUBO - LARGO_TUBO / 2.0, 0.0),
         (0.0, Y_TUBO + LARGO_TUBO / 2.0, 0.0))

# La abrazadera que une el manillar con la barra. Corta a proposito, para que el
# cable del acelerador pueda pasar por delante al girar hacia la barra.
LARGO_ABRAZADERA = 0.024

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
ESPERADO_LARGO = (2.3, 2.55)
ESPERADO_ANCHO = (0.15, 0.60)
ESPERADO_CORTE_Y = (-1.70, -1.45)

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


# Fallos de la anilla y del cable, que se comprueban al construir el manillar,
# antes de unir las piezas. _informe() los suma despues.
ANILLA_MAL = 0
CABLE_MAL = 0


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


def tubo_trayecto(nombre, puntos, radio, mat, lados=6, referencia=(0.0, 1.0, 0.0)):
    """Un tubo que sigue una polilinea, sin costuras ni uniones.

    En cada punto del camino se coloca un anillo perpendicular a la tangente, y
    los anillos vecinos se empolvan. Asi la curva sale continua, que es justo lo
    que distingue un manillar curvo de una barra recta con dos palos pegados.
    """
    arriba = Vector(referencia)
    camino = [Vector(p) for p in puntos]
    vertices = []
    for i, punto in enumerate(camino):
        if i == 0:
            tangente = camino[1] - camino[0]
        elif i == len(camino) - 1:
            tangente = camino[-1] - camino[-2]
        else:
            tangente = camino[i + 1] - camino[i - 1]
        tangente.normalize()
        n1 = tangente.cross(arriba)
        if n1.length < 1e-6:
            # El camino va en la misma linea que la referencia: se usa otra.
            n1 = tangente.cross(Vector((0.0, 0.0, 1.0)))
        n1.normalize()
        n2 = tangente.cross(n1)
        for j in range(lados):
            a = 2.0 * math.pi * j / lados
            vertices.append(tuple(punto + radio * (math.cos(a) * n1
                                                   + math.sin(a) * n2)))
    caras = []
    for i in range(len(camino) - 1):
        for j in range(lados):
            k = (j + 1) % lados
            caras.append((i * lados + j, i * lados + k,
                          (i + 1) * lados + k, (i + 1) * lados + j))
    # Las dos tapas, para que el tubo sea un solido cerrado.
    caras.append(tuple(range(lados - 1, -1, -1)))
    base = (len(camino) - 1) * lados
    caras.append(tuple(base + j for j in range(lados)))
    return malla_propia(nombre, vertices, caras, mat)


def _distancia_camino(punto, camino):
    """Lo mas lejos que esta un punto de una polilinea, tramos y no puntos.

    Medir solo contra los puntos sueltos da un numero falso: el tubo se crea
    entre punto y punto, y sus vertices caen en medio, lejos de cualquiera de
    los dos. Hay que medir contra el tramo entero.
    """
    camino = [Vector(p) for p in camino]
    mejor = 1e9
    for a, b in zip(camino, camino[1:]):
        u = b - a
        largo = u.length
        if largo < 1e-9:
            continue
        t = max(0.0, min(1.0, (punto - a).dot(u) / (largo * largo)))
        mejor = min(mejor, (punto - (a + u * t)).length)
    if len(camino) == 1:
        mejor = (punto - camino[0]).length
    return mejor


def _muestra_camino(camino, paso=0.005):
    """El camino con puntos intermedios, para poder medir por franjas."""
    camino = [Vector(p) for p in camino]
    salida = []
    for a, b in zip(camino, camino[1:]):
        largo = (b - a).length
        n = max(1, int(largo / paso))
        for i in range(n):
            salida.append(a + (b - a) * (i / n))
    salida.append(camino[-1])
    return salida


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
    caja_motor = cilindro("CajaMotor", 0.048, 0.090, (0.0, Y_CAJA_MOTOR, 0.010),
                          oscuro, 10, "Y")
    return unir("Motor", [bloque, caja_motor])


def pieza_barra(plateado):
    tubo = cilindro("Barra", RADIO_TUBO, LARGO_TUBO, (0.0, Y_TUBO, 0.0),
                    plateado, 10, "Y")
    return unir("Barra", [tubo])


def pieza_manillar(mats):
    """Manillar de cuerno de buey, con los puños arriba.

    No son dos palos clavados en una barra recta, que es como parecia antes y no
    es ergonomic: es un unico tubo que sale de la abrazadera, se abre en U y sube
    por los dos lados. El camino lo recorre tubo_trayecto para que la curva sea
    continua, y los puños de goma van en las dos puntas, con los mandos en el
    derecho.

    Ademas lleva lo que de verdad hace falta en una desbrozadora: la anilla del
    arnes, colgando de la barra por delante del manillar, y el cable del
    acelerador hasta el motor.
    """
    barra = tubo_trayecto("BarraManillar", MANILLAR, RADIO_BARRA, mats["negro"], 6)
    piezas = [barra]

    for lado, punta, anterior in (("Izq", 0, 1), ("Der", -1, -2)):
        # El eje del puño es el del ultimo tramo de la curva, que es el que dice
        # hacia donde apunta el puño.
        hacia = (Vector(MANILLAR[punta]) - Vector(MANILLAR[anterior])).normalized()
        quat = hacia.to_track_quat("Z", "Y")
        centro = Vector(MANILLAR[punta]) + quat @ Vector((0.0, 0.0, 0.030))

        puno = cilindro("Puno%s" % lado, RADIO_PUNO, LARGO_PUNO,
                        (0.0, 0.0, 0.0), mats["goma"], 8, "Z")
        puno.rotation_mode = "QUATERNION"
        puno.rotation_quaternion = quat
        puno.location = centro
        piezas.append(puno)

        if lado == "Der":
            # El gatillo cuelga por debajo del puño, y el paro va encima, que es
            # donde lo llevan las de verdad.
            gatillo = _en_el_puno("Gatillo", (0.022, 0.040, 0.050),
                                  (0.0, -0.032, 0.010),
                                  mats["naranja"], centro, quat)
            piezas.append(gatillo)
            piezas.append(_en_el_puno("Paro", (0.018, 0.016, 0.024),
                                      (0.0, 0.030, 0.030),
                                      mats["rojo"], centro, quat))

    # El cable sale de debajo del gatillo, no de un punto inventado al lado: si
    # el gatillo se mueve, el cable le sigue.
    inicio = tuple(gatillo.matrix_world.translation
                   + gatillo.matrix_world.to_3x3() @ Vector((0.0, -0.020, 0.0)))
    camino = [(inicio, None, None)] + [(p, t, c) for p, t, c in CABLE[1:]]
    cable = tubo_trayecto("Cable", [p for p, _, _ in camino], RADIO_CABLE,
                          mats["negro"], 4, referencia=(0.0, 0.0, 1.0))
    piezas.append(cable)

    # La abrazadera que une el manillar con la barra.
    abrazadera = cilindro("Abrazadera", RADIO_TUBO + 0.011, LARGO_ABRAZADERA,
                          (0.0, 0.0, 0.0), mats["plateado"], 10, "Y")
    piezas.append(abrazadera)

    # La anilla del arnes: collar en la barra, por delante del manillar, y
    # argolla colgando por debajo. Es el punto donde se cuelga el operario.
    collar = cilindro("CollarArnes", RADIO_TUBO + 0.011, 0.030,
                      (0.0, Y_ANILLA, 0.0), mats["plateado"], 10, "Y")
    piezas.append(collar)
    anilla = toro("AnillaArnes", 0.026, 0.007, (0.0, Y_ANILLA, -0.052),
                  mats["plateado"], 8, 3)
    anilla.rotation_euler = (0.0, math.radians(90.0), 0.0)
    piezas.append(anilla)

    # Las piezas se comprueban aqui, antes de unirlas: despues del join solo
    # existe el objeto Manillar y estos nombres ya no estan.
    global ANILLA_MAL, CABLE_MAL
    for clave in ("PunoIzq", "PunoDer", "AnillaArnes", "Cable", "Gatillo",
                  "Paro", "Abrazadera"):
        if not any(p.name == clave for p in piezas):
            print("  [FALLO] falta la pieza del manillar", clave)
            ANILLA_MAL += 1

    # matrix_world no esta al dia hasta que el depsgraph se actualiza, y aqui
    # los objetos son nuevos: sin esto se lee la matriz de antes de moverlos.
    bpy.context.view_layer.update()
    org = anilla.matrix_world.translation
    # Lo que se comprueba es lo que se pidio: separada del manillar, y antes en
    # la barra, o sea entre el manillar y el cabezal. La separacion se mide de
    # verdad, no de memoria: si se junta al mango, se ve.
    holgura = Y_MA - org.y
    if holgura < SEPARACION_ANILLA - 0.005:
        print("  [FALLO] la anilla del arnes esta a %.3f m del manillar: tiene"
              " que estar a %.3f, separada del mango"
              % (holgura, SEPARACION_ANILLA))
        ANILLA_MAL += 1
    elif org.y < Y_CABEZA + 0.10:
        print("  [FALLO] la anilla del arnes se ha ido al cabezal (%.3f)" % org.y)
        ANILLA_MAL += 1
    else:
        print("  [OK] anilla del arnes en (%.2f, %.2f, %.2f), a %.3f m del"
              " manillar, antes en la barra"
              % (org.x, org.y, org.z, holgura))

    # Y el cable tiene que ir PEGADO al tubo, no flotando al lado. Se mide por
    # tramos, porque el tubo cambia: sigue el manillar, gira en la esquina y
    # sigue la barra. La esquina se salta, porque ahi no puede ir pegado a los
    # dos a la vez.
    #
    # La holura es la distancia al eje del tubo menos el radio del tubo. Si es
    # cero, el cable esta tocando; si es positiva, esta en el aire.
    for nombre, tubo in (("manillar", MANILLAR), ("barra", BARRA)):
        radio = RADIO_BARRA if nombre == "manillar" else RADIO_TUBO
        holuras = []
        for i, (punto, tramo, a_que) in enumerate(camino):
            if tramo != nombre:
                continue
            holuras.append(_distancia_camino(Vector(punto), tubo) - radio)
        if not holuras:
            print("  [FALLO] el cable no tiene ningun tramo por la %s" % nombre)
            CABLE_MAL += 1
            continue
        peor = max(holuras)
        print("  cable por la %s: holura maxima %.4f m" % (nombre, peor))
        if peor > 0.005:
            print("  [FALLO] el cable se separa %.4f m de la %s: flota"
                  % (peor, nombre))
            CABLE_MAL += 1
        else:
            print("  [OK] el cable va pegado a la %s" % nombre)

    return unir("Manillar", piezas)


def _en_el_puno(nombre, tamano, offset, mat, centro, quat):
    """Una pieza pegada al puño, colocada en el sistema del propio puño."""
    ob = caja(nombre, tamano, (0.0, 0.0, 0.0), mat)
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = quat
    ob.location = centro + quat @ Vector(offset)
    return ob


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
        # Los punos son de goma: mas oscura, mas mate y mas gordos que la barra,
        # para que se lean de lejos que ahi van las manos.
        "goma": material("Goma", (0.05, 0.05, 0.06), 0.0, 0.85),
        "rojo": material("Rojo", (0.70, 0.08, 0.06), 0.0, 0.45),
    }


def _montar_maquina(mats):
    """La desbrozadora con su cuchilla de serie. Sin cabezales de repuesto."""
    motor = pieza_motor(mats["naranja"], mats["oscuro"])
    barra = pieza_barra(mats["plateado"])
    manillar = pieza_manillar(mats)
    cabezal = pieza_cabezal(mats["plateado"], mats["naranja"], mats["oscuro"],
                             mats["negro"])

    # Regla 3: nada se exporta con rotacion ni escala sin aplicar.
    for ob in (motor, barra, manillar, cabezal):
        aplicar(ob)

    # Giro SIN rotacion: el disco exportado está horizontal y el juego lo anima
    # sobre Y, el eje vertical de Godot. Una inclinación aquí mezclaría ejes.
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

    global ANILLA_MAL, CABLE_MAL
    fallos = 0
    # La anilla y el cable se comprueban al construir el manillar, antes de
    # unir las piezas, y avisan por pantalla. Se suman aqui, que es donde se
    # decide si la maquina se exporta.
    fallos += ANILLA_MAL + CABLE_MAL
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

    # --- Regla 4: el manillar se curva hacia arriba ------------------------
    manillar = objetos.get("Manillar")
    if manillar is None:
        print("  [FALLO] no esta la pieza Manillar")
        fallos += 1
    else:
        # Lo que distingue un manillar de cuerno de buey de dos palos clavados en
        # una barra recta es que la altura media SUBE segun te alejas del
        # centro. Se mide por franjas de X sobre el camino, no sobre la malla: la
        # malla incluye el cable y los mandos, que la falsearian.
        camino = _muestra_camino(MANILLAR)
        franjas = []
        for x0, x1 in ((0.05, 0.11), (0.11, 0.16), (0.16, 0.30)):
            zs = [p.z for p in camino if x0 <= abs(p.x) < x1]
            franjas.append(sum(zs) / len(zs) if zs else 0.0)
        print("  manillar: altura media por franjas %.3f, %.3f, %.3f m"
              % tuple(franjas))
        if not (franjas[0] < franjas[1] < franjas[2] and franjas[2] > 0.10):
            print("  [FALLO] el manillar no se curva hacia arriba: parece una"
                  " barra recta con dos palos")
            fallos += 1
        else:
            print("  [OK] manillar curvo, con los punos arriba")

        # Y la barra tiene que cruzar el eje de la maquina, que es donde van las
        # manos. El manillar ya no esta en Y=0 exacto: esta a Y_MA, hacia el
        # cabezal, asi que lo que se comprueba es que el punto central de su
        # camino este en Y_MA. Se mira el camino y no el objeto, porque despues
        # del unir el origen del objeto se queda donde estaba, en Y=0.
        central = Vector(MANILLAR[len(MANILLAR) // 2])
        if abs(central.x) > TOLERANCIA or abs(central.z) > TOLERANCIA:
            print("  [FALLO] el manillar no esta centrado en X y Z")
            fallos += 1
        elif abs(central.y - Y_MA) > TOLERANCIA:
            print("  [FALLO] el manillar esta en Y=%.3f y deberia estar en %.3f"
                  % (central.y, Y_MA))
            fallos += 1
        else:
            print("  [OK] el manillar cruza la barra en Y=%.3f, ahi van las"
                  " manos" % central.y)


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
    # giro.rotation.y, que es la vertical en Godot; cualquier inclinación previa
    # se mezclaría con la rotación y el disco dejaría de girar plano.
    giro = objetos.get("Giro")
    if giro is not None:
        if any(abs(a) > 1e-6 for a in giro.rotation_euler):
            print("  [FALLO] Giro tiene que ir sin rotacion, para que el giro del"
                  " juego sea sobre la vertical")
            fallos += 1
        else:
            print("  [OK] Giro sin rotacion: el juego lo gira sobre su Y vertical")
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
