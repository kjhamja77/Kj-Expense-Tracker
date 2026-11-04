class TransactionData{
  String name;
  double price;
  String type;           // transaction type, e.g. "Debit", "Credit", "Purchase"
  double? availableBalance; // balance remaining after this transaction, if present
  String dateTime;
  DateTime timeStamp;
  int? cashId;          // null for SMS items

  TransactionData(this.name,
      this.availableBalance,this.type,this.dateTime,this.price,this.timeStamp,this.cashId);
}