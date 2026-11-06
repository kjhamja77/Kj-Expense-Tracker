import 'package:exp_track/models/message_model.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

class SmsHistory {
  final SmsQuery query = SmsQuery();

  static const int _pageSize = 500; // must be <= 1000

  /// Fetches ALL past messages from one sender by paging.
  Future<List<MessageModel>> fetchPastMessages(String address) {
    return _fetch(address, stopBefore: null);
  }

  /// Fetches only as far back as [from]; faster for recent ranges.
  Future<List<MessageModel>> fetchMessagesSince(String address, DateTime from) {
    return _fetch(address, stopBefore: from);
  }

  Future<List<MessageModel>> _fetch(String address,
      {DateTime? stopBefore}) async {
    final result = <MessageModel>[];
    var offset = 0;

    while (true) {
      final List<SmsMessage> page = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        address: address,
        start: offset,
        count: _pageSize,
        sort: true,
      );
      if (page.isEmpty) break;

      for (final m in page) {
        result.add(MessageModel(
          id: 'history_${m.id}',
          address: m.address,
          body: m.body,
          date: m.date,
        ));
      }

      if (page.length < _pageSize) break; // last page

      if (stopBefore != null) {
        final oldest = page
            .map((m) => m.date)
            .whereType<DateTime>()
            .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
        if (oldest != null && oldest.isBefore(stopBefore)) break;
      }
      offset += _pageSize;
    }
    return result;
  }
}