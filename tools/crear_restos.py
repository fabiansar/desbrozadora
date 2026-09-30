"""
Restos de vegetacion cortada: la familia de trozos que saltan al desbrozar.

Ocho piezas sueltas de low poly, cada una con su curvatura, su tuerce y su
punta, pensadas para que el escombro se lea como un enredo de vegetacion
troceada y no como cuatro losas repetidas. Antes eran cuatro cintas casi
iguales construidas a codigo en GDScript; ahora son modelos de verdad, hechos
aqui y exportados a models/restos.glb.

La familia, con las medidas reales del juego:

    HojaCesped1..3   laminas de 8-16 cm de largo, 1-3 cm de ancho y 3-5 mm de
                     grueso (planas, no cajas), con arco de hoja y tuerce
    TalloMaleza1..2  tallos de 12-24 cm, mas gruesos y tiesos que la hoja
    CanaZarza1..3    canas de 10-20 cm y 1-2,5 cm de diametro, con el extremo
                     de corte APLASTADO, que es la marca que deja el hilo

Las reglas del contrato con el juego (se comprueban solas en el informe):

  1. Cada pieza es una malla independiente, hija del empty "Restos", con su
     origen CENTRADO EN SU PROPIO VOLUMEN. No van sembradas en el suelo: en
     Godot cada trozo es una particula y rota sobre su origen; centrado es lo
     que hace que gire sobre si mismo y no sobre una punta.
  2. Ningun nodo lleva rotacion ni escala propia: todo va cocido en la malla.
  3. Presupuesto: 40 triangulos por pieza como maximo (la hoz entera son 120).
  4. Un unico material mate "RestoVerde": base blanco verdoso neutro, porque el
     tono lo modula Godot en cada rafaga. Roughness ~0,9 y doble cara.
  5. Color de vertice: mas verde el pie y pajizo la punta, para que un mismo
     trozo cambie de color a lo largo. Sin UV y sin texturas.

Uso:
    flatpak run --filesystem=$HOME/Documentos org.blender.Blender --background \
        --python "$PWD/tools/crear_restos.py"
    Las rutas van absolutas: el flatpak arranca Blender en su propio directorio
    y no encuentra el proyecto con rutas relativas.
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
OUT_FILE = os.path.join(OUT_DIR, "restos.glb")

# Presupuesto por pieza. La hoz entera son 120 triangulos y aqui cada trozo es
# una particula: si una pieza pasa de 40, con cien trozos en pantalla se nota.
MAX_TRIANGULOS = 40

# El color de vertice va de verde en el pie a pajizo en la punta. Son los dos
# extremos de la gradacion; el tono de la planta lo pone Godot por rafaga.
VERDE_CESPED = (0.62, 0.88, 0.45)
PAJA_CESPED = (1.00, 0.95, 0.72)
VERDE_MALEZA = (0.55, 0.78, 0.42)
PAJA_MALEZA = (0.98, 0.92, 0.62)
VERDE_ZARZA = (0.60, 0.80, 0.46)
PAJA_ZARZA = (0.95, 0.88, 0.66)

# Las ocho piezas. Cada una con su forma (arco, tuerce, punta) y su gradacion.
# Los numeros estan escogidos para que no haya dos siluetas iguales: la 1 casi
# recta, la 2 muy doblada, la 3 corta y ancha... y asi. Una pieza recta se lee
# como un palillo; el escombro bueno es un enredo.
PIEZAS = [
    # nombre, tipo, parametros, color pie, color punta
    ("HojaCesped1", "cinta",
     dict(largo=0.11, ancho=0.022, grosor=0.004, arco=0.014, tuerce=30.0, punta=0.008),
     VERDE_CESPED, PAJA_CESPED),
    ("HojaCesped2", "cinta",
     dict(largo=0.15, ancho=0.014, grosor=0.004, arco=0.026, tuerce=70.0, punta=0.014),
     VERDE_CESPED, PAJA_CESPED),
    ("HojaCesped3", "cinta",
     dict(largo=0.085, ancho=0.028, grosor=0.005, arco=0.009, tuerce=12.0, punta=0.006),
     VERDE_CESPED, PAJA_CESPED),
    ("TalloMaleza1", "cinta",
     dict(largo=0.16, ancho=0.010, grosor=0.007, arco=0.012, tuerce=18.0, punta=0.012),
     VERDE_MALEZA, PAJA_MALEZA),
    ("TalloMaleza2", "cinta",
     dict(largo=0.22, ancho=0.009, grosor=0.006, arco=0.024, tuerce=45.0, punta=0.022),
     VERDE_MALEZA, PAJA_MALEZA),
    ("CanaZarza1", "cana",
     dict(largo=0.14, radio=0.012, lados=6, arco=0.020, aplastado=0.30, tuerce=20.0),
     VERDE_ZARZA, PAJA_ZARZA),
    ("CanaZarza2", "cana",
     dict(largo=0.19, radio=0.009, lados=6, arco=0.034, aplastado=0.35, tuerce=50.0),
     VERDE_ZARZA, PAJA_ZARZA),
    ("CanaZarza3", "cana",
     dict(largo=0.11, radio=0.011, lados=6, arco=0.012, aplastado=0.25, tuerce=8.0),
     VERDE_ZARZA, PAJA_ZARZA),
]

# Lo que tiene que medir cada pieza, para el informe. El largo es la dimension
# de la pieza (X); la seccion es lo que mide de canto y de plano, que en las
# piezas curvas NO se puede sacar de la caja envolvente (el arco la engorda):
# se comprueba contra los parametros de construccion, que son la medida real.
ESPERADO = {
    "HojaCesped": dict(largo=(0.08, 0.16), ancho=(0.010, 0.030),
                       grosor=(0.003, 0.005)),
    "TalloMaleza": dict(largo=(0.12, 0.24), ancho=(0.006, 0.014),
                        grosor=(0.005, 0.010)),
    "CanaZarza": dict(largo=(0.10, 0.20), diametro=(0.010, 0.025)),
}


def limpiar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(nombre, color, rugosidad, metalico):
    mat = bpy.data.materials.new(nombre)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rugosidad
    bsdf.inputs["Metallic"].default_value = metalico
    # Doble cara: el trozo gira libre en el aire y desde media vuelta se tiene
    # que ver igual. Es el mismo ajuste que pide el juego para sus particulas.
    mat.use_backface_culling = False
    # El color de vertice en el arbol de nodos es solo para verlo a ojo al
    # abrir el .glb en Blender; el juego pinta con su propio material y lee
    # COLOR_0, que va en la malla.
    nodos = mat.node_tree.nodes
    atributo = nodos.new("ShaderNodeVertexColor")
    atributo.layer_name = "Color"
    atributo.location = (-320.0, 240.0)
    mat.node_tree.links.new(atributo.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def malla_de(nombre, caras, material_obj, coleccion):
    """Crea una malla a partir de una lista de caras (listas de Vector).

    Se soldan los vertices repetidos al pasarlos: cada pieza se construye anillo
    a anillo y cada anillo repite los puntos del anterior, asi que sin soldar
    saldria una malla con las costuras abiertas y el doble de vertices.
    """
    me = bpy.data.meshes.new(nombre)
    indices = {}
    vertices = []
    triangulos = []
    for cara in caras:
        fila = []
        for v in cara:
            clave = (round(v.x, 6), round(v.y, 6), round(v.z, 6))
            if clave not in indices:
                indices[clave] = len(vertices)
                vertices.append(clave)
            fila.append(indices[clave])
        triangulos.append(fila)
    me.from_pydata(vertices, [], triangulos)
    me.validate()
    me.update()
    ob = bpy.data.objects.new(nombre, me)
    ob.data.materials.append(material_obj)
    coleccion.objects.link(ob)
    return ob


def cuadrilatero(caras, a, b, c, d):
    """Anade un cuadrilatero como dos triangulos, con la normal hacia fuera."""
    caras.append([a, b, c])
    caras.append([a, c, d])


def _seccion(lado_y, lado_z, giro):
    """Las cuatro esquinas de una seccion rectangular girada `giro` radianes.

    El orden es antihorario visto desde +X, que es lo que deja las normales de
    los costados hacia fuera con el orden de cuadrilatero() de arriba.
    """
    esquinas = []
    for sy, sz in ((-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)):
        y = sy * lado_y
        z = sz * lado_z
        esquinas.append((y * math.cos(giro) - z * math.sin(giro),
                         y * math.sin(giro) + z * math.cos(giro)))
    return esquinas


def _cerrar_anillos(caras, anillos, con_tapas=True):
    """Cose anillos consecutivos con costados, y tapa los dos extremos."""
    for i in range(len(anillos) - 1):
        actual = anillos[i]
        siguiente = anillos[i + 1]
        lados = len(actual)
        for k in range(lados):
            j = (k + 1) % lados
            cuadrilatero(caras, actual[k], actual[j], siguiente[j], siguiente[k])
    if not con_tapas:
        return
    base = anillos[0]
    punta = anillos[-1]
    # La tapa de la base mira a -X (al reves que el anillo) y la de la punta a
    # +X, para que las dos queden hacia fuera.
    cuadrilatero(caras, base[-1], base[-2], base[-3], base[-4])
    if len(punta) == 4:
        cuadrilatero(caras, punta[0], punta[1], punta[2], punta[3])
    else:
        for k in range(1, len(punta) - 1):
            caras.append([punta[0], punta[k], punta[k + 1]])


def construir_cinta(nombre, largo, ancho, grosor, arco, tuerce, punta, mat, coleccion):
    """Lamina plana y gruesa: hoja de cesped o tallo fino.

    Se barre una seccion rectangular a lo largo de X con cuatro anillos: base,
    dos intermedios y punta. El arco levanta el centro (la pieza se apoya en
    las puntas, como una hoja de verdad), la tuerce la gira sobre su eje, y la
    punta se dobla hacia abajo. El ancho se estrecha hacia la punta.
    """
    secciones = 4
    anillos = []
    for i in range(secciones):
        t = float(i) / float(secciones - 1)
        x = t * largo
        # El arco: sube en el centro y la punta cae. Los dos efectos juntos
        # son los que quitan el aire de tabla.
        z = arco * math.sin(math.pi * t) - punta * (t ** 3) * 3.0
        giro = math.radians(tuerce) * t
        medio_ancho = ancho * 0.5 * (1.0 - 0.85 * t)
        medio_grueso = grosor * 0.5 * (1.0 - 0.40 * t)
        anillos.append([Vector((x, y, z + dz))
                        for y, dz in _seccion(medio_ancho, medio_grueso, giro)])
    caras = []
    _cerrar_anillos(caras, anillos)
    return malla_de(nombre, caras, mat, coleccion)


def construir_cana(nombre, largo, radio, lados, arco, aplastado, tuerce, mat,
                   coleccion):
    """Cana de zarza: tubo de pocos lados con el corte aplastado.

    Tres anillos (corte, medio y punta). El del corte se aplasta en Z, que es
    la marca que deja el hilo al segar: una cana cortada a golpe de nylon sale
    chafada, no redonda. El radio se estrecha hacia la punta y el arco curva
    la cana entera.
    """
    anillos = []
    for t in (0.0, 0.5, 1.0):
        x = t * largo
        z_centro = arco * math.sin(math.pi * t * 0.9)
        giro = math.radians(tuerce) * t
        r = radio * (1.0 - 0.35 * t)
        anillo = []
        for k in range(lados):
            angulo = 2.0 * math.pi * float(k) / float(lados)
            y = r * math.cos(angulo)
            z = r * math.sin(angulo)
            y, z = (y * math.cos(giro) - z * math.sin(giro),
                    y * math.sin(giro) + z * math.cos(giro))
            if t == 0.0:
                z *= aplastado
            anillo.append(Vector((x, y, z_centro + z)))
        anillos.append(anillo)
    caras = []
    _cerrar_anillos(caras, anillos)
    return malla_de(nombre, caras, mat, coleccion)


def centrar(ob):
    """Mueve la malla para que el centro de su volumen caiga en el origen.

    Es la regla de las particulas: Godot rota cada trozo sobre su origen, asi
    que el origen va en el centro y no en una punta.
    """
    me = ob.data
    mn = Vector((min(v.co.x for v in me.vertices),
                 min(v.co.y for v in me.vertices),
                 min(v.co.z for v in me.vertices)))
    mx = Vector((max(v.co.x for v in me.vertices),
                 max(v.co.y for v in me.vertices),
                 max(v.co.z for v in me.vertices)))
    centro = (mn + mx) * 0.5
    for v in me.vertices:
        v.co -= centro
    me.update()


def pintar_gradacion(ob, largo, color_pie, color_punta):
    """Color de vertice: verde en el pie (x=0) y pajizo en la punta (x=largo).

    Se pinta ANTES de centrar, que es cuando el eje X todavia va de 0 a largo.
    """
    me = ob.data
    atributo = me.color_attributes.new(name="Color", type="FLOAT_COLOR",
                                       domain="CORNER")
    for poligono in me.polygons:
        for indice_loop in poligono.loop_indices:
            x = me.vertices[me.loops[indice_loop].vertex_index].co.x
            t = min(max(x / largo, 0.0), 1.0)
            atributo.data[indice_loop].color = (
                color_pie[0] + (color_punta[0] - color_pie[0]) * t,
                color_pie[1] + (color_punta[1] - color_pie[1]) * t,
                color_pie[2] + (color_punta[2] - color_pie[2]) * t,
                1.0)
    me.color_attributes.active_color_index = len(me.color_attributes) - 1


def triangulos_de(ob):
    return sum(max(1, len(p.vertices) - 2) for p in ob.data.polygons)


def _montar():
    limpiar()
    escena = bpy.context.scene
    raiz = bpy.data.objects.new("Restos", None)
    escena.collection.objects.link(raiz)

    mate = material("RestoVerde", (0.93, 0.97, 0.88), 0.9, 0.0)

    for nombre, tipo, parametros, color_pie, color_punta in PIEZAS:
        if tipo == "cinta":
            ob = construir_cinta(nombre, mat=mate, coleccion=escena.collection,
                                 **parametros)
        else:
            ob = construir_cana(nombre, mat=mate, coleccion=escena.collection,
                                **parametros)
        pintar_gradacion(ob, parametros["largo"], color_pie, color_punta)
        centrar(ob)
        ob.parent = raiz
    bpy.context.view_layer.update()
    return _informe(raiz)


def _informe(raiz):
    objetos = bpy.context.scene.objects
    nombres = sorted(o.name for o in objetos)
    print("nodos (%d): %s" % (len(nombres), ", ".join(nombres)))

    fallos = 0
    if raiz.name != "Restos":
        print("  [FALLO] falta la raiz Restos")
        fallos += 1

    esperadas = [p[0] for p in PIEZAS]
    for nombre in esperadas:
        if nombre not in nombres:
            print("  [FALLO] falta la pieza %s" % nombre)
            fallos += 1
    sobran = [n for n in nombres if n not in esperadas and n != "Restos"]
    if sobran:
        print("  [FALLO] nodos que no tocan: %s" % ", ".join(sobran))
        fallos += 1

    total = 0
    for nombre, tipo, parametros, _cp, _cu in PIEZAS:
        ob = objetos.get(nombre)
        if ob is None:
            continue
        tris = triangulos_de(ob)
        total += tris
        dim = ob.dimensions
        familia = nombre.rstrip("0123456789")
        rango = ESPERADO[familia]
        problemas = []
        if tris > MAX_TRIANGULOS:
            problemas.append("%d tris (max %d)" % (tris, MAX_TRIANGULOS))
        largo = parametros["largo"]
        if not (rango["largo"][0] <= largo <= rango["largo"][1]):
            problemas.append("largo %.3f m fuera de (%.2f, %.2f)"
                             % (largo, rango["largo"][0], rango["largo"][1]))
        if abs(dim.x - largo) > 0.001:
            problemas.append("la malla no mide el largo que dice (%.3f)" % dim.x)
        if tipo == "cinta":
            if not (rango["ancho"][0] <= parametros["ancho"] <= rango["ancho"][1]):
                problemas.append("ancho %.3f m fuera de (%.2f, %.2f)"
                                 % (parametros["ancho"], rango["ancho"][0],
                                    rango["ancho"][1]))
            if not (rango["grosor"][0] <= parametros["grosor"] <= rango["grosor"][1]):
                problemas.append("grueso %.3f m fuera de (%.3f, %.3f)"
                                 % (parametros["grosor"], rango["grosor"][0],
                                    rango["grosor"][1]))
        else:
            diametro = parametros["radio"] * 2.0
            if not (rango["diametro"][0] <= diametro <= rango["diametro"][1]):
                problemas.append("diametro %.3f m fuera de (%.3f, %.3f)"
                                 % (diametro, rango["diametro"][0],
                                    rango["diametro"][1]))
            # La marca del hilo: el anillo del corte tiene que estar mucho mas
            # chato que el del medio. Si no, la cana se lee como un tubo cortado
            # limpio y pierde justo lo que la hace de zarza.
            me = ob.data
            x_base = min(v.co.x for v in me.vertices)
            z_base = [v.co.z for v in me.vertices if abs(v.co.x - x_base) < 1e-4]
            z_medio = [v.co.z for v in me.vertices if abs(v.co.x) < 0.02]
            chato = ((max(z_base) - min(z_base))
                     / max(max(z_medio) - min(z_medio), 1e-6))
            if chato > 0.6:
                problemas.append("el corte no esta aplastado (%.2f del medio)"
                                 % chato)
        # Origen centrado en el volumen: |centro de la caja| casi cero.
        me = ob.data
        for eje, indice in (("x", 0), ("y", 1), ("z", 2)):
            mn = min(v.co[indice] for v in me.vertices)
            mx = max(v.co[indice] for v in me.vertices)
            if abs((mn + mx) * 0.5) > 0.002:
                problemas.append("origen no centrado en %s (%.3f)"
                                 % (eje, (mn + mx) * 0.5))
        if len(me.color_attributes) == 0:
            problemas.append("sin color de vertice")
        if tuple(round(a, 6) for a in ob.rotation_euler) != (0.0, 0.0, 0.0):
            problemas.append("lleva rotacion propia")
        if tuple(round(a, 6) for a in ob.scale) != (1.0, 1.0, 1.0):
            problemas.append("lleva escala propia")
        if problemas:
            print("  [FALLO] %s: %s" % (nombre, "; ".join(problemas)))
            fallos += 1
        else:
            print("  %-13s %2d tris  %.3f x %.3f x %.3f m (caja)"
                  % (nombre, tris, dim.x, dim.y, dim.z))

    print("  triangulos totales de la familia: %d" % total)
    print("  material: %s" % mate_nombre(raiz))

    os.makedirs(OUT_DIR, exist_ok=True)
    exportar_blender.exportar(OUT_FILE, colores_vertice=True)
    print("exportada: %s" % OUT_FILE)
    return fallos


def mate_nombre(raiz):
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH" and ob.data.materials:
            return ob.data.materials[0].name
    return "(ninguno)"


def main():
    fallos = _montar()
    print("---")
    print("RESULTADO: %s" % ("todo correcto" if fallos == 0
                             else "%d problema(s)" % fallos))
    return fallos


if __name__ == "__main__":
    main()
