"""
Comprueba que un cabezal suelto se puede colgar de "Giro" y que el plano de
corte del cabezal de serie y el del nuevo coinciden.

Un cabezal suelto tiene su origen en el centro de giro, asi que al anadirlo
como hijo de "Giro" con matrix_parent_inverse por identidad se coloca solo. Si
alguien cambia el origen de un cabezal, el corte se va de sitio y la hierba
aparece en el aire: eso es justo lo que se comprueba aqui.

Uso:
    flatpak run --command=blender org.blender.Blender --background \
        --factory-startup --python "$PWD/tools/probar_cambio.py" -- \
        "$PWD/models/desbrozadora.glb" "$PWD/models/cabezal_hilo.glb"
"""

import sys

import mathutils
import bpy


def _argv():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) < 2:
        print("hace falta: maquina.glb cabezal.glb")
        return None
    return argv[0], argv[1]


def main():
    par = _argv()
    if par is None:
        return 1
    maquina, repuesto = par

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=maquina)
    giro = bpy.context.scene.objects.get("Giro")
    corte = bpy.context.scene.objects.get("Corte")
    if giro is None or corte is None:
        print("[FALLO] la maquina no tiene Giro o Corte")
        return 1

    # Donde esta el corte ahora mismo, con el cabezal de serie.
    antes = corte.matrix_world.translation.copy()
    print("corte con el cabezal de serie: (%.3f, %.3f, %.3f)"
          % (antes.x, antes.y, antes.z))
    print("Giro en: (%.3f, %.3f, %.3f)"
          % (giro.matrix_world.translation.x, giro.matrix_world.translation.y,
             giro.matrix_world.translation.z))

    # Se aparta el cabezal de serie, como haria el juego al cambiar de disk.
    serie = bpy.context.scene.objects.get("Cabezal_Corta")
    if serie is not None:
        serie.hide_viewport = True
        serie.hide_render = True

    bpy.ops.import_scene.gltf(filepath=repuesto)
    nuevo = bpy.context.scene.objects.get(repuesto.rsplit("/", 1)[-1][:-4])
    if nuevo is None:
        candidatos = [o for o in bpy.context.scene.objects
                      if o.name not in ("Desbrozadora", "Barra", "Giro",
                                        "Corte", "Manillar", "Motor")]
        nuevo = candidatos[-1] if candidatos else None
    if nuevo is None:
        print("[FALLO] no se encuentra el cabezal repuesto en", repuesto)
        return 1

    # El juego lo cuelga tal cual, sin tocar la matriz de parenting: en Godot
    # es giro.add_child(nuevo), que en Blender es esto.
    nuevo.parent = giro
    nuevo.matrix_parent_inverse = mathutils.Matrix.Identity(4)
    bpy.context.view_layer.update()

    # El repuesto es una malla suelta: el nodo Corte lo aporta la maquina, en
    # el mismo sitio para todos los cabezales. Asi que lo que se comprueba es
    # que la malla del repuesto queda centrada en el punto de corte, que es lo
    # que hace que la hierba se corte a la altura correcta.
    centro = sum((nuevo.matrix_world @ v.co
                  for v in nuevo.data.vertices), mathutils.Vector())
    centro /= len(nuevo.data.vertices)
    print("centro del repuesto: (%.3f, %.3f, %.3f)"
          % (centro.x, centro.y, centro.z))
    error = (centro - antes).length
    print("separacion del centro de corte: %.4f m" % error)

    fallos = 0
    if error > 0.05:
        print("[FALLO] el repuesto no corta en el mismo sitio (%.4f m)" % error)
        fallos += 1
    else:
        print("[OK] el repuesto corta en el mismo sitio que el de serie")

    # Y el repuesto no puede verse cortado por la costura del plano: el canto
    # en Z dice si el disco esta tumbado o de punta.
    zs = [(nuevo.matrix_world @ v.co).z for v in nuevo.data.vertices]
    canto = max(zs) - min(zs)
    print("canto en Z del repuesto: %.4f m" % canto)
    if canto > 0.09:
        print("[FALLO] el repuesto no va tumbado: canto de %.3f m" % canto)
        fallos += 1
    else:
        print("[OK] el repuesto va tumbado")

    print("---")
    print("RESULTADO: %s" % ("todo correcto" if fallos == 0
                             else "%d problema(s)" % fallos))
    return fallos


if __name__ == "__main__":
    sys.exit(main())
