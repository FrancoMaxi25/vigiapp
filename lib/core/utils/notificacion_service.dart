import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/incidente.dart';

class NotificacionService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _inicializado = false;

  // Set en memoria de IDs ya notificados en esta sesión
  static final Set<String> _yaNotificados = {};

  static Future<void> inicializar() async {
    if (_inicializado) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    // Asignamos a variable primero para evitar el error de parsing
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    _inicializado = true;
  }

  static Future<void> mostrar({
    required int id,
    required String titulo,
    required String cuerpo,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'vigiapp_canal',
      'Alertas VigiApp',
      channelDescription: 'Notificaciones de incidentes cercanos',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, titulo, cuerpo, details);
  }

  static Future<void> verificarProximidad({
    required Incidente incidente,
    required double latitudUsuario,
    required double longitudUsuario,
  }) async {
    // Si ya notificamos este incidente en esta sesión, ignorar
    if (_yaNotificados.contains(incidente.id)) return;

    final prefs = await SharedPreferences.getInstance();
    final radioKm = prefs.getDouble('radio_alertas') ?? 2.0;
    final radioMetros = radioKm * 1000;

    final distancia = Geolocator.distanceBetween(
      latitudUsuario,
      longitudUsuario,
      incidente.latitud,
      incidente.longitud,
    );

    if (distancia <= radioMetros) {
      final distanciaTexto = distancia < 1000
          ? '${distancia.toStringAsFixed(0)} m'
          : '${(distancia / 1000).toStringAsFixed(1)} km';

      final tipoTexto = {
        'peligro':  '🔴 PELIGRO',
        'transito': '🟡 TRÁNSITO',
        'apoyo':    '🟢 APOYO',
      }[incidente.tipo] ?? '⚠️ INCIDENTE';

      await mostrar(
        id: incidente.hashCode,
        titulo: '$tipoTexto cerca de ti',
        cuerpo: '${incidente.descripcion} — a $distanciaTexto de tu ubicación.',
      );

      // Marca como notificado para no repetir
      _yaNotificados.add(incidente.id);
    }
  }

  // Registra incidentes existentes al iniciar la app
  // para que NO disparen notificación (solo los nuevos deben notificar)
  static void registrarExistentes(List<Incidente> incidentes) {
    for (final i in incidentes) {
      _yaNotificados.add(i.id);
    }
  }
}