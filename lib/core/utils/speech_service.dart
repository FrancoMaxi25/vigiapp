import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechService {
  static const _canal = MethodChannel('com.vigiapp/speech');

  // Solicita permiso de micrófono antes de escuchar
  static Future<bool> _solicitarPermiso() async {
    final estado = await Permission.microphone.status;

    if (estado.isGranted) return true;

    if (estado.isDenied) {
      final resultado = await Permission.microphone.request();
      return resultado.isGranted;
    }

    if (estado.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    return false;
  }

  static Future<String?> escuchar() async {
    // Verifica permiso primero
    final tienePermiso = await _solicitarPermiso();
    if (!tienePermiso) return null;

    try {
      final texto = await _canal
          .invokeMethod<String>('iniciarReconocimiento')
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );
      return texto;
    } on PlatformException catch (e) {
      if (e.code == 'NO_DISPONIBLE') return null;
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> detener() async {
    try {
      await _canal.invokeMethod('detenerReconocimiento');
    } catch (_) {}
  }
}