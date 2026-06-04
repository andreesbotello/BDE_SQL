PROYECTO POSTGIS 2024/2025

Carácter individual – Ámbito municipal

•  Trabajo de carácter individual. Utilización de los foros para resolver dudas hasta fecha

límite de entrega de la tarea.

•  Elección por parte del alumno de un municipio, con una población superior a 50000 ha.,
perteneciente a una o varias Comunidades Autónomas seleccionadas por el profesor que
facilitará un listado para que cada estudiante elija un municipio distinto.

•  Nueva BDD: Espacial + funciones_extra.sql

•  Estructura con esquemas PostgreSQL:

•  Esquema para importación: jcm1

Valoración: 4 puntos sobre 30.

Explicación: importación directa (sin cambiar el SRS, ni borrar ningún campo o registro)
y completa desde QGIS.

Sobre las capas importadas en este esquema, no realizaremos ninguna modificación
de datos. Será como una copia original de los datos. Las modificaciones se realizarán
en las tablas de jcm2.

•  Esquema para el modelo de datos: jcm2

Valoración: 13 puntos sobre 30.

Explicación: capas de jcm1, pero adaptadas a:

Elección del SRS del proyecto (puede ser necesario reproyección): No se pueden
comparar dos geometrías, o utilizar cualquier operador o predicado espacial entre dos
geometrías si no tienen el mismo SRS.

Ámbito geográfico del proyecto (municipal)

Reducción de número de campos (con un fin docente solo dejaremos los campos más
representativos de cada capa, y que necesitaremos para un análisis espacial posterior).

¿Comprobar el tipo de campos, es lo que se adapta a mi modelo? ¿Se permite nulos o
no en cada campo?

•  Esquema para el análisis espacial: jcm3

Explicación: Nuevas capas o vistas espaciales derivadas de jcm2, de salida de nuestro
análisis espacial.

Valoración: 13 puntos sobre 30.

- 1 -

    ENTREGABLES

Se subirá antes de la fecha límite como adjunto a la correspondiente tarea de
poliformat. Se adjuntarán dos ficheros a dicha tarea:

a) Fichero PDF con la Memoria (deberá incluir al menos estos ítems):

-  Todos los pasos que se han seguido, y una descripción de cada uno según se
considere.

- Captura de pantalla de QGIS con un zoom extensión de cada capa de los esquemas
jcm1 y jcm2 y también captura de su tabla de atributos en QGIS.

-  Sentencias SQL ejecutadas, en cada uno de los tres bloques (importación, modelo
de datos, análisis espacial).

- Capturas de pantalla de los resultados obtenidos, especialmente del análisis
espacial (en tabla sin son resultados estadísticos, o captura de QGIS)

b) Fichero ZIP con dos ficheros de backup, uno para el esquema jcm2, y otro para el
esquema jcm3 (NO entregar el backup de jcm1 porque puede ocupar varios GB). Los
backups se harán en formato plain y deben incluir la definición de los objetos y los
datos.

En la valoración del proyecto se tendrá en cuenta:

- Memoria

- Complejidad de los análisis espaciales, y/o modelo de datos realizado.

- Cualquier procedimiento en que el alumno ha investigado por sí mismo, cubriendo
conceptos no vistos en la asignatura.

- Competitividad del proyecto comparado con los otros proyectos de los
compañeros.

Esquema para importación: jcm1

1. Esquema 1: Importación
1.1. Importación sin modificar el original

Importación directa (sin cambiar el SRS original de la capa, ni borrar ningún campo o
registro) y completa desde QGIS.

1.2 Configuración QGIS y Encoding.

a) Si QGIS encuentra una geometría no válida, permite comportarse de diferentes
formas, tanto en las operaciones de importación como en cualquier otro proceso de
análisis o procesado espacial. Como lo vamos a utilizar para importar datos, aunque
una geometría nos sea válida la deseamos importar en PostGIS, para desde éste
tratarla si es el caso.

- 2 -

Abrir el menú: QGIS -> Menú configuración / opciones / Procesado, y en el apartado
General, marcar la opción "Filtrado de objetos no válidos" como "No filtrar (mejor
rendimiento)"

b) Alguna capa al ser de varios cientos de miles de filas, puede ser que QGIS requiera
mucho tiempo para abrir la tabla de atributos. Para agilizar, configura QGIS para que la
tabla de atributos solo muestre las entidades que aparecen en pantalla, y cuando
abras la tabla de atributos realiza un zoom previo a una zona de la cartografía.

QGIS -> Menú configuración / opciones / Fuentes de datos -> Marcar opción
"Comportamiento de tabla de atributos" a "Mostrar objetos espaciales visibles en el
mapa".

Además de QGIS, que es la forma en la que vamos a importar toda la cartografía en
este proyecto, hay varias formas de importar datos espaciales y/o alfanuméricos a
PostGIS. Entre otras:

•  Desde un SIG escritorio (QGIS, gvSIG, etc.)

•  Biblioteca GDAL/OGR. ogr2ogr.exe

•  PostGIS ShapeFile Loader/shp2pgsql.exe (situado en el bin de PostgreSQL).

2. Esquema 1: Cartografía a utilizar

La cartografía detallada a continuación es mínima y suficiente para el proyecto. El
alumno, importará esta cartografía, adaptará su modelo de datos, y realizará un
análisis espacial en la cual debe intervenir todas las capas.

Se valorará, si además el alumno aporta más cartografía, si lo hace, esta nueva
cartografía deberá intervenir además en el análisis espacial realizado.

2.1. Catastro (formato origen en GML)
- Descarga: según Servicios ATOM de conjuntos de datos predefinidos INSPIRE (también
existe un complemento/plugin de QGIS para descargar el catastro de forma sencilla).

- 3 -

- Ámbito: municipal

- Capas:

