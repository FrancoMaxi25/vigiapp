# VigiApp

Aplicación móvil multiplataforma desarrollada en **Flutter** para el registro, geolocalización y seguimiento de reportes e incidencias en tiempo real, diseñada con arquitectura **offline-first** para operar incluso sin conexión a internet.

## Características principales

- **Geolocalización y mapas interactivos:** obtención de coordenadas GPS en tiempo real y visualización sobre mapas con flutter_map y geolocator.
- **Registro multimedia:** captura fotográfica desde cámara o selección desde galería mediante image_picker con control de permisos en tiempo de ejecución.
- **Arquitectura Offline-First:** almacenamiento local estructurado en **SQLite** (sqflite) y preferencias persistentes (shared_preferences), con sincronización hacia la nube.
- **Backend en la nube:** autenticación, base de datos y almacenamiento gestionados con **Supabase** (supabase_flutter).
- **Notificaciones locales:** alertas y confirmaciones de estado en el dispositivo mediante flutter_local_notifications.

## Stack tecnológico

- **Framework:** Flutter / Dart (^3.11.5)
- **Backend / BaaS:** Supabase
- **Base de datos local:** SQLite (sqflite)
- **Mapas y ubicación:** flutter_map, latlong2, geolocator
- **Multimedia y sistema:** image_picker, permission_handler, flutter_local_notifications

## Ejecución local

1. Clonar el repositorio: git clone [https://github.com/FrancoMaxi25/vigiapp.git](https://github.com/FrancoMaxi25/vigiapp.git)
2. Instalar dependencias: flutter pub get
3. Ejecutar en emulador o dispositivo físico: flutter run
