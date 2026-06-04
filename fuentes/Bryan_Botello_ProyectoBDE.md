1

Proyecto POSTGIS
Municipio de Estepona Málaga
Bryan Andrés Botello Sarmiento - babotsar@upv.edu.es

Universitat Politecnica de Valencia
Master universitario en ingeniería geomática y geoinformación

Contenido

2

1.
2.

2.1.
2.2.

Preparación de entorno QGIS .............................................................................................................. 2
Preparación de entorno para apoyo con inteligencia artificial de contexto .......................................... 3
Preparación de fuentes de contexto ............................................................................................ 3
Creación de archivo de contexto y metodología de trabajo ........................................................ 3
3.  Esquema 1: Importación ..................................................................... ¡Error! Marcador no definido.
Descarga de ficheros Buldings y Parcelas. ................................................................................. 3
Descarga de datos de Transporte. ............................................................................................... 3
Exploración inicial de los datos descargados.............................................................................. 4
Importación de los datos al esquema 1 (jmc1) ..................................................................................... 5
Importación de Parcelas y Construcciones ................................................................................. 5

3.1.
3.2.
3.3.

4.1.

4.

1.  Preparación de entorno QGIS

Para evaluar la calidad de las descargas de datos, es necesario evitar el filtrado de geometrías
no validas.

Además de la visualización de la tabla de atributos para elementos visibles unicament en el
mapa. Para optimizar y prevenir que el programa se cuelgue.

3

2.  Preparación de entorno para apoyo con inteligencia artificial de contexto

Adicionalmente  se  va  a  optar  por  observación  y  depurado  con  solo  muestras  para
posteriormente realizarlo con todo el volumen de datos apoyado con scripts de Python y SQL.

2.1. Preparación de fuentes de contexto

Primero,  nos  apoyamos  en  las  fuentes  del  instructivo  y  este  documento  en  desarrollo  en
formato  pdf.  Lo  procesamos  con  el  fichero  “convertir_fuentes.py”  con  la  librería
markitdown  que  se  ha  demostrado  reduce  el  consumo  de  tokens  al  pasar  las  fuentes  de
contexto de pdf a markdown (“.md”).

2.2. Creación de archivo de contexto y metodología de trabajo

Una vez tengamos los archivos fuente, es recomendable diseñar un archivo que permita

darle instrucciones persistentes al modelo. Generalmente llamado “README.md”.

3.  Descarga de datos

3.1. Descarga de ficheros Buldings y Parcelas.

Utilizando el fichero descargas.py se automatiza la descarga conociendo el URL de cada

uno.

https://www.catastro.hacienda.gob.es/INSPIRE/CadastralParcels/29/29051-

ESTEPONA/A.ES.SDGC.CP.29051.zip

3.2. Descarga de datos de Transporte.

Para esto se a realizado un proceso de automatización de descarga complejo, debido a que el
botón  de  descarga  de  https://centrodedescargas.cnig.es/CentroDescargas/informacion-
geografica-referencia no tiene un link directo, por el tema del licenciamiento de descarga.
Sin embargo, al realizar la descarda desde la “canasta de compra”, ha permitido descargar un

4

archivo con extensión . .jnlp, evaluando su funcionamiento se identificó que trabaja bajo el
lenguaje xml, que conecta con un pequeño programa de extensión .jar que trabaja con JAVA.
Al inspeccionar el programa notamos que lo único que hace es leer la licencia y reenviar al
centro de descargas con la licencia que me han otorgado.
URL de mi licencia:
https://centrodedescargas.cnig.es/CentroDescargas/generarFichero.do?codLicencia=LIGW
267074566
Respuesta de la URL:
http://ftpcdd.cnig.es/PUBLICACION_CNIG_DATOS_VARIOS/red_transporte/RT_MAL
AGA_shp.zip|67.83|9150739
Esta información por fin nos da la URL del archivo de descarga. Una vez identificamos el
descargable. Podemos automatizarlo.

3.3. Descarga información hidrográfica

Para poder automatizar la descarga de la información de cuenca hidrográfica, se descargo
toda la información comprendida en su pagina web, obteniendo las geometrías de las cuencas,
se procedió a calcular la envolvente de cada cuenca para obtener un polígono al cual se le
realizaron 3 buffers para determinar las áreas de influencia (10m servidumbre, 100m policía,
500m  general). Así obteniendo la información  del  municipio  y estas geometrías se  puede
determinar  que  se  descargue  únicamente  la  cuenca  de  interés.  Respecto  al  vinculo  de
descarga, se identifico de la misma forma que datos de transporte.
http://ftpcdd.cnig.es/PUBLICACION_CNIG_DATOS_VARIOS/hidrografia/DH_V0_ES0
91_Ebro.ZIP

3.4.Descarga información temática SIOSE

Continuando con el mismo procedimiento, se identificó y automatizo el vinculo de descarga.
 http://ftpcdd.cnig.es/SIOSE/SIOSE_2014/SIOSE_Andalucia_2014_GPKG.zip

3.5.Exploración inicial de los datos descargados

Descomprimiendo y revisando la información se obtiene la siguiente tabla para el Municipio
de Estepona.

Parcelas

Codificación  UTF-8

25830

Sistema  de
referencia
(SRS)

Edificios

ISO-8859-1

25830

Archivos

A.ES.SDGC.CP.29051.cadastralparcel.gml  A.ES.SDGC.BU.29051.building.gml

internos

A.ES.SDGC.CP.29051.cadastralzoning.gml
A.ES.SDGC.CP.MD.29051.xml

A.ES.SDGC.BU.29051.buildingpart.gml
A.ES.SDGC.BU.29051.otherconstruction.gml
A.ES.SDGC.BU.MD.29051.xml

Conteo
elementos

de

Parcelas Catastrales: 16.985
Zonificación Catastral: 1.594

Edificios: 11.758
Partes de edificios: 58.908
Otras Construcciones: 4.409

5

La  inclusión  de  estos  elementos  estructurales  en  los  archivos  cadastralparcel.gml,
building.gml y buildingpart.gml garantiza el cumplimiento de las directrices técnicas de las
Directivas  INSPIRE  para  la  armonización  de  datos  espaciales.  Al  integrar  campos
normativos como areaValue y localId para las parcelas catastrales, el uso actual (currentUse),
el  número  de  unidades  de  edificación  (numberOfBuildingUnits)  y  la  superficie  oficial
(officialArea/value) para los edificios, así como el número de plantas sobre y bajo rasante
(numberOfFloorsAboveGround  y  numberOfFloorsBelowGround)  en  las  partes  de  los
edificios,  los  conjuntos  de  datos  proporcionan  una  semántica  estandarizada  y  una
interoperabilidad transfronteriza total de acuerdo con las especificaciones de los temas de
Catastro (CP) y Edificios (BU) de INSPIRE.

4.  Importación de los datos al esquema 1 (jmc1)

4.1. Importación de Parcelas y Construcciones

Para aprovechar la librería GDAL, se va a hacer uso del Python que viene con la importación
de QGIS. Y haciendo uso de OSGeo4W Shell ejecutaremos los scripts. De tal manera que se
genera  el  fichero  que  automatiza  la  importación  de  la  información  de  los  comprimidos
denominado “importar_jcm1.py”.

Revisión en PgAdmin de la existencia de los datos.

6

5.  asds

