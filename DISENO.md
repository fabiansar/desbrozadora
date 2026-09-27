# Diseno del proyecto

Vision global y hoja de ruta. Aqui esta **que queremos construir y por que**.
Lo que se puede jugar hoy esta en [LEEME.md](LEEME.md), el detalle por archivo en
[DOCUMENTACION.md](DOCUMENTACION.md) y el estado fino en [REVISION.md](REVISION.md).

Este documento es direccion, no codigo. Se cambia cuando cambie el rumbo, no en
cada ajuste de un valor.

---

## 1. Que es

**Desbrozadora** es un simulador de trabajo autonomo de desbroce y mantenimiento
de fincas en un entorno rural de Galicia. No es un arcade de cortar yerba ni un
tractor: es un oficio. El jugador es un autonomo que cobra por dejar un terreno
limpio, y el juego trata de que ese trabajo se sienta como trabajo.

De ahi sale todo lo demas. La desbrozadora pesa porque pesa de verdad, no porque
suene a motor. El viaje entre aldeas es parte del juego porque el trabajo esta
lejos. La gasolina cara y la maquina que se rompe son el antagonista, porque en
un oficio lo que te para no es un dragon.

### Que NO vamos a hacer

- **No es una supervivencia hostil.** No hay hambre que medir en milisegundos, ni
  barra de sed, ni companeros que te abandonan. La presion economica es suave y
  se resuelve trabajando, no optimizando.
- **No es un sandbox sin objetivo.** Se puede trastear, pero siempre hay una
  finca que atender.
- **No es violente.** No hay armas ni enemigos. Lo que se combate es la maleza.

---

## 2. Bucle de juego principal

```
   Encargo             Preparacion          Trayecto            Trabajo          Cobro y
 (telefono / GPS)   (maquinaria, disco,   (furgoneta,       (desbroce,        mantenimiento
                     combustible)          carretera)          limpieza)
      |                    |                  |                 |                 |
      v                    v                  v                 v                 v
  ¿donde y          ¿con que corto?      ¿cuanto tarde      ¿tengo el         ¿para que
   cuanto hay        ¿llego el gas?        en llegar?        ritmo?             el dinero
   que hacer?        ¿esta afilada?       ¿llego con         ¿que se atasca?    aguanta?
                                            tiempo?
```

El bucle esta cerrado a proposito: **cada vuelta deja el taller mas caro y el
terreno mas limpio**. El jugador avanza en el mapa y en la mecanica a la vez.

### Encargo

Llega por telefono o por el GPS de la furgoneta. Dice dos cosas y solo dos:
donde y cuanto. El resto lo tiene que resolver el jugador, que para eso sabe.

### Preparacion

Antes de salir hay que mirar la maquinaria. Que disco lleva montado decide que
puede cortar. Le falta gas, decide si llega. Esta afilada, decide si gana tiempo
o lo pierde. Aqui se decide el exito de la fase de trabajo, y todavia no se ha
tocado la maleza.

### Trayecto

Conduccion por aldeas y caminos de tierra. Es tiempo muerto a proposito, y por
eso tiene que ser util: se ve el terreno que viene, se decide por donde se entra,
se gasta combustible. Es la transicion que hace que un encargo al otro se sienta
como una jornada y no como un corte de escena.

### Trabajo

Desbroce y limpieza. Es aqui donde esta el 80 % de la calidad del juego, y donde
se juega con la desbrozadora: el arnes, el peso, el esfuerzo, el disco
equivocado. **El terreno se nota en las manos.**

### Cobro y mantenimiento

Se cobra por metro lineal limpio. Y con el dinero: gasolina, reparaciones,
recambios, y cuando toca, una maquina mas potente. El gasto es la consecuencia
de como se ha trabajado, no un imposedor.

---

## 3. Pilares

### Pilar 1 - La desbrozadora se siente real

Es el pilar central. Si la desbrozadora no pesa, el juego entero falla, porque
todo lo demas es un envoltorio para estar usandola.

- **Arnes asimetrico.** La maquina va colgada de la cadera **derecha**. De ahi
  sale la asimetria: a la izquierda se barre mucho mas arco (96 grados) que a la
  derecha (38), porque el torso y el brazo se cruzan y no hay nada que estorbe,
  mientras que a la derecha se topa con el hombro y las costillas. No es un tope
  de software, es un cuerpo.
- **Masa.** Llega tarde, sigue cuando frenas, y tiene que pasar por parado al
  cambiar de sentido. La asimetria de peso va en la inercia, no en la velocidad
  maxima.
- **Esfuerzo de barrido.** A y D no solo esquivan: echan la maquina a un lado a
  proposito. Es el gesto de esfuerzo, y es lo que da ritmo al trabajo en vez de
  dejarlo en automatico.
