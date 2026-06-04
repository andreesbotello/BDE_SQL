import sys
from pathlib import Path
import psycopg2
from psycopg2 import sql
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
from config import DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME

def inicializar_base_datos():
    print("=====================================================================")
    print("INICIALIZADOR DE BASE DE DATOS Y ESQUEMAS POSTGIS")
    print("=====================================================================")
    
    # Ruta del archivo SQL con las sentencias de configuración
    scripts_dir = Path(__file__).resolve().parent
    sql_file_path = scripts_dir / "inicializar_db.sql"
    
    if not sql_file_path.exists():
        print(f"[ERROR] No se encuentra el archivo SQL de inicialización en: {sql_file_path}")
        sys.exit(1)
        
    # 1. Conectar a la base de datos por defecto 'postgres' para comprobar/crear la base de datos destino
    conn_pg = None
    try:
        print(f"Conectando a servidor PostgreSQL (db: 'postgres') en {DB_HOST}:{DB_PORT}...")
        conn_pg = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            database="postgres"
        )
        conn_pg.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cur_pg = conn_pg.cursor()
        
        # Verificar si la base de datos ya existe
        cur_pg.execute("SELECT 1 FROM pg_database WHERE datname = %s;", (DB_NAME,))
        exists = cur_pg.fetchone()
        
        if not exists:
            print(f"La base de datos '{DB_NAME}' no existe. Creándola...")
            # Usar psycopg2.sql para evitar inyecciones e identar de forma segura
            cur_pg.execute(sql.SQL("CREATE DATABASE {} OWNER {};").format(
                sql.Identifier(DB_NAME),
                sql.Identifier(DB_USER)
            ))
            print(f"[OK] Base de datos '{DB_NAME}' creada con éxito.")
        else:
            print(f"La base de datos '{DB_NAME}' ya existe.")
            
        cur_pg.close()
        conn_pg.close()
        
    except Exception as e:
        print(f"[ERROR] No se pudo comprobar o crear la base de datos: {e}")
        if conn_pg:
            conn_pg.close()
        sys.exit(1)

    # 2. Conectar a la base de datos del proyecto y ejecutar el archivo inicializar_db.sql
    conn_db = None
    try:
        print(f"\nConectando a la base de datos del proyecto '{DB_NAME}'...")
        conn_db = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME
        )
        conn_db.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cur_db = conn_db.cursor()
        
        # Leer y ejecutar el archivo inicializar_db.sql
        print(f"Leyendo y ejecutando sentencias de: {sql_file_path.name}...")
        with open(sql_file_path, "r", encoding="utf-8") as f:
            sql_queries = f.read()
            
        cur_db.execute(sql_queries)
        print(f"[OK] Sentencias de {sql_file_path.name} ejecutadas exitosamente.")
        
        cur_db.close()
        conn_db.close()
        
        print("\n=====================================================================")
        print(f"INICIALIZACIÓN COMPLETADA CON ÉXITO para la base de datos: {DB_NAME}")
        print("=====================================================================")
        
    except Exception as e:
        print(f"[ERROR] Fallo al ejecutar inicialización en la base de datos '{DB_NAME}': {e}")
        if conn_db:
            conn_db.close()
        sys.exit(1)

if __name__ == "__main__":
    inicializar_base_datos()
