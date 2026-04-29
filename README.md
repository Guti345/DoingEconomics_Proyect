# 🫒 Digitalización y Posicionamiento en el Mercado de Restaurantes Mediterráneos en Bogotá

> Proyecto de investigación · Haciendo Economía 2026-1 · Universidad del Rosario

**Pregunta de investigación:** ¿Cuáles son las tecnologías que han transformado las estrategias de posicionamiento en el mercado de restaurantes mediterráneos en Bogotá?

---

## Descripción

Este proyecto caracteriza el mercado de restaurantes mediterráneos en Bogotá y analiza la relación entre la adopción de estrategias digitales de posicionamiento y la visibilidad de los establecimientos en plataformas digitales.
---

## Estructura del repositorio

```
DoingEconomics_Proyect/
│
├── Data/
│   └── Raw/
│       ├── restaurantes_mediterraneos_bogota.xlsx       # Directorio completo: id, dirección, coordenadas,
│       │                                                # rating, n.º de reseñas, link Google Maps,
│       │                                                # tipo de cocina, barrio, pertenencia a muestra
│       ├── restaurantes_mediterraneos_bogota.csv        # Misma base en formato CSV
│       ├── restaurantes_mediterraneos_bogota_classified.xlsx  # Directorio completo con clasificación por tipo de cocina
│       └── Barrios_Bogota/                              # Shapefile de barrios de Bogotá para construcción de mapas
│
├── Documents/
│   ├── base_datos_proyecto.xlsx                         # Borrador de estructura de la base de datos con
│   │                                                    # variables de encuesta y observación externa
│   ├── Consentimiento_informado.pdf                     # Consentimiento informado 
│   ├── Cuestionario - Restaurantes Mediterraneos        # Cuestionario (Google Forms)
│   │   en Bogota - Formularios de Google          
│   └── Plan_de_análisis.pdf                             # Plan de análisis: variables, índices IRS/IDL/IPO
│                                                        # y estrategia estadística
│
├── Outputs/
│   └── Graphs/
│       ├── mapa_restaurantes_mediterraneos              # Mapa de todos los restaurantes identificados en Bogotá
│       └── mapa_encuesta_campo_puntos                  # Mapa de los 41 restaurantes seleccionados para encuesta
│
└── Scripts/
    ├── 01_extraccion_restaurantes                       # Extracción de restaurantes vía Google Maps API
    ├── 02_mapa_restaurantes.py                          # Visualización del mapa general (Python)
    ├── 02_mapa_restaurantes.R                           # Visualización del mapa general (R)
    ├── 03_completar_barrios                             # Asignación de barrios a partir de coordenadas
    ├── 04_clasificar_cocina                             # Clasificación de establecimientos por tipo de cocina
    ├── 05_aleatorizacion_encuesta                       # Aleatorización y selección de la muestra (n=41)
    ├── 06_mapa_encuesta_campo                           # Mapa de restaurantes asignados para trabajo de campo
    └── api_request_log                                  # Log de consultas realizadas a la API de Google Maps
```

---

## Estado del proyecto

- [x] Extracción y clasificación del directorio de restaurantes
- [x] Aleatorización de la muestra
- [x] Diseño del cuestionario y consentimiento informado
- [x] Plan de análisis
- [ ] Recolección de datos en campo
- [ ] Construcción de índices IRS, IDL e IPO
- [ ] Análisis estadístico
- [ ] Redacción del informe final