- **Tipos de disco segun el tipo de maleza.** Un disco de mata no sirve para un
  codeso. Elegir herramienta para el trabajo es la decision recurrente.

### Pilar 2 - Exploracion y conduccion

Desplazarse en furgoneta o pickup entre aldeas, con GPS. El mapa se conoce por
ir y venir. El terreno que se ve desde el camino es el terreno que hay que
limpiar despues.

### Pilar 3 - Progresion economica

Gestion de costes, no solo de ingresos: reparaciones, mezcla de gasolina, compra
de maquinaria mas potente, imprevistos. El objetivo no es acumular, es
**mantenerse vivo una temporada**. Un jugador que pierde la desbrozadora y tiene
que volver a comprarla con un impone mas bajo ha pasado por la parte dura del
oficio, y eso es el juego.

---

## 4. Hoja de ruta

### Fase 1 - Fundamentos que se notan  _(hecha)_

Lo que hace que el nucleo se sienta bien antes de ponerle nada alrededor.

- [x] Fisicas de barrido: arnes asimetrico, topes por lado, masa, inercia.
- [x] El cuerpo no gira con la mirada, gira al avanzar; las caderas van detras de
      la maquina.
- [x] Apoyo del cabezal en el suelo al trabajar.
- [x] Camara: cabeceo al trabajar e inclinacion lateral por el barrido.
- [x] **El cabezal no se pierde de vista.** Con la hierba alta hacia falta para
      cortar zarza de verdad: la camara baja sola lo justo para que la
      herramienta siga en el encuadre, y el jugador puede mirar hasta 55 grados
      hacia arriba. Sin esto, trabajar de pie era mirar al suelo.
- [x] **Andar hacia atras sin que el mundo gire.** La camara cuelga del cuerpo,
      y con `S` el cuerpo se daba media vuelta y arrastraba la vista. Ahora la
      camara mide su giro en el mundo.
- [x] Hierba por cuadrantes (chunking). El `MultiMesh` se trocea en cuadrados
      de 8 m con su caja ajustada, mas un recorte por distancia. Sin esto el
      motor dibujaba las hojas enteras siempre y la densidad no se podia subir.
- [x] Limpiar el `Cube` que sobra en el modelo de la desbrozadora.
- [x] Suite de pruebas que fija el comportamiento. Empezo en 131 comprobaciones
      en headless; hoy son **183**.

> La fase 1 se cierra con lo de la camara y el chunking, que no estaban
> previstos aqui y salieron de jugar: el primero de mirar arriba y perder la
> herramienta, y el segundo al querer mas densidad de la que cabia en un solo
> `MultiMesh`. Los dos cumplen el criterio de la seccion 6: se notan en las
> manos y se pueden medir.

### Fase 2 - El corte que cuesta  _(hecha)_

Aqui el terreno empieza a oponer resistencia, y la desbrozadora deja de ser la
misma segun donde estes.

Empezo por el **segundo tipo de hierba**, que es lo que mas se nota sin tocar
economia, y de ahi salieron la resistencia y el morro: la maleza alta no sirve
de nada si la maquina no nota que hay algo delante ni si llega a cortarlo.

- [x] **Segundo tipo de hierba, en matas.** `MalezaAlta`, con su semilla, su
      material y su dureza. Sale en claros y no como una alfombra, y se corta
      con la misma maquina que el cesped.
- [x] **Resistencia segun densidad de maleza.** La zona no se limpia igual de
      rapido en un claro que en un zarzal. La maquina tiene que trabajar mas
      lento donde hay mas, y ahora lo hace con lo que tiene **de pie** por
      delante, no con lo que se sembró: lo que se nota es lo que queda.
- [x] **El morro sube al mirar arriba.** Sin esto, la maleza alta era un muro:
      el cabezal no pasaba de 0,35 m y no habia forma de cortar nada por encima
      de la rodilla.
- [ ] **Discos y hilo.** Mata, hilo de nylon, cuchilla. Cada uno para un tipo de
      maleza, con su desgaste y sus limites.
- [ ] **Consumo de combustible y RPMs.** El acelerador pasa a ser un recurso que
      se gasta y un sonido que cambia con las vueltas.
- [ ] **Desgaste y afilado.** La cuchilla pierde filo y hay que revisarla.

> **Lo que queda de esta fase y por que.** El desgaste, el combustible y los
> discos no se han hecho, y a proposito: son sistemas que se notan mucho cuando
> estan a medias, y sin un disco el afilado no tiene a que desgastar. Lo primero que
> haria falta no es el desgaste sino el **terreno con desnivel de verdad**, que
> es lo que haria que el terreno de verdad oponga resistencia y no solo las
> matas. Con el terreno llano que hay, la densidad es lo unico que puede oponer
> algo, y ya se nota.

