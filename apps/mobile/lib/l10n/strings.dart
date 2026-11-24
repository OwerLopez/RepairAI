/// Centralized localization strings for ReparaAI.
///
/// Organized by screen and feature using static methods parameterized by language index:
/// - `0`: Spanish (`es`)
/// - `1`: English (`en`)
class Strings {
  Strings._();

  // ---------------------------------------------------------------------------
  // General / Navigation
  // ---------------------------------------------------------------------------

  /// App name constant.
  static String appName(int lang) => 'ReparaAI';

  /// Generic error message for failed actions.
  static String actionError(int lang) => lang == 0
      ? 'No se pudo completar la acción. Inténtalo de nuevo.'
      : 'Could not complete the action. Try again.';

  /// Cancel button label.
  static String cancel(int lang) => lang == 0 ? 'Cancelar' : 'Cancel';

  /// Delete button label.
  static String delete(int lang) => lang == 0 ? 'Eliminar' : 'Delete';

  /// Try again button label.
  static String tryAgain(int lang) => lang == 0 ? 'Reintentar' : 'Try again';

  /// Tooltip for the app bar language toggle button.
  static String switchLanguageTooltip(int lang) =>
      lang == 0 ? 'Switch to English' : 'Cambiar a español';

  /// Scanner tab label in bottom navigation.
  static String scannerTitle(int lang) => lang == 0 ? 'Escáner' : 'Scanner';

  /// History tab label in bottom navigation.
  static String historyTitle(int lang) => lang == 0 ? 'Historial' : 'History';

  /// Settings tab label in bottom navigation.
  static String settingsTitle(int lang) => lang == 0 ? 'Ajustes' : 'Settings';

  // ---------------------------------------------------------------------------
  // Scanner / Home Page
  // ---------------------------------------------------------------------------

  /// Offline indicator badge text.
  static String worksOffline(int lang) =>
      lang == 0 ? 'Funciona sin conexión' : 'Works offline';

  /// Hero card main heading.
  static String repairGarment(int lang) =>
      lang == 0 ? 'Repara una prenda' : 'Repair a garment';

  /// Hero card descriptive subtitle.
  static String inspectDamageDesc(int lang) => lang == 0
      ? 'Examina el daño con una foto y sigue una guía compatible con tu prenda.'
      : 'Inspect the damage with a photo and follow a guide that fits your garment.';

  /// Button label for taking a photo via camera.
  static String takePhoto(int lang) =>
      lang == 0 ? 'Tomar fotografía' : 'Take a photo';

  /// Button label for picking an image from gallery.
  static String chooseFromGallery(int lang) =>
      lang == 0 ? 'Elegir de la galería' : 'Choose from gallery';

  /// Progress message while analyzing an image.
  static String processingPhoto(int lang) =>
      lang == 0 ? 'Procesando la fotografía…' : 'Processing the photo…';

  /// Title for photo capture guidance card.
  static String setupPhotoTitle(int lang) =>
      lang == 0 ? 'Prepara la foto' : 'Set up your photo';

  /// Instructions for framing textile damage.
  static String setupPhotoDesc(int lang) => lang == 0
      ? 'Extiende la prenda y acércate al daño con luz uniforme.'
      : 'Lay the garment flat and frame the damage closely in even light.';

  /// Link label for downloading APK.
  static String downloadApk(int lang) =>
      lang == 0 ? 'Descargar APK' : 'Download APK';

  /// Link label for IEEE research paper.
  static String ieeePaper(int lang) =>
      lang == 0 ? 'Artículo IEEE' : 'IEEE paper';

  /// Permission error snackbar message.
  static String permissionError(int lang) => lang == 0
      ? 'Revisa los permisos de cámara o fotos en los ajustes del teléfono.'
      : 'Check camera or photo access in your phone settings.';

  /// Invalid image size or format message.
  static String imageSizeFormatError(int lang) => lang == 0
      ? 'Elige una imagen JPEG o PNG de hasta 28 MB y 32 megapíxeles.'
      : 'Choose a JPEG or PNG image up to 28 MB and 32 megapixels.';

  // ---------------------------------------------------------------------------
  // History Page
  // ---------------------------------------------------------------------------

  /// Heading for history list.
  static String yourRepairs(int lang) =>
      lang == 0 ? 'Tus reparaciones' : 'Your repairs';

  /// Retry button when loading history fails.
  static String retryLoadingHistory(int lang) =>
      lang == 0 ? 'Reintentar cargar el historial' : 'Retry loading history';

  /// Placeholder message when no repairs are recorded yet.
  static String emptyHistory(int lang) => lang == 0
      ? 'Las reparaciones que inicies aparecerán aquí.'
      : 'Repairs will appear here once you start them.';