Fichero GML (BU) Buildings (capas Building, Buildingpart) -> building,buildingpart (nombre en postgis)

Fichero GML (CP) Cadastral Parcels (capa: cadastralparcel) -> cadastralparcel (nombre en postgis)

  - SRS: Consultad varias formas para estar seguros: metadatos capa, o fichero gml con
notepad++, o SRS que selecciona QGIS por defecto para la capa.

- Encoding: ¿se ve bien los campos de texto (acentos o eñes), con la codificación de QGIS?

- Documentación (breve descripción, las especificaciones de datos se verán en la segunda
parte de la asignatura)

Guías de Especificación de datos de INSPIRE de parcelas catastrales y edificios:
Disponibles en la web de INSPIRE y https://www.idee.es/datos, ejemplo, pág. 40 de
buildings con esquema UML).

Guías de Transformación de parcelas catastrales y edificios. Son guías basadas en las
guías de INSPIRE del punto anterior, pero personalizadas para España. En estas
veremos mejor los atributos de los objetos espaciales y qué significado y valores
pueden tomar:

https://idee.es/guias-para-implementar

Ejemplo: página 52, valores posibles de currentValueUse, que es la lista de

valores  admitida por el atributo currentUse (página 46).

2.1.1 Importación
Para la importación podemos utilizar directamente QGIS como se explica en este mismo
apartado un poco más adelante.

En algunos casos según qué municipio QGIS puede dar un error en la importación si la capa
original contiene geometrías simples y multi mezcladas. En tal caso, utilizaremos QGIS, pero
con uno de los métodos alternativos explicados en el documento de PoliformaT Importación
de capas con geometrías variadas a PostGIS.pdf.

1) Cargar la capa original y comprobad la codificación en el caso de que el formato

origen sea shape file. Si es Geopackage o GML no hará falta porque por
defecto son UTF8 y QGIS lo averigua correctamente.

En caso de ficheros shape, siempre hay que comprobar la codificación y
cambiarla si es necesario. Generalmente es suficiente con elegir entre
estas dos opciones:

a)  España = ISO-8859-1 (fuente del sistema en MS Windows) = WIN1252 =

LATIN1 (más información en https://en.wikipedia.org/wiki/ISO/IEC_8859)

b) UTF8

2) Desde el administrador de BBDD realizar la importación: Marcar (PK gid,
índice espacial, minúsculas)

- 4 -

Importación a PostGIS desde QGIS (menú de administrador BBDD)

2.2 Red de Transporte (formato origen shape)
- Descarga según centro de descargas del IGN. Ficheros p.ej.: RT-VALENCIA.ZIP

- Ámbito: provincial

- 5 -

- Capas:

Capa RT_VIARIA/rt_tramo_vial.shp -> tramovial (nombre en postgis)

Capa RT_VIARIA/rt_portalpk_p.shp -> portalpk (nombre en postgis)

  - SRS: Consultad varias formas para estar seguros: metadatos capa, o fichero gml con
notepad++, o SRS que selecciona QGIS por defecto para la capa.

- Encoding: Observar con detenimiento los valores de los campos tipovehicD o calzadaD de
tramo_vial, o de fuenteD de portalpk_p para ver si se ven bien los acentos y eñes.

- Documentación:

