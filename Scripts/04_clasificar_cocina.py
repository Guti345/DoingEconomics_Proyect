"""
=============================================================
CLASIFICACIÓN DE COCINA → COLUMNA EN CSV
=============================================================
Lee  : Data/Raw/restaurantes_mediterraneos_bogota.csv
Escribe la columna 'cocina' directamente en el mismo CSV.

Lógica de clasificación (en orden de prioridad):
  1. Griega       → tipos/query contiene: grieg, greek
  2. Española     → tipos/query contiene: españ, spanish, tapas
  3. Italiana     → tipos/query contiene: italian, pizza, trattoria
  4. Árabe        → tipos/query contiene: arab, middle_eastern,
                    lebanes, shawarma, beirut, falafel, libanés
  5. Mediterránea → fallback (ninguna de las anteriores)

Si una fila ya tiene valor en 'cocina', el script la respeta
y NO la sobreescribe — solo completa las que están vacías.
Para reclasificar todo desde cero: pon FORZAR_RECLASIFICAR = True
=============================================================
"""

import pandas as pd
from pathlib import Path

# ─── RUTAS ────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
INPUT_CSV    = PROJECT_ROOT / "Data" / "Raw" / "restaurantes_mediterraneos_bogota.csv"
OUTPUT_XLSX = PROJECT_ROOT / "Data" / "Raw" / "restaurantes_mediterraneos_bogota.xlsx"

# ─── CONFIGURACIÓN ────────────────────────────────────────────────────────────
# True  → reclasifica TODAS las filas (sobreescribe valores existentes)
# False → solo completa filas sin cocina asignada
FORZAR_RECLASIFICAR = False


# ─── FUNCIÓN DE CLASIFICACIÓN ─────────────────────────────────────────────────
def clasificar_cocina(tipos: str, query_origen: str) -> str:
    """
    Clasifica un restaurante según las columnas 'tipos' (etiquetas de Google)
    y 'query_origen' (query usado para encontrarlo).

    Prioridad:
      Griega > Española > Italiana > Árabe > Mediterránea (fallback)

    Señales por categoría
    ─────────────────────
    Griega       : tipos → grieg, greek
                   query → grieg, greek

    Española     : tipos → españ, spanish
                   query → españ, tapas

    Italiana     : tipos → italian
                   query → italian, pizza, trattoria

    Árabe        : tipos → arab, middle_eastern, lebanes, shawarma
                   query → arab, libanés, libanes, shawarma, beirut, falafel

    Mediterránea : fallback si ninguna categoría coincide
    """
    t = str(tipos).lower()
    q = str(query_origen).lower()

    if "grieg" in t or "greek" in t or "grieg" in q or "greek" in q:
        return "Griega"

    if "españ" in t or "spanish" in t or "españ" in q or "tapas" in q:
        return "Española"

    if "italian" in t or "italian" in q or "pizza" in q or "trattoria" in q:
        return "Italiana"

    if ("arab" in t or "middle_eastern" in t or "lebanes" in t or "shawarma" in t
            or "arab" in q or "libanés" in q or "libanes" in q
            or "shawarma" in q or "beirut" in q or "falafel" in q):
        return "Árabe"

    return "Mediterránea"


# ─── MAIN ─────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 55)
    print("  CLASIFICACIÓN DE COCINA → CSV")
    print("=" * 55)

    if not INPUT_CSV.exists():
        raise FileNotFoundError(f"CSV no encontrado:\n  {INPUT_CSV}")

    df = pd.read_csv(INPUT_CSV, encoding="utf-8-sig")
    print(f"\n📋 Restaurantes cargados: {len(df)}")

    # Crear columna si no existe
    if "cocina" not in df.columns:
        df["cocina"] = None
        print("   Columna 'cocina' creada")

    # Identificar filas a clasificar
    if FORZAR_RECLASIFICAR:
        mask = pd.Series([True] * len(df))
        print("   Modo: RECLASIFICAR TODO")
    else:
        mask = df["cocina"].isna() | (df["cocina"].str.strip() == "")
        print(f"   Modo: solo filas sin cocina ({mask.sum()} filas)")

    # Aplicar clasificación
    df.loc[mask, "cocina"] = df.loc[mask].apply(
        lambda r: clasificar_cocina(r.get("tipos", ""), r.get("query_origen", "")),
        axis=1
    )

    # Guardar CSV
    df.to_csv(INPUT_CSV, index=False, encoding="utf-8-sig")
    print(f"\n💾 CSV actualizado: {INPUT_CSV}")

    # Resumen
    print(f"\n{'─' * 40}")
    print(f"  Distribución por cocina:")
    conteo = df["cocina"].value_counts()
    for cocina, n in conteo.items():
        pct = n / len(df) * 100
        print(f"    {cocina:<15} : {n:>3}  ({pct:.1f}%)")
    print(f"{'─' * 40}")

    # Mostrar los Árabes detectados para verificar
    arabes = df[df["cocina"] == "Árabe"][["id", "nombre", "tipos", "query_origen"]]
    if len(arabes) > 0:
        print(f"\n🟣 Restaurantes clasificados como Árabe ({len(arabes)}):")
        print(arabes.to_string(index=False))
    else:
        print("\n⚠️  No se detectaron restaurantes Árabes.")
        print("   Si hay alguno, revisa que su columna 'tipos' o 'query_origen'")
        print("   contenga alguna de estas palabras:")
        print("   arab, middle_eastern, lebanes, shawarma, beirut, falafel, libanés")

    # Advertencia si hay muchos en Mediterránea (posible mala clasificación)
    n_med = conteo.get("Mediterránea", 0)
    if n_med > len(df) * 0.3:
        print(f"\n⚠️  {n_med} restaurantes cayeron en 'Mediterránea' (fallback).")
        print("   Puede indicar que Google no les asignó etiqueta específica.")
        print("   Puedes revisar manualmente con:")
        print("   df[df['cocina']=='Mediterránea'][['nombre','tipos','query_origen']]")

# ─── EXPORTAR A EXCEL ─────────────────────────────────────────────────────────

df.to_excel(OUTPUT_XLSX, index=False, engine="openpyxl")
print(f"\n💾 Excel guardado: {OUTPUT_XLSX}")