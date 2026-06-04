# Configuración global del proyecto de automatización PostGIS

# Código del municipio de estudio (5 dígitos).
# Modifique este valor para ejecutar todo el flujo del proyecto con otro municipio.
CODIGO_MUNICIPIO = "29051"
CODIGO_PROVINCIA = CODIGO_MUNICIPIO[:2]

# Datos descriptivos y técnicos asociados al municipio
NOMBRE_MUNICIPIO = "Estepona"
PROVINCIA = "Málaga"
SRID_PROYECTO = 25830

# Parámetros de conexión a la base de datos PostgreSQL
DB_HOST = "localhost"
DB_PORT = 5432
DB_USER = "postgres"
DB_PASSWORD = "TU_CONTRASEÑA_AQUI"
DB_NAME = "proyecto_final"