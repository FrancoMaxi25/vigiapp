import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/utils/notificacion_service.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/mapa_screen.dart';
import 'presentation/screens/reporte_screen.dart';
import 'presentation/screens/ajustes_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/estadisticas_screen.dart';
import 'presentation/screens/perfil_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xoinqirwyyxrrntlxwoj.supabase.co',
    anonKey: 'sb_publishable_om5OKJL4ZU6ywH0JI79kwQ___1L6WMd',
  );

  await NotificacionService.inicializar();

  runApp(const VigiApp());
}

final supabase = Supabase.instance.client;

class VigiApp extends StatelessWidget {
  const VigiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VigiApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        if (session != null) {
          return const MainNavigation();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    MapaScreen(),
    ReporteScreen(),
    EstadisticasScreen(),
    PerfilScreen(),
    AjustesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _iniciarRealtimeGlobal();
  }

  // WebSocket global — activo en toda la app siempre
  void _iniciarRealtimeGlobal() {
  supabase
      .channel('incidentes_canal')
      .onPostgresChanges(
        event:  PostgresChangeEvent.insert,
        schema: 'public',
        table:  'incidentes',
        callback: (payload) {
          debugPrint('🟢 Nuevo incidente recibido: ${payload.newRecord}');
        },
      )
      .onPostgresChanges(
        event:  PostgresChangeEvent.delete,
        schema: 'public',
        table:  'incidentes',
        callback: (payload) {
          debugPrint('🔴 Incidente eliminado: ${payload.oldRecord}');
        },
      )
      .subscribe();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.report_outlined),
            selectedIcon: Icon(Icons.report),
            label: 'Reportar',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}