<h1 align="center">Proyecto 2 – Confiabilidad en Sistemas de Potencia (2026)</h1>

<p align="center">
<img src="https://img.shields.io/badge/STATUS-FRAMEWORK-blue">
<img src="https://img.shields.io/badge/MATLAB-R2022%2B-orange">
<img src="https://img.shields.io/badge/MATPOWER-7.1-green">
<img src="https://img.shields.io/badge/NIVEL-HL--II-blue">
</p>

---

# 📑 Índice

- [Información general](#info-general)
- [Objetivo del proyecto](#objetivo)
- [Metodología implementada](#metodologia)
- [Conceptos clave](#conceptos)
- [Índices de confiabilidad](#indices)
- [Sistema de prueba](#sistema)
- [Entorno de desarrollo](#entorno)
- [Arquitectura del framework](#arquitectura)
- [Estructura del repositorio](#estructura)
- [Archivos proporcionados](#archivos)
- [Uso del framework](#uso)
- [Parámetros configurables](#parametros)
- [Salida en consola](#salida)
- [Autora](#autora)

---

<a id="info-general"></a>
## 💡 Información general

<p align="justify">
Este repositorio contiene el framework base y los casos de estudio para el desarrollo del Proyecto 2 del curso:
</p>

<p align="justify">
<strong>Curso:</strong> Confiabilidad en Sistemas de Potencia (2026).<br>
<strong>Profesor:</strong> Dr. Mario Alberto Ríos Mesías, Ph.D.<br>
<strong>Universidad:</strong> Universidad de los Andes.
</p>

---

<a id="objetivo"></a>
## 🎯 Objetivo del proyecto

<p align="justify">
Evaluar la confiabilidad del sistema IEEE RTS-24 mediante simulación de Monte Carlo en el Nivel Jerárquico II (HL-II Generación + Transmisión), analizando:
</p>

<p align="justify">
1. El efecto de las restricciones de la red de transmisión sobre los índices de confiabilidad, en comparación con los resultados obtenidos en el Nivel Jerárquico I.<br>
2. El impacto de la integración de fuentes renovables (eólica y solar) sobre los índices de confiabilidad en presencia de restricciones de red.<br>
3. El efecto de la ubicación geográfica y la combinación tecnológica de las fuentes renovables sobre la confiabilidad del sistema, considerando operación diurna y nocturna.<br>
4. El papel del clustering como herramienta de estratificación, así como su sensibilidad respecto al número de clústeres seleccionados.<br>
5. La eficiencia computacional del framework propuesto, en términos de uso de caché, tiempos de cómputo y procesamiento paralelo.
</p>

---

<a id="metodologia"></a>
## 👩‍💻 Metodología implementada

<p align="justify">
- Simulación Monte Carlo no secuencial (HL-II: Generación + Transmisión).<br>
- Truncamiento del espacio de estados combinado (K<sub>gen</sub> + K<sub>lin</sub> ≤ 2).<br>
- Flujo de potencia óptimo (OPF) con deslastre de carga mediante MATPOWER.<br>
- Muestreo estratificado por clústeres basado en resultados del Nivel I (K-means).<br>
- Integración FNCER mediante Point Estimate Method (PEM – 2m+1).<br>
- Estimación estadística con control de error relativo.
</p>

---

<a id="conceptos"></a>
## 📖 Conceptos clave

### Nivel Jerárquico II (HL-II)

<p align="justify">
A diferencia del Nivel I (HL-I), donde se verifica si la capacidad total de generación es suficiente para cubrir la demanda sin considerar la red, el Nivel II agrega la red de transmisión al problema. La potencia debe poder llegar a los nodos de carga a través de las líneas, respetando sus límites de capacidad. En cada escenario se resuelve un flujo de potencia óptimo (OPF) que determina cuánta potencia puede efectivamente entregar el sistema.
</p>

### Flujo de potencia óptimo (OPF) y deslastre de carga

<p align="justify">
Cada escenario se evalúa resolviendo un OPF sobre el sistema con los generadores y líneas falladas ya desconectados. Para representar el deslastre de carga, se agregan generadores ficticios con costo muy alto en cada nodo de carga. Lo que despachan estos generadores ficticios corresponde a la DNS. Con fuentes renovables, se resuelve un OPF por cada punto de concentración del método PEM, y la DNS final es el promedio ponderado.
</p>

### Muestreo estratificado por clústeres

<p align="justify">
Dado que resolver un OPF es considerablemente más costoso que el balance simple del Nivel I, se emplea un muestreo estratificado basado en los resultados del Nivel I. Los escenarios únicos se agrupan mediante K-means en clústeres definidos por tres variables: la DNS del escenario, el nivel de carga relativo al pico (LoadRatio), y el número de generadores síncronos fallados. El Nivel II distribuye sus N realizaciones entre los clústeres de forma proporcional a su frecuencia en el Nivel I.
</p>

<p align="justify">
El número de clústeres puede fijarse manualmente o seleccionarse automáticamente mediante una combinación de dos métricas: el ASW (Average Silhouette Width), que mide qué tan bien separados están los clústeres, y el MSE (Mean Squared Error), que mide su compacidad interna.
</p>

### Descomposición de contingencias

<p align="justify">
En el Nivel II, la DNS puede originarse por distintas causas. Los eventos con DNS > 0 se clasifican en tres categorías:
</p>

<p align="justify">
- <strong>Solo generación</strong> (1 ≤ K<sub>gen</sub> ≤ 2, K<sub>lin</sub> = 0): falta de capacidad de generación, sin fallas en la red.<br>
- <strong>Solo transmisión</strong> (K<sub>gen</sub> = 0, 1 ≤ K<sub>lin</sub> ≤ 2): congestión o pérdida de líneas, aunque la generación sea suficiente.<br>
- <strong>Mixta</strong> (K<sub>gen</sub> = 1, K<sub>lin</sub> = 1): combinación simultánea de fallas de generación y transmisión.
</p>

---

<a id="indices"></a>
## 📊 Índices de confiabilidad

<p align="justify">
A partir de la metodología se estiman los principales índices clásicos de confiabilidad del sistema, los cuales se describen a continuación:
</p>

| Índice | Definición | Unidad |
|--------|------------|--------|
| E[DNS] | Valor esperado de la demanda no suministrada | MW |
| LOLP | Probabilidad de pérdida de carga | - |
| LOLE | Expectativa de pérdida de carga = LOLP × h_periodo | horas/año |
| LOEE | Expectativa de pérdida de energía = E[DNS] × h_periodo | MWh/año |

<p align="justify">
Donde h_periodo corresponde a las horas del período analizado (día o noche) en el año, obtenidas a partir de la curva de duración de carga del sistema.
</p>

---

<a id="sistema"></a>
## 🔌 Sistema de prueba

<p align="justify">
Se utiliza el sistema IEEE RTS-24, compuesto por 24 barras, 32 generadores síncronos, 38 líneas de transmisión y dos niveles de tensión (138 kV y 230 kV). La demanda nominal del sistema es 2850 MW y la capacidad total instalada es 3405 MW.
</p>

### Integración de fuentes renovables

<p align="justify">
Se reemplazan 9 de los 32 generadores síncronos por parques de generación renovable. La capacidad síncrona removida es 1274 MW. Los generadores reemplazados se ubican en dos zonas geográficas: Norte (buses 1 y 2) y Sur (buses 15, 16 y 23).
</p>

| Parque | Gen. reemplazado | Pn síncr. [MW] | Zona |
|--------|------------------|-----------------|------|
| F1 | #3 (Bus 1) | 76 | Norte |
| F2 | #4 (Bus 1) | 76 | Norte |
| F3 | #7 (Bus 2) | 76 | Norte |
| F4 | #8 (Bus 2) | 76 | Norte |
| F5 | #20 (Bus 15) | 155 | Sur |
| F6 | #21 (Bus 16) | 155 | Sur |
| F7 | #30 (Bus 23) | 155 | Sur |
| F8 | #31 (Bus 23) | 155 | Sur |
| F9 | #32 (Bus 23) | 350 | Sur |

### Escenarios de reemplazo tecnológico

<p align="justify">
- <strong>Caso eólico</strong> (<code>script_eolica.m</code>): los 9 parques son eólicos. Velocidad del viento modelada con distribución Weibull diferenciada por zona.<br>
- <strong>Caso solar</strong> (<code>script_solar.m</code>): los 9 parques son solares. Generación modelada con distribución Beta a partir de datos históricos de irradiancia (GHI).<br>
- <strong>Caso mixto</strong> (<code>script_mixto.m</code>): los 9 parques combinan tecnología eólica y solar según tres configuraciones predefinidas.
</p>

### Configuraciones del caso mixto

| Parque | Pn síncr. [MW] | Zona | Config = 1 | Config = 2 | Config = 3 |
|--------|-----------------|------|------------|------------|------------|
| F1 | 76 | Norte | Eólica | Solar | Eólica |
| F2 | 76 | Norte | Eólica | Solar | Solar |
| F3 | 76 | Norte | Eólica | Solar | Eólica |
| F4 | 76 | Norte | Eólica | Solar | Solar |
| F5 | 155 | Sur | Solar | Eólica | Eólica |
| F6 | 155 | Sur | Solar | Eólica | Solar |
| F7 | 155 | Sur | Solar | Eólica | Eólica |
| F8 | 155 | Sur | Solar | Eólica | Solar |
| F9 | 350 | Sur | Solar | Eólica | Eólica |

### Parámetros Weibull del recurso eólico

| Zona | a [m/s] | b |
|------|---------|------|
| Norte | 12 | 1.85 |
| Sur | 10 | 1.75 |

### Red de transmisión

<p align="justify">
La red consta de 38 líneas y transformadores que operan a 138 kV y 230 kV. La probabilidad de falla en estado estacionario de cada línea se calcula como FOR = λ / (λ + μ), donde μ = 8760 / MTTR. Los valores de FOR resultantes son del orden de 10⁻⁴ para líneas aéreas y de 10⁻³ para transformadores.
</p>

### Demanda del sistema

<p align="justify">
La demanda se modela mediante un histograma probabilístico de estados de carga, con dos períodos (día y noche), cada uno con su distribución de probabilidad y horas asociadas. La clasificación resulta en 4658 horas diurnas y 4102 horas nocturnas anuales. La carga total se distribuye entre los nodos del sistema según los porcentajes de participación por barra.
</p>

---

<a id="entorno"></a>
## 🖥 Entorno de desarrollo

<p align="justify">
Desarrollado en:
</p>

<p align="justify">
- <strong>MATLAB</strong> (compatible R2022+).<br>
- <strong>MATPOWER</strong> versión 7.1 (requerido para OPF). Disponible en <a href="https://matpower.org/download/">matpower.org</a>.
</p>

---

<a id="arquitectura"></a>
## 🏗 Arquitectura del framework

<p align="justify">
El framework sigue una arquitectura modular compuesta por:
</p>

<p align="justify">
1. <strong>Capa de datos</strong>: carga del sistema IEEE RTS-24, red de transmisión y perfiles renovables.<br>
2. <strong>Capa probabilística</strong>: modelado de fallas de generación, fallas de líneas y variables FNCER.<br>
3. <strong>Motor Monte Carlo Nivel I</strong>: simulación no secuencial en HL-I con clustering (K-means).<br>
4. <strong>Motor Monte Carlo Nivel II</strong>: muestreo estratificado con OPF y deslastre de carga.<br>
5. <strong>Integración PEM (2m+1)</strong>: tratamiento probabilístico de renovables.<br>
6. <strong>Capa estadística</strong>: estimación de índices de confiabilidad y descomposición de contingencias.<br>
7. <strong>Capa de ejecución</strong>: scripts que configuran escenarios (base, eólico, solar, mixto).
</p>

---

<a id="estructura"></a>
## 📂 Estructura del repositorio

### DATA/
- `Carga.xlsx`
- `Solar.csv`
- `case24_ieee_rts_1.m`

### FUNCIONES/
- `SMC_Nivel1_Clustering.m`
- `SMC_Nivel2_Muestreo.m`
- `PEM.m`
- `Generacion_eolica.m`
- `Generacion_solar.m`
- `Histograma_carga.m`
- `Estados_carga.m`
- `Generadores_deslastre.m`
- `indices_confiabilidad.m`
- `bi2de.m`

### SCRIPTS/
- `script_base.m`
- `script_eolica.m`
- `script_solar.m`
- `script_mixto.m`

---

<a id="archivos"></a>
## 📁 Archivos proporcionados

### Scripts principales

| Archivo | Descripción |
|----------|------------|
| `script_base.m` | Caso base con generación 100% síncrona |
| `script_eolica.m` | Escenario con integración eólica |
| `script_solar.m` | Escenario con integración solar |
| `script_mixto.m` | Escenario con mix tecnológico (eólica + solar) |

### Funciones del framework

| Archivo | Descripción |
|----------|------------|
| `SMC_Nivel1_Clustering.m` | Motor Monte Carlo Nivel I con clustering |
| `SMC_Nivel2_Muestreo.m` | Motor Monte Carlo Nivel II con muestreo estratificado |
| `Generacion_eolica.m` | Caracterización estadística de generación eólica |
| `Generacion_solar.m` | Caracterización estadística de generación solar |
| `PEM.m` | Implementación del método Point Estimate Method (2m+1) |
| `Histograma_carga.m` | Distribución probabilística de la demanda |
| `Estados_carga.m` | Generación de estados de carga por bus |
| `Generadores_deslastre.m` | Generadores ficticios para deslastre de carga |
| `indices_confiabilidad.m` | Cálculo de DNS por escenario |
| `bi2de.m` | Conversión vector binario → decimal |

### Archivos de datos

| Archivo | Descripción |
|----------|------------|
| `case24_ieee_rts_1.m` | Caso MATPOWER del sistema IEEE RTS-24 (topología, generadores, líneas, costos) |
| `Carga.xlsx` | Datos de la curva de carga del sistema |
| `Solar.csv` | Datos históricos de irradiancia solar (GHI) |

---

<a id="uso"></a>
## ▶ Uso del framework

<p align="justify">
1. Descargar o clonar el repositorio.<br>
2. Abrir MATLAB.<br>
3. Instalar y configurar <a href="https://matpower.org/download/">MATPOWER 7.1</a> en el path de MATLAB.<br>
4. Ejecutar uno de los scripts ubicados en la carpeta <code>SCRIPTS</code>.
</p>

---

<a id="parametros"></a>
## ⚙ Parámetros configurables

| Parámetro | Descripción | Valores |
|------------|------------|----------|
| p_max | Demanda pico del sistema [MW] | 3300 |
| dn | Período del día | 1 = día, 0 = noche |
| num_clusters | Número de clústeres para estratificación | 0 (automático), 3, 30 |
| config | Configuración del mix tecnológico (solo `script_mixto.m`) | 1, 2, 3 |

---

<a id="salida"></a>
## 📟 Salida en consola

<p align="justify">
Durante la ejecución, el framework imprime en consola un resumen estructurado del escenario simulado.
</p>

<p align="justify">
En todos los casos (base y con renovables) se muestra:
</p>

<p align="justify">
- Caracterización del sistema (capacidad instalada, demanda, margen de reserva).<br>
- Espacio de estados de generación y transmisión (N-0, N-1, N-2).<br>
- Modelado probabilístico de la demanda.<br>
- Resultados del clustering (número de clústeres, ASW, MSE, tabla de clústeres con medoides).<br>
- Progreso iterativo de la simulación Monte Carlo Nivel I y Nivel II.<br>
- Resultados finales (E[DNS], LOLP, intervalo de confianza, error relativo) y archivo <code>.mat</code> generado.
</p>

<p align="justify">
En los escenarios con generación renovable se adiciona además:
</p>

<p align="justify">
- Descripción del reemplazo de generación síncrona.<br>
- Capacidad renovable instalada y factor de sobredimensionamiento.<br>
- Caracterización estadística de las fuentes renovables.<br>
- Espacio de estados de FNCER mediante el método PEM (2m+1).<br>
- Tabla de escenarios y pesos asociados.
</p>

### Métricas computacionales

<p align="justify">
Al finalizar cada nivel de simulación, el framework reporta las siguientes métricas de eficiencia:
</p>

| Métrica | Descripción |
|---------|-------------|
| Tiempo | Duración total de la simulación del nivel correspondiente, en minutos. |
| Hit rate del caché | Porcentaje de realizaciones cuyo estado de red ya había sido evaluado previamente y cuyo resultado se reutilizó sin resolver un nuevo OPF. Un hit rate alto indica que el caché está ahorrando cómputo efectivamente. |
| OPFs calculados | Número de flujos de potencia óptimos resueltos desde cero (sin caché). Corresponde a los estados de red únicos que requirieron evaluación completa. |
| Cálculos ahorrados | Número de evaluaciones evitadas gracias al caché, equivalente a realizaciones totales menos OPFs calculados. |
| Velocidad | Tasa de procesamiento expresada en realizaciones por minuto. Permite comparar la eficiencia entre escenarios con y sin renovables. |

<p align="justify">
Esta estructura permite verificar la correcta configuración del escenario, la convergencia estadística del estimador y el efecto de las restricciones de red sobre la confiabilidad del sistema.
</p>

---

<a id="autora"></a>
## ✍ Autora

María Daniela Medina Buitrago  
2026
