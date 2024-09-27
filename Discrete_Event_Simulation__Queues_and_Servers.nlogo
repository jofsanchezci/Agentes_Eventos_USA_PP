;;------------------------------------------------------------------------------
;; Copyright 2017 Nick Bennett
;;
;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at
;;
;;     http://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.
;;------------------------------------------------------------------------------

;;------------------------------------------------------------------------------
;; Version History
;; 2010-02-21 - v1.0:   M/M/n queueing simulation; up to 10 servers; standard
;;                      aggregate statistics & corresponding expected values.
;; 2017-07-26 - v1.5:   Updated for NetLogo 6. Licensed under Apache License
;;                      2.0.
;; 2017-07-29 - v1.6:   Added plot & more NetLogo 6-related updates, including
;;                      use of anonymous procedures and range reporter.
;; 2017-08-03 - v1.6.1: Fix info details.
;;------------------------------------------------------------------------------


;; The model has two types of agents: customers, who enter and wait in a queue
;; until a server is available; and servers, who serve each customer in
;; first-come, first-served order.

breed [customers customer]
breed [servers server]


;; Each customer records the time entering the system, and the time entering
;; service, so that average time-in-queue/time-in-system statistics can be
;; computed.

customers-own [
  time-entered-queue
  time-entered-service
]


;; Each server records the customer agent being served, and the scheduled
;; completion of that service. Since servers are homogenous, individual
;; utilization statistics aren't kept.

servers-own [
  customer-being-served
  next-completion-time
]


globals [
  ; Waiting line
  queue
  ; Arrival process
  arrival-count
  next-arrival-time
  ; Statistics for average load/usage of queue and servers
  stats-start-time
  total-customer-queue-time
  total-customer-service-time
  ; Statistics for average time-in-queue and time-in-service
  total-time-in-queue
  total-time-in-system
  total-queue-throughput
  total-system-throughput
  ; Physical layout parameters
  server-ycor
  queue-server-offset
  customer-xinterval
  customer-yinterval
  customers-per-row
  ; Saved slider values to allow detection of changes during a simulation run
  save-mean-arrival-rate
  save-mean-service-time
  ; Theoretical measures, computed analytically using classic queueing theory
  expected-utilization
  expected-queue-length
  expected-queue-time
  ; Anonymous procedures
  end-run-task
  arrive-task
  complete-service-task
  reset-stats-task
]


;; Sets up the model when loaded.

to startup
  setup
end


;; Initializes global variables and server agents.

to setup
  clear-all
  setup-globals
  setup-servers
  setup-tasks
  compute-theoretical-measures
  reset-ticks
  reset-stats
  schedule-arrival
end


;; Resets statistics, initializes queue list, and sets agent shapes and other
;; display properties.

to setup-globals
  set queue []
  set next-arrival-time 0
  set arrival-count 0
  set-default-shape servers "server"
  set-default-shape customers "person"
  set server-ycor (min-pycor + 1)
  set queue-server-offset 1.5
  set customer-xinterval 0.5
  set customer-yinterval 1
  set customers-per-row (1 + (world-width - 1) / customer-xinterval)
  set save-mean-arrival-rate mean-arrival-rate
  set save-mean-service-time mean-service-time
end


;; Creates server agents and arranges them horizontally, evenly spaced along
;; the bottom of the NetLogo world. This layout is purely cosmetic, and has no
;; functional purpose or impact.

to setup-servers
  let horizontal-interval (world-width / number-of-servers)
  create-servers number-of-servers [
    set color green
    setxy (min-pxcor - 0.5 + horizontal-interval * (0.5 + who)) server-ycor
    set size 2.75
    set label ""
    set customer-being-served nobody
    set next-completion-time 0
  ]
end


;; Sets up anonymous procedures for event queue entries.

to setup-tasks
  set end-run-task [[?ignore] -> end-run]
  set arrive-task [[?ignore] -> arrive]
  set complete-service-task [[?server] -> complete-service ?server]
  set reset-stats-task [[?ignore] -> reset-stats]
end


;; Updates statistics (which also advances the clock) and invokes the
;; relevant anonymous procedure for the next event scheduled.

