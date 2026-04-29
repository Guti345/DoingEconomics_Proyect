"""
=============================================================
ENRIQUECIMIENTO DE VARIABLE 'BARRIO' — SPATIAL JOIN
Restaurantes Mediterráneos — Bogotá
=============================================================
Recibe : Data/Raw/restaurantes_mediterraneos_bogota.csv
         Data/Raw/Barrios_Bogota/*.shp  (shapefile IDECA)

Produce: Data/Raw/restaurantes_mediterraneos_bogota.csv
         columna 'barrio' completada con nombre oficial

pip install geopandas pandas
=============================================================
"""

import pandas as pd
import geopandas as gpd
from pathlib import Path

# ─── RUTAS DEL PROYECTO ───────────────────────────────────────────────────────
SCRIPT_DIR   = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
DATA_RAW_DIR = PROJECT_ROOT / "Data" / "Raw"

INPUT_CSV   = DATA_RAW_DIR / "restaurantes_mediterraneos_bogota.csv"
BARRIOS_DIR = DATA_RAW_DIR / "Barrios_Bogota"

# ─── AJUSTA ESTE VALOR ────────────────────────────────────────────────────────
# Nombre del campo con el nombre del barrio dentro del shapefile.
# Si no sabes cuál es, corre el script una vez y te imprime todas las columnas.
CAMPO_BARRIO = "SCANOMBRE"

# ─── MAIN ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 60)
    print("  ENRIQUECIMIENTO DE BARRIOS — SPATIAL JOIN")
    print("=" * 60)

    # ── 1. Cargar CSV ─────────────────────────────────────────────────────────
    if not INPUT_CSV.exists():
        raise FileNotFoundError(f"No se encontró el CSV en:\n  {INPUT_CSV}")

    df = pd.read_csv(INPUT_CSV, encoding="utf-8-sig")
    print(f"\n📋 Restaurantes cargados : {len(df)}")
    print(f"   Sin barrio actualmente : {df['barrio'].isna().sum() + (df['barrio'] == '').sum()}")

    # ── 2. Cargar shapefile de barrios ────────────────────────────────────────
    shp_files = list(BARRIOS_DIR.glob("*.shp"))
    if not shp_files:
        raise FileNotFoundError(
            f"No se encontró ningún .shp en:\n  {BARRIOS_DIR}\n"
            "Verifica que la carpeta contiene los archivos del shapefile."
        )

    shp_path = shp_files[0]
    barrios  = gpd.read_file(shp_path)

    print(f"\n📂 Shapefile : {shp_path.name}")
    print(f"   Polígonos : {len(barrios)}")
    print(f"   CRS       : {barrios.crs}")
    print(f"   Columnas  : {list(barrios.columns)}")

    # Verificar que el campo de barrio existe
    if CAMPO_BARRIO not in barrios.columns:
        raise KeyError(
            f"\nEl campo '{CAMPO_BARRIO}' no existe en el shapefile.\n"
            f"Columnas disponibles: {list(barrios.columns)}\n"
            f"Ajusta la variable CAMPO_BARRIO en la línea 28 del script."
        )

    # ── 3. Alinear CRS a WGS84 ────────────────────────────────────────────────
    barrios = barrios.to_crs(epsg=4326)

    # ── 4. Convertir restaurantes a GeoDataFrame ──────────────────────────────
    gdf = gpd.GeoDataFrame(
        df,
        geometry=gpd.points_from_xy(df["lon"], df["lat"]),
        crs="EPSG:4326"
    )

    # ── 5. Spatial Join ───────────────────────────────────────────────────────
    print("\n🔗 Ejecutando spatial join...")

    joined = gpd.sjoin(
        gdf,
        barrios[[CAMPO_BARRIO, "geometry"]],
        how="left",
        predicate="within"
    )

    # ── 6. Escribir resultado en la columna barrio ────────────────────────────
    # Prioriza el join; si el punto cae fuera de todo polígono (bordes),
    # conserva el valor original del CSV.
    df["barrio"] = (
        joined[CAMPO_BARRIO]
        .str.strip()
        .str.title()           # "LA CANDELARIA" → "La Candelaria"
        .fillna(df["barrio"])  # fallback al valor previo si no hubo match
        .fillna("Sin datos")
        .replace("", "Sin datos")
    )

    # ── 7. Guardar CSV actualizado ────────────────────────────────────────────
    df.to_csv(INPUT_CSV, index=False, encoding="utf-8-sig")
    print(f"💾 CSV actualizado : {INPUT_CSV}")

    # ── 8. Resumen ────────────────────────────────────────────────────────────
    total      = len(df)
    con_barrio = (df["barrio"] != "Sin datos").sum()
    sin_barrio = (df["barrio"] == "Sin datos").sum()

    print(f"\n{'─' * 40}")
    print(f"  Total restaurantes  : {total}")
    print(f"  Con barrio          : {con_barrio}  ({con_barrio/total*100:.1f}%)")
    print(f"  Sin barrio          : {sin_barrio}  ({sin_barrio/total*100:.1f}%)")
    print(f"{'─' * 40}")

    print(f"\n📊 Top 15 barrios:")
    print(df["barrio"].value_counts().head(15).to_string())
