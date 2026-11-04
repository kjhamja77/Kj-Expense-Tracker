import 'package:exp_track/models/cash_model.dart';
import 'package:exp_track/services/app_database.dart';

class CashTranscationDao {
  static const table = 'cash_transactions';

  //Create row in db
  Future<int> insert(CashTransactionModel t) async{
    final db = await AppDatabase.instance.database;
    return db.insert(table, t.toMap()..remove('id'));
  }

  // READ: date range, newest first
  Future<List<CashTransactionModel>> getBetween(DateTime start, DateTime end) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      table,
      where: 'time >= ? AND time < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'time DESC',
    );
    return rows.map(CashTransactionModel.fromMap).toList();
  }

  // READ: everything
  Future<List<CashTransactionModel>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(table, orderBy: 'time DESC');
    return rows.map(CashTransactionModel.fromMap).toList();
  }

  // UPDATE
  Future<int> update(CashTransactionModel t) async {
    final db = await AppDatabase.instance.database;
    return db.update(table, t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  // DELETE
  Future<int> delete(int id) async {
    final db = await AppDatabase.instance.database;
    return db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // TOTAL in a range
  Future<double> totalBetween(DateTime start, DateTime end) async {
    final db = await AppDatabase.instance.database;
    final r = await db.rawQuery(
      'SELECT SUM(amount) AS total FROM $table WHERE time >= ? AND time < ?',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }

}