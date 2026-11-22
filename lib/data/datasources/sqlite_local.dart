import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/incidente_model.dart';

class SqliteLocal {
  static Database? _db;

  // Inicializar la base de datos local
  Future<Database> get db async {
    _db ??= await _inicializar();
    return _db!;
  }

  Future<Database> _inicializar() async {
    final ruta = join(await getDatabasesPath(), 'vigiapp.db');
    return openDatabase(
      ruta,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE incidentes (
            id           TEXT PRIMARY KEY,
            descripcion  TEXT NOT NULL,
            latitud      REAL NOT NULL,
            longitud     REAL NOT NULL,
            tipo         TEXT NOT NULL,
            foto_url     TEXT,
            creado_en    TEXT NOT NULL,
            sincronizado INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  // Guardar incidente localmente (modo offline)
  Future<void> guardarIncidente(IncidenteModel incidente) async {
    final database = await db;
    await database.insert(
      'incidentes',
      incidente.toSqlite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Obtener todos los incidentes guardados localmente
  Future<List<IncidenteModel>> obtenerTodos() async {
    final database = await db;
    final maps = await database.query(
      'incidentes',
      orderBy: 'creado_en DESC',
    );
    return maps.map((m) => IncidenteModel.fromSqlite(m)).toList();
  }

  // Obtener solo los incidentes pendientes de sincronizar
  Future<List<IncidenteModel>> obtenerPendientes() async {
    final database = await db;
    final maps = await database.query(
      'incidentes',
      where: 'sincronizado = ?',
      whereArgs: [0],
    );
    return maps.map((m) => IncidenteModel.fromSqlite(m)).toList();
  }

  // Marcar un incidente como sincronizado
  Future<void> marcarSincronizado(String id) async {
    final database = await db;
    await database.update(
      'incidentes',
      {'sincronizado': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Contar incidentes pendientes (para mostrar en pantalla Ajustes)
  Future<int> contarPendientes() async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as total FROM incidentes WHERE sincronizado = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}