Basándose en la especificación de datos de INSPIRE (inglés,  https://www.idee.es/datos), el
IGN ha creado varios documentos de trabajo para la red de transporte (Descargables desde el
link de información auxiliar de la figura de arriba) "Especificación de datos del IGN", "Guía de
transformación de datos del IGN" y "Modelo físico de redes de transporte del IGN". En el
modelo físico se puede consultar de forma más sencilla el significado de los campos de
atributos de todas las capas.

2.2.1 Importación
Para la importación podemos utilizar directamente QGIS como se explica en el apartado 2.1.1

2.3 Red de Hidrografía (formato origen shape)
- Descarga: según centro de descargas del IGN. Ficheros p.ej.: DH-JUCAR.ZIP

- Ámbito: cuenca hidrográfica

- 6 -

- Capas:

Capa hi_tramocurso_l.shp -> tramocurso (nombre en postgis)

  - SRS: Consultad varias formas para estar seguros

- Encoding: Observar con detenimiento los valores de un campo de texto como nombre para
ver si se ven bien los acentos y eñes.

- Documentación:

Basándose en la especificación de datos de INSPIRE (inglés,  https://www.idee.es/datos), el
IGN ha creado varios documentos de trabajo para la red de hidrografía (Descargables desde el
link de información auxiliar de la figura de arriba): "Especificación de datos espaciales IGR -
Hidrografía". En este documento se puede encontrar la información de la capa de tramos de
cursos (curso de agua lineal) y sus atributos.

2.3.1 Importación
Para la importación podemos utilizar directamente QGIS.

2.4 Límites municipales (formato origen shape)
- Descarga: según centro de descargas del IGN. Ficheros p.ej.: líneas_limite.ZIP

- Ámbito: toda España

- Capas:

Capa recintos_municipales_inspire_peninbal_etrs89 -> ttmm (nombre en postgis)

  - SRS: Consultad varias formas para estar seguros

- Encoding: Observar con detenimiento los valores de un campo de texto como nameunit para
ver si se ven bien los acentos y eñes.

- 7 -

- Documentación:

Basándose en la especificación de datos de unidades administrativas de INSPIRE (inglés,
https://www.idee.es/datos), el IGN ha creado un documento explicativo que se encuentra
dentro del descargable de líneas límite "Leeme BDDAE.pdf". En este documento se puede
encontrar la información de la capa de recientos de límites municipales y sus atributos.

2.4.1 Importación
Para la importación podemos utilizar directamente QGIS.

2.5 SIOSE (formato origen geopackage)
- Descarga: según centro de descargas del IGN: SIOSE_Comunitat_Valenciana_2014_GPKG.zip

Es un Geopackage que contiene varias capas y tablas alfanuméricas. Al cargarlo QGIS nos
pedirá seleccionar cuales queremos cargar: Solo hay una capa espacial (T_POLIGONOS), las
demás son tablas alfanuméricas. La columna 'Número de objetos espaciales' de la tabla
inferior, se refiere al número de filas.

- Ámbito: Comunidad Autónoma

Diálogo al cargar el fichero gpkg (QGIS)

-  Capas:

Capa t_poligonos -> siose_pol (nombre en postgis)

- 8 -

- Encoding: Geopackage utiliza solo UTF8, así que los campos se deben ver bien.

- Tablas alfanuméricas:

Estas tablas contienen la descripción textual del tipo de suelo (codiige) y del uso del
suelo (hilucs). Ambos campos aparecen en siose_pol de forma numérica. Son tablas
informativas para el alumno, quizás valdrían únicamente para realizar leyendas en un
mapa SIG, pero no para realizar un análisis espacial. Las importaremos a PostgreSQL:

Tabla t_siose_codiige -> siose_codiigel (nombre en postgresql)

Tabla t_siose_hilucs -> siose_hilucs (nombre en postgresql)

 - SRS: Consultad varias formas para estar seguros

 - Documentación:

Basándose en la especificación de datos de INSPIRE (inglés,  https://www.idee.es/datos), el
IGN ha creado varios documentos de trabajo para el SIOSE (Descargables desde el link de
información auxiliar de la figura de arriba): En el documento "Estructura y consulta base de
datos SIOSE  se puede encontrar la información de los atributos.

- Nota: Simbolización para QGIS. Se aportan dos ficheros SLD, con simbolizaciones por codiige
(cobertura del suelo), y hilucs (uso del suelo).

- Curiosidad modelo SIOSE:

La tabla t_valores (no la utilizamos en este documento), contiene 3 o 4 veces más
registros que t_poligonos, y está relacionada con t_poligonos (mediante el campo
id_polygon) con una cardinalidad 1 (t_poligonos) a n (t_valores). Para cada polígono de
t_polygonos tenemos en t_valores varias filas indicando los subcomponentes (y sus
porcentajes) del tipo de suelo.

2.5.1 Importación
2.5.1.1 Capas alfanuméricas.
La importación de las tablas t_siose_codiige y t_siose_hilucs se realizará desde QGIS como
hasta ahora, pero no marcaremos el campo gid, sino que dejaremos el id como clave primaría.

2.5.1.2 Capa siose_pol
Nota importante para la importación a PostGIS: Para la tabla espacial siose_pol, la
importación no la realizaremos con QGIS como se explica en el apartado 2.1.1, sino con uno de
los métodos alternativos explicados en el documento de PoliformaT Importación de capas con
geometrías variadas a PostGIS.pdf.

- 9 -

Esquema para el modelo de datos: jcm2

3. Esquema 2: Creación y relleno de las tablas de jcm2 a partir de
los datos de jcm1.
Primero, pensad en el municipio donde se realizará el análisis espacial. Elegir a ser posible un
término municipal con una extensión mediana o grande. Con una superficie construida de
varios centenares de edificios al menos para que se pueda realizar un análisis catastral mínimo.

3.1 Proyección de estudio
Las capas de jcm1 pueden estar georreferenciadas en varios SRS diferentes: EPSG 4258,
25830, etc.). En jcm2 vamos a trabajar con un único SRS, y además como vamos a realizar
análisis espacial que requieren de magnitudes lineales reales, utilizaremos un SRS que se
corresponda con un sistema proyectado.

Por ejemplo, en el caso de estar en zona 30 UTM elegiríamos el SRS EPSG:25830. Todas las
capas espaciales creadas en jcm2 deberán crearse con este SRS.

Para cambiar de SRS una geometría, es necesario utilizar el comando ST_Transform (geom,
srid) de PostGIS, que reproyecta la geometría geom, al SRS de número srid, y devuelve la
nueva geometría reproyectada que ya podremos insertar en la nueva capa.

3.2 Reducción de las dimensiones de las geometrías.
Seguiemos un modelo de datos en 2D, aunque PostGIS también puede trabajar en 3D, pero
podemos evitar algunos problemas.

Puede haber alguna capa que tenga dimensión 3, es decir, coordenada Z, como la capa de
tramo_vial. Como no vamos a utilizar la Z en nuestro análisis, y así también facilitaremos un
poco más este análisis espacial, al crear la capa jcm2.tramo_vial utilizaremos geometrías de
dimensión 2, y el operador ST_Force2D(geom) para pasar la geometría 3D de jcm1.tramo_vial
a la 2D de jcm2.tramo_vial. Lo mismo haremos si hay más capas con coordenadas Z.

3.3 Zona de estudio
Deberemos establecer una zona de estudio para recortar las demás capas (de ámbito
provincial, o de comunidad autónoma) a la zona municipal elegida.

En jcm2 crearemos una nueva tabla o vista espacial a partir de jcm1.ttmm únicamente con
nuestro municipio (si es una vista espacial, deberemos crear un índice sobre el campo
nameunit de jcm1.ttmm utilizado en el where para filtrar el nombre del municipio de una
forma eficaz). Llamaremos a esta tabla o vista espacial: jcm2.municipio.

Esta capa la utilizaremos en las concatenaciones internas posteriores para seleccionar la
cartografía de las demás capas que se encuentra dentro del término municipal con
ST_Intersects o ST_Covers.

- 10 -

Opcional:

Si lo deseas, una opción mejor sería ampliar la zona de estudio a una distancia del
límite municipal, porque puede que necesitemos las geometrías próximas al término
municipal para nuestro análisis. Estaría bien, extender la zona de estudio por ejemplo
500 metros, en tal caso, en lugar del ST_Intersects utilizaremos el nuevo predicado
ST_DWithin (geom1, geom2, distancia). ST_DWithin devolverá true si las dos
geometrías están a menos de 500 metros.

"ST_Dwithin (geom1, geom2, 500)", es similar a "ST_Distance (geom1,
geom2) < 500", aunque ST_Dwithin es mucho mejor porque está optimizado
para utilizar la indexación espacial de las capas.

3.4 Reducción de campos
Para simplificar el trabajo, no vamos a utilizar todos los campos importados las tablas de
jcm1. En jcm2, dispondremos solo de algunos campos. El alumno, es libre de utilizar más
campos siempre que luego los utilice en su análisis espacial.

Las tablas de jcm2, pueden tener el mismo nombre que las de jcm1, o uno diferente, pero
solo conservarán (como mínimo) los siguientes campos de las capas originales de jcm1.

Además de estos campos, se creará un campo gid de tipo autonumérico en cada tabla,

y que será la clave primaria de la tabla espacial.

jcm2.ttmm: inspireid, natcode, nameunit. Solo debe contener una fila con el
municipio que se haya elegido.

jcm2.building: gml_id, currentuse, numberofbuildingunits, value.

jcm2.buildingpart: gml_id, numberoffloorsaboveground,
numberoffloorsbelowground

jcm2.cadastralparcel: gml_id, areavalue, localid

jcm2.tramovial: id_tramo, id_vial, clased, nombre, firmed

jcm2.portalpk: id_tramo, id_vial, id_porpk, numero

jcm2.tramocurso: id_curso, nombre, tipo_curso

jcm2.siose_pol: id_polygon, codiige, hilucs

* Los campos en cursiva se corresponden con campos con listas acotadas de números o textos.

Estas dos tablas son alfanuméricas (no espaciales). Serán tablas detalle para aplicar
una integridad referencial a los campos codiige y hilucs de la capa jcm2.siose_pol. Los
códigos codiige y hilucs serán las claves primarias, no necesitamos un campo gid
autonumérico.

jcm2.siose_codiige: codiige, descripcion, color_html

jcm2.siose_hilucs: hilucs, descripcion, color_html

- 11 -

Metodología:

Nota: Si un predicado espacial (como ST_Intersects), o cualquier tipo de operador (como
ST_Intersection) que coge dos geometrías como argumentos, debe cumplir que: las dos
geometrías tengan el mismo SRS y las mismas dimensiones, en caso contrario dará error, o
bien no producirá los resultados pedidos.

La metodología a seguir será como la del ejercicio de la práctica 1 del módulo 9, es decir,
primero se crea la tabla espacial con el campo gid, y los campos de arriba como mínimo (tras
averiguar el tipo de datos de cada uno de ellos), el tipo de geometrías, y el SRS adecuado para
nuestro estudio.

create table jcm2.building (gid serial primary key, gml_id varchar,
currentuse varchar, numberofbuildingunits integer, value integer, geom
geometry (multipolygon,25830));

A continuación, se insertarán los datos con la sentencia insert into..utilizando un select para
insertar solo la cartografía de nuestro término municipal (recordar no insertar valores en el
campo gid porque será autonumérico).

insert into jcm2.building (gml_id, currentuse, numberofbuildingunits,
value, geom) select gml_id, currentuse, numberofbuildingunits, value,
geom from jcm1.building;

Nota: en otras capas de ámbito provincial o de comunidad autónoma en el select
anterior habrá que concatenar la tabla origen con la de municipio y filtrar solo la
cartografía que interseca o está dentro del municipio. Además, puede ser necesario
realizar una transformación al SRC del proyecto, que en este ejemplo es el 258380.

Por último, crea los índices espaciales, y cualquier otro índice sobre los campos que pienses
que vas a utilizar los predicados (on, where) de tus consultas espaciales. Aunque, si los
necesitas los pueden crear más adelante.

create index jcm2_building_geom_idx on jcm2.building using gist(geom);

create index jcm2_building_currentuse_idx on jcm2.building
(currentuse);

Ahora, veremos si podemos aplicar algunas restricciones que constriñan un poco los valores
de los campos, como: not null, unique, check. Para ello, antes hay que realizar algunas
comprobaciones de nuestros datos como se indica en el apartado siguiente:

4. Esquema 2: Comprobaciones semánticas de los datos y adición
de restricciones
Objetivo: conocer la naturaleza de nuestros datos, significado de los campos, y valores
admitidos por cada campo. Otro objetivo es añadir en función de este análisis alguna
restricción para un control posterior si se quieren añadir o actualizar datos.

Para esto es necesario realizar un análisis estadístico de cada campo (ejecutar las
correspondientes sentencias SQL para comprobar):

- 12 -

¿Tiene algún valor nulo? Si no hay ningún nulo, poner una restricción not null.

¿Tiene un valor diferente para cada fila, es decir, es un campo único? En tal caso, se
podría valorar poner una restricción unique.

Si es un campo numérico, calcular el valor mínimo y máximo. Con los resultados
podemos tomar alguna decisión, por ejemplo: si no hay valores negativos, ni tiene
sentido que los haya según la naturaleza del campo, poned una retricción check para
solo admitir valores positivos.

Si es un campo con una lista de valores acotada (p. ej. currentuse). Obtener la lista de
valores y cantidad de cada uno de ellos (en este caso tiene 6 valores textuales diferentes
y también el valor nulo en 10 filas). Ejemplo:

En este caso aplicaremos una restricción check con la lista de valores. Otra solución
(que aplicaremos en la capa del SIOSE con los campos codiige y hilucs, sería crear una
tabla detalle y aplicar una restricción de integridad referencial.

Aplica con la orden ALTER las correspondientes restricciones que crees que necesitan
tus datos.

IMPORTATE: No olvides copar en la memoria todo el SQL que vayas utilizando, como el
SQL para avergiguar si hay valores nulos, si son únicos, etc. y la creación de tablas,
inserción, índices, y adición de restricciones.

5. Esquema 2: Comprobaciones de propiedades geométricas,
validez y magnitud mínima permitida de longitud o superficie.
Aplicable a Todas las capas.
Antes de empezar este apartado, debes de haber cargado ya en jcm2 todas las capas, y las
dos tablas alfanuméricas. Debes de haber aplicado las correspondientes restricciones y haber
hecho un pequeño estudio de los valores de cada campo.

Ahora, vamos a pasar a comprobar algunas propiedades geométricas según el modelo del
OGC, y que nos ayudará a comprender también el estado y estructura de nuestras geometrías.

Para cada una de las capas espaciales, comprueba con las correspondientes sentencias SQL lo
siguiente:

- 13 -

5.1.- Cuantos elementos no sencillos hay en cada capa lineal.
Si hay algún elemento no sencillo, localízalo en QGIS (a través de su gid) y trata de averiguar
la razón. Si es un elemento lineal que tiene algún lazo, es un elemento sospechoso y debería
ser editado para ser convertido a un elemento multilinestring sencillo.

5.2.- Cuantos polígonos no válidos hay en tus capas superficiales.
Si hay algún polígono no válido localízalo en QGIS para ver la razón de no validez de forma
gráfica, y luego utiliza la orden ST_MakeValid de PostGIS para corregirlo.

5.3.- Dimensiones mínimas (longitud, superficie).
Según la escala de tu cartografía (puedes comprobar la escala en la información que te da el
IGN o Catastro al descargar los datos), ¿qué longitud mínima sería admisible? Si la escala es
1:5000, la precisión topográfica como sabemos es de 5000x0.2 mm = 1 m. Por lo tanto,
cualquier línea inferior a digamos a 1 m., o si queremos tomar un margen de seguridad,
inferior a la mitad, es decir, 0.5m sería un error. Tales líneas deberían ser analizadas, y o bien
borradas, o bien fundidas en el elemento lineal al que conectan. Lo mismo, con los polígonos, a
una escala 5000, cualquier superficie inferior a 0.5m2 se podría considerar como error, y se
debería analizar.

Obtén un listado de los gid de las geometrías de las capas lineales cuya longitud sea

inferior a esta tolerancia. Haz lo mismo con el área de las geometrías de las capas poligonales.

5.4.- Geometrías Multi.
Si tus capas son de tipo muti, es decir, multilinestring o multipolygon, sería interesante
obtener un listado como el de la imagen de abajo, donde aparecen cuantas geometrías
sencillas contiene cada geometría multi. Esto puede darte una idea de la complejidad de tus
datos, ya que geometrías multi con más de un elemento, suelen ser geometrías más difíciles
de analizar.

Ejemplo con la capa buildings. Vemos que hay por ejemplo 29 multipolígonos que están
formados por 5 polígonos. El operador ST_NumGeometries (geom) devuelve el número de
geometrías integrantes de una geometría de tipo multi.

5.5.- ¿Se te ocurre algún tipo más de comprobación de las propiedades de las
geometrías? Si es así, pon el SQL y los resultados.

- 14 -

6. Esquema 2: Adición de restricciones de tipo check sobre
campos de geometría
Además de las restricciones check de tipo semántico sobre los campos de atributos, que
hemos visto para mantener la integridad de una lista de posibles valores de un campo o unos
valores mínimos o máximos, también podemos aplicar restricciones de tipo check a una
columna de geometría para, por ejemplo:

- Permitir únicamente aquellas geometrías mayores de una longitud, o superficie.
Estableciendo así una magnitud mínima por debajo de la precisión topográfica, por debajo de
la cual no tiene sentido que existe un objeto geográfico.

- Permitir únicamente geometrías poligonales válidas. Si se intenta introducir un polígono no
valido, el sistema no dejará, ya que se violará la restricción check.

- Permitir únicamente geometrías simples, especialmente útil para capas de líneas.

Trata de agregar estas condiciones (con sus correspondientes sentencias ALTER) a una o
varias capas de jcm2, y después intenta actualizar alguna geometría existente, o crear alguna
nueva que no cumple estas condiciones. Compruébalo con QGIS, haz pantallazos de QGIS en la
memoria con lo que sucede.

¿Se te ocurre alguna otra restricción geométrica que puedes establecer en una columna de
geometría y tenga sentido?

Esquema para el análisis espacial: jcm3

7. Esquema 3: Comprobaciones o reglas topológicas
Las comprobaciones o reglas topológicas son relaciones espaciales no permitidas por nuestro
modelo de datos o nuestros propios criterios sobre el comportamiento de nuestra cartografía.
Por ejemplo, no puede haber dos edificios que se solapen en la capa buildings, o no puede
haber una geometría de tramovial que interseque a un edificio.

No son nada 'raro', en realidad no son más que consultas espaciales, pero que tienen como
objetivo encontrar problemas en nuestra cartografía, siempre siguiendo las directrices de
nuestro modelo de datos. Ya que, el modelo es quien nos debe decir si se permite, por
ejemplo, el solape entre dos edificios o no.

7.1 Repaso y resumen sobre las reglas topológicas
Lo hemos visto todo en los módulos y las prácticas de la asignatura, pero como resumen
vamos a hacer un ejemplo. El resultado de estas comprobaciones topológicas como cualquier
consulta espacial puede ser mediante:

7.1.1 Mediante tablas alfanuméricas
Una simple tabla alfanumérica sin componentes espacial, con al menos los identificadores de
las geometrías (gid) que no cumplen la condición diseñada.

- 15 -

Por ejemplo, obtener los polígonos que se solapan de la tabla ttmmbis, utilizada en un
ejercicio similar en la práctica 10 del módulo 10.

create table jcm3.solapes1 as

select t1.gid as gid1, t2.gid as gid2, t1.nombre as nombre
  from ttmmbis t1, ttmmbis t2
  where (  st_overlaps (t1.geom, t2.geom ) or
         st_covers (t1.geom, t2.geom) or

  st_covers (t2.geom, t1.geom) ) and t1.gid <> t2.gid;

Esta tabla daría los siguientes resultados en la capa ttmmbis original:

7.1.2 Mediante tablas espaciales
Una tabla espacial: Si además queremos ver de forma gráfica con un SIG de escritorio las
geometrías implicadas entonces crearemos una tabla o una vista espacial que será similar a la
consulta anterior, pero añadiendo el campo de geometría y la cargaremos con QGIS para
realizar las correspondientes comprobaciones.

create table jcm3.solapes2 (gid serial primary key, gid1 integer, gid2
integer, nombre varchar, geom geometry (multipolygon, 23030));

insert into jcm3.solapes2 (gid1, gid2, nombre, geom)
select t1.gid, t2.gid, t1.nombre, t1.geom
  from ttmmbis t1, ttmmbis t2
  where ( st_overlaps (t1.geom, t2.geom) or
          st_covers (t1.geom, t2.geom) or

  st_covers (t2.geom, t1.geom) ) and t1.gid <> t2.gid;

Evidentemente, si modificamos alguna geometría de la tabla ttmmbis, y queremos volver a
comprobar los solapes deberemos volver a ejecutar las sentencias anteriores.

7.1.3 Mediante vistas alfanuméricas o espaciales
Una vista alfanumérica o una vista espacial: Con las vistas podemos obtener siempre los
solapes actualizados, aunque cambie la capa ttmmbis, ya que al consultar una vista se ejecuta
automáticamente la consulta (select) utilizada en su creación.

La transformación de la tabla alfanumérica de 1.1.1 o de la tabla espacial de 1.1.2 en vistas
es inmediato. Aunque si la vista espacial aplica algún operador espacial sobre la geometría de
la tabla original como es el caso de la práctica 2 del módulo 9, entonces habrá que aplicar un
cast explícito como se hace en dicho ejercicio.

- 16 -

Ejemplo de vista espacial:

create view jcm3.solapes4 as

select t1.gid as gid1, t2.gid as gid2, t1.nombre, t1.geom
  from ttmmbis t1, ttmmbis t2
  where ( st_overlaps (t1.geom, t2.geom) or
          st_covers (t1.geom, t2.geom) or

  st_covers (t2.geom, t1.geom) ) and t1.gid <> t2.gid;

La vista solapes4, la podemos cargar en QGIS, seleccionando un campo identificador único de
forma manual. En este caso la combinación de los campos gid1 y gid2 será nuestro
identificador único, según hicimos en la práctica 7 del módulo 9.

Ventajas e inconvenientes de las vistas:

Como siempre, la ventaja de la vista es que mostrará en tiempo real cualquier cambio que se
produzca entre las geometrías de las capas analizadas, pero por contra cada vez que hagamos
un zoom, o nos movamos en QGIS, o abramos la tabla de atributos en QGIS, la vista
ejecutará su select asociado y por lo tanto son mucho más lentas que una tabla, e incluso
podríamos tener problemas en este sentido si las capas analizadas son de gran tamaño.

Por tanto, si la capa de ttmmbis fuera un poco más grande, o incluso no quiesieramos esperar
los varios segundos que tarda ahora el select de la vista, lo normal sería realizar una tabla
espacial, y de vez en cuando actualizarla, borrando previamente todos los registros (delete *
from solapes), y volviendo a realizar el insert into.

7.1.4 Variación del ejercicio anterior mediante agrupación
Si nos fijamos, un mismo polígono de ttmmbis puede presentar solapes con varios polígonos
de alrededor.

Puedes comprobarlo, editando un polígono de ttmmbis en QGIS y moviéndolo ligeramente
para que solape a varios de su alrededor.

En este caso hemos movido ligeramente el ttmm con gid = 170.

En tal caso, las consultas anteriores tendrán varias filas para un mismo polígono, es decir, el
gid1 se repetirá, y si son capas o vistas espaciales entonces aparecerán varios polígonos unos
encima de otros.

- 17 -

Una variación sería pues realizar una agrupación por t1.gid, y de esta forma solo habría una
fila en la tabla/vista resultante por cada polígono de ttmmbis. En los campos de dicha tabla,
como sabemos no podemos conservar ningún campo de t2, como el t2.gid, a no ser que
utilicemos agregados como min, max, count, etc.

Con la agrupación obtendríamos un resultado similar a este. Además, hemos utilizado un
nuevo agregado, array_agg que convierte los datos pasados como argumento a una lista de
PostgreSQL. La conversión explícita:: varchar, es para que aparezca correctamente en la tabla
de atributos de QGIS, ya que QGIS no entiende el tipo de listas de PostgreSQL. En forma de
vista, el SQL sería:

create view jcm3.solapes5 as
select t1.gid as gid, count(t2.gid) as nsolapes,

array_agg(t2.gid)::varchar as listasolapes, t1.geom as geom

  from ttmmbis t1, ttmmbis t2
  where ( st_overlaps (t1.geom, t2.geom) or
          st_covers (t1.geom, t2.geom) or

  st_covers (t2.geom, t1.geom) ) and t1.gid <> t2.gid

  group by t1.gid;

Si la finalidad es visualizar los datos en un SIG, desde luego es mejor utilizar una agrupación y
evitar tener varias filas con la misma geometría.

7.1.5 Obtención de las intersecciones de los solapes (hacer previamente módulo 10)
Por último, puede ser interesante que esa capa o vista espacial no contenga los polígonos que
se superponen, sino que contenga las zonas de solapes en sí mismas, es decir, la intersección
de dos polígonos, y para esto debemos utilizar además el operador ST_Intersection.

De esta forma, podemos utilizar esos polígonos resultantes de las intersecciones para arreglar
esos solapes, por ejemplo, eliminando esa zona de intersección de a uno de los dos polígonos
implicados (ST_Difference). Como curiosidad, la regla topológica de ArcGIS "Must not overlap"
muestra una capa de errores topológicos con dichas intersecciones.

En este caso, no utilizaríamos agrupaciones, ya que las geometrías resultantes de la
intersección que será lo que almacenaremos en la capa/vista, son diferentes para cada uno de
los casos repetidos de gid=170.

- 18 -

Este ejercicio re resolvió en la práctica 10 del módulo 10. En dicha práctica se creó una tabla
espacial, se utilizó las funciones stx_extract y st_intersection, según el vídeo de
"operadoresespaciales" de obligada visión de la práctica 1 del mismo módulo. En este ejemplo
vamos a crear una vista en lugar de una tabla espacial.

create view solapes6 as
select t1.gid as gid1, t2.gid as gid2,
  t1.nombre as nombre1, t2.nombre as nombre2,
stx_extract (st_intersection(t1.geom,t2.geom),2)::geometry (multipolygon,23030) as geom
from ttmmbis t1, ttmmbis t2
where ( st_overlaps (t1.geom, t2.geom) or
          st_covers (t1.geom, t2.geom) or

  st_covers (t2.geom, t1.geom) ) and t1.gid < t2.gid;

Si no entiendes por qué se utiliza la conversión explícita ::geometry en el campo geom, repasa
la práctica 2 y la práctica 4 del módulo 9.

Nota: Fíjate como al poner t1.gid < t2.gid, en lugar de '<>', deja solo una de las dos parejas. Si
mirar las tablas del apartado 1.1.4, verás que las parejas están repetidas, por ejemplo, la 170
con la 135, y a su vez la 135 con la 170. Evidentemente, ambas combinaciones producen la
misma intersección, ya que el operador ST_Intersection es conmutativo, por lo cual poniendo
únicamente el operador lógico < o el >, eliminados estas parejas repetidas.

7.2 Reglas topológicas propuestas en el proyecto:
Si has repasado el resumen del apartado anterior, te darás cuenta que la forma de hacer la
regla de topología depende del resultado final buscado, puede ser solo una tabla alfanumérica,
una tabla o una vista, y además como columna de geometría se puede utilizar:

a)  Una selección de las geometrías de la/s capa/s originales (ttmmbis) que incumplen dicha

regla de topología.

- 19 -

b)  las nuevas geometrías obtenidas a partir de las intersecciones de los solapes entre los
polígonos. En el caso es necesario haber estudiado el módulo 10 donde se explican las
intersecciones de geometrías.

Todo depende de lo que el usuario analista de cartografía, que eres tú, está buscando y de tu
imaginación. Algunas reglas topológicas que puedes crear para tu proyecto son:

7.2.1 Los edificios bulding no pueden intersecar con los viales (tramovial).
Se pide obtener una capa/vista de entidades lineales que representen las intersecciones entre
ambas capas. Es hasta normal que encuentres algún vial que interseca a algún edificio, si no es
así, coge QGIS y modifica algún vial para que interseque a un edificio y al refrescar la capa de la
regla en QGIS veas el resultado.

Después de haber creado la regla anterior, en un segundo ejercicio, trata de modificar la vista
anterior, para que incluya un campo que contenga la longitud de la línea. Habrá que tener
especial cuidado con aquellos errores cuya longitud sea superior a la precisión topográfica.

Nota: Como se explica en el apartado 1.2, el alumno puede optar porque a) esa tabla/vista
muestra una selección de aquellos edificios o aquellos tramos que intersecan, o si ha estudiado
el módulo 10, puede también optar por b) crear una tabla/vista de entidades lineales que
representen esas intersecciones (st_intersection) de las geometrías de las dos capas.

