import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _cargando = false;
  bool _modoRegistro = false;
  bool _verPassword = false;
  String _error = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _autenticar() async {
    setState(() {
      _cargando = true;
      _error = '';
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Completa todos los campos';
        _cargando = false;
      });
      return;
    }

    try {
      if (_modoRegistro) {
        final res = await supabase.auth.signUp(
          email: email,
          password: password,
        );
        debugPrint('📋 SignUp: ${res.user?.email}');
      } else {
        final res = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        debugPrint('✅ Login: ${res.user?.email}');
      }

      // Navega inmediatamente después del login exitoso
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      debugPrint('❌ AuthException: ${e.message}');
      setState(() => _error = _traducirError(e.message));
    } catch (e) {
      debugPrint('❌ Error: $e');
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  String _traducirError(String mensaje) {
    if (mensaje.contains('Invalid login credentials')) {
      return 'Correo o contraseña incorrectos';
    }
    if (mensaje.contains('Email not confirmed')) {
      return 'Confirma tu correo antes de ingresar';
    }
    if (mensaje.contains('User already registered')) {
      return 'Este correo ya está registrado';
    }
    if (mensaje.contains('Password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return mensaje;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1B4B),
              Color(0xFF1A237E),
              Color(0xFF0D1B4B),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blueAccent, width: 2),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 48,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'VigiApp',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const Text(
                    'Seguridad ciudadana en tiempo real',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    _modoRegistro ? 'Crear cuenta' : 'Iniciar sesión',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Email
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Correo electrónico',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Contraseña
                  TextField(
                    controller: _passwordController,
                    obscureText: !_verPassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Contraseña',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.lock_outlined,
                          color: Colors.white54),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _verPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white54,
                        ),
                        onPressed: () => setState(
                            () => _verPassword = !_verPassword),
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                  // Error
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade400),
                      ),
                      child: Text(
                        _error,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Botón principal
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _cargando ? null : _autenticar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _cargando
                          ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                          : Text(
                              _modoRegistro ? 'Crear cuenta' : 'Ingresar',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Toggle registro/login
                  TextButton(
                    onPressed: () => setState(() {
                      _modoRegistro = !_modoRegistro;
                      _error = '';
                    }),
                    child: Text(
                      _modoRegistro
                          ? '¿Ya tienes cuenta? Inicia sesión'
                          : '¿No tienes cuenta? Regístrate',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}