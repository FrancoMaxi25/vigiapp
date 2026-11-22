import '../../domain/entities/incidente.dart';

class IncidenteModel extends Incidente {
  const IncidenteModel({
    required super.id,
    required super.descripcion,
    required super.latitud,
    required super.longitud,
    required super.tipo,
    super.fotoUrl,
    required super.creadoEn,
    super.sincronizado,
  });

  // Convierte el JSON que viene de Supabase en un IncidenteModel
  factory IncidenteModel.fromJson(Map<String, dynamic> json) {
    return IncidenteModel(
      id:           json['id'] as String,
      descripcion:  json['descripcion'] as String,
      latitud:      (json['latitud'] as num).toDouble(),
      longitud:     (json['longitud'] as num).toDouble(),
      tipo:         json['tipo'] as String? ?? 'peligro',
      fotoUrl:      json['foto_url'] as String?,
      creadoEn:     DateTime.parse(json['creado_en'] as String),
      sincronizado: json['sincronizado'] as bool? ?? true,
    );
  }

  // Convierte el modelo en JSON para enviar a Supabase
  Map<String, dynamic> toJson() {
    return {
      'descripcion':  descripcion,
      'latitud':      latitud,
      'longitud':     longitud,
      'tipo':         tipo,
      'foto_url':     fotoUrl,
      'sincronizado': sincronizado,
      'expira_en':    DateTime.now()
          .add(const Duration(hours: 24))
          .toIso8601String(),
    };
  }

  // Convierte el modelo en Map para guardar en SQLite
  Map<String, dynamic> toSqlite() {
    return {
      'id':           id,
      'descripcion':  descripcion,
      'latitud':      latitud,
      'longitud':     longitud,
      'tipo':         tipo,
      'foto_url':     fotoUrl ?? '',
      'creado_en':    creadoEn.toIso8601String(),
      'sincronizado': sincronizado ? 1 : 0,
    };
  }

  // Convierte un Map de SQLite en un IncidenteModel
  factory IncidenteModel.fromSqlite(Map<String, dynamic> map) {
    return IncidenteModel(
      id:           map['id'] as String,
      descripcion:  map['descripcion'] as String,
      latitud:      map['latitud'] as double,
      longitud:     map['longitud'] as double,
      tipo:         map['tipo'] as String,
      fotoUrl:      map['foto_url'] as String?,
      creadoEn:     DateTime.parse(map['creado_en'] as String),
      sincronizado: (map['sincronizado'] as int) == 1,
    );
  }
}