  // ---------------------------------------------------------------------------
  // Diagnosis Page
  // ---------------------------------------------------------------------------

  /// Diagnosis page app bar title.
  static String diagnosisTitle(int lang) =>
      lang == 0 ? 'Diagnóstico' : 'Diagnosis';

  /// Button and screen title for pinpointing damage.
  static String markArea(int lang) =>
      lang == 0 ? 'Señalar zona' : 'Mark an area';

  /// Instruction explaining how to point near fabric damage.
  static String markAreaInstruction(int lang) => lang == 0
      ? 'Toca la tela cerca del daño. El modelo buscará alrededor de ese punto.'
      : 'Tap the fabric near the damage. The model will search around that point.';

  /// Accessibility label for the interactive focus photo.
  static String photoForMarkingDamage(int lang) =>
      lang == 0 ? 'Foto para señalar el daño' : 'Photo for marking damage';

  /// Guidance text when the model finds a damage candidate.
  static String candidateHint(int lang) => lang == 0
      ? 'Revisa la zona marcada. Confirma el daño mirando la prenda y el tejido en la etiqueta.'
      : 'Inspect the marked area. Confirm the damage on the garment and check the fabric label.';

  /// Guidance text when the model score is below threshold.
  static String uncertainHint(int lang) => lang == 0
      ? 'Puedes señalar una zona para acotar la búsqueda o identificar el daño manualmente.'
      : 'Mark an area to narrow the search or identify the damage manually.';

  /// Guidance text when an image was rejected by quality heuristics.
  static String rejectedHint(int lang) => lang == 0
      ? 'Vuelve a tomar una foto nítida con iluminación uniforme.'
      : 'Retake a sharp photo with even lighting.';

  /// Header for raw analysis details expansion panel.
  static String analysisDetails(int lang) =>
      lang == 0 ? 'Detalles del análisis' : 'Analysis details';

  /// Label showing uncalibrated model score.
  static String uncalibratedScore(int lang, String score) =>
      lang == 0 ? 'Puntaje sin calibrar $score' : 'Uncalibrated score $score';

  /// Button to reset the focus point and return to full-image scan.
  static String returnToFullAnalysis(int lang) => lang == 0
      ? 'Volver al análisis completo'
      : 'Return to full-image analysis';

  /// Accessibility label during sub-region inference.
  static String searchingMarkedArea(int lang) =>
      lang == 0 ? 'Buscando en la zona señalada' : 'Searching the marked area';

  /// Button to dismiss diagnosis and return to scanner.
  static String returnToScanner(int lang) =>
      lang == 0 ? 'Volver al escáner' : 'Return to scanner';

  /// Form section header for manual confirmation.
  static String confirmDamageAndFabric(int lang) => lang == 0
      ? 'Confirma el daño y la tela'
      : 'Confirm the damage and fabric';

  /// Label for observed damage dropdown.
  static String observedDamage(int lang) =>
      lang == 0 ? 'Daño observado' : 'Observed damage';

  /// Damage option: Hole.
  static String damageHole(int lang) => lang == 0 ? 'Agujero' : 'Hole';

  /// Damage option: Tear.
  static String damageTear(int lang) => lang == 0 ? 'Desgarro' : 'Tear';

  /// Damage option: Open seam.
  static String damageSeam(int lang) =>
      lang == 0 ? 'Costura recta abierta' : 'Open straight seam';

  /// Damage option: Other.
  static String damageOther(int lang) =>
      lang == 0 ? 'Otro o sin confirmar' : 'Other or unconfirmed';

  /// Label for fabric dropdown.
  static String confirmedFabric(int lang) =>
      lang == 0 ? 'Tela confirmada' : 'Confirmed fabric';

  /// Fabric option: Denim.
  static String fabricDenim(int lang) => lang == 0 ? 'Denim' : 'Denim';

  /// Fabric option: Non-stretch woven.
  static String fabricWoven(int lang) =>
      lang == 0 ? 'Tejido plano no elástico' : 'Non-stretch woven fabric';

  /// Fabric option: Unknown or other.
  static String fabricUnknown(int lang) =>
      lang == 0 ? 'Otra o desconocida' : 'Other or unknown';

  /// Switch title for sewing machine availability.
  static String haveSewingMachine(int lang) =>
      lang == 0 ? 'Tengo máquina de coser' : 'I have a sewing machine';

  /// Checkbox title confirming everyday garment.
  static String everydayGarment(int lang) => lang == 0
      ? 'Es una prenda de uso cotidiano'
      : 'This is an everyday garment';

  /// Checkbox subtitle excluding technical gear.
  static String everydayGarmentDesc(int lang) => lang == 0
      ? 'Excluye prendas de protección y equipo técnico.'
      : 'Exclude protective garments and technical equipment.';

