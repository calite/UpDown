/// Configuración general de la aplicación.
/// Aquí se centralizan todas las opciones de configuración,
/// tanto de puntuación como de visibilidad de estadísticas.
class AppConfig {
  // =============================
  // PUNTUACIÓN
  // =============================

  /// Valor que suma cada positivo.
  static int positiveValue = 1;

  /// Valor que resta cada negativo.
  static int negativeValue = -1;

  // =============================
  // ESTADÍSTICAS
  // =============================

  /// Mostrar/ocultar la sección de estadísticas globales.
  static bool showGlobalStats = true;

  /// Mostrar/ocultar la sección de estadísticas por equipos.
  static bool showTeamStats = true;

  /// Mostrar/ocultar la sección de estadísticas por integrantes.
  static bool showMemberStats = true;
}
