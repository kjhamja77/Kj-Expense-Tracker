import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static Database? db;

  Future<Database> get database async{
    db??=await open();
    return db!;
  }

  Future<Database> open()async{
    final path = join(await getDatabasesPath(),'incash_tracker.db');
    return openDatabase(path,version: 1, onCreate: (db,version) async{
      await db.execute(
        '''
        CREATE TABLE cash_transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        note TEXT,
        time INTEGER NOT NULL
        )
      '''
      );
      await db.execute(
          'CREATE INDEX idx_cash_time ON cash_transactions(time)'
      );
    });
  }

}