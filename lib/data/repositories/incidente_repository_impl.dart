import 'package:uuid/uuid.dart';
import '../../domain/entities/incidente.dart';
import '../../domain/repositories/incidente_repository.dart';
import '../datasources/supabase_remote.dart';
import '../datasources/sqlite_local.dart';
import '../models/incidente_model.dart';

class IncidenteRepositoryImpl implements IncidenteRepository {
  final SupabaseRemote _remoto = SupabaseRemote();
  final SqliteLocal    _local  = SqliteLocal();
  final _uuid = const Uuid();

  @override
  Future<List<Incidente>> obtenerIncidentes() async {
    try {
      return await _remoto.obtenerIncidentes();
    } catch (_) {
      return await _local.obtenerTodos();
    }
  }

  @override
  Future<void> guardarIncidente(Incidente incidente) async {
    final modelo = IncidenteModel(
      id:           _uuid.v4(),
      descripcion:  incidente.descripcion,
      latitud:      incidente.latitud,
      longitud:     incidente.longitud,
      tipo:         incidente.tipo,
      fotoUrl:      incidente.fotoUrl,
      creadoEn:     incidente.creadoEn,
      sincronizado: false,
    );

    try {
      await _remoto.insertarIncidente(modelo);
    } catch (_) {
      await _local.guardarIncidente(modelo);
    }
  }

  // Elimina de Supabase — el Realtime lo propaga a todos
  Future<void> eliminarIncidente(String id) async {
    await _remoto.eliminarIncidente(id);
  }

  @override
  Stream<Incidente> escucharIncidentes() {
    // Stream vacío — ahora usamos postgres_changes en mapa_screen
    return const Stream.empty();
  }

  @override
  Future<List<Incidente>> obtenerPendientes() async {
    return await _local.obtenerPendientes();
  }

  @override
  Future<void> sincronizarPendientes() async {
    final pendientes = await _local.obtenerPendientes();
    for (final incidente in pendientes) {
      try {
        await _remoto.insertarIncidente(incidente as IncidenteModel);
        await _local.marcarSincronizado(incidente.id);
      } catch (_) {
        continue;
      }
    }
  }
}