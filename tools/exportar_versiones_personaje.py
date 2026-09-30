#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Exporta TODAS las versiones del personaje low-poly a .glb dentro del proyecto.

Uso:
    flatpak run --filesystem=$HOME/Documentos org.blender.Blender \
        --background --python tools/exportar_versiones_personaje.py

Que hace:
  1. Recorre las carpetas `versiones/v*/` de la libreria de modelos y abre cada
     `.blend` en background.
  2. Exporta cada uno a `models/pruebas/personaje_<v>.glb` **con las animaciones
     dentro** (Caminar, Correr, Naruto), que es justo lo que distingue estos
     modelos de los demas del proyecto.

Ojo con el `export_apply`: va apagado a proposito. En background el exportador
aplicaria los modificadores sobre el resto y las animaciones del esqueleto se
quedarian fuera; sin aplicar, la malla va skinned y Godot importa el
Skeleton3D + AnimationPlayer con las acciones nombradas.

Esta carpeta de salida es de PRUEBAS, no el modelo definitivo del juego: aqui
se comparan versiones. El modelo que juega sigue siendo
`models/personaje_trabajo.glb`.
"""

import glob
import os

import bpy

LIBRERIA = os.path.expanduser(
    "~/Documentos/modelos 3d blender automaticos/personaje_lowpoly/versiones")
PROYECTO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIDA = os.path.join(PROYECTO, "models", "pruebas")


def exportar_todo():
    os.makedirs(SALIDA, exist_ok=True)
    blends = sorted(glob.glob(os.path.join(LIBRERIA, "*", "*.blend")))
    if not blends:
        print("NO HIZO NADA: no hay .blend en %s" % LIBRERIA)
        return
    for ruta in blends:
        version = os.path.basename(os.path.dirname(ruta))
        salida = os.path.join(SALIDA, "personaje_%s.glb" % version)
        bpy.ops.wm.open_mainfile(filepath=ruta)
        bpy.ops.export_scene.gltf(
            filepath=salida,
            export_format="GLB",
            export_animations=True,
            export_skins=True,
            export_yup=True,
            export_apply=False)
        print("EXPORTADO %s -> %s" % (version, salida))


# Blender ejecuta el fichero como script: el bloque corre si o si.
exportar_todo()
