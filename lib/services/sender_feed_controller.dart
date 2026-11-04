import 'package:exp_track/models/message_model.dart';
import 'package:exp_track/services/live_sms_channel.dart';
import 'package:exp_track/services/sms_history.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';

class SenderFeedController extends ChangeNotifier{
  final SmsHistory history = SmsHistory();
  final NativeLiveSmsChannel liveSmsChannel = NativeLiveSmsChannel();

  late String trackedSender;

  /// Which date's messages are currently shown. Defaults to today.
  DateTime selectedDate = DateTime.now();

  List<MessageModel> messages = [];
  bool isLoading = false;
  bool permissionDenied = false;

  /// A live message is ALSO written into the device's own SMS store by
  /// Android, so it would reappear on the next history fetch. This set
  /// is how duplicates are avoided across the two sources.
  final Set<String> _seenIds = {};

  SenderFeedController(this.trackedSender) {
    _initialise();
  }

  bool get _isViewingToday{
    final now = DateTime.now();
    return selectedDate.year == now.year &&
    selectedDate.month == now.month &&
    selectedDate.day == now.day;
  }


  Future<void> _initialise()async {
    final status = await Permission.sms.request();

    if(!status.isGranted){
      isLoading = false;
      permissionDenied = true;
      notifyListeners();
      return;
    }
    // 1) Load history for whatever date is selected (today, by default).
    await loadPastMessages();

    // 2) Tell native code which sender to filter for, then start
    //    listening. Lives for the controller's whole lifetime.
    await liveSmsChannel.setTrackedSender(trackedSender);
    liveSmsChannel.incomingMessages(trackedSender).listen(
      _onLiveMessage,
      onError: (error) =>debugPrint("live sms stream error $error"),
    );
  }

  /// Loads past messages for trackedSender, filtered down to selectedDate.
  Future<void> loadPastMessages()async {
    isLoading = true;
    notifyListeners();

    final all = await history.fetchPastMessages(trackedSender);
    final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final filtered = all.where((m){
      final d = m.date;
      return d != null && !d.isBefore(startOfDay) && d.isBefore(endOfDay);
    }).toList()..sort((a,b){
      final ad = a.date?.millisecondsSinceEpoch ?? 0;
      final bd = b.date?.millisecondsSinceEpoch?? 0;
      return bd.compareTo(ad);
    });
    _seenIds..clear()..addAll(filtered.map((m) => m.id));
    messages = filtered;

    isLoading = false;
    notifyListeners();
  }

  /// Only appended while the user is looking at today. Never lost
  /// otherwise — Android already persisted it, so the next time the
  /// user selects today, loadPastMessages() picks it up naturally.
  void _onLiveMessage(MessageModel message) {
    if (!_seenIds.add(message.id)) return; // duplicate guard
    if (!_isViewingToday) return;           // not viewing today — skip

    messages.insert(0, message); // newest-first
    notifyListeners();
  }

  /// Called when the user picks a different date. Re-fetches history
  /// scoped to that date.
  Future<void> selectDate(DateTime newDate) async {
    selectedDate = newDate;
    await loadPastMessages();
  }

  /// Switch the feed to a different sender. Live subscription itself
  /// stays open — no re-registration.
  Future<void> changeSender(String newSender) async {
    trackedSender = newSender;
    await loadPastMessages();
    await liveSmsChannel.setTrackedSender(newSender);
  }
}