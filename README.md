
# Programación Orientada a Agentes y Programación Orientada a Eventos

## Programación Orientada a Agentes

La programación orientada a agentes (ABM, por sus siglas en inglés) es un enfoque de modelado computacional utilizado para simular el comportamiento de sistemas complejos formados por entidades autónomas conocidas como *agentes*. Cada agente opera de forma independiente siguiendo un conjunto de reglas o comportamientos predefinidos, y puede interactuar con otros agentes y con su entorno. El objetivo de la ABM es observar cómo las interacciones entre agentes individuales generan comportamientos emergentes a nivel de sistema.

### Características Clave de ABM:
1. **Agentes Autónomos**: Los agentes actúan de forma independiente según reglas predefinidas. Pueden representar individuos, animales, células, organizaciones o entidades abstractas.
2. **Entorno**: Los agentes operan dentro de un entorno que puede influir en su comportamiento. Este entorno puede ser un espacio físico o una estructura abstracta como una red social.
3. **Interacciones**: Los agentes interactúan entre sí y con su entorno, de manera cooperativa o competitiva.
4. **Comportamiento Emergente**: Comportamientos complejos surgen de interacciones simples entre los agentes.

### Aplicaciones de ABM:
- **Ciencias Sociales**: Simulación de comportamientos grupales, adopción de tecnologías, propagación de rumores y dinámica de poblaciones.
- **Ecología**: Modelado de ecosistemas e interacciones entre especies.
- **Economía**: Simulación de mercados, competencia entre empresas y comportamiento de consumidores.
- **Epidemiología**: Modelado de la propagación de enfermedades infecciosas.
- **Simulaciones Urbanas**: Modelado del tráfico y patrones de crecimiento urbano.

### Ventajas de ABM:
- **Flexibilidad**: Permite modelar sistemas complejos y no lineales.
- **Comportamiento Emergente**: Captura patrones que surgen de interacciones locales.
- **Simulación Detallada**: Permite modelar con gran detalle el comportamiento de agentes individuales.

### Desafíos:
- **Costo Computacional**: Los modelos con muchos agentes o reglas complejas pueden ser intensivos en recursos.
- **Validación**: Los comportamientos emergentes pueden ser difíciles de predecir o comparar con datos reales.
- **Diseño de Reglas**: Definir reglas y comportamientos adecuados para los agentes puede ser complicado.

---

## Programación Orientada a Eventos

La programación orientada a eventos (EDP, por sus siglas en inglés) es un paradigma de programación en el que el flujo del programa está determinado por la ocurrencia de eventos. Un evento puede ser cualquier acción, como una interacción del usuario (clic del mouse, pulsación de tecla), mensajes de red, cambios en el estado del sistema o la llegada de datos externos. Este paradigma es común en interfaces gráficas de usuario (GUIs), sistemas en tiempo real y aplicaciones altamente interactivas, como videojuegos o sistemas de red.

### Características Clave de EDP:
1. **Eventos**: Los eventos son acciones o sucesos que pueden provenir de diversas fuentes (interacción del usuario, entrada de hardware, mensajes del sistema).
2. **Manejadores de Eventos**: Son funciones o métodos que responden a eventos específicos. Cuando ocurre un evento, su manejador correspondiente se activa para procesarlo.
3. **Bucle de Eventos**: El programa entra en un bucle que monitorea continuamente la ocurrencia de eventos y ejecuta los manejadores correspondientes.
4. **Asincronía**: La programación orientada a eventos suele ser asíncrona, permitiendo que las tareas ocurran sin seguir una secuencia fija, lo que mejora la eficiencia.

### Ejemplo de Uso:
- **Interfaces Gráficas (GUIs)**: EDP es común para manejar las interacciones del usuario, como clics y pulsaciones de teclas.
- **Sistemas Distribuidos y Redes**: EDP se utiliza para gestionar conexiones o mensajes entrantes, como en servidores web asíncronos (Node.js).
- **Sistemas en Tiempo Real**: Se utiliza para manejar datos de sensores, entradas de usuario o alertas del sistema en aplicaciones en tiempo real.

### Ventajas de EDP:
- **Eficiencia**: Ideal para sistemas que requieren una respuesta rápida a interacciones o eventos externos.
- **Escalabilidad**: El manejo asincrónico de eventos permite un uso eficiente de los recursos y una mayor escalabilidad, especialmente en aplicaciones de red.
- **Modularidad**: Los manejadores de eventos permiten dividir el código en unidades pequeñas e independientes, lo que facilita el mantenimiento.

