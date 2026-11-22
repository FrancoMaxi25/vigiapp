import '../entities/incidente.dart';

abstract class IncidenteRepository {
  Future<List<Incidente>> obtenerIncidentes();
  Future<void> guardarIncidente(Incidente incidente);
  Stream<Incidente> escucharIncidentes();
  Future<List<Incidente>> obtenerPendientes();
  Future<void> sincronizarPendientes();
  Future<void> eliminarIncidente(String id); // ← agrega esta línea
}