  /// Notice when no procedure matches user criteria.
  static String noCompatibleProcedures(int lang) => lang == 0
      ? 'No hay un procedimiento compatible con estos datos.'
      : 'There is no compatible procedure for this information.';

  /// Section heading for available repair procedures.
  static String compatibleProcedures(int lang) =>
      lang == 0 ? 'Procedimientos compatibles' : 'Compatible procedures';

  /// Button to initiate a selected procedure.
  static String startRepair(int lang) =>
      lang == 0 ? 'Iniciar reparación' : 'Start repair';

  // ---------------------------------------------------------------------------
  // Repair Page
  // ---------------------------------------------------------------------------

  /// Guided repair page app bar title.
  static String guidedRepairTitle(int lang) =>
      lang == 0 ? 'Reparación guiada' : 'Guided repair';

  /// Confirmation dialog title for deleting a repair.
  static String deleteRepairDialogTitle(int lang) =>
      lang == 0 ? '¿Eliminar reparación?' : 'Delete this repair?';

  /// Confirmation dialog message for deleting a repair.
  static String deleteRepairDialogContent(int lang) => lang == 0
      ? 'Se eliminarán también sus fotos y notas.'
      : 'Its photos and notes will also be deleted.';

  /// Progress bar accessibility label.
  static String stepProgress(int lang) =>
      lang == 0 ? 'Avance de pasos' : 'Step progress';

  /// Text indicating number of completed steps.
  static String stepsComplete(int lang, int count, int total) => lang == 0
      ? '$count / $total pasos completados'
      : '$count / $total steps complete';

  /// Header for materials and safety precautions.
  static String toolsPrecautionsSource(int lang) => lang == 0
      ? 'Materiales, precauciones y fuente'
      : 'Tools, precautions and source';

  /// Safety reminder during repair.
  static String safetyPrecaution(int lang) => lang == 0
      ? 'Retira alfileres al terminar y revisa que no hayas cosido otra capa.'
      : 'Remove pins when finished and check that no other garment layer was stitched.';

  /// Button to advance to the next step.
  static String completeStep(int lang, int step) =>
      lang == 0 ? 'Completar paso $step' : 'Complete step $step';

  /// Section header for diagnosis summary and evidence photos.
  static String diagnosisAndPhotos(int lang) =>
      lang == 0 ? 'Diagnóstico y fotos' : 'Diagnosis and photos';

  /// Button to attach an after-repair photo.
  static String addOutcomePhoto(int lang) =>
      lang == 0 ? 'Añadir foto del resultado' : 'Add outcome photo';

  /// Button to replace the after-repair photo.
  static String replaceOutcomePhoto(int lang) =>
      lang == 0 ? 'Cambiar foto del resultado' : 'Replace outcome photo';

  /// Header for finalizing the repair outcome.
  static String recordOutcome(int lang) =>
      lang == 0 ? 'Registra el resultado' : 'Record the outcome';

  /// Dropdown label for repair outcome selection.
  static String observedOutcome(int lang) =>
      lang == 0 ? 'Resultado observado' : 'Observed outcome';

  /// Label for optional repair notes.
  static String optionalNotes(int lang) =>
      lang == 0 ? 'Notas opcionales' : 'Optional notes';

  /// Button to persist the repair outcome and notes.
  static String saveOutcome(int lang) =>
      lang == 0 ? 'Guardar resultado' : 'Save outcome';

  /// Button to delete the repair session.
  static String deleteRepair(int lang) =>
      lang == 0 ? 'Eliminar reparación' : 'Delete repair';

  // ---------------------------------------------------------------------------
  // Status Labels & Photo Comparison
  // ---------------------------------------------------------------------------

  /// Label for scan status candidate.
  static String scanLabelCandidate(int lang) => lang == 0
      ? 'Posible agujero · experimental'
      : 'Possible hole · experimental';

  /// Label for scan status resolution rejection.
  static String scanLabelResolution(int lang) =>
      lang == 0 ? 'Resolución insuficiente' : 'Insufficient resolution';

  /// Label for scan status lighting rejection.
  static String scanLabelLighting(int lang) => lang == 0
      ? 'Iluminación insuficiente o excesiva'
      : 'Image too dark or too bright';

  /// Label for scan status focus rejection.
  static String scanLabelFocus(int lang) =>
      lang == 0 ? 'Falta de detalle o enfoque' : 'Insufficient detail or focus';

  /// Label when the model abstains or is uncertain.
  static String scanLabelAbstained(int lang) =>
      lang == 0 ? 'El modelo se abstuvo' : 'The model abstained';

