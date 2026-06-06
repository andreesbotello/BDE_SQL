import os
import sys
from pathlib import Path
import psycopg2

# Configurar path para importar config.py
SCRIPTS_DIR = Path(__file__).resolve().parent
sys.path.append(str(SCRIPTS_DIR))

from config import DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME

SQL_FILE_PATH = SCRIPTS_DIR / "crear_vistas_calidad_jcm2.sql"

def crear_vistas_calidad():
    print("=====================================================================")
    print("CREADOR CONDICIONAL DE VISTAS DE AUDITORÍA GEOMÉTRICA (jcm2)")
    print("=====================================================================")

    if not SQL_FILE_PATH.exists():
        print(f"[ERROR] No se encuentra el archivo SQL: {SQL_FILE_PATH}")
        sys.exit(1)

    print(f"Leyendo {SQL_FILE_PATH.name}...")
    with open(SQL_FILE_PATH, "r", encoding="utf-8") as f:
        sql_content = f.read()

    conn = None
    try:
        print(f"Conectando a base de datos '{DB_NAME}' en {DB_HOST}:{DB_PORT}...")
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME
        )
        conn.autocommit = True
        cur = conn.cursor()

        print("Ejecutando bloque procedural dinámico PL/pgSQL para construir vistas condicionales...")
        # Capturar avisos del servidor PostgreSQL (como RAISE NOTICE)
        cur.execute(sql_content)
        
        # Imprimir avisos de PostgreSQL para dar visibilidad de qué vistas se crearon
        if conn.notices:
            for notice in conn.notices:
                print(f"  [DB] {notice.strip()}")
            # Limpiar lista de avisos para ejecuciones futuras
            conn.notices.clear()

        print("[OK] Creación condicional de vistas de calidad finalizada con éxito.")
        cur.close()
        conn.close()

    except Exception as e:
        print(f"[ERROR] Falló la creación de vistas condicionales: {e}")
        if conn:
            conn.close()
        sys.exit(1)

if __name__ == "__main__":
    crear_vistas_calidad()
