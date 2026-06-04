import sys
import time
from pathlib import Path
import numpy as np
import pypdfium2 as pdfium
from rapidocr_onnxruntime import RapidOCR

# Carpeta raíz del proyecto
ROOT = Path(__file__).resolve().parent.parent

RAW_DIR = ROOT / "fuentes_sql"
OUT_DIR = ROOT / "sql"

# Crear directorio de salida si no existe
OUT_DIR.mkdir(exist_ok=True)

def main():
    print("=====================================================================")
    print("CONVERTIDOR DE FUENTES SQL (PDF ESCANEADOS A MARKDOWN)")
    print("=====================================================================")
    
    start_time = time.time()
    
    print("Inicializando el motor OCR (RapidOCR)...")
    try:
        engine = RapidOCR()
    except Exception as e:
        print(f"[ERROR] No se pudo inicializar el motor OCR: {e}")
        sys.exit(1)
        
    # Listar y ordenar PDFs para procesar
    archivos_pdf = sorted([p for p in RAW_DIR.iterdir() if p.suffix.lower() == ".pdf"])
    
    if not archivos_pdf:
        print(f"No se encontraron archivos PDF en {RAW_DIR}")
        sys.exit(0)
        
    print(f"Se encontraron {len(archivos_pdf)} archivos PDF para procesar.")
    
    for idx, archivo in enumerate(archivos_pdf, 1):
        print(f"\n[{idx}/{len(archivos_pdf)}] Procesando: {archivo.name}")
        file_start = time.time()
        
        try:
            pdf = pdfium.PdfDocument(str(archivo))
            num_pages = len(pdf)
            markdown_content = []
            
            for page_idx in range(num_pages):
                page = pdf.get_page(page_idx)
                bitmap = page.render(scale=2)
                pil_img = bitmap.to_pil()
                img_np = np.array(pil_img)
                
                result, _ = engine(img_np)
                
                page_text = []
                if result:
                    for box, text, score in result:
                        page_text.append(text)
                
                page_content = "\n".join(page_text)
                markdown_content.append(f"## Página {page_idx + 1}\n\n{page_content}\n")
                page.close()
            
            salida = OUT_DIR / f"{archivo.stem}.md"
            salida.write_text("\n".join(markdown_content), encoding="utf-8")
            
            file_elapsed = time.time() - file_start
            print(f"OK -> {salida.name} ({file_elapsed:.2f}s, {num_pages} páginas)")
            pdf.close()
            
        except Exception as e:
            print(f"ERROR al procesar {archivo.name}: {e}")
            
    total_elapsed = time.time() - start_time
    print("\n=====================================================================")
    print(f"Conversión finalizada en {total_elapsed:.2f} segundos.")
    print("=====================================================================")

if __name__ == "__main__":
    main()
