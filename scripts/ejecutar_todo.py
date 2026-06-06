import os
import sys
import time
import subprocess
from datetime import datetime
from pathlib import Path

# Carpeta raíz del proyecto (padre de scripts/)
ROOT = Path(__file__).resolve().parent.parent

# Configurar path para importar config.py y leer CODIGO_MUNICIPIO
sys.path.append(str(ROOT / "scripts"))
try:
    from config import CODIGO_MUNICIPIO
except ImportError:
    CODIGO_MUNICIPIO = "unknown"

# Asegurar que la carpeta de resultados existe
RESULTADOS_DIR = ROOT / "resultados"
RESULTADOS_DIR.mkdir(exist_ok=True)

# Crear archivo de log con el formato solicitado
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
log_path = RESULTADOS_DIR / f"{CODIGO_MUNICIPIO}_{timestamp}.txt"

# Lista de scripts a ejecutar en orden
SCRIPTS = [
    ROOT / "scripts" / "descargas.py",
    ROOT / "scripts" / "generar_metadata.py",
    ROOT / "scripts" / "inicializar_db.py",
    ROOT / "scripts" / "importar_jcm1.py",
    ROOT / "scripts" / "procesar_jcm2.py",
    ROOT / "scripts" / "ejecutar_consultas_calidad.py",
    ROOT / "scripts" / "procesar_jcm3.py",
]

def run_script(script_path, log_file):
    script_name = script_path.name
    print(f"\n=====================================================================")
    print(f">>> INICIANDO: {script_name} ...")
    print(f"=====================================================================")
    
    header = f"\n=== SCRIPT: {script_name} | INICIO: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===\n"
    log_file.write(header)
    log_file.flush()
    
    start_time = time.time()
    
    # Ejecutar el script usando el mismo intérprete de Python en un subproceso
    # Usamos -u para salida sin búfer y stdin heredado para interactividad
    process = subprocess.Popen(
        [sys.executable, "-u", str(script_path)],
        stdin=None,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        bufsize=1
    )
    
    # Leer e imprimir la salida del script en tiempo real carácter por carácter
    # para evitar bloqueos cuando se solicita entrada de usuario.
    while True:
        char = process.stdout.read(1)
        if not char:
            break
        sys.stdout.write(char)
        sys.stdout.flush()
        log_file.write(char)
        log_file.flush()
        
    process.wait()
    elapsed = time.time() - start_time
    
    footer = f"\n=== SCRIPT: {script_name} | FIN | DURACIÓN: {elapsed:.2f}s | CÓDIGO DE RETORNO: {process.returncode} ===\n"
    log_file.write(footer)
    log_file.flush()
    
    if process.returncode != 0:
        print(f"\n[ERROR] El script {script_name} falló con código {process.returncode}. Abortando pipeline.")
        return False
        
    print(f"[OK] {script_name} finalizó con éxito en {elapsed:.2f} segundos.")
    return True

def main():
    print("=====================================================================")
    print("ORQUESTADOR DE PIPELINE POSTGIS: AUTOMATIZACIÓN MUNICIPAL")
    print(f"Municipio: {CODIGO_MUNICIPIO} | Reporte: resultados/{log_path.name}")
    print("=====================================================================")
    
    pipeline_start = time.time()
    
    with open(log_path, "w", encoding="utf-8") as log_file:
        log_file.write("=====================================================================\n")
        log_file.write("REPORTE DE EJECUCIÓN DEL PIPELINE COMPLETO\n")
        log_file.write(f"Municipio: {CODIGO_MUNICIPIO}\n")
        log_file.write(f"Fecha Inicio: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        log_file.write("=====================================================================\n")
        log_file.flush()
        
        for idx, script in enumerate(SCRIPTS, 1):
            if not script.exists():
                err_msg = f"[ERROR] El script requerido no existe: {script}\n"
                print(err_msg)
                log_file.write(err_msg)
                sys.exit(1)
                
            success = run_script(script, log_file)
            if not success:
                log_file.write(f"\n[PIPELINE ABORTADO] Falló en el paso {idx}: {script.name}\n")
                log_file.flush()
                sys.exit(1)
                
        total_elapsed = time.time() - pipeline_start
        summary_header = "\n=====================================================================\n"
        summary_body = f"[PIPELINE EXITOSO] El flujo completo finalizó en {total_elapsed:.2f} segundos.\n"
        summary_footer = "=====================================================================\n"
        
        print(summary_header + summary_body + summary_footer)
        log_file.write(summary_header + summary_body + summary_footer)
        log_file.flush()

if __name__ == "__main__":
    main()
