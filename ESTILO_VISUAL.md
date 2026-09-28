# Direccion visual

## Referencia

La referencia visual aportada para el proyecto es el estilo de **How to Fish**.
Las dos capturas compartidas en la sesion sirven como guia de forma, escala y
proporcion para el futuro personaje. Esta especificacion conserva sus rasgos
aunque las imagenes no se hayan convertido en archivos del repositorio.

## Rasgos obligatorios

- Low-poly estilizado, con volumenes facetados y geometria deliberadamente simple.
- Cuerpos muy alargados, estrechos y cilindrico-prismaticos.
- Cabezas simples y expresivas, con ojos grandes y claramente visibles.
- Brazos y piernas delgados, articulaciones legibles y manos simplificadas.
- Ropa con bloques de color grandes, sin texturas realistas recargadas.
- Silueta reconocible a distancia y exageracion comica moderada.
- Materiales mates, colores saturados pero limpios y sombras suaves.
- Proporciones y lenguaje visual consistentes entre personaje, aldeanos y entorno.

## Aplicacion a la desbrozadora

La herramienta debe parecer parte del mismo juego aunque conserve medidas
funcionales reales. El cuerpo del personaje sera la referencia de escala para:

- El anclaje del arnes en la cadera.
- La posicion de las manos sobre el manillar.
- La separacion lateral de la maquina respecto al torso.
- La altura y el arco visible del cabezal.
- La lectura visual del peso y del barrido.

## Primera iteracion registrada

Existe un personaje completo en `models/personaje_trabajo.glb`, generado en
`tools/crear_personaje_mesh.py` e integrado en `scenes/jugador.tscn`. La vista de
juego oculta la cabeza y los brazos estáticos, pero deja visibles torso y piernas;
los brazos dinámicos siguen los agarres de la máquina. La cámara va adelantada a
la cara y parte mirando la zona de trabajo para producir una lectura GoPro del
cuerpo y la herramienta.

La segunda herramienta, la **hoz** (`models/hoz.glb`, generada con
`tools/crear_hoz_mesh.py`), sigue la misma regla: madera mate en el mango, acero
en la virola y en la hoja, silueta de media luna con el filo por dentro y la punta
por debajo de la mano, que es lo que la hace reconocible como una hoz y no como
un cuchillo curvo. Va en 114 triangulos, que es lo que se ve en primera persona
sin mirar de cerca.

Esta es una primera calibración, no el resultado visual final. Hay que revisar en
el juego la proporción que ocupa el torso, la separación/lectura de las piernas y
la relación entre manos, máquina y campo durante paneo, agachado y carrera. El
modelo completo debe conservar el estilo low-poly del proyecto.
