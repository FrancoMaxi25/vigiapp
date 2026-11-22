import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/incidente.dart';
import '../../data/repositories/incidente_repository_impl.dart';
import '../../core/utils/speech_service.dart';
import '../../main.dart';

class ReporteScreen extends StatefulWidget {
  final double? latitudManual;
  final double? longitudManual;

  const ReporteScreen({
    super.key,
    this.latitudManual,
    this.longitudManual,
  });

  @override
  State<ReporteScreen> createState() => _ReporteScreenState();
}

class _ReporteScreenState extends State<ReporteScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _descripcionController = TextEditingController();
  final IncidenteRepositoryImpl _repo = IncidenteRepositoryImpl();
  final ImagePicker _picker = ImagePicker();

  String _tipoSeleccionado = 'peligro';
  File?  _fotoSeleccionada;
  bool   _enviando         = false;
  String _estadoGps        = 'Obteniendo ubicación...';
  Position? _posicionActual;

  // Coordenadas manuales
  bool   _posicionManual = false;
  double _latManual      = 0.0;
  double _lonManual      = 0.0;

  // Micrófono
  bool _grabando = false;
  late AnimationController _micAnimController;
  late Animation<double>   _micEscala;

  @override
  void initState() {
    super.initState();

    // Si vienen coordenadas manuales las usamos directamente
    if (widget.latitudManual != null && widget.longitudManual != null) {
      _posicionManual = true;
      _latManual      = widget.latitudManual!;
      _lonManual      = widget.longitudManual!;
      _estadoGps      = '📍 Ubicación manual: '
          '${_latManual.toStringAsFixed(5)}, '
          '${_lonManual.toStringAsFixed(5)}';
    } else {
      _obtenerUbicacion();
    }

    _micAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _micEscala = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _micAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _micAnimController.dispose();
    super.dispose();
  }

  Future<void> _obtenerUbicacion() async {
    try {
      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      final posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _posicionActual = posicion;
        _estadoGps      = 'Lat: ${posicion.latitude.toStringAsFixed(5)}, '
            'Lon: ${posicion.longitude.toStringAsFixed(5)}';
      });
    } catch (e) {
      setState(() => _estadoGps = 'Error al obtener GPS');
    }
  }
  