7.2.2 No puede haber tramos de vial que se crucen
La conectividad de los tramos por los contornos no se debe considerar como error) con otros
tramos de vial de la misma capa. Según nuestro modelo de datos donde se cruzan dos tramos
debería haber una división de tramos, es decir, las geometrías deberían estar partidas en
dichos cruces.

- 20 -

La tabla/vista contendrá una a) selección de aquellos viales que se crucen o b) los puntos de
intersección entre dichos objetos geográficos.

7.2.3 Otras reglas
¿Se te ocurre alguna otra regla que sea diferente a las dos anteriores?  Si es así, escribe el
SQL, y describe su significado. Pruébala con QGIS.

8. Esquema 3: Otras consultas espaciales
Ejemplos de consultas sobre las capas disponibles. Se valorará realizar otro tipo de consultas
que las mostradas aquí.

 ¿Cuántas parcelas (cadastralparcel) tienen algún edificio (building) en su

8.1. -
interior?

¿Cuantas parcelas no tienen ningún edificio (building) en su interior (hazlo sin utilizar
un group by)?

¿Cuál es la referencia catastral (gml_id) de la parcela que tiene más edificios (building)
en su interior?

8.2.- ¿Cuantos edificios aislados (building) hay?
Vamos a considerar que un edificio es aislado cuando no tienen ningún otro edificio en un
radio de 100 metros.

