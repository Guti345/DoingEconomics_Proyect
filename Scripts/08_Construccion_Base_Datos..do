/* =============================================================================
   PROYECTO: Digitalización y posicionamiento en restaurantes mediterráneos
             en Bogotá
   SCRIPT:   Construcción y etiquetado de la base de datos final
   --------------------------------------------------------------------------
   DESCRIPCIÓN:
   Este script importa, fusiona, limpia y etiqueta la base de datos final
   que combina:
     (1) Resultados del cuestionario aplicado a restaurantes (result_encuesta)
     (2) Base enriquecida con datos de Google Maps y TripAdvisor
   ============================================================================= */

clear all
set more off

* -----------------------------------------------------------------------------
* DIRECTORIOS DE TRABAJO
* -----------------------------------------------------------------------------
cd "C:\Users\anton\OneDrive\Documentos\GitHub\DoingEconomics_Proyect\Scripts"

global main    "C:\Users\anton\OneDrive\Documentos\GitHub\DoingEconomics_Proyect"
global graphs  "${main}\Outputs\Graphs"
global tables  "${main}\Outputs\Tables"
global raw     "${main}\Data\Raw"
global clean   "${main}\Data\Clean"


/* =============================================================================
   SECCIÓN 1 – IMPORTACIÓN DE DATOS
   ============================================================================= */

* -----------------------------------------------------------------------------
* 1.1 Importar resultados del cuestionario (hoja "Diccionarío Códigos")
*     y guardar como .dta para el merge posterior
* -----------------------------------------------------------------------------
import excel "${raw}\result_encuesta.xlsx", ///
    firstrow sheet("Diccionarío Códigos") clear

save "${raw}\results_encuesta.dta", replace

* -----------------------------------------------------------------------------
* 1.2 Importar base enriquecida con datos observacionales
*     (Google Maps + TripAdvisor, construida externamente)
* -----------------------------------------------------------------------------
import excel "${clean}\base_restaurantes_enriquecida_tripadvisor.xlsx", ///
    firstrow clear


/* =============================================================================
   SECCIÓN 2 – MERGE
   ============================================================================= */

* -----------------------------------------------------------------------------
* 2.1 Combinar ambas bases usando el identificador único del restaurante (id)
*     nogen suprime la variable _merge; el match es 1:1
* -----------------------------------------------------------------------------
merge 1:1 id using "${raw}\results_encuesta.dta", nogen


/* =============================================================================
   SECCIÓN 3 – GENERACIÓN DE VARIABLES AUXILIARES
   ============================================================================= */

* -----------------------------------------------------------------------------
* 3.1 Indicador de restaurante con encuesta aplicada
*     (1 si el nombre del restaurante está presente en la encuesta, 0 si no)
* -----------------------------------------------------------------------------
gen encuesta_si = (Nombredelrestaurante != "")

* -----------------------------------------------------------------------------
* 3.2 Indicador binario de presencia activa en TripAdvisor
*     (1 si existe calificación registrada, 0 si no)
* -----------------------------------------------------------------------------
gen tripadvisor_profile = (tripadvisor_rating != "")

* -----------------------------------------------------------------------------
* 3.3 Convertir calificación de TripAdvisor a variable numérica
*     tripadvisor_rating viene como string desde el Excel; se convierte a
*     numérico continuo para permitir análisis cuantitativos
*     force: convierte a missing (.) los valores no numéricos si los hubiera
* -----------------------------------------------------------------------------
destring tripadvisor_rating, replace force


/* =============================================================================
   SECCIÓN 4 – SELECCIÓN DE VARIABLES (KEEP)
   Conservar únicamente las variables relevantes para el análisis
   ============================================================================= */
keep id nombre                                                          ///
     rating num_reviews                                                 ///
     tripadvisor_rating tripadvisor_n_reviews tripadvisor_ranking       ///
     tripadvisor_profile                                                ///
     Barrio                                                             ///
     Cuáldescribemejorlaidentida Perteneceaunacadenaderesta             ///
     Quétancompetitivoconsiderae Elrestauranterealizaactualme           ///
     Enquéplataformasinvierteen  Conquéfrecuenciapagapublici            ///
     Aproximadamentequéporcentaje                                       ///
     Utilizaactualmentealgunaherr Quéherramientasdeinteligenci          ///
     Cómollegalamayoríadesuscl  Decada10clientescuántosll O P          ///
     Cuálcanalconsideramásrentab                                        ///
     Lasplataformasdedeliveryle  Utilizaesainformaciónparato            ///
     Elrestaurantegestionaactivam Utilizaalgunaherramientadei           ///
     Enlospróximos12mesescuál   Cuálcreequeseráelfactormá               ///
     Situvieraaccesofácilyeconóm                                        ///
     encuesta_si


/* =============================================================================
   SECCIÓN 5 – RENAME
   Estandarizar nombres: variables de encuesta → p# / p#x
                         variables observacionales → obs#
   ============================================================================= */

* --- Variables de identificación y contexto ----------------------------------
rename rating        rating_google
rename num_reviews   google_num_reviews

