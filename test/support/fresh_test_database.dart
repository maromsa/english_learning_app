// test/support/fresh_test_database.dart
//
// AppDatabase.instance is a process-wide singleton normally backed by a
// real on-disk SQLite file (via sqflite_common_ffi on desktop/CI). Under
// `flutter test`'s default concurrency, multiple test files touching that
// same fixed file path at once can deadlock the whole run (observed as a
// 10-minute timeout on Windows) — and even without that, closing the
// connection alone leaves the file's rows in place, so the next test
// silently inherits whatever a previous one left behind.
//
// resetAppDatabaseForTest() switches AppDatabase to an in-memory database
// instead: private to its own connection, never touches disk, and is
// always empty on open — sidestepping both problems at once. Call it at
// the start of every test (or a setUp) that touches AppDatabase, directly
// or indirectly via SrsService's default `db`.

import 'package:english_learning_app/services/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// sqfliteFfiInit() spins up the native FFI bindings' background isolate and
// is meant to run once per process — calling it again on every test (as a
// naive per-test reset would) accumulates isolates/native handles and can
// deadlock the whole run after enough repetitions (observed as a
// consistently-reproducible 10-minute hang around the 9th/10th test in a
// single file). Guard it so only the first call actually initializes.
bool _ffiInitialized = false;

Future<AppDatabase> resetAppDatabaseForTest() async {
  if (!_ffiInitialized) {
    sqfliteFfiInit();
    _ffiInitialized = true;
  }
  databaseFactory = databaseFactoryFfi;
  AppDatabase.useInMemoryDatabaseForTests = true;

  final db = AppDatabase.instance;
  await db.close();

  return db;
}
