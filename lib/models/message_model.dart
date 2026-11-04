/// Unified message shape used regardless of source (live channel or the
/// flutter_sms_inbox package), so the controller/UI only deal with ONE
/// type instead of juggling two different SmsMessage-like classes.
class MessageModel {
  final String id;              // stable identity, used for de-duplication
  final String? address;
  final String? body;
  final DateTime? date;

  MessageModel({
    required this.id,
    this.address,
    this.body,
    this.date,
  });
}