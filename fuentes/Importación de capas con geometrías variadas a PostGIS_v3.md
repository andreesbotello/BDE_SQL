Importación de capas con geometrías variadas a PostGIS

Contenido
Descripción del problema ............................................................................................................. 1

Soluciones ...................................................................................................................................... 2

SOLUCION 1 (QGIS): Herramienta que utiliza Gdal en Qgis ...................................................... 2

SOLUCION 2 (QGIS): Herramienta Guardar Como ... ................................................................ 3

SOLUCION 3 (GDAL): COMANDO MANUAL DESDE CONSOLA .................................................. 4

Descripción del problema
Algunas herramientas de QGIS como el importador desde el administrador de bases de datos puede
fallar cuando la capa original a importar sea GML, u otro formato como GEOPACKAGE que esté formada
por diferentes tipos de geometría (ej. filas con polígonos y multipolígonos). Dependiendo del municipio
elegido puede que os encontréis con este problema.

Ejemplo del error: importación desde el administrador de bases de datos de QGIS de una capa de
catastro buildings en formato GML que contiene polígnos y mutipolígonos.

Conclusión:  Los SIG de escritorio son una capa que facilita el trabajo, pero siempre es menos potente
que otras herramientas que, aunque más difícil de utilizar debemos tener conocimiento de ellas, por
ejemplo, PostGIS y los comandos de GDAL.

Soluciones
Este documento muestra tres formas diferentes para la importación que solucionan el problema
planteado.

La solución 1 o 2, indistintamente, son las recomendadas en la realización del proyecto.

La solución 3, quizás es la solución más potente, ya que utiliza directamente el comando GDAL de forma
manual, y explica todas sus opciones. La dejamos propuesta, como curiosidad, en el caso de que el
estudiante quiera profundizar en la importación utilizando un comando GDAL directamente.

SOLUCION 1 (QGIS): Herramienta que utiliza Gdal en Qgis
Ejecutamos la herramienta exportar a PostgreSQL que utilizará GDAL, incluso veremos al final de la
herramienta el comando GDAL utilizado que será similar a la solución 1 que hemos hecho de forma
manual.

Los parámetros de la herramienta serán los siguientes:

Al final del proceso debemos de ver el resultado de la ejecución:

SOLUCION 2 (QGIS): Herramienta Guardar Como ...
Otra solución consiste en utilizar el menú Exportar / Guardar como… de QGIS. Aunque no existe la
opción de guardar la capa en la base de datos PostGIS directamente, sino que la exportaremos a un
fichero sql, y luego cargaremos dicho fichero sql nosotros mismos.

Configura el diálogo de exportar como las imágenes superiores. La exportación creará el fichero
c:\tmp\building.sql en este caso que cargaremos en PostGIS desde el cliente psql:

psql –U postgres –f c:\tmp\bulding.sql proy

SOLUCION 3 (GDAL): COMANDO MANUAL DESDE CONSOLA
Utilizamos la librería de GDAL, con el comando ogr2ogr.exe para convertir de forma manual un fichero
GML a un fichero SQL de PostGIS. Este formato de salida se llama en  GDAL PGDump, y podéis consultar
las opciones de dicho formato en: https://gdal.org/drivers/vector/pgdump.html

Las opciones de dicho formato se pasan como argumentos en el comando ogr2ogr con la opción –lco.
De esta manera en el comando de abajo, especificamos todas las opciones que utilizamos en el
importador de QGIS más algunas extra:

El esquema de salida (schema=jcm1)

-
-  Que no cree el esquema porque ya lo tenemos creado (create_schema=off)
-
-
-  De paso que nos cree ya el índice espacial (SPATIAL_INDEX=GIST)

El nombre de la columna de geometría (geometry_name=geom)
El campo que utilizaremos como clave primaria, autonumérico (FID=gid)

Además, utilizamos las siguientes opciones del comando de GDAL, ogr2ogr.exe

https://gdal.org/programs/ogr2ogr.html

-f : especifica el formato de salida, PGDump en nuestro caso, para PostGIS
-nln building : especifica el nombre de la capa en PostGIS.
-nlt promoto_tu_multi : hace la MAGIA de convertir polígonos a multipolígonos con
solo un polígono integrante, solucionando nuestro PROBLEMA INICIAL.
-nlt multipolygon : especifica el tipo de geometría de la columna de geom a
multipoligonos.

C:\Users\Alumno\Downloads\A.ES.SDGC.BU.46137> c:\qgis\bin\ogr2ogr.exe -f PGDump
building.sql A.ES.SDGC.BU.46137.building.gml -lco schema=jcm1 -lco
create_schema=OFF -lco GEOMETRY_NAME=geom -lco FID=gid -lco
SPATIAL_INDEX=GIST -nln building1 -nlt promote_to_multi -nlt
multipolygon

Video en:

https://www.youtube.com/watch?v=XSGN5ELnOWk

