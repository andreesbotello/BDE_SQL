from pathlib import Path
from markitdown import MarkItDown

# Carpeta raíz del proyecto
ROOT = Path(__file__).resolve().parent.parent

RAW_DIR = ROOT / "fuentes_raw"
OUT_DIR = ROOT / "fuentes"

OUT_DIR.mkdir(exist_ok=True)

converter = MarkItDown()

for archivo in RAW_DIR.iterdir():

    if archivo.suffix.lower() != ".pdf":
        continue

    try:
        print(f"Procesando: {archivo.name}")

        resultado = converter.convert(str(archivo))

        salida = OUT_DIR / f"{archivo.stem}.md"

        salida.write_text(
            resultado.text_content,
            encoding="utf-8"
        )

        print(f"OK -> {salida.name}")

    except Exception as e:
        print(f"ERROR -> {archivo.name}")
        print(e)

print("Conversión finalizada.")