Future<void> _toggleMicrofono() async {
  if (_grabando) {
    await SpeechService.detener();
    setState(() => _grabando = false);
    _micAnimController.stop();
    _micAnimController.reset();
    return;
  }

  setState(() => _grabando = true);
  _micAnimController.repeat(reverse: true);

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎤 Habla ahora claramente...'),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 3),
      ),
    );
  }

  final texto = await SpeechService.escuchar();

  if (!mounted) return;

  setState(() => _grabando = false);
  _micAnimController.stop();
  _micAnimController.reset();

  if (texto != null && texto.isNotEmpty) {
    setState(() {
      _descripcionController.text =
          _descripcionController.text.isEmpty
              ? texto
              : '${_descripcionController.text} $texto';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Transcrito: "$texto"'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '❌ No se detectó voz. Habla más cerca del micrófono e intenta de nuevo.',
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }
}

  Future<void> _seleccionarFoto(ImageSource fuente) async {
    final XFile? foto = await _picker.pickImage(
      source:       fuente,
      imageQuality: 70,
      maxWidth:     1024,
    );
    if (foto != null) {
      setState(() => _fotoSeleccionada = File(foto.path));
    }
  }

  Future<String?> _subirFoto() async {
    if (_fotoSeleccionada == null) return null;
    try {
      final nombre = '${const Uuid().v4()}.jpg';
      final bytes  = await _fotoSeleccionada!.readAsBytes();

      await supabase.storage
          .from('evidencias')
          .uploadBinary(nombre, bytes,
              fileOptions:
                  const FileOptions(contentType: 'image/jpeg'));

      return supabase.storage.from('evidencias').getPublicUrl(nombre);
    } catch (e) {
      debugPrint('❌ Error al subir foto: $e');
      return null;
    }
  }

  Future<void> _enviarReporte() async {
    if (_descripcionController.text.trim().isEmpty) {
      _mostrarMensaje('Escribe o dicta una descripción', Colors.orange);
      return;
    }

    if (!_posicionManual && _posicionActual == null) {
      _mostrarMensaje(
          'Espera a que el GPS obtenga tu ubicación', Colors.orange);
      return;
    }

    setState(() => _enviando = true);

    try {
      final fotoUrl = await _subirFoto();

      final lat = _posicionManual ? _latManual : _posicionActual!.latitude;
      final lon = _posicionManual ? _lonManual : _posicionActual!.longitude;

      final incidente = Incidente(
        id:          const Uuid().v4(),
        descripcion: _descripcionController.text.trim(),
        latitud:     lat,
        longitud:    lon,
        tipo:        _tipoSeleccionado,
        fotoUrl:     fotoUrl,
        creadoEn:    DateTime.now(),
      );

      await _repo.guardarIncidente(incidente);
      _mostrarMensaje('✅ Reporte enviado correctamente', Colors.green);

      setState(() {
        _descripcionController.clear();
        _fotoSeleccionada = null;
        _tipoSeleccionado = 'peligro';
      });

      // Si vino del mapa con coordenadas manuales, regresa al mapa
      if (_posicionManual && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _mostrarMensaje('❌ Error al enviar: $e', Colors.red);
    } finally {
      setState(() => _enviando = false);
    }
  }

  void _mostrarMensaje(String texto, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:          Text(texto),
        backgroundColor:  color,
        duration:         const Duration(seconds: 3),
      ),
    );
  }

  Widget _selectorTipo() {
    final tipos = [
      {'valor': 'peligro',  'label': 'Peligro',  'icono': Icons.dangerous,         'color': Colors.redAccent},
      {'valor': 'transito', 'label': 'Tránsito', 'icono': Icons.traffic,           'color': Colors.yellow},
      {'valor': 'apoyo',    'label': 'Apoyo',    'icono': Icons.volunteer_activism, 'color': Colors.greenAccent},
    ];

    return Row(
      children: tipos.map((tipo) {
        final seleccionado = _tipoSeleccionado == tipo['valor'];
        final color        = tipo['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(
                () => _tipoSeleccionado = tipo['valor'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin:  const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: seleccionado
                    ? color.withOpacity(0.2)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: seleccionado ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(tipo['icono'] as IconData,
                      color: seleccionado ? color : Colors.white38,
                      size: 28),
                  const SizedBox(height: 4),
                  Text(tipo['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: seleccionado ? color : Colors.white38,
                        fontWeight: seleccionado
                            ? FontWeight.bold
                            : FontWeight.normal,
                      )),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_posicionManual
            ? 'Reportar — Ubicación manual'
            : 'Reportar Incidente'),
        backgroundColor: const Color(0xFF1A237E),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // GPS / Ubicación manual
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_posicionActual != null || _posicionManual)
                    ? Colors.green.withOpacity(0.15)
                    : Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_posicionActual != null || _posicionManual)
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _posicionManual ? Icons.push_pin : Icons.gps_fixed,
                    color: (_posicionActual != null || _posicionManual)
                        ? Colors.green
                        : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_estadoGps,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  if (!_posicionManual && _posicionActual == null)
                    GestureDetector(
                      onTap: _obtenerUbicacion,
                      child: const Text('Reintentar',
                          style: TextStyle(
                              color: Colors.orange, fontSize: 12)),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tipo
            const Text('Tipo de incidente',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            _selectorTipo(),

            const SizedBox(height: 20),

            // Descripción + micrófono
            Row(
              children: [
                const Text('Descripción',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                Text(
                  _grabando
                      ? '🔴 Grabando...'
                      : '🎤 Presiona para dictar',
                  style: TextStyle(
                    fontSize: 11,
                    color: _grabando
                        ? Colors.redAccent
                        : Colors.white38,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Stack(
              children: [
                TextField(
                  controller: _descripcionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Describe el incidente o usa el micrófono...',
                    filled:      true,
                    fillColor:   Colors.white10,
                    contentPadding:
                        const EdgeInsets.fromLTRB(16, 16, 60, 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                Positioned(
                  right:  8,
                  bottom: 8,
                  child: GestureDetector(
                    onTap: () => _toggleMicrofono(),
                    child: AnimatedBuilder(
                      animation: _micAnimController,
                      builder: (_, child) => Transform.scale(
                        scale: _grabando ? _micEscala.value : 1.0,
                        child: child,
                      ),
                      child: Container(
                        width:  44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _grabando
                              ? Colors.redAccent
                              : Colors.blueAccent,
                          shape: BoxShape.circle,
                          boxShadow: _grabando
                              ? [
                                  BoxShadow(
                                    color: Colors.redAccent
                                        .withOpacity(0.5),
                                    blurRadius:  12,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [],
                        ),
                        child: Icon(
                          _grabando ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size:  22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Foto
            const Text('Foto de evidencia',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),

            if (_fotoSeleccionada != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _fotoSeleccionada!,
                  height: 180,
                  width:  double.infinity,
                  fit:    BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _fotoSeleccionada = null),
                icon:  const Icon(Icons.delete, color: Colors.red),
                label: const Text('Eliminar foto',
                    style: TextStyle(color: Colors.red)),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _seleccionarFoto(ImageSource.camera),
                      icon:  const Icon(Icons.camera_alt),
                      label: const Text('Cámara'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        side: const BorderSide(color: Colors.white30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _seleccionarFoto(ImageSource.gallery),
                      icon:  const Icon(Icons.photo_library),
                      label: const Text('Galería'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        side: const BorderSide(color: Colors.white30),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 28),

            // Botón enviar
            SizedBox(
              width:  double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _enviando ? null : _enviarReporte,
                icon: _enviando
                    ? const SizedBox(
                        width:  20,
                        height: 20,
                        child:  CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(
                    _enviando ? 'Enviando...' : 'Enviar Reporte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}