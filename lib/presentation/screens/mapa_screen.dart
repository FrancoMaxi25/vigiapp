import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/notificacion_service.dart';
import '../../data/models/incidente_model.dart';
import '../../data/repositories/incidente_repository_impl.dart';
import '../../domain/entities/incidente.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import 'reporte_screen.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final MapController _mapController = MapController();
  final IncidenteRepositoryImpl _repo = IncidenteRepositoryImpl();

  LatLng? _miUbicacion;
  List<Incidente> _incidentes = [];
  bool _cargando = true;
  String _error = '';
  bool _modoMarcador = false;
  LatLng? _marcadorManual;
  bool _canalActivo = false;
  RealtimeChannel? _canal;

  final Set<String> _filtrosActivos = {'peligro', 'transito', 'apoyo'};

  List<Incidente> get _incidentesFiltrados => _incidentes
      .where((i) => _filtrosActivos.contains(i.tipo))
      .toList();

  // Método agregado
  String _tiempoRestante(DateTime creadoEn) {
    final expira = creadoEn.add(const Duration(hours: 24));
    final ahora = DateTime.now();
    final restante = expira.difference(ahora);
    if (restante.isNegative) return 'Expirado';
    if (restante.inHours > 0) {
      return 'Expira en ${restante.inHours}h ${restante.inMinutes.remainder(60)}min';
    }
    return 'Expira en ${restante.inMinutes} min';
  }

  @override
  void initState() {
    super.initState();
    _inicializar();
  }


  Future<void> _inicializar() async {
    // Limpia incidentes expirados al iniciar
    _limpiarExpirados();

    await Future.wait([
      _obtenerUbicacion(),
      _cargarIncidentes(),
    ]);
    _escucharIncidentesNuevos();
  }

  // Elimina de Supabase los incidentes con más de 24 horas
  Future<void> _limpiarExpirados() async {
    try {
      await supabase
          .from('incidentes')
          .delete()
          .lt('expira_en', DateTime.now().toIso8601String());
      debugPrint('🧹 Incidentes expirados eliminados');
    } catch (e) {
      debugPrint('❌ Error limpiando expirados: $e');
    }
  }

  Future<void> _obtenerUbicacion() async {
    try {
      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.deniedForever) {
        setState(() =>
            _error = 'Permiso de ubicación denegado permanentemente.');
        return;
      }
      final posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _miUbicacion = LatLng(posicion.latitude, posicion.longitude);
      });
    } catch (e) {
      setState(() => _error = 'Error al obtener ubicación: $e');
    }
  }

  Future<void> _cargarIncidentes() async {
    try {
      // Primero carga los locales (instantáneo)
      final locales = await _repo.obtenerPendientes();
      if (locales.isNotEmpty && mounted) {
        setState(() {
          _incidentes = locales;
          _cargando   = false;
        });
      }

      // Luego carga de Supabase en segundo plano
      final remotos = await _repo.obtenerIncidentes();
      if (mounted) {
        setState(() {
          _incidentes = remotos;
          _cargando   = false;
        });
        NotificacionService.registrarExistentes(remotos);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error    = 'Sin conexión — mostrando datos locales';
        });
        // Limpia el error después de 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _error = '');
        });
      }
    }
  }

  // Realtime con postgres_changes — funciona entre dispositivos
