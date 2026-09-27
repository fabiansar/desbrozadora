"""
Exportador de Blender a glTF con las dos correcciones que Godot necesita.

Uso:
    blender --background --python tools/exportar_blender.py
    blender --background --python tools/exportar_blender.py -- models/desbrozadora.glb

Que resuelve:
  1. Origen en la base. En Godot una malla se siembra por su origen, asi que si
     el origen esta en el centro de la pieza la pieza flota medio metro por
     encima del suelo. Aqui el origen se baja a la base de la geometria y la
     base se deja en 0, sin deformar la pieza.
  2. Sufijo -col en las de colision. Es el sufijo que el importador de escenas
     de Godot reconoce: un nodo "Valla-col" entra como colision y no como malla
     visible. Se detectan por nombre ("Colision..."), por material ("Colision")
     o por la propiedad "colision" del objeto.
  3. Prueba. Sin argumentos, este script se monta a si mismo una escena de
     prueba, la arregla dos veces (para ver que no rompe nada al repetir),
     imprime el informe y exporta un .glb a un directorio temporal. Asi se
     comprueba el pipeline entero en background sin tocar models/.

Ojo con los ejes: Blender es Z-up y Godot es Y-up, asi que el eje Z de aqui es
el Y de alla, que es el que se apoya en el suelo.
"""

import os
import sys
import tempfile

import bpy

OUT_DIR = os.path.expanduser("~/Documentos/desarrollos/desbrozadora/models")
SUFIJO_COLISION = "-col"
EJES = ("X", "Y", "Z")
TOLERANCIA = 1e-4


def limpiar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _indice(eje):
    e = str(eje).upper()
    if e not in EJES:
        raise ValueError("el eje tiene que ser X, Y o Z, no %r" % (eje,))
    return EJES.index(e)


def aplicar_origen_base(ob, eje="Z", a_cero=True, mover_hijos=False):
    """Baja el origen del objeto a la base de su geometria, sin deformarla.

    Devuelve (destino, movido). Con a_cero la base queda ademas en el 0 del
    eje, que es lo que se quiere al sembrar en Godot; sin a_cero solo se mueve
    el origen y la pieza se queda donde estaba.
    """
    if ob.type != "MESH" or not ob.data.vertices:
        return None, False
    if ob.children and not mover_hijos:
        return None, False
    bpy.context.view_layer.update()

    i = _indice(eje)
    matriz = ob.matrix_world
    # El minimo se saca de los vertices en coordenadas de mundo, no de
    # bound_box: el bound_box es local y con el objeto girado da un suelo mas
    # bajo del real, que es justo el numero que no queremos.
    bajo = min((matriz @ v.co)[i] for v in ob.data.vertices)
    origen = matriz.translation.copy()

    # Son dos Moves, no uno. Primero el origen baja hasta la base, y la malla
    # se sube lo mismo para que la pieza no se deforme. Despues, si toca, la
    # pieza entera baja hasta el suelo.
    en_la_base = origen.copy()
    en_la_base[i] = bajo
    destino = origen.copy()
    destino[i] = 0.0 if a_cero else bajo
    if (abs(bajo - origen[i]) < TOLERANCIA
            and abs(destino[i] - origen[i]) < TOLERANCIA):
        return destino, False

    # El guardado se calcula en mundo y se pasa a local con la inversa de la
    # rotacion. Con el objeto girado, mover el origen "hacia abajo" en local no
    # es bajar: es tirar en diagonal.
    local = matriz.to_3x3().inverted() @ (en_la_base - origen)
    for v in ob.data.vertices:
        v.co -= local
    ob.matrix_world.translation = destino
    return destino, True


def es_colision(ob):
    """Si la malla es de colision, a ojo de los tres avisos."""
    if ob.type != "MESH":
        return False
    if ob.get("colision"):
        return True
    if ob.name.lower().startswith("col"):
        return True
    for mat in ob.data.materials:
        if mat is not None and "col" in mat.name.lower():
            return True
    return False


def sufijar_colision(ob, datos=True):
    """Pone el sufijo -col. Devuelve True si ha tenido que tocarlo."""
    if ob.name.endswith(SUFIJO_COLISION):
        return False
    ob.name += SUFIJO_COLISION
    # El nombre de la malla tambien: Godot lo usa para nombrar la superficie
    # cuando el importador separa mallas por material.
    if datos and not ob.data.name.endswith(SUFIJO_COLISION):
        ob.data.name += SUFIJO_COLISION
    return True


def preparar(objetos=None, eje="Z", a_cero=True, colisiones=True, mover_hijos=False):
    """Aplica las dos correcciones y devuelve un informe [(nombre, accion)]."""
    bpy.context.view_layer.update()
    if objetos is None:
        objetos = list(bpy.context.scene.objects)

    informe = []
    for ob in objetos:
        if ob.type != "MESH":
            informe.append((ob.name, "se salta: no es malla"))
            continue
        if ob.children and not mover_hijos:
            informe.append((ob.name, "se salta: tiene hijos, bajarlo los mueve"))
            continue
        destino, movido = aplicar_origen_base(ob, eje=eje, a_cero=a_cero,
                                               mover_hijos=mover_hijos)
        if destino is None:
            informe.append((ob.name, "se salta: malla sin vertices"))
        elif movido:
            informe.append((ob.name, "origen a la base (%s) en (%.3f, %.3f, %.3f)"
                            % (eje, destino.x, destino.y, destino.z)))
        else:
            informe.append((ob.name, "el origen ya estaba en la base"))

    if colisiones:
        for ob in objetos:
            if es_colision(ob) and sufijar_colision(ob):
                informe.append((ob.name, "sufijo %s puesto" % SUFIJO_COLISION))
    return informe