### Desafíos:
- **Complejidad**: Los sistemas basados en eventos pueden ser difíciles de gestionar, ya que las interacciones no lineales pueden hacer que el código sea más complicado de depurar.
- **Gestión del Estado**: Compartir el estado entre eventos puede generar condiciones de carrera (race conditions) o inconsistencias.
- **Callback Hell**: Los callbacks anidados pueden llevar a un código difícil de leer y mantener, común en algunos lenguajes como JavaScript.

---

# Discrete Event Simulation: Queues and Servers

## Descripción del modelo

Este modelo simula un sistema de **colas M/M/n**, donde los clientes llegan y esperan en una cola hasta que uno de los servidores esté disponible para atenderlos. El número de servidores (hasta 10) y las tasas de llegada y servicio de los clientes son configurables. El modelo permite recopilar estadísticas agregadas sobre el tiempo promedio en la cola y en el sistema.

### Propósito del modelo

El propósito del modelo es analizar el comportamiento de un sistema de colas y servidores, midiendo cómo factores como el número de servidores o la tasa de llegada afectan el tiempo de espera de los clientes.

---

## Tipos de agentes

1. **Clientes (customers)**: Los clientes son las entidades que llegan al sistema y esperan en la cola para ser atendidos. Cada cliente registra su tiempo de llegada y el tiempo en que comienza el servicio.

2. **Servidores (servers)**: Los servidores atienden a los clientes en orden de llegada. Cada servidor registra el cliente que está atendiendo y el tiempo estimado para finalizar el servicio.

---

## Propiedades de los agentes

### Propiedades de los clientes (customers):
- **time-entered-queue**: Tiempo en que el cliente ingresó al sistema (cola).
- **time-entered-service**: Tiempo en que el cliente comenzó a ser atendido por un servidor.

### Propiedades de los servidores (servers):
- **customer-being-served**: El cliente que el servidor está atendiendo.
- **service-completion-time**: Tiempo estimado de finalización del servicio para el cliente actual.

---

## Dinámica del modelo

- Los clientes llegan al sistema a intervalos de tiempo definidos por una tasa de llegada (lambda). Cuando llegan, entran a una cola si no hay servidores disponibles.
- Si hay un servidor disponible, el cliente pasa directamente a ser atendido.
- Los servidores atienden a los clientes en el orden en que llegaron (primero en entrar, primero en ser servido). Cada cliente tiene un tiempo de servicio, tras el cual el servidor se libera y puede atender a otro cliente.
- Las estadísticas sobre el tiempo que los clientes pasan en la cola y en el sistema completo se recopilan para calcular promedios.

---

## Parámetros del modelo

- **Número de servidores (n)**: Puedes configurar hasta 10 servidores.
- **Tasa de llegada (lambda)**: Define el intervalo de tiempo entre la llegada de clientes al sistema.
- **Tasa de servicio (mu)**: Determina cuánto tiempo tarda cada servidor en atender a un cliente.

---

## Estadísticas y gráficos

El modelo recopila las siguientes estadísticas:
- **Tiempo promedio en la cola**: El tiempo que los clientes esperan en la cola antes de ser atendidos.
- **Tiempo promedio en el sistema**: El tiempo total que los clientes pasan en el sistema (cola + servicio).
- **Número de clientes en la cola**: La cantidad de clientes que esperan para ser atendidos en un momento dado.

Estas estadísticas se visualizan en gráficos a lo largo del tiempo, lo que permite observar el comportamiento del sistema bajo diferentes configuraciones.

---




## Conclusión

La Programación Orientada a Agentes y la Programación Orientada a Eventos son dos paradigmas potentes que se aplican a diferentes tipos de aplicaciones. Mientras que ABM es adecuado para modelar sistemas complejos donde el comportamiento emerge de las interacciones entre agentes, EDP es ideal para aplicaciones interactivas, en tiempo real y altamente sensibles a eventos. Ambos enfoques se utilizan ampliamente en dominios como simulaciones sociales, sistemas de red y GUIs.

Para explorar más a fondo estos paradigmas, consulte tutoriales, ejemplos y documentación específicos de cada implementación.