to go
  ifelse (ticks < max-run-time) [
    let next-event []
    let event-queue (list (list max-run-time end-run-task nobody))
    let next-server-to-complete next-server-complete
    set event-queue (
      fput (list next-arrival-time arrive-task nobody) event-queue)
    if (is-turtle? next-server-to-complete) [
      set event-queue (fput
        (list
          ([next-completion-time] of next-server-to-complete)
          complete-service-task
          next-server-to-complete)
        event-queue)
    ]
    if (stats-reset-time > ticks) [
      set event-queue (
        fput (list stats-reset-time reset-stats-task nobody) event-queue)
    ]
    set event-queue (sort-by [[?1 ?2] -> first ?1 < first ?2] event-queue)
    set next-event (first event-queue)
    update-usage-stats (first next-event)
    set next-event (but-first next-event)
    (run (first next-event) (last next-event))
  ]
  [
    stop
  ]
end


;; Ends the execution of the simulation. In fact, this procedure does nothing,
;; but is still necessary. When the associated event is the first in the event
;; queue, the clock will be updated to the simulation end time prior to this
;; procedure being invoked; this causes the go procedure to stop on the next
;; iteration.

to end-run
  ; Do nothing
end


;; Creates a new customer agent, adds it to the queue, and attempts to start
;; service.

to arrive
  let color-index (arrival-count mod 70)
  let main-color (floor (color-index / 5))
  let shade-offset (color-index mod 5)
  create-customers 1 [
    set color (3 + shade-offset + main-color * 10)
    set time-entered-queue ticks
    move-forward length queue
    set queue (lput self queue)
    set time-entered-queue ticks
  ]
  set arrival-count (arrival-count + 1)
  schedule-arrival
  begin-service
end


;; Samples from the exponential distribution to schedule the time of the next
;; customer arrival in the system.

to schedule-arrival
  set next-arrival-time (ticks + random-exponential (1 / mean-arrival-rate))
end


;; If there are customers in the queue, and at least one server is idle, starts
;; service on the first customer in the queue, using a randomly selected
;; idle server, and generating a complete-service event with a time sampled
;; from the exponential distribution. Updates the queue display, moving each
;; customer forward.

to begin-service
  let available-servers (servers with [not is-agent? customer-being-served])
  if (not empty? queue and any? available-servers) [
    let next-customer (first queue)
    let next-server one-of available-servers
    set queue (but-first queue)
    ask next-customer [
      set time-entered-service ticks
      set total-time-in-queue
        (total-time-in-queue + time-entered-service - time-entered-queue)
      set total-queue-throughput (total-queue-throughput + 1)
      move-to next-server
    ]
    ask next-server [
      set customer-being-served next-customer
      set next-completion-time (ticks + random-exponential mean-service-time)
      set label precision next-completion-time 3
      set color red
    ]
    (foreach queue (range (length queue)) [
      [?1 ?2] ->
      ask ?1 [
        move-forward ?2
      ]
    ])
  ]
end


;; Updates time-in-system statistics, removes current customer agent, returns
;; the server to the idle state, and attempts to start service on another
;; customer.

to complete-service [?server]
  ask ?server [
    set total-time-in-system (total-time-in-system + ticks
      - [time-entered-queue] of customer-being-served)
    set total-system-throughput (total-system-throughput + 1)
    ask customer-being-served [
      die
    ]
    set customer-being-served nobody
    set next-completion-time 0
    set color green
    set label ""
  ]
  begin-service
end


;; Reports the busy server with the earliest scheduled completion.

to-report next-server-complete
  report (min-one-of
    (servers with [is-agent? customer-being-served]) [next-completion-time])
end


;; Sets all aggregate statistics back to 0 - except for the simulation start
;; time (used for computing average queue length and average server
;; utilization), which is set to the current time (which is generally not 0,
;; for a reset-stats event).

to reset-stats
  set total-customer-queue-time 0
  set total-customer-service-time 0
  set total-time-in-queue 0
  set total-time-in-system 0
  set total-queue-throughput 0
  set total-system-throughput 0
  set stats-start-time ticks