void _escucharIncidentesNuevos() {
  // Evita crear múltiples canales
  if (_canalActivo) return;
  _canalActivo = true;

  _canal = supabase
      .channel('mapa_canal_vigiapp')
      .onPostgresChanges(
        event:    PostgresChangeEvent.insert,
        schema:   'public',
        table:    'incidentes',
        callback: (payload) async {
          debugPrint('🟢 INSERT recibido');
          try {
            final nuevo = IncidenteModel.fromJson(payload.newRecord);

            if (!mounted) return;

            setState(() {
              final existe = _incidentes.any((i) => i.id == nuevo.id);
              if (!existe) _incidentes.insert(0, nuevo);
            });

            // Notifica solo si no fue ya notificado antes
            if (_miUbicacion != null) {
              await NotificacionService.verificarProximidad(
                incidente:       nuevo,
                latitudUsuario:  _miUbicacion!.latitude,
                longitudUsuario: _miUbicacion!.longitude,
              );
            }
          } catch (e) {
            debugPrint('❌ Error procesando INSERT: $e');
          }
        },
      )
      .onPostgresChanges(
        event:    PostgresChangeEvent.delete,
        schema:   'public',
        table:    'incidentes',
        callback: (payload) {
          debugPrint('🔴 DELETE recibido');
          final id = payload.oldRecord['id'] as String?;
          if (id != null && mounted) {
            setState(() {
              _incidentes.removeWhere((i) => i.id == id);
            });
          }
        },
      )
      .subscribe((status, [error]) {
        debugPrint('📡 Canal status: $status');
      });
}
@override
void dispose() {
  _canal?.unsubscribe();
  super.dispose();
}

  Color _colorTipo(String tipo) {
    switch (tipo) {
      case 'transito': return Colors.yellow;
      case 'apoyo':    return Colors.greenAccent;
      default:         return Colors.redAccent;
    }
  }

  IconData _iconoTipo(String tipo) {
    switch (tipo) {
      case 'transito': return Icons.traffic;
      case 'apoyo':    return Icons.volunteer_activism;
      default:         return Icons.dangerous;
    }
  }

  LatLng _calcularOffset(int index, Incidente incidente) {
    final mismoPunto = _incidentes
        .sublist(0, index)
        .where((i) =>
            (i.latitud  - incidente.latitud).abs()  < 0.0001 &&
            (i.longitud - incidente.longitud).abs() < 0.0001)
        .length;
    return LatLng(
      incidente.latitud  + (mismoPunto * 0.00008),
      incidente.longitud + (mismoPunto * 0.00005),
    );
  }

