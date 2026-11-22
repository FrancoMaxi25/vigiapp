class Incidente {
  final String id;
  final String descripcion;
  final double latitud;
  final double longitud;
  final String tipo; // 'peligro', 'transito', 'apoyo'
  final String? fotoUrl;
  final DateTime creadoEn;
  final bool sincronizado;

  const Incidente({
    required this.id,
    required this.descripcion,
    required this.latitud,
    required this.longitud,
    required this.tipo,
    this.fotoUrl,
    required this.creadoEn,
    this.sincronizado = true,
  });

  // Color según el tipo de incidente
  static const Map<String, int> colores = {
    'peligro':  0xFFE53935, // Rojo
    'transito': 0xFFFDD835, // Amarillo
    'apoyo':    0xFF43A047, // Verde
  };
}