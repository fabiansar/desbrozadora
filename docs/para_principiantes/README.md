# Guía para empezar a aportar

Esta carpeta es un manual práctico para aprender Godot y Blender trabajando
directamente en **Desbrozadora**. Está escrito para empezar desde cero y poder
avanzar incluso sin un asistente de IA.

## Punto de partida estable

La versión base confirmada manualmente por el usuario el 28-09-2026 está fijada
en el commit **`8da06a626c01250e0dda99fa3df17095e6e7dac0`**
(`Establece base funcional para continuar`).
Ese es el punto al que volver si un experimento rompe el proyecto. La guía y los
cambios posteriores de documentación se guardan en commits posteriores.

Para localizarlo en la terminal:

```bash
git log --oneline --all --grep="Establece base funcional para continuar"
```

No uses `reset --hard` para volver a esa versión: las instrucciones seguras de
Git están en [03_git_y_pruebas.md](03_git_y_pruebas.md).

## Orden recomendado

1. [Godot desde cero](01_godot.md): abrir el proyecto, entender escenas y nodos,
   ajustar una propiedad y revisar errores.
2. [Blender desde cero](02_blender.md): generar, abrir, editar y comprobar los
   modelos sin perder su jerarquía ni su escala.
3. [Git y pruebas](03_git_y_pruebas.md): proteger el trabajo, hacer cambios
   pequeños y confirmar que siguen funcionando.

## Abrir el proyecto

En una terminal, entra en la carpeta del repositorio y lanza Godot:

```bash
cd ~/Documentos/desarrollos/desbrozadora
flatpak run --filesystem=$HOME/Documentos org.godotengine.Godot --path .
```

Si Godot muestra el gestor de proyectos, importa la carpeta que contiene
`project.godot` y ábrela. La escena de entrada es `scenes/main.tscn`.

## Documentación del proyecto

- [LEEME.md](../../LEEME.md): cómo se juega y cómo arrancar las pruebas.
- [DOCUMENTACION.md](../../DOCUMENTACION.md): estructura y detalles técnicos.
- [DISENO.md](../../DISENO.md): visión y hoja de ruta.
- [REVISION.md](../../REVISION.md): estado actual y asuntos abiertos.
- [AGENTS.md](../../AGENTS.md): modos de trabajo y reglas del repositorio.
- [CHANGELOG.md](../../CHANGELOG.md): cambios y bases verificadas.

## Una regla que evita frustraciones

Primero cambia **una sola cosa**, guarda, ejecuta el juego y comprueba el
resultado. Si algo falla, deshaz solo ese cambio antes de continuar. No combines
una edición visual, una modificación de física y una refactorización en el mismo
experimento: así es fácil descubrir qué causó el problema.