### Fase 3 - Conduccion

- [ ] Conduccion basica de la furgoneta / pickup.
- [ ] Transporte de herramientas: el espacio de la desbrozadora en la caja.
- [ ] GPS y navegacion entre aldeas.
- [ ] Consumo real de combustible en el trayecto.

### Fase 4 - Encargos

- [ ] Telefono y bandeja de encargos.
- [ ] Mapas de fincas con **porcentaje de limpieza requerido** para cobrar.
- [ ] Cancelar un encargo a medias, y lo que cuesta.
- [ ] Clientes: aldeas, fincas y facturas que simulen a quien paga.

### Fase 5 - Economia rural

- [ ] Gastos recurrentes: combustible, mantenimiento, averias.
- [ ] Taller: reparar, cambiar disco, afilar.
- [ ] Tienda de maquinaria: mejoras progresivas.
- [ ] Imprevistos: piezas que fallan, dias de lluvia que no dejan trabajar.

---

## 5. Decisiones de arquitectura ya tomadas

Se dejan escritas para que no se rediscutan en cada cambio.

| Decision | Por que |
| --- | --- |
| La maquina cuelga de `Caderas`, no de la camara ni de las manos | El arnes es lo que justifica la asimetria. Si colgara de las manos, los dos lados serian iguales. |
| El cuerpo gira **hacia donde avanza**, no hacia donde esquiva | A y D tambien barre. Si el cuerpo girase al esquivar, la maquina se mediria respecto a un cuerpo que acaba de dar media vuelta y D barreria al lado contrario del pedido. |
| La asimetria de inercia va en el **peso**, no en la rigidez | En un muelle criticamente amortiguado `w = k / (2 k peso) = 1 / (2 peso)`: la rigidez se cancela. Multiplicarla no cambia nada. |
| Sin parabola en el alcance | El alcance es fijo porque la maquina va atada, no sostenida. El arco sale de girar alrededor del arnes, no de estirar el brazo. |
| **El cabezal se ve siempre; la camara se acomoda** | Va 47 grados por debajo del horizonte y solo entran 34. Un tope de inclinacion de 85 arriba habria bastado para no mirar de frente, pero obligaria a apuntar al suelo para trabajar. Bajando la camara, el jugador mira libre y la herramienta no se pierde. |
| **Los topes de inclinacion son asimetricos** (85 abajo, 55 arriba) | Es lo que deja que la camara tenga sitio para encuadrar el cabezal al mirar arriba, sin que el jugador note el limite. |
| **La camara mide su giro en el mundo, no en local** | Cuelga del cuerpo, y el cuerpo se vuelve hacia donde camina. En local el giro del cuerpo se le sumaba y `S` daba un tiron de 180 grados. |
| **La hierba va por cuadrantes, no en un `MultiMesh` entero** | Con una sola caja de 100 m el motor no descarta nada y dibuja todas las hojas siempre. Troceada, cada cuadrado se descarta solo y la densidad se puede subir. |
| **El viento es un nodo del mundo, no de cada campo** | Con dos tipos de hierba, un `Viento` por campo significaba dos mapas peleandose por los mismos materiales. El viento es una cosa del prado, y por eso usa el radio mayor de todos los campos. |
| La suite va en headless y es obligatoria antes de dar algo por bueno | Es lo que permite seguir tocando fisicas sin depender de que alguien mire. |
| **La suite con ventana no se lanza con el juego abierto** | Godot se queda con el foco y la entrada, y salen fallos falsos de raton y de movimiento. En headless no hay ese problema. |
| Los valores de la hierba del juego viven en `main.tscn`, no en el script | La hierba se ajusta a ojo en el Inspector mientras se juega; si estuvieran en el codigo habria que recompilar para cambiar la densidad. Ademas son **dos campos con valores distintos** (`Hierba` y `MalezaAlta`), no uno con parametros. |
| Los valores de feltro van en el Inspector, no en el codigo | `max_left_angle`, `max_right_angle`, `sweep_speed`, `inertia_smoothness`, `masa_izquierda` y `rigidez_derecha` se ajustan sin recompilar. |

---

## 6. Como se decide que toca

El criterio es siempre el mismo, y es el que se ha usado hasta ahora:

1. **Que se note en las manos.** Si el jugador no lo nota, no entra.
2. **Que se pueda medir.** Si no hay una comprobacion automatizada, no entra.
3. **Un cambio cada vez.** La prueba la hace la persona que lleva el proyecto
   jugando, y el siguiente cambio sale de ahi. Los tres modos de `AGENTS.md`
   respetan esto: hasta el modo autonomo comprueba y corrige un punto cada vez
   antes de pasar al siguiente.
