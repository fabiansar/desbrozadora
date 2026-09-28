"""
Mide el modelo de la desbrozadora y comprueba que esta donde debe.

Uso:
    flatpak run --command=blender org.blender.Blender --background \
        --python "$PWD/tools/ver_modelo.py" -- "$PWD/models/desbrozadora.glb"

Sin argumento mide la maquina. Se le puede pasar cualquier .glb, que es como
se miden los cabezales sueltos.

Sirve para no tener que mirar el modelo a ojo: si el cabezal de corte se queda
a 40 cm en vez de a 1,1 m, la desbrozadora se veria diminuta en la camara y es
mucho mas facil enterarse con numeros que jugando.
"""

import os
import sys

import mathutils
import bpy

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUTA = os.path.join(PROJECT_DIR, "models", "desbrozadora.glb")

# Lo que se espera del modelo, con margen.
ESPERADO_LARGO = (2.3, 2.55)
ESPERADO_ANCHO = (0.15, 0.60)
ESPERADO_CORTE_Y = (-1.70, -1.45)


def main():
    # Blender pone los argumentos del usuario despues de "--".
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ruta = argv[0] if argv else RUTA
    if not os.path.exists(ruta):
        print("NO EXISTE: %s" % ruta)
        return 1
    print("midiendo: %s" % ruta)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=ruta)
    bpy.context.view_layer.update()

    nombres = [o.name for o in bpy.context.scene.objects]
    print("nodos:", ", ".join(nombres))

    mn = [1e9, 1e9, 1e9]
    mx = [-1e9, -1e9, -1e9]
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        pmin = [1e9, 1e9, 1e9]
        pmax = [-1e9, -1e9, -1e9]
        for esquina in ob.bound_box:
            mundo = ob.matrix_world @ mathutils.Vector(esquina)
            for i in range(3):
                pmin[i] = min(pmin[i], mundo[i])
                pmax[i] = max(pmax[i], mundo[i])
                mn[i] = min(mn[i], mundo[i])
                mx[i] = max(mx[i], mundo[i])
        # Cada pieza por separado: si una se sale, hay que saber cual.
        print("    %-10s y[%6.2f, %6.2f]  x[%6.2f, %6.2f]"
              % (ob.name, pmin[1], pmax[1], pmin[0], pmax[0]))

    largo = mx[1] - mn[1]
    ancho = mx[0] - mn[0]
    print("caja: x[%.2f, %.2f] y[%.2f, %.2f] z[%.2f, %.2f]"
          % (mn[0], mx[0], mn[1], mx[1], mn[2], mx[2]))
    print("largo total: %.2f m, ancho: %.2f m" % (largo, ancho))

    fallos = 0
    es_maquina = "Corte" in nombres
    if es_maquina:
        fallos += _comprobar("largo", largo, *ESPERADO_LARGO)
        fallos += _comprobar("ancho", ancho, *ESPERADO_ANCHO)
    # La altura del corte se mide en el nodo "Corte", no en el centro de la
    # caja: la empunadura asoma hacia arriba y ese centro no significa nada.
    corte = bpy.context.scene.objects.get("Corte")
    if corte is not None:
        y_corte = corte.matrix_world.translation.y
        z_corte = corte.matrix_world.translation.z
        fallos += _comprobar("altura del corte", y_corte, *ESPERADO_CORTE_Y)
        print("  punto de corte en (%.2f, %.2f, %.2f)"
              % (corte.matrix_world.translation.x, y_corte, z_corte))
    else:
        print("  (es un cabezal suelto: la caja y la altura del corte no"
              " se comprueban)")

    # El punto de corte tiene que existir: es donde luego se buscara la hierba.
    for clave in ("Corte", "Giro"):
        if clave in nombres:
            print("  [OK] esta el nodo", clave)
        elif es_maquina:
            print("  [FALLO] falta el nodo", clave)
            fallos += 1

    print("---")
    print("RESULTADO: %s" % ("todo correcto" if fallos == 0
                             else "%d problema(s)" % fallos))
    return fallos


def _comprobar(etiqueta, valor, minimo, maximo):
    ok = minimo <= valor <= maximo
    print("  [%s] %s = %.2f (se espera entre %.2f y %.2f)"
          % ("OK" if ok else "FALLO", etiqueta, valor, minimo, maximo))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
