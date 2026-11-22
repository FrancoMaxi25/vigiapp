import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/incidente_model.dart';
import '../../main.dart';

class SupabaseRemote {

  Future<List<IncidenteModel>> obtenerIncidentes() async {
    final response = await supabase
        .from('incidentes')
        .select()
        .order('creado_en', ascending: false);

    return (response as List)
        .map((json) => IncidenteModel.fromJson(json))
        .toList();
  }

  Future<void> insertarIncidente(IncidenteModel incidente) async {
    await supabase
        .from('incidentes')
        .insert(incidente.toJson());
  }

  Future<void> eliminarIncidente(String id) async {
    await supabase
        .from('incidentes')
        .delete()
        .eq('id', id);
  }
}