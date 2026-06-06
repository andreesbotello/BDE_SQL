import sys
import psycopg2
from pathlib import Path
import datetime

# Setup paths
SCRIPTS_DIR = Path(__file__).resolve().parent
sys.path.append(str(SCRIPTS_DIR))

from config import DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME

SQL_FILE = SCRIPTS_DIR / "consultas_control_calidad.sql"
OUTPUT_FILE = SCRIPTS_DIR.parent / "temp" / "reporte_resultados_calidad.md"

def ejecutar_consultas():
    print("=====================================================================")
    print("EJECUTANDO CONSULTAS DE CONTROL DE CALIDAD Y GENERANDO REPORTE")
    print("=====================================================================")

    if not SQL_FILE.exists():
        print(f"[ERROR] No se encuentra el archivo SQL: {SQL_FILE}")
        sys.exit(1)

    with open(SQL_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    # Split the file into blocks based on "-- ["
    blocks = content.split("-- [")
    query_blocks = []
    
    for block in blocks:
        if not block.strip():
            continue
        # Format of block:
        # KEY] Title
        # SQL query...
        if "]" in block:
            header, sql_part = block.split("]", 1)
            key = header.strip()
            # Split lines of sql_part to find title in first line
            sql_lines = sql_part.strip().splitlines()
            title = ""
            if sql_lines:
                title = sql_lines[0].replace("--", "").strip()
                sql_lines = sql_lines[1:]
            query = "\n".join(sql_lines).strip()
            # Remove any trailing semicolons or comments
            if query:
                query_blocks.append({
                    "key": key,
                    "title": title,
                    "query": query
                })

    conn = None
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME
        )
        cur = conn.cursor()

        now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        markdown_lines = [
            "# Reporte de Resultados de Calidad de Datos (QA/QC)\n\n",
            f"**Fecha de generación:** {now_str}\n\n",
            "Este reporte contiene los resultados detallados de las consultas de control de calidad aplicadas al esquema de datos depurado `jcm2` y al esquema de origen `jcm1`.\n\n",
            "## Índice de Contenidos\n\n",
            "1. [Capa de Tramos Viales y Cursos de Agua No Simples](#1-elementos-no-simples)\n",
            "2. [Geometrías Inválidas en Origen y Razones de Invalidez](#2-geometrías-inválidas-en-origen)\n",
            "3. [Microgeometrías y Slivers Descartados](#3-microgeometrías-y-slivers-descartados)\n",
            "4. [Distribución del Número de Sub-geometrías en Elementos Multiparte](#4-distribución-del-número-de-sub-geometrías)\n",
            "5. [Auditorías de Integridad Propuestas (Nuevos Chequeos)](#5-propuestas-de-nuevos-controles-de-calidad)\n\n"
        ]

        for qb in query_blocks:
            key = qb["key"]
            title = qb["title"]
            query = qb["query"]

            print(f"Ejecutando {key}: {title}...")
            
            # Map key to custom section headers
            if key == "CONSULTA_1A":
                markdown_lines.append("## 1. Elementos No Simples\n\n")
                markdown_lines.append("### A. Tramos Viales no simples en `jcm1.tramovial` (dentro de área de estudio)\n\n")
            elif key == "CONSULTA_1B":
                markdown_lines.append("### B. Cursos de Agua no simples en `jcm1.tramocurso` (dentro de área de estudio)\n\n")
            elif key == "CONSULTA_2":
                markdown_lines.append("## 2. Geometrías Inválidas en Origen\n\n")
                markdown_lines.append("Detalle de las geometrías en `jcm1` que presentaban inconsistencias de validez y su correspondiente razón reportada por PostGIS/GEOS:\n\n")
            elif key == "CONSULTA_3":
                markdown_lines.append("## 3. Microgeometrías y Slivers Descartados\n\n")
                markdown_lines.append("Registros filtrados debido a que su área espacial es menor al límite establecido de 0.5 m²:\n\n")
            elif key == "CONSULTA_4":
                markdown_lines.append("## 4. Distribución del Número de Sub-geometrías\n\n")
                markdown_lines.append("Distribución del recuento de sub-geometrías por entidad en las capas finales (`jcm2`):\n\n")
            elif key == "PROPUESTA_5A":
                markdown_lines.append("## 5. Propuestas de Nuevos Controles de Calidad\n\n")
                markdown_lines.append("### A. Discrepancia mayor al 10% entre Superficie Catastral Declarada y Calculada por GIS\n\n")
            elif key == "PROPUESTA_5B":
                markdown_lines.append("### B. Partes de Edificios (`buildingpart`) Huérfanas (sin intersección con `building`)\n\n")

            # Execute query
            cur.execute(query)
            colnames = [desc[0] for desc in cur.description]
            rows = cur.fetchall()

            if not rows:
                markdown_lines.append("*No se encontraron registros que cumplan esta condición (0 registros).* \n\n")
            else:
                # Generate markdown table
                markdown_lines.append("| " + " | ".join(colnames) + " |\n")
                markdown_lines.append("| " + " | ".join(["---"] * len(colnames)) + " |\n")
                limit_rows = rows[:500]
                for row in limit_rows:
                    row_strs = []
                    for val in row:
                        if val is None:
                            row_strs.append("NULL")
                        elif isinstance(val, (int, float)) and not isinstance(val, bool):
                            if isinstance(val, float):
                                row_strs.append(f"{val:.4f}")
                            else:
                                row_strs.append(str(val))
                        else:
                            val_str = str(val)
                            # Escape pipe character in markdown table
                            val_str = val_str.replace("|", "\\|")
                            if len(val_str) > 80:
                                val_str = val_str[:77] + "..."
                            row_strs.append(val_str)
                    markdown_lines.append("| " + " | ".join(row_strs) + " |\n")
                
                if len(rows) > 500:
                    markdown_lines.append(f"\n*(Nota: Mostrados solo los primeros 500 de {len(rows)} registros totales)*\n")
                markdown_lines.append("\n")

        # Ensure temp folder exists
        OUTPUT_FILE.parent.mkdir(exist_ok=True)
        
        with open(OUTPUT_FILE, "w", encoding="utf-8") as out:
            out.writelines(markdown_lines)

        print(f"[OK] Reporte generado exitosamente en: {OUTPUT_FILE}")
        cur.close()
        conn.close()

    except Exception as e:
        print(f"[ERROR] Ocurrió un error al ejecutar consultas de control de calidad: {e}")
        if conn:
            conn.close()
        sys.exit(1)

if __name__ == "__main__":
    ejecutar_consultas()
