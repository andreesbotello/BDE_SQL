# Proyecto PostGIS: Automatización Municipal - Estepona (Málaga)

Este repositorio contiene el proyecto final de la asignatura **Bases de Datos Espaciales (BDE)** del *Máster Universitario en Ingeniería Geomática y Geoinformación* de la **Universitat Politècnica de València (UPV)**. El proyecto está completamente parametrizado para ejecutarse automáticamente sobre cualquier municipio.

* **Alumno:** Bryan Andrés Botello Sarmiento (babotsar@upv.edu.es)
* **Municipio de Estudio (Por Defecto):** Estepona, Málaga (Código INE: 29051)
* **Tecnologías Principales:** PostgreSQL, PostGIS, QGIS, Python

---
## 0. Configuración Local

Para ejecutar este proyecto, necesitas configurar las credenciales de la base de datos:
1. Ve a la carpeta `scripts/`.
2. Duplica el archivo `config.py.example` y renombra la copia como `config.py`.
3. Abre `config.py` y edita la variable `DB_PASSWORD` con tu contraseña local de PostgreSQL.

## 1. Contexto y Objetivos del Proyecto

El objetivo del proyecto es importar, modelar y analizar datos espaciales y alfanuméricos de diversas fuentes oficiales para el municipio de Estepona, aplicando metodologías avanzadas de bases de datos espaciales y análisis geográfico.

El proyecto se estructura en tres esquemas PostgreSQL principales:

### Esquema 1: Importación (`jcm1`)
Copia fiel y original de los datos descargados sin modificar el SRS (Sistema de Referencia Espacial), campos ni registros.
* **Catastro (GML):** Edificios (`building`, `buildingpart`) y parcelas catastrales (`cadastralparcel`).
* **Red de Transporte (IGN - Shapefile):** Tramos viales (`tramovial`) y portales/puntos kilométricos (`portalpk`).
* **Red de Hidrografía (IGN - Shapefile):** Tramos de cursos de agua (`tramocurso`).
* **Límites Municipales (IGN - Shapefile):** Recinto del término municipal (`ttmm`).
* **SIOSE (Geopackage):** Polígonos de ocupación del suelo (`siose_pol`) y tablas de codificación (`siose_codiige`, `siose_hilucs`).

### Esquema 2: Modelo de Datos (`jcm2`)
Adaptación y optimización de los datos de `jcm1` al ámbito y requisitos del estudio:
* **SRS del Proyecto:** Homogeneización al sistema proyectado (ej. **EPSG:25830** - UTM Huso 30N).
* **Ámbito Municipal:** Recorte de todas las capas al término municipal de Estepona (o zona de influencia de amortiguación de 500m).
* **Reducción de Dimensiones:** Conversión de geometrías 3D a 2D (`ST_Force2D`).
* **Simplificación y Restricciones:** Conservación selectiva de campos clave, análisis semántico (valores nulos, rangos) y aplicación de restricciones (`NOT NULL`, `CHECK`, `UNIQUE`, integridad referencial).
* **Validación Geométrica:** Corrección de geometrías no válidas (`ST_MakeValid`), filtrado de líneas y polígonos por debajo de la tolerancia topográfica y creación de índices espaciales (`GiST`).

### Esquema 3: Análisis Espacial (`jcm3`)
Resultados del análisis espacial, reglas topológicas y consultas de localización óptima:
* **Reglas Topológicas:** Detección de solapes o intersecciones no permitidas (ej. edificios que intersecan viales, cruces de viales no divididos).
* **Consultas Avanzadas:** Análisis estadísticos y de relaciones espaciales entre parcelas, edificios, SIOSE e hidrografía.
* **Localización Óptima:** Implementación de un modelo espacial multicriterio basado en SQL para resolver un problema de localización (ej. búsqueda de parcelas candidatas que cumplan criterios de distancias, áreas y usos).
* **Automatización:** Creación de reglas SQL y disparadores (Triggers) para mantener la integridad geométrica y actualización automática de atributos (ej. cálculo de áreas).

---

## 2. Estructura del Workspace

```text
Proyecto_Final/
├── descargas/            # Archivos fuente descargados comprimidos/crudos.
├── fuentes_raw/          # Documentación original en formato PDF (enunciados, guías).
├── fuentes/              # Documentación convertida a Markdown para fácil lectura del agente.
├── scripts/              # Scripts de automatización en Python.
│   ├── config.py             # Configuración global y variables parametrizables (municipio, SRID).
│   ├── convertir_fuentes.py  # Conversión de PDFs a Markdown usando MarkItDown.
│   └── descargas.py          # Script de automatización para descargas y procesamiento.
├── proyecto_final.qgz    # Proyecto de QGIS para la visualización gráfica de los esquemas.
├── README.md             # Este archivo de contexto y directrices.
└── [Documentación de Memoria y backups correspondientes]
```