end


;; Updates the usage/utilization statistics and advances the clock to the
;; specified event time.

to update-usage-stats [event-time]
  let delta-time (event-time - ticks)
  let busy-servers (servers with [is-agent? customer-being-served])
  let in-queue (length queue)
  let in-process (count busy-servers)
  let in-system (in-queue + in-process)
  set total-customer-queue-time
    (total-customer-queue-time + delta-time * in-queue)
  set total-customer-service-time
    (total-customer-service-time + delta-time * in-process)
  tick-advance (event-time - ticks)
  update-plots
end


;; Moves to the specified queue position, based on the global spacing
;; parameters. This queue display is purely cosmetic, and has no functional
;;  purpose or impact.

to move-forward [queue-position]
  let new-xcor
    (max-pxcor - customer-xinterval * (queue-position mod customers-per-row))
  let new-ycor (server-ycor + queue-server-offset
    + customer-yinterval * floor (queue-position / customers-per-row))
  ifelse (new-ycor > max-pycor) [
    hide-turtle
  ]
  [
    setxy new-xcor new-ycor
    if (hidden?) [
      show-turtle
    ]
  ]
end


;; Checks to see if the values of the mean-arrival-rate and mean-service-time
;; sliders have changed since the last time that the theoretical system measures
;; were calculated; if so, the theoretical measures are recalculated.
;; (Note: This reporter is invoked by the expected queue length monitor. Since
;; monitors are updated periodically, even when a forever button isn't pressed,
;; this allows the theoretical statistics to be updated when the sliders
;; change, even if the model isn't running.

to-report sliders-changed?
  let changed? false
  if ((save-mean-arrival-rate != mean-arrival-rate)
      or (save-mean-service-time != mean-service-time)) [
    set changed? true
    set save-mean-arrival-rate mean-arrival-rate
    set save-mean-service-time mean-service-time
    compute-theoretical-measures
  ]
  report changed?
end


;; Computes the expected utilization, queue length, and time in queue for M/M/n
;; queueing system.

to compute-theoretical-measures
  let balance-factor (mean-arrival-rate * mean-service-time)
  let n (count servers)
  ifelse ((balance-factor / n) < 1) [
    let k 0
    let k-sum 1
    let power-product 1
    let factorial-product 1
    let busy-probability 0
    foreach (range 1 n) [
      [?] ->
      set power-product (power-product * balance-factor)
      set factorial-product (factorial-product * ?)
      set k-sum (k-sum + power-product / factorial-product)
    ]
    set power-product (power-product * balance-factor)
    set factorial-product (factorial-product * n)
    set k (k-sum / (k-sum + power-product / factorial-product))
    set busy-probability ((1 - k) / (1 - balance-factor * k / n))
    set expected-utilization (balance-factor / n)
    set expected-queue-length
      (busy-probability * expected-utilization / (1 - expected-utilization))
    set expected-queue-time
      (busy-probability * mean-service-time / (n * (1 - expected-utilization)))
  ]
  [
    set expected-utilization 1
    set expected-queue-length "N/A"
    set expected-queue-time "N/A"
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
215
10
785
154
-1
-1
19.4
1
9
1
1
1
0
1
1
1
-14
14
-3
3
1
1
0
ticks
60.0

SLIDER
10
10
205
43
number-of-servers
number-of-servers
1
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
10
105
205
138
mean-arrival-rate
mean-arrival-rate
0
2
0.9
0.05
1
per tick
HORIZONTAL

SLIDER
10
145
205
178
mean-service-time
mean-service-time
0.05
10
1.4
0.05
1
ticks
HORIZONTAL

SLIDER
10
235
205
268
stats-reset-time
stats-reset-time
0
max-run-time / 5
5000.0
1000
1
ticks
HORIZONTAL

SLIDER
10
195
205
228
max-run-time
max-run-time
10000
500000
340000.0
10000
1
ticks
HORIZONTAL

BUTTON
60
55
155
88
Setup
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
110
280
205
313
Go
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

MONITOR
790
10
900
55
Current Time
ticks
3
1
11

MONITOR
790
110
900
155
Queue Length
length queue
0
1
11

MONITOR
560
340
670
385
Server Utilization %
100 * total-customer-service-time / (ticks - stats-start-time) / count servers
3
1
11

MONITOR
215
340
325
385
Avg. Queue Length
total-customer-queue-time / (ticks - stats-start-time)
3
1
11

MONITOR
445
340
555
385
Avg. Time in System
total-time-in-system / total-system-throughput
3
1
11

BUTTON
10
280
105
313
Next
go
NIL
1
T
OBSERVER
NIL
N
NIL
NIL
1

MONITOR
330
340
440
385
Avg. Time in Queue
total-time-in-queue / total-queue-throughput
3
1
11

MONITOR
790
60
900
105
Next Arrival Time
next-arrival-time
3
1
11

MONITOR
560
392
670
437
Exp. Utilization %
100 * expected-utilization
3
1
11

MONITOR
215
392
325
437
Exp. Queue Length
ifelse-value sliders-changed? [\n  expected-queue-length\n]\n[\n  expected-queue-length\n]\n
3
1
11

MONITOR
330
392
440
437
Exp. Time in Queue
expected-queue-time
3
1
11

MONITOR
445
392
555
437
Exp. Time in System
expected-queue-time + mean-service-time
3
1
11

BUTTON
680
370
780
405
Reset Stats
reset-stats
NIL
1
T
OBSERVER
NIL
R
NIL
NIL
1

PLOT
215
160
785
335
Queue Length
Time
NIL
0.0
10.0
0.0
10.0
true
false
"" "if (max-run-time != plot-x-max) [\n  set-plot-x-range 0 max-run-time\n]"
PENS
"default" 1.0 0 -9276814 true "" "plotxy ticks (length queue)"

@#$#@#$#@
## WHAT IS IT?

Se trata de un modelo de sistema de colas simple, con una cola única e ilimitada y 1-10 servidores homogéneos. Las llegadas siguen un proceso de Poisson y los tiempos de servicio se distribuyen exponencialmente.

## HOW IT WORKS

Se trata de una simulación de eventos discretos, que es un tipo de simulación que hace avanzar el reloj en pasos discretos, a menudo de tamaño irregular, en lugar de hacerlo en trozos de tiempo muy pequeños y regulares (que generalmente se utilizan para producir una simulación cuasi-continua). En cada paso, el reloj avanza hasta el siguiente evento programado en una cola de eventos, y ese evento se procesa. En este modelo, los diferentes eventos son: la llegada de un cliente y su entrada en la cola (seguida, si es posible, por el inicio del servicio); la finalización del servicio, con la salida del cliente del sistema (seguida, si es posible, por el inicio del servicio para un nuevo cliente); el reinicio de las estadísticas; y el fin de la simulación. Dado que estos son los únicos eventos que pueden dar lugar a un cambio de estado de la simulación, no tiene sentido hacer avanzar el reloj en pasos de tiempo más pequeños que los intervalos entre los eventos.
## HOW TO USE IT

Utiliza el deslizador **número de servidores** para establecer el número de servidores; a continuación, pulsa el botón **Configuración** para crear los servidores y reiniciar el reloj de la simulación.

Los controles deslizantes **tasa media de llegada** y **tiempo medio de servicio** controlan los procesos de llegada y servicio, respectivamente. Estos valores pueden cambiarse antes de iniciar la simulación, o en cualquier momento durante la ejecución de la misma; cualquier cambio se refleja inmediatamente en un modelo en ejecución.

Los deslizadores **tiempo máximo de ejecución** y **tiempo de restablecimiento de las estadísticas** controlan la duración de la simulación y el momento en que se restablecen todas las estadísticas agregadas, respectivamente. Esto último permite reducir los efectos del inicio del sistema en las estadísticas agregadas.

La simulación puede ejecutarse paso a paso con el botón **Siguiente**, o procesando repetidamente los eventos con el botón **Ir**.

Las estadísticas agregadas pueden restablecerse en cualquier momento &ndash; sin vaciar la cola ni poner los servidores en estado de reposo &ndash; con el botón **Reset Stats**.
## THINGS TO NOTICE

Una vez iniciada la simulación, la próxima hora de llegada programada se muestra siempre en el monitor **Hora de llegada próxima**. Cuando alguno de los servidores está ocupado, la hora programada de finalización del servicio se muestra en la etiqueta debajo del servidor.

En la notación de la teoría de colas, el tipo de sistema que se simula en este modelo se denomina _M/M/n_ &ndash; es decir, llegadas de Poisson, tiempos de servicio exponenciales, capacidad de cola y población de origen infinitas, disciplina de cola FIFO. Cuando hay un único servidor, o cuando todos los servidores tienen el mismo tiempo medio de servicio, las características del estado estacionario (si el sistema es capaz de alcanzar un estado estacionario) pueden determinarse analíticamente. En este modelo, estos valores teóricos se muestran en la fila inferior de monitores. Si la utilización teórica de los servidores &ndash; determinada multiplicando la tasa de llegada por el tiempo de servicio, dividiendo por el número de servidores, y tomando el resultado menor del cálculo y 1 &ndash; es menor que 1, entonces las ecuaciones de colas tienen una solución definida; de lo contrario, la longitud esperada de la cola y el tiempo esperado en la cola son ilimitados. En este modelo, estos valores no limitados se indican con "N/A" en los monitores asociados.

Este modelo muestra los servidores en una fila a lo largo de la parte inferior del mundo NetLogo; los clientes se muestran en una cola que "serpentea" desde cerca de la parte inferior del mundo NetLogo hasta la parte superior. Sin embargo, estas características de la pantalla son puramente para propósitos de visualización; las posiciones de los servidores y clientes, y los colores de los clientes, no tienen ningún propósito o impacto funcional. Los colores de los servidores, en cambio, sí tienen un significado: un servidor inactivo se muestra en verde, mientras que un servidor ocupado es rojo.

## THINGS TO TRY

Realiza la simulación varias veces, para tener una idea de los efectos de los diferentes parámetros sobre la longitud media de la cola y el tiempo medio en la cola. ¿Cómo se comparan estas estadísticas observadas con los valores teóricos? ¿Parece que los parámetros de entrada afectan no sólo a la longitud media de la cola, sino también a la variabilidad de la misma?

## EXTENDING THE MODEL

Este modelo podría ampliarse fácilmente para soportar tiempos de servicio medios no idénticos para diferentes servidores (posiblemente a través de un botón **Add Server** que crea servidores de uno en uno, cada uno con un valor de tiempo de servicio medio especificado); distribuciones de tiempo de servicio adicionales además de la exponencial; una cola capacitada; y disciplinas de cola alternativas (prioridad aleatoria y LIFO serían las más fáciles de añadir). Sin embargo, cuando se simula un sistema con estos factores complicados, los cálculos de la longitud esperada de la cola y el tiempo esperado en la cola pueden resultar difíciles, o incluso prácticamente imposibles. Sin embargo, hay que tener en cuenta que existe una relación general, conocida como la fórmula de Little, entre la longitud esperada de la cola y el tiempo esperado en la cola (o, más generalmente, entre el número esperado de clientes/transacciones en todo el sistema y el tiempo esperado que un cliente/transacción pasa en el sistema), que se mantiene incluso para sistemas de colas muy complicados.

## NETLOGO FEATURES

Este modelo utiliza la primitiva **`tick-advance`** para avanzar el valor de los ticks de NetLogo en cantidades no integrales. Esto permite que el reloj de NetLogo sea utilizado como un reloj de simulación de eventos discretos. Sin embargo, la pantalla de ticks estándar (normalmente vista justo debajo del deslizador de velocidad) no puede mostrar valores no integrales, por lo que este modelo utiliza un monitor de ticks separado.

## CREDITS AND REFERENCES

Copyright 2017 Nick Bennett

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

&nbsp;&nbsp;&nbsp;&nbsp;[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

server
false
0
Rectangle -7500403 true true 75 75 225 90
Rectangle -7500403 true true 75 90 90 210
Rectangle -7500403 true true 210 90 225 210
Rectangle -7500403 true true 75 210 225 225

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