Nota: En lugar de utilizar la expresión "ST_Distance (geom1, geom2) < 100", utiliza la
expresión "ST_DWithin (geom1, geom2, 100)" que significa lo mismo, pero utiliza de forma
correcta la indexación espacial porque la función ST_Distance no la utiliza y la consulta puede
tardar muchísimo en ejecutarse.

8.3.- Area total de edificios por tipo de suelo.
Muestra una tabla donde aparezca al área total de edificios (buildings) por tipo de suelo
(siose_pol, campo codiige de SIOSE). Muestra solo los 5 tipos de suelo con más área.

Modificación del consulta anterior para que devuelva un campo extra con la descripción del
tipo de suelo (tabla jcm2.siose_codiige, campo descripcion).

Nota: Si no sabes cómo hacerlo con una única consulta, siempre puedes guardar el resultado
de la tabla del ejercicio anterior en una tabla nueva en jcm3 y realizar una concatenación
entre la nueva tabla y jcm2.codiige.

- 21 -

8.4. Building y buildingpart
Los edificios (building) se componen de diferentes partes (buildingpart) que representan
diferencias de volúmenes catastrales. La capa buildingpart tiene dos campos de atributos
numberoffloorsaboveground y numberoffloorsbelowground que representan alturas sobre el
terreno (pisos) y por debajo del terreno (sótanos).

