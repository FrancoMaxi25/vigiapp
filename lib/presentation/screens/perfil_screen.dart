import 'package:flutter/material.dart';
import '../../data/repositories/incidente_repository_impl.dart';
import '../../domain/entities/incidente.dart';
import '../../main.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final IncidenteRepositoryImpl _repo = IncidenteRepositoryImpl();

  List<Incidente> _misReportes = [];
  bool _cargando = true;

  String get _email =>
      supabase.auth.currentUser?.email ?? 'Sin correo';

  String get _iniciales {
    if (_email.isEmpty) return '?';
    return _email[0].toUpperCase();
  }

  String get _miembroDesde {
    final fecha = supabase.auth.currentUser?.createdAt;
    if (fecha == null) return 'Desconocido';
    final dt = DateTime.parse(fecha);
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  void initState() {
    super.initState();
    _cargarMisReportes();
  }

  Future<void> _cargarMisReportes() async {
    try {
      final todos = await _repo.obtenerIncidentes();
      setState(() {
        _misReportes = todos;
        _cargando    = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
    }
  }

  int get _totalPeligro  => _misReportes.where((i) => i.tipo == 'peligro').length;
  int get _totalTransito => _misReportes.where((i) => i.tipo == 'transito').length;
  int get _totalApoyo    => _misReportes.where((i) => i.tipo == 'apoyo').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: const Color(0xFF1A237E),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF0D1B4B),
                  title: const Text('¿Cerrar sesión?',
                      style: TextStyle(color: Colors.white)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Salir',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirmar == true) {
                await supabase.auth.signOut();
              }
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [

                  // Avatar
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.blueAccent, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _iniciales,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Email
                  Text(
                    _email,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Miembro desde $_miembroDesde',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),

                  const SizedBox(height: 28),

                  // Stats del usuario
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Mis reportes en la comunidad',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: [
                            _statItem(
                              '${_misReportes.length}',
                              'Total',
                              Icons.location_pin,
                              Colors.blueAccent,
                            ),
                            _statItem(
                              '$_totalPeligro',
                              'Peligro',
                              Icons.dangerous,
                              Colors.redAccent,
                            ),
                            _statItem(
                              '$_totalTransito',
                              'Tránsito',
                              Icons.traffic,
                              Colors.yellow,
                            ),
                            _statItem(
                              '$_totalApoyo',
                              'Apoyo',
                              Icons.volunteer_activism,
                              Colors.greenAccent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Lista de mis reportes
                  if (_misReportes.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.history,
                            color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Historial de reportes',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._misReportes.take(10).map((i) => _itemReporte(i)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _statItem(
      String valor, String label, IconData icono, Color color) {
    return Column(
      children: [
        Icon(icono, color: color, size: 24),
        const SizedBox(height: 6),
        Text(valor,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            )),
        Text(label,
            style: const TextStyle(
                color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _itemReporte(Incidente incidente) {
    final color = incidente.tipo == 'peligro'
        ? Colors.redAccent
        : incidente.tipo == 'transito'
            ? Colors.yellow
            : Colors.greenAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 10),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incidente.descripcion,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  incidente.creadoEn
                      .toLocal()
                      .toString()
                      .substring(0, 16),
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          if (incidente.fotoUrl != null)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.photo,
                  color: Colors.white38, size: 16),
            ),
        ],
      ),
    );
  }
}