  /// Outcome label: repaired.
  static String outcomeRepaired(int lang) =>
      lang == 0 ? 'Reparado según el usuario' : 'Repaired, self-reported';

  /// Outcome label: partial.
  static String outcomePartial(int lang) =>
      lang == 0 ? 'Resultado parcial' : 'Partial result';

  /// Outcome label: stopped.
  static String outcomeStopped(int lang) =>
      lang == 0 ? 'Interrumpida' : 'Stopped';

  /// Outcome label: in progress.
  static String outcomeInProgress(int lang) =>
      lang == 0 ? 'En progreso' : 'In progress';

  /// Section heading for before/after comparison.
  static String compareBeforeAndAfter(int lang) =>
      lang == 0 ? 'Comparar antes y después' : 'Compare before and after';

  /// Label for after photo.
  static String afterPhotoLabel(int lang) => lang == 0 ? 'Después' : 'After';

  /// Label for before photo.
  static String beforePhotoLabel(int lang) => lang == 0 ? 'Antes' : 'Before';

  /// Slider accessibility label.
  static String photoComparisonControl(int lang) => lang == 0
      ? 'Control de comparación de fotos'
      : 'Photo comparison control';

  /// Slider accessibility percentage readout.
  static String photoComparisonPercent(int lang, int percent) => lang == 0
      ? '$percent por ciento de la foto anterior'
      : '$percent percent of the before photo';

  // ---------------------------------------------------------------------------
  // Settings Screen
  // ---------------------------------------------------------------------------

  /// Settings language section title.
  static String languageSection(int lang) => lang == 0 ? 'Idioma' : 'Language';

  /// Spanish language option name.
  static String spanish(int lang) => lang == 0 ? 'Español' : 'Spanish';

  /// English language option name.
  static String english(int lang) => lang == 0 ? 'Inglés' : 'English';

  /// App version section title.
  static String versionTitle(int lang) =>
      lang == 0 ? 'Versión de la aplicación' : 'App version';

  /// About section title.
  static String aboutSection(int lang) =>
      lang == 0 ? 'Acerca de ReparaAI' : 'About ReparaAI';

  /// Authors subsection header.
  static String authorsTitle(int lang) => lang == 0 ? 'Autores' : 'Authors';

  /// Privacy section title.
  static String privacySection(int lang) =>
      lang == 0 ? 'Privacidad y seguridad' : 'Privacy & Security';

  /// Privacy policy statement.
  static String privacyDesc(int lang) => lang == 0
      ? 'ReparaAI funciona completamente sin conexión. Tus fotos y registros se almacenan únicamente de manera local en tu dispositivo y nunca se transmiten a servidores externos.'
      : 'ReparaAI operates entirely offline. Your photos and repair records are stored locally on your device and are never transmitted to external servers.';

  /// Data management section title.
  static String dataSection(int lang) =>
      lang == 0 ? 'Gestión de datos' : 'Data Management';

  /// Button to erase all application data.
  static String deleteAllData(int lang) =>
      lang == 0 ? 'Borrar todos los datos' : 'Delete all data';

  /// Confirmation dialog title for wiping data.
  static String deleteAllDataConfirmTitle(int lang) =>
      lang == 0 ? '¿Borrar todos los datos?' : 'Delete all data?';

  /// Confirmation dialog content for wiping data.
  static String deleteAllDataConfirmContent(int lang) => lang == 0
      ? 'Se eliminarán permanentemente todas las reparaciones, imágenes y preferencias guardadas.'
      : 'All saved repairs, images, and preferences will be permanently deleted.';

  /// Snackbar message confirming data purge.
  static String dataDeletedSnackbar(int lang) => lang == 0
      ? 'Todos los datos han sido eliminados.'
      : 'All data has been deleted.';

  // ---------------------------------------------------------------------------
  // Environmental Impact Widget
  // ---------------------------------------------------------------------------

  /// Environmental impact widget title.
  static String impactTitle(int lang) => lang == 0
      ? 'Impacto ambiental acumulado'
      : 'Cumulative Environmental Impact';

  /// Completed repairs statistic label.
  static String impactRepairs(int lang, int count) =>
      lang == 0 ? '$count prendas reparadas' : '$count garments repaired';

  /// Metric for CO2 emissions saved.
  static String impactCo2(int lang, String co2) =>
      lang == 0 ? '$co2 kg CO₂ evitados' : '$co2 kg CO₂ saved';

  /// Metric for water conserved.
  static String impactWater(int lang, String water) =>
      lang == 0 ? '$water L de agua ahorrada' : '$water L water saved';

  /// Metric for textile waste avoided.
  static String impactWaste(int lang, int count) => lang == 0
      ? '$count prendas rescatadas'
      : '$count garments diverted from waste';
}