La relación entre building y buildingpart aparece de forma alfanumérica entre los campos
gml_id de building y gml_id de buildingpart, para ello se agrega un sufijo _part1, _part2, etc.
según el número de parte de ese edificio en el campo gml_id de buildingpart. Ejemplo:

Nota: Puedes tener toda la información del modelo de edificios de catastro consultando las
especificaciones de datos de INSPIRE para edificios, como se comentó cuando realizaste la
descarga e importación de este conjunto de datos.

Para comparar que el campo gml_id de buildingpart se refiere al mismo building utiliza la
función SQL "left", de esta forma la relación entre las tablas podría ser: "left
(gml_id_de_buildingpart, 25) = gml_id_de_building". Consulta la ayuda de PostgreSQL sobre
left sino puedes intuir su significado.

Con esto dicho, se pide la siguiente consulta:

Muestra el gml_id de los cinco edificios (building) con mayor volumen de todos sus
sótanos (numberoffloorsbelowground > 0). Para todas las partes (buildingpart) del edificio,
deberás realizar un sumatorio del área y multiplicarlo por el "número de pisos bajo rasante"
x 2.5 (consideramos una constante de 2.5 metros por piso).

- 22 -

8.5.- Consultas propuestas por el estudiante
Tras resolver las consultas anteriores, se propone al alumno que realice algunas otras
consultas diferentes a las anteriores, es decir, que no sean las mismas, aunque se utilicen otras
capas.