def exportar(ruta, solo_seleccion=False):
    """Exporta a .glb o .gltf, con los parametros que Godot entiende bien."""
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    formato = "GLB" if ruta.lower().endswith(".glb") else "GLTF_SEPARATE"
    bpy.ops.export_scene.gltf(
        filepath=ruta,
        export_format=formato,
        use_selection=solo_seleccion,
        export_yup=True,          # Blender es Z-up y Godot Y-up
        export_apply=True,        # los modificadores van dentro de la malla
        export_extras=True,       # conserva la propiedad "colision"
        export_animations=False,  # este juego no usa animaciones de nodo
    )
    return ruta


def montar_escena_de_prueba():
    """Tres casos: algo que flota, algo de colision y algo ya terminado."""
    limpiar()
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.15, depth=2.0,
                                        location=(0.0, 0.0, 2.0))
    arbol = bpy.context.active_object
    arbol.name = "Arbol"
    arbol.data.name = "ArbolMalla"

    bpy.ops.mesh.primitive_cube_add(size=0.5, location=(1.0, 0.0, 0.25))
    valla = bpy.context.active_object
    valla.name = "ColisionValla"
    valla["colision"] = True

    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(2.0, 0.0, 0.15))
    tronco = bpy.context.active_object
    tronco.name = "Tronco" + SUFIJO_COLISION
    tronco.data.name = "TroncoMalla"

    # Un Empty, que es como estan los nodos "Corte" y "Giro" de la
    # desbrozadora: no es malla y no debe romper nada.
    corte = bpy.data.objects.new("Corte", None)
    bpy.context.collection.objects.link(corte)
    bpy.context.view_layer.update()


def prueba():
    montar_escena_de_prueba()
    for pasada in (1, 2):
        print("--- pasada %d ---" % pasada)
        for nombre, accion in preparar():
            print("  %-18s %s" % (nombre, accion))
    print("--- comprobaciones ---")

    fallos = 0
    arbol = bpy.data.objects["Arbol"]
    z = arbol.matrix_world.translation.z
    fallos += _ok("el origen del arbol baja a z=0", abs(z) < TOLERANCIA, "z=%.4f" % z)
    base = min((arbol.matrix_world @ v.co).z for v in arbol.data.vertices)
    fallos += _ok("el arbol apoya en el suelo", abs(base) < TOLERANCIA,
                  "base z=%.4f" % base)
    alto = max((arbol.matrix_world @ v.co).z for v in arbol.data.vertices)
    fallos += _ok("y sigue mide 2 m de alto", abs(alto - 2.0) < 1e-3,
                  "alto=%.4f" % alto)

    fallos += _ok("la valla gana el sufijo",
                  "ColisionValla" + SUFIJO_COLISION in bpy.data.objects,
                  ", ".join(sorted(bpy.data.objects.keys())))
    tronco_nombre = bpy.data.objects["Tronco" + SUFIJO_COLISION].name
    fallos += _ok("el tronco no acumula sufijos",
                  tronco_nombre.count(SUFIJO_COLISION) == 1, tronco_nombre)
    fallos += _ok("el empty sobrevive", "Corte" in bpy.data.objects, "")

    dest = os.path.join(tempfile.mkdtemp(prefix="exportar_blender_"), "prueba.glb")
    exportar(dest)
    tam = os.path.getsize(dest) if os.path.exists(dest) else 0
    fallos += _ok("el .glb se escribe", tam > 0, "%d bytes" % tam)
    print("  .glb de prueba en %s" % dest)

    print("---")
    print("RESULTADO: %s" % ("todo correcto" if fallos == 0
                             else "%d problema(s)" % fallos))
    return fallos


def _ok(etiqueta, condicion, detalle):
    print("  [%s] %s%s" % ("OK" if condicion else "FALLO", etiqueta,
                           " (%s)" % detalle if detalle else ""))
    return 0 if condicion else 1


def _argumentos():
    argv = sys.argv
    if "--" not in argv:
        return []
    return argv[argv.index("--") + 1:]


def main():
    rutas = _argumentos()
    if not rutas:
        prueba()
        return
    for ruta in rutas:
        print("preparando:", ruta)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=ruta)
        for nombre, accion in preparar():
            print("  %-18s %s" % (nombre, accion))
        salida = os.path.join(OUT_DIR, os.path.basename(ruta))
        os.makedirs(OUT_DIR, exist_ok=True)
        exportar(salida)
        print("exportado:", salida)


if __name__ == "__main__":
    main()