* --- Variables de encuesta ---------------------------------------------------
rename Barrio                          barrio
rename Cuáldescribemejorlaidentida     p0a
rename Perteneceaunacadenaderesta      p3
rename Quétancompetitivoconsiderae     p3b
rename Elrestauranterealizaactualme    p4
rename Enquéplataformasinvierteen      p5
rename Conquéfrecuenciapagapublici     p6
rename Aproximadamentequéporcentaje    p7
rename Utilizaactualmentealgunaherr    p7b
rename Quéherramientasdeinteligenci    p7c
rename Cómollegalamayoríadesuscl       p8
rename Decada10clientescuántosll       p9
rename O                               p10
rename P                               p11
rename Cuálcanalconsideramásrentab     p12
rename Lasplataformasdedeliveryle      p12b
rename Utilizaesainformaciónparato     p12c
rename Elrestaurantegestionaactivam    p13
rename Utilizaalgunaherramientadei     p13b
rename Enlospróximos12mesescuál        p14
rename Cuálcreequeseráelfactormá       p16
rename Situvieraaccesofácilyeconóm     p18

* --- Variables observacionales (Google Maps y TripAdvisor) -------------------
rename google_num_reviews   obs1
rename rating_google        obs2
rename tripadvisor_profile  obs3
rename tripadvisor_n_reviews obs4
rename tripadvisor_rating   obs5


/* =============================================================================
   SECCIÓN 6 – LABEL VARIABLE
   Asignar etiqueta descriptiva a cada variable
   ============================================================================= */

* --- Auxiliares --------------------------------------------------------------
label variable encuesta_si          "Restaurante con encuesta aplicada (1=Si, 0=No)"

* --- Identificación y contexto -----------------------------------------------
label variable id                   "Identificador del restaurante"
label variable nombre               "Nombre del restaurante"
label variable barrio               "Barrio"

* --- Preguntas del cuestionario ----------------------------------------------
label variable p0a                  "p0a - Tipo de cocina del restaurante"
label variable p3                   "p3 - Pertenece a una cadena de restaurantes"
label variable p3b                  "p3b - Nivel de competitividad percibida del nicho (escala 1-5)"
label variable p4                   "p4 - Realiza inversion en marketing digital"
label variable p5                   "p5 - Plataformas donde invierte en publicidad paga"
label variable p6                   "p6 - Frecuencia con la que paga publicidad"
label variable p7                   "p7 - Porcentaje de ingresos destinado a marketing digital"
label variable p7b                  "p7b - Herramientas de IA en estrategia de redes sociales"
label variable p7c                  "p7c - Herramientas de IA para administrar el negocio"
label variable p8                   "p8 - Canal principal de descubrimiento de clientes nuevos"
label variable p9                   "p9 - De cada 10 clientes, cuantos llegan de manera presencial"
label variable p10                  "p10 - De cada 10 clientes, cuantos llegan por delivery (plataformas)"
label variable p11                  "p11 - De cada 10 clientes, cuantos llegan por domicilio propio"
label variable p12                  "p12 - Canal percibido como mas rentable"
label variable p12b                 "p12b - Acceso y consulta de datos de comportamiento en delivery"
label variable p12c                 "p12c - Uso de datos de delivery para decisiones de menu, precios o promociones"
label variable p13                  "p13 - Gestion activa del perfil en Google Maps o TripAdvisor"
label variable p13b                 "p13b - Uso de IA para gestionar o responder resenas"
label variable p14                  "p14 - Acciones digitales a implementar en los proximos 12 meses"
label variable p16                  "p16 - Factor mas determinante para posicionamiento futuro en nicho mediterraneo"
label variable p18                  "p18 - Aplicacion de IA de mayor interes para el restaurante"

* --- Variables observacionales -----------------------------------------------
label variable obs1                 "obs1 - Numero de resenas en Google Maps"
label variable obs2                 "obs2 - Calificacion promedio en Google Maps (1.0-5.0)"
label variable obs3                 "obs3 - Presencia activa en TripAdvisor (1=Si, 0=No)"
label variable obs4                 "obs4 - Numero de resenas en TripAdvisor"
label variable obs5                 "obs5 - Calificacion promedio en TripAdvisor (1.0-5.0)"
label variable tripadvisor_ranking  "ranking - Posicion en el ranking de TripAdvisor Bogota"


/* =============================================================================
   SECCIÓN 7 – ORDER
   Ordenar columnas: encuesta_si primero → identificación → encuesta → 
                     observacionales → tripadvisor_ranking al final
   ============================================================================= */
order encuesta_si                           ///
      id nombre barrio                      ///
      p0a p3 p3b                            ///
      p4 p5 p6 p7 p7b p7c                  ///
      p8 p9 p10 p11 p12 p12b p12c          ///
      p13 p13b p14 p16 p18                 ///
      obs1 obs2 obs3 obs4 obs5             ///
      tripadvisor_ranking


/* =============================================================================
   SECCIÓN 8 – GUARDAR BASE FINAL Y EXPORTAR EXCEL
   ============================================================================= */
save "${clean}\base_final.dta", replace
export excel "${clean}\base_final.xlsx", firstrow(varlabels) replace