---

## 3. Metodología de Trabajo para el Agente (AI Agent Instructions)

> [!IMPORTANT]
> **Esta sección define las reglas de comportamiento y restricciones técnicas que debe seguir cualquier agente de Inteligencia Artificial que trabaje en este repositorio.**
> El incumplimiento de estas normas puede comprometer la reproducibilidad del proyecto o alterar el flujo de automatización definido por el usuario.

### Regla 1: Uso Restringido de la Terminal
El agente **NO** debe utilizar comandos en la terminal de manera autónoma, salvo que existan instrucciones explícitas del usuario para ejecutar una tarea concreta (ej. correr un script específico o realizar pruebas de conexión). Para la exploración de archivos, edición y tareas comunes, se deben preferir las herramientas y APIs nativas provistas por el entorno de desarrollo.

### Regla 2: SQL Exclusivo en Archivos .sql (Prohibido SQL embebido o hardcodeado en Python)
En todos los procesos de automatización y consulta, las sentencias SQL deben residir **exclusivamente dentro de archivos `.sql` individuales**.
* **PROHIBIDO:** Escribir, embeber o hardcodear cualquier consulta SQL (ya sean DDLs, inserciones, actualizaciones o consultas de validación/conteo) como cadenas de texto dentro de los scripts de Python.
* **MANDATORIO:** Si una funcionalidad requiere ejecutar sentencias SQL adicionales o realizar validaciones secundarias, se deben crear múltiples archivos `.sql` individuales. Los scripts de Python deben actuar **únicamente como conectores y ejecutores** de dichos archivos.

### Regla 3: Preservación de Datos y Buenas Prácticas de PostGIS
* Al construir consultas o scripts que realicen operaciones espaciales pesadas (como cálculo de distancias sobre miles de filas), se debe priorizar el uso de índices espaciales mediante predicados eficientes como `ST_DWithin` en lugar de evaluar distancias exactas con `ST_Distance` cuando no sea necesario.
* Todas las geometrías generadas o modificadas en el esquema `jcm2` y `jcm3` deben asegurar la consistencia del **SRID (25830)**.
* Mantener los comentarios del código de Python y documentar brevemente el propósito de cada consulta SQL embebida.

### Regla 4: Personalidad y Comunicación del Agente
El agente debe interactuar y comunicarse de forma pragmática, concisa y sin expresiones emocionales o de cortesía redundantes. Las explicaciones deben ceñirse estrictamente a los hechos técnicos y a las modificaciones del código para optimizar el flujo de trabajo y la lectura de respuestas.

### Regla 5: Parametrización y Automatización
* **PROHIBIDO:** Hardcodear el código del municipio (`CODIGO_MUNICIPIO`), nombre o SRID de proyección en los scripts de descarga o de procesamiento de base de datos.
* **MANDATORIO:** Importar estas variables directamente desde `scripts/config.py`. De este modo, el usuario puede automatizar el ejercicio para cualquier otro municipio simplemente editando el valor de `CODIGO_MUNICIPIO` en dicho archivo de configuración.

### Regla 6: Desarrollo Escalonado (Staged Development) y Uso de Carpeta Temporal (temp/)
* **MANDATORIO:** Al procesar grandes volúmenes de datos espaciales (como archivos de hidrografía, SIOSE o Catastro completo de varios gigabytes), el agente **no debe** intentar ejecutar la automatización sobre el conjunto total de los datos en el primer intento.
* **PROCESO:** Se debe crear siempre un script de prueba o testeo ligero (ej. `test_ligero.py`) utilizando la muestra o archivo de menor peso del conjunto (por ejemplo, los archivos correspondientes a Ceuta o Melilla) para validar y depurar primero el flujo de datos, tipos de geometrías, compatibilidad de librerías y formatos.
* **UBICACIÓN DE PRUEBAS:** Todos los scripts de prueba temporal, benchmarks, validaciones de variables o testeos unitarios deben crearse **únicamente dentro del directorio `temp/`** para evitar la contaminación de la carpeta de código limpio `scripts/`.
* **ESCALABILIDAD:** Solo tras verificar que la prueba unitaria ligera se ejecuta con éxito total, se procederá a implementar y ejecutar el código a gran escala sobre todo el volumen. Esto optimiza el consumo de cómputo y previene errores complejos de seguir y depurar.

### Regla 7: Evitar Microgestiones Innecesarias
* **PROHIBIDO:** Realizar microgestiones superfluas en el código que no aporten valor funcional real, tales como insertar y posteriormente borrar comentarios vacíos, reformatear saltos de línea (enters) sin justificación técnica o realizar ediciones estéticas redundantes. El agente debe centrarse exclusivamente en realizar los cambios lógicos y de funcionalidad necesarios para resolver la tarea.


