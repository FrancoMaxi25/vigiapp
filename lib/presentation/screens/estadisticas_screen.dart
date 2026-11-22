import 'package:flutter/material.dart';
import '../../data/repositories/incidente_repository_impl.dart';
import '../../domain/entities/incidente.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  final IncidenteRepositoryImpl _repo = IncidenteRepositoryImpl();

  List<Incidente> _incidentes = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final lista = await _repo.obtenerIncidentes();
      setState(() {
        _incidentes = lista;
        _cargando   = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
    }
  }

  // Contadores por tipo
  int get _totalPeligro  => _incidentes.where((i) => i.tipo == 'peligro').length;
  int get _totalTransito => _incidentes.where((i) => i.tipo == 'transito').length;
  int get _totalApoyo    => _incidentes.where((i) => i.tipo == 'apoyo').length;
  int get _total         => _incidentes.length;

  // Porcentaje por tipo
  double _porcentaje(int cantidad) {
    if (_total == 0) return 0;
    return cantidad / _total;
  }

  // Últimas 24 horas
  int get _ultimas24h {
    final ahora  = DateTime.now();
    final limite = ahora.subtract(const Duration(hours: 24));
    return _incidentes
        .where((i) => i.creadoEn.isAfter(limite))
        .length;
  }

  // Incidente más reciente
  Incidente? get _masReciente {
    if (_incidentes.isEmpty) return null;
    return _incidentes.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        backgroundColor: const Color(0xFF1A237E),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _cargando = true);
              _cargarDatos();
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Resumen general ───────────────────────────
                    _seccionTitulo(Icons.bar_chart, 'Resumen general'),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _tarjetaResumen(
                            titulo: 'Total',
                            valor:  '$_total',
                            icono:  Icons.location_pin,
                            color:  Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _tarjetaResumen(
                            titulo: 'Últimas 24h',
                            valor:  '$_ultimas24h',
                            icono:  Icons.access_time,
                            color:  Colors.purpleAccent,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Distribución por tipo ─────────────────────
                    _seccionTitulo(Icons.pie_chart, 'Distribución por tipo'),
                    const SizedBox(height: 12),

                    _barraEstadistica(
                      label:     'Peligro',
                      cantidad:  _totalPeligro,
                      porcentaje: _porcentaje(_totalPeligro),
                      color:     Colors.redAccent,
                      icono:     Icons.dangerous,
                    ),
                    const SizedBox(height: 10),
                    _barraEstadistica(
                      label:     'Tránsito',
                      cantidad:  _totalTransito,
                      porcentaje: _porcentaje(_totalTransito),
                      color:     Colors.yellow,
                      icono:     Icons.traffic,
                    ),
                    const SizedBox(height: 10),
                    _barraEstadistica(
                      label:     'Apoyo',
                      cantidad:  _totalApoyo,
                      porcentaje: _porcentaje(_totalApoyo),
                      color:     Colors.greenAccent,
                      icono:     Icons.volunteer_activism,
                    ),

                    const SizedBox(height: 28),

                    // ── Indicadores visuales ──────────────────────
                    _seccionTitulo(Icons.insights, 'Indicadores'),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _tarjetaResumen(
                            titulo: 'Peligro',
                            valor:  '$_totalPeligro',
                            icono:  Icons.dangerous,
                            color:  Colors.redAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _tarjetaResumen(
                            titulo: 'Tránsito',
                            valor:  '$_totalTransito',
                            icono:  Icons.traffic,
                            color:  Colors.yellow,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _tarjetaResumen(
                            titulo: 'Apoyo',
                            valor:  '$_totalApoyo',
                            icono:  Icons.volunteer_activism,
                            color:  Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Incidente más reciente ────────────────────
                    if (_masReciente != null) ...[
                      _seccionTitulo(
                          Icons.notification_important, 'Más reciente'),
                      const SizedBox(height: 12),
                      _tarjetaIncidente(_masReciente!),
                    ],

                    const SizedBox(height: 28),

                    // ── Lista reciente ────────────────────────────
                    _seccionTitulo(Icons.list_alt, 'Últimos reportes'),
                    const SizedBox(height: 12),

                    ..._incidentes.take(5).map(
                          (i) => _itemReciente(i),
                        ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Widgets reutilizables ────────────────────────────────────────

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

  Widget _tarjetaResumen({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            titulo,
            style: const TextStyle(
                color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _barraEstadistica({
    required String label,
    required int cantidad,
    required double porcentaje,
    required Color color,
    required IconData icono,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: color, size: 16),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13)),
              const Spacer(),
              Text(
                '$cantidad  (${(porcentaje * 100).toStringAsFixed(1)}%)',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: porcentaje,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaIncidente(Incidente incidente) {
    final color = incidente.tipo == 'peligro'
        ? Colors.redAccent
        : incidente.tipo == 'transito'
            ? Colors.yellow
            : Colors.greenAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  incidente.tipo.toUpperCase(),
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
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
          const SizedBox(height: 10),
          Text(
            incidente.descripcion,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on,
                  color: Colors.white38, size: 12),
              const SizedBox(width: 4),
              Text(
                '${incidente.latitud.toStringAsFixed(4)}, '
                '${incidente.longitud.toStringAsFixed(4)}',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemReciente(Incidente incidente) {
    final color = incidente.tipo == 'peligro'
        ? Colors.redAccent
        : incidente.tipo == 'transito'
            ? Colors.yellow
            : Colors.greenAccent;

    final icono = incidente.tipo == 'peligro'
        ? Icons.dangerous
        : incidente.tipo == 'transito'
            ? Icons.traffic
            : Icons.volunteer_activism;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: color, size: 18),
          ),
          const SizedBox(width: 12),
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
            const Icon(Icons.photo, color: Colors.white38, size: 16),
        ],
      ),
    );
  }
}