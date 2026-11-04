import 'package:exp_track/models/message_model.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

class SmsHistory {
  final SmsQuery query = SmsQuery();

  /// Fetches ALL past messages from one sender (no date filtering here —
  /// that's applied one layer up in the controller).
  Future<List<MessageModel>> fetchPastMessages(String address) async {
    final List<SmsMessage> raw = await query.querySms(
      kinds: [SmsQueryKind.inbox], // received messages only
      address: address,            // filtered at the query level
    );

    return raw.map((m) {
      return MessageModel(
        // flutter_sms_inbox's SmsMessage.id is the SMS provider's row
        // ID — stable and unique, ideal for de-duplication.
        id: 'history_${m.id}',
        address: m.address,
        body: m.body,
        date: m.date,
      );
    }).toList();
  }

}