9.- Esquema 3: Ejercicio de análisis espacial
Se trata de la localización de una zona del municipio, o una parcela catastral, un edificio, etc.
que cumpla una serie de características, según unas necesidades determinadas para la
localización óptima de una infraestructura, p. ej. Vertedero, central nuclear, urbanización, etc.

El trabajo se le encarga al técnico de SIG y debe de dar las posibles soluciones. De forma
clásica, este tipo de análisis se resuelve con un SIG de escritorio, pero la potencia de PostGIS
nos permite resolverlo de forma más eficaz, y sobre todo con un SQL que podemos reutilizar o
volver a ejecutar para actualizar los resultados si cambia nuestra cartografía inicial o incluso los
parámetros iniciales del análisis.

Ejemplo (no realizarlo igual que este ejemplo, es solo una muestra de la complejidad del
ejercicio de análisis espacial que se pide):

Un cliente encarga a una inmobiliaria la posible búsqueda de una vivienda en el municipio
para una posible compra.

- El área del edificio debe ser como el 40% o menos del área de la parcela catastral en la que
se encuentra. La parcela catastral debe ser superior a 700 m2
- Debe ser un edificio sencillo, es decir, con 3 o menos partes (buildingpart).
- El cliente quiere mucha tranquilidad y no desea que haya ningún edificio a menos de 200
metros por lo menos.
- Al cliente le gusta mucho la naturaleza, y exige que el edificio esté a menos de 200 metros
áreas de Bosques, pastizales, matorral o combinación de vegetación,
- El cliente no quiere problemas con las avenidas y desea que vivienda esté a más de 200
metros de cualquier cauce fluvial.
- La distancia respecto a suelos de tipo 'caso' o 'ensanche' debe ser superior a 1000 metros.
El alumno deberá diseñar un análisis similar, e irá almacenando los resultados de cada una de
las condiciones en diferentes capas o vistas espaciales, en el esquema jcm3.

10. Esquema 3: Otros ejercicios de análisis espacial propuestos
En esta sección el alumno puede completar el análisis espacial con otras técnicas no utilizadas
anteriormente, vistas en clase, o investigadas por el mismo.

10.1. Ejemplo: Reglas SQL en VISTAS
Crear reglas de inserción y actualización, para actualizar un campo area con el valor del área
de la geometría (st_area). Para ello, se elegirá una capa de polígonos de jcm2, se añadirá un
campo area de tipo double precision, y se crearán las reglas correspondientes.

Para actualizar el campo area la primera vez, se obligará al sistema a ejecutar una orden
UPDATE sobre todas las filas, para de esta forma se ejecute la regla de actualización y se
modifique el valor del área.

- 23 -

A continuación, desde QGIS, se actualizará la geometría de algún polígono, y se verá como el
valor de área del campo de atributos cambia de forma automática. Se insertará también un
nuevo polígono y se comprobará de nuevo el valor del área.

Se debe aportar el código completo de modificación de la tabla original, reglas y en la
memoria deben aparecer las pruebas realizadas.

10.2 Disparadores
Creación de disparadores para actualización automáticas de campos o validación de
condiciones espaciales entre capas.

Nota valoración esquema 3.

Se valorará especialmente cuando los ejemplos aportados sean distintos a los expuestos en
esta memoriía, es decir, reglas de topología diferentes (apartado 1.2), ejemplos de consultas
espaciales diferentes (apartado 2), ejercicio completo de análisis espacial (diferente al del
apartado 3), y reglas SQL y disparadores (apartado 4) diferentes a los vistos en esta memoria o
en clase.

- 24 -