void _mostrarDetalle(Incidente incidente) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B4B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _colorTipo(incidente.tipo).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _colorTipo(incidente.tipo),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(_iconoTipo(incidente.tipo),
                          color: _colorTipo(incidente.tipo), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        incidente.tipo.toUpperCase(),
                        style: TextStyle(
                          color: _colorTipo(incidente.tipo),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  incidente.creadoEn
                      .toLocal()
                      .toString()
                      .substring(0, 16),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              incidente.descripcion,
              style: const TextStyle(
                  fontSize: 16, color: Colors.white, height: 1.4),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${incidente.latitud.toStringAsFixed(5)}, '
                  '${incidente.longitud.toStringAsFixed(5)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            // Tiempo restante
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                    color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(
                  _tiempoRestante(incidente.creadoEn),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            if (incidente.fotoUrl != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  incidente.fotoUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 180,
                      color: Colors.white10,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 60,
                    color: Colors.white10,
                    child: const Center(
                      child: Text('No se pudo cargar la foto',
                          style: TextStyle(color: Colors.white38)),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF0D1B4B),
                      title: const Text('¿Eliminar reporte?',
                          style: TextStyle(color: Colors.white)),
                      content: const Text(
                        'Esta acción no se puede deshacer.',
                        style: TextStyle(color: Colors.white54),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Eliminar',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirmar == true) {
                    await _repo.eliminarIncidente(incidente.id);
                    if (mounted) Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Reporte eliminado'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 18),
                label: const Text('Eliminar reporte',
                    style: TextStyle(color: Colors.red, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _barraFiltros() {
    final tipos = [
      {'valor': 'peligro',  'label': 'Peligro',  'color': Colors.redAccent,   'icono': Icons.dangerous},
      {'valor': 'transito', 'label': 'Tránsito', 'color': Colors.yellow,      'icono': Icons.traffic},
      {'valor': 'apoyo',    'label': 'Apoyo',    'color': Colors.greenAccent, 'icono': Icons.volunteer_activism},
    ];

    return Container(
      margin:  const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B4B).withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:     Colors.black.withOpacity(0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: tipos.map((tipo) {
          final activo = _filtrosActivos.contains(tipo['valor']);
          final color  = tipo['color'] as Color;
          return GestureDetector(
            onTap: () {
              setState(() {
                if (activo) {
                  if (_filtrosActivos.length > 1) {
                    _filtrosActivos.remove(tipo['valor']);
                  }
                } else {
                  _filtrosActivos.add(tipo['valor'] as String);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin:  const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: activo
                    ? color.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activo ? color : Colors.white24,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(tipo['icono'] as IconData,
                      color: activo ? color : Colors.white38,
                      size: 14),
                  const SizedBox(width: 4),
                  Text(
                    tipo['label'] as String,
                    style: TextStyle(
                      color: activo ? color : Colors.white38,
                      fontSize: 11,
                      fontWeight: activo
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _incidentesFiltrados;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _miUbicacion ?? const LatLng(-16.4090, -71.5375),
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (tapPosition, punto) {
                if (_modoMarcador) {
                  setState(() => _marcadorManual = punto);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.vigiapp',
              ),
              MarkerLayer(
                markers: [
                  if (_miUbicacion != null)
                    Marker(
                      point:  _miUbicacion!,
                      width:  50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.blueAccent, width: 2),
                        ),
                        child: const Icon(Icons.my_location,
                            color: Colors.blueAccent, size: 28),
                      ),
                    ),

                  ...filtrados.asMap().entries.map((entry) {
                    final index     = entry.key;
                    final incidente = entry.value;
                    final punto     =
                        _calcularOffset(index, incidente);
                    final color     = _colorTipo(incidente.tipo);

                    return Marker(
                      point:  punto,
                      width:  44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _mostrarDetalle(incidente),
                        child: Container(
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: color, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius:   8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(_iconoTipo(incidente.tipo),
                              color: color, size: 22),
                        ),
                      ),
                    );
                  }),

                  if (_marcadorManual != null)
                    Marker(
                      point:  _marcadorManual!,
                      width:  44,
                      height: 44,
                      child: const Icon(Icons.push_pin,
                          color: Colors.purpleAccent, size: 36),
                    ),
                ],
              ),
            ],
          ),

          if (_cargando)
            const Center(child: CircularProgressIndicator()),

          if (_error.isNotEmpty)
            Positioned(
              bottom: 20,
              left:   16,
              right:  16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error,
                    style:
                        const TextStyle(color: Colors.white)),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Contador
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1B4B)
                              .withOpacity(0.95),
                          borderRadius:
                              BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '${filtrados.length} de '
                              '${_incidentes.length} incidente(s)',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Botón centrar
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1B4B)
                              .withOpacity(0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.my_location,
                              color: Colors.blueAccent),
                          onPressed: () {
                            if (_miUbicacion != null) {
                              _mapController.move(
                                  _miUbicacion!, 15);
                            }
                          },
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Botón modo marcador manual
                      Container(
                        decoration: BoxDecoration(
                          color: _modoMarcador
                              ? Colors.purpleAccent
                                  .withOpacity(0.9)
                              : const Color(0xFF0D1B4B)
                                  .withOpacity(0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            _modoMarcador
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _modoMarcador = !_modoMarcador;
                              if (!_modoMarcador) {
                                _marcadorManual = null;
                              }
                            });
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                content: Text(_modoMarcador
                                    ? '📍 Toca el mapa para colocar un marcador'
                                    : '📍 Modo marcador desactivado'),
                                duration: const Duration(
                                    seconds: 2),
                                backgroundColor: _modoMarcador
                                    ? Colors.purpleAccent
                                    : Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                _barraFiltros(),
              ],
            ),
          ),

          // Botón usar marcador manual
          if (_marcadorManual != null)
            Positioned(
              bottom: 20,
              left:   16,
              right:  16,
              child: ElevatedButton.icon(
                onPressed: () {
                  final lat = _marcadorManual!.latitude;
                  final lon = _marcadorManual!.longitude;

                  setState(() {
                    _modoMarcador   = false;
                    _marcadorManual = null;
                  });

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReporteScreen(
                        latitudManual:  lat,
                        longitudManual: lon,
                      ),
                    ),
                  );
                },
                icon:  const Icon(Icons.send),
                label: const Text(
                    'Usar esta ubicación para reportar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
