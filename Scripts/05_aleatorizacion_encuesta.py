"""
=============================================================
ALEATORIZACIÓN DE ENCUESTAS DE CAMPO
Restaurantes Mediterráneos — Bogotá
=============================================================
Input  : Data/Raw/restaurantes_mediterraneos_bogota.xlsx
Output : Data/Raw/restaurantes_mediterraneos_bogota.xlsx
         (misma ruta, columna 'encuesta' añadida)

Lógica:
  - Solo considera filas con sample == 1
  - Por cada categoría de cocina, selecciona aleatoriamente
    al menos el 50% de los restaurantes (redondeo hacia arriba)
  - Asigna encuesta = 1 a los seleccionados, 0 al resto
  - Fija una semilla (SEED) para reproducibilidad

pip install pandas openpyxl
=============================================================
"""

import pandas as pd
import math
from pathlib import Path

# ─── RUTAS ────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
DATA_RAW_DIR = PROJECT_ROOT / "Data" / "Raw"

INPUT_XLSX  = DATA_RAW_DIR / "restaurantes_mediterraneos_bogota.xlsx"
OUTPUT_XLSX = INPUT_XLSX   # sobreescribe el mismo archivo

# ─── CONFIGURACIÓN ────────────────────────────────────────────────────────────
PROPORCION_MINIMA = 0.50   # mínimo 50% por categoría — ajusta si necesitas más
SEED              = 42     # semilla para reproducibilidad (cualquier entero fijo)
                           # cambia el número para obtener una asignación diferente

# ─── MAIN ─────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 55)
    print("  ALEATORIZACIÓN DE ENCUESTAS — CAMPO")
    print("=" * 55)

    if not INPUT_XLSX.exists():
        raise FileNotFoundError(f"Excel no encontrado:\n  {INPUT_XLSX}")

    df = pd.read_excel(INPUT_XLSX, engine="openpyxl")
    print(f"\n📋 Restaurantes cargados : {len(df)}")

    # Validar columnas requeridas
    for col in ["cocina", "sample"]:
        if col not in df.columns:
            raise KeyError(
                f"Columna '{col}' no encontrada.\n"
                f"Columnas disponibles: {list(df.columns)}"
            )

    # Inicializar columna encuesta en 0 para todos
    df["encuesta"] = 0

    # Filtrar solo los que están en el sample
    mask_sample = df["sample"] == 1
    df_sample   = df[mask_sample].copy()

    print(f"   En sample (sample=1)   : {len(df_sample)}")
    print(f"   Fuera de sample        : {(~mask_sample).sum()}")
    print(f"   Proporción mínima      : {PROPORCION_MINIMA*100:.0f}% por categoría")
    print(f"   Semilla aleatoria      : {SEED}")

    # ── Aleatorización por categoría ──────────────────────────────────────────
    print(f"\n{'─' * 55}")
    print(f"  {'Categoría':<15} {'Total':>6} {'Mínimo':>7} {'Asignados':>10}")
    print(f"{'─' * 55}")

    seleccionados_idx = []

    for cocina, grupo in df_sample.groupby("cocina"):
        total_cat = len(grupo)
        n_minimo  = math.ceil(total_cat * PROPORCION_MINIMA)  # redondeo hacia arriba

        # Selección aleatoria reproducible dentro del grupo
        seleccion = grupo.sample(n=n_minimo, random_state=SEED)
        seleccionados_idx.extend(seleccion.index.tolist())

        print(f"  {str(cocina):<15} {total_cat:>6} {n_minimo:>7} {n_minimo:>10}")

    print(f"{'─' * 55}")

    # Asignar encuesta = 1 a los seleccionados
    df.loc[seleccionados_idx, "encuesta"] = 1

    total_asignados = df["encuesta"].sum()
    print(f"\n  TOTAL asignados a encuesta : {total_asignados}")
    print(f"  % sobre el sample total    : {total_asignados/len(df_sample)*100:.1f}%")

    # ── Guardar Excel ──────────────────────────────────────────────────────────
    df.to_excel(OUTPUT_XLSX, index=False, engine="openpyxl")
    print(f"\n💾 Excel actualizado: {OUTPUT_XLSX}")

    # ── Resumen detallado ──────────────────────────────────────────────────────
    print(f"\n{'─' * 55}")
    print("  Resumen por categoría:")
    print(f"{'─' * 55}")

    resumen = (
        df[mask_sample]
        .groupby("cocina")["encuesta"]
        .agg(
            total        = "count",
            asignados    = "sum",
        )
        .assign(pct = lambda x: (x["asignados"] / x["total"] * 100).round(1))
    )
    resumen.columns = ["Total en sample", "Asignados encuesta", "% asignado"]
    print(resumen.to_string())

    # ── Lista de restaurantes asignados ───────────────────────────────────────
    cols_mostrar = [c for c in ["id", "nombre", "cocina", "barrio"] if c in df.columns]
    asignados_df = df[df["encuesta"] == 1][cols_mostrar].sort_values("cocina")

    print(f"\n{'─' * 55}")
    print(f"  Restaurantes asignados a encuesta ({len(asignados_df)}):")
    print(f"{'─' * 55}")
    print(asignados_df.to_string(index=False))
