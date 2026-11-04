class CashTransactionModel{
  final int? id;
  final String name;
  final double amount;
  final String? type;
  final String? note;
  final int time;

  CashTransactionModel(
      { this.id,
        required this.name,
        required this.amount,
        required this.type,
        this.note,
        required this.time
      });

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'amount': amount,
    'type': type,
    'note': note,
    'time': time,
  };

  factory CashTransactionModel.fromMap(Map<String, Object?> m) => CashTransactionModel(
    id: m['id'] as int?,
    name: m['name'] as String,
    amount: (m['amount'] as num).toDouble(),
    type: m['type'] as String?,
    note: m['note'] as String?,
    time: m['time'] as int,
  );

  CashTransactionModel copyWith({
    String? name,
    double? amount,
    String? type,
    String? note,
    int? time,
  }) =>
      CashTransactionModel(
        id: id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        note: note ?? this.note,
        time: time ?? this.time,
      );
}