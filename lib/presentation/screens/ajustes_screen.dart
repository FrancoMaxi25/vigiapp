import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/notificacion_service.dart';
import '../../data/datasources/sqlite_local.dart';
import '../../data/repositories/incidente_repository_impl.dart';
import '../../main.dart';

class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  final SqliteLocal _sqlite = SqliteLocal();
  final IncidenteRepositoryImpl _repo = IncidenteRepositoryImpl();

  double _radioAlertas = 2.0;
  int    _pendientes   = 0;
  bool   _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
    _contarPendientes();
  }

  Future<void> _cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _radioAlertas = prefs.getDouble('radio_alertas') ?? 2.0;
    });
  }

  Future<void> _guardarRadio(double valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('radio_alertas', valor);
    setState(() => _radioAlertas = valor);
  }

  Future<void> _contarPendientes() async {
    final total = await _sqlite.contarPendientes();
    setState(() => _pendientes = total);
  }

  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    try {
      await _repo.sincronizarPendientes();
      await _contarPendientes();
      _mostrarMensaje('✅ Sincronización completada', Colors.green);
    } catch (e) {
      _mostrarMensaje('❌ Error al sincronizar: $e', Colors.red);
    } finally {
      setState(() => _sincronizando = false);
    }
  }

  void _mostrarMensaje(String texto, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(texto),
        backgroundColor: color,
        duration:        const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: const Color(0xFF1A237E),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Radio de alertas ──────────────────────────────────
            _seccionTitulo(Icons.radar, 'Radio de alertas'),
            const SizedBox(height: 8),
            const Text(
              'Recibirás una notificación cuando un incidente ocurra '
              'dentro de este radio desde tu ubicación.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),

            Center(
              child: Column(
                children: [
                  Text(
                    '${_radioAlertas.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const Text('radio de alerta',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Slider(
              value:        _radioAlertas,
              min:          0.5,
              max:          10.0,
              divisions:    19,
              activeColor:  Colors.blueAccent,
              inactiveColor: Colors.white24,
              label:        '${_radioAlertas.toStringAsFixed(1)} km',
              onChanged:    _guardarRadio,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0.5 km',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 11)),
                  Text('5 km',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 11)),
                  Text('10 km',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Divider(color: Colors.white12),
            const SizedBox(height: 24),

            // ── Sincronización offline ────────────────────────────
            _seccionTitulo(Icons.sync, 'Sincronización offline'),
            const SizedBox(height: 8),
            const Text(
              'Los reportes enviados sin internet se guardan localmente '
              'y se sincronizan automáticamente al recuperar la conexión.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _pendientes > 0
                    ? Colors.orange.withOpacity(0.15)
                    : Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _pendientes > 0
                      ? Colors.orange
                      : Colors.green,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _pendientes > 0
                        ? Icons.cloud_off
                        : Icons.cloud_done,
                    color: _pendientes > 0
                        ? Colors.orange
                        : Colors.green,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pendientes > 0
                              ? '$_pendientes reporte(s) pendiente(s)'
                              : 'Todo sincronizado',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _pendientes > 0
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ),
                        Text(
                          _pendientes > 0
                              ? 'Esperando conexión a internet'
                              : 'No hay reportes pendientes',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Forzar sincronización
            SizedBox(
              width:  double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _sincronizando ? null : _sincronizar,
                icon: _sincronizando
                    ? const SizedBox(
                        width:  18,
                        height: 18,
                        child:  CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync),
                label: Text(_sincronizando
                    ? 'Sincronizando...'
                    : 'Forzar sincronización'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Actualizar conteo
            SizedBox(
              width:  double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _contarPendientes,
                icon:  const Icon(Icons.refresh),
                label: const Text('Actualizar conteo'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Probar notificación
            SizedBox(
              width:  double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await NotificacionService.mostrar(
                    id:     999,
                    titulo: '🔴 PELIGRO cerca de ti',
                    cuerpo: 'Prueba de notificación de VigiApp '
                        'funcionando correctamente.',
                  );
                },
                icon: const Icon(Icons.notifications_active,
                    color: Colors.amber),
                label: const Text('Probar notificación'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.amber),
                  foregroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(color: Colors.white12),
            const SizedBox(height: 24),

            // ── Acerca de VigiApp ─────────────────────────────────
            _seccionTitulo(Icons.info_outline, 'Acerca de VigiApp'),
            const SizedBox(height: 16),

            _infoItem('Versión',        '1.0.0'),
            _infoItem('Base de datos',  'Supabase + SQLite'),
            _infoItem('Mapas',          'OpenStreetMap (gratuito)'),
            _infoItem('Desarrollado por', 'Franco Maxi\nImanol Mollehuanca'),

            const SizedBox(height: 24),
            const Divider(color: Colors.white12),
            const SizedBox(height: 24),

            // Cerrar sesión
            SizedBox(
              width:  double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF0D1B4B),
                      title: const Text('¿Cerrar sesión?',
                          style: TextStyle(color: Colors.white)),
                      content: const Text(
                        '¿Estás seguro que deseas salir?',
                        style: TextStyle(color: Colors.white54),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, true),
                          child: const Text('Salir',
                              style:
                                  TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmar == true) {
                    await supabase.auth.signOut();
                  }
                },
                icon:  const Icon(Icons.logout, color: Colors.white),
                label: const Text('Cerrar sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _seccionTitulo(IconData icono, String titulo) {
    return Row(
      children: [
        Icon(icono, color: Colors.blueAccent, size: 20),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _infoItem(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 13)),
          Text(valor,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}