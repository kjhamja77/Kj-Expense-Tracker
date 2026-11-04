import 'package:exp_track/models/message_model.dart';
import 'package:flutter/services.dart';

class NativeLiveSmsChannel{

  /// Wraps the two platform channels declared in MainActivity.kt.
  static const EventChannel eventChannel = EventChannel('app.live_sms/incoming');
  static const MethodChannel methodChannel = MethodChannel('app.live_sms/control');

  Future<void> setTrackedSender(String sender)async{
    return methodChannel.invokeMethod('setTrackSender', {'sender': sender});
  }

  /// Starts listening. [initialSender] doubles as the EventChannel's
  /// listen() argument, giving native code a filter from message one.
  Stream<MessageModel> incomingMessages(String initialSender) {
    return eventChannel.receiveBroadcastStream(initialSender).map((event) {
      final map = Map<String, dynamic>.from(event as Map);
      final millis = map['timestamp'] as int?;

      return MessageModel(
        // Live messages carry no provider row ID, so timestamp+body is
        // used as a stable-enough identity for de-duplication.
        id: 'live_${millis}_${map['body'].hashCode}',
        address: map['address'] as String?,
        body: map['body'] as String?,
        date: millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null,
      );
    });
  }

}