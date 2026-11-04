package com.example.exp_track

import io.flutter.embedding.android.FlutterActivity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.provider.Telephony
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel


class MainActivity : FlutterActivity(){

    // EVENT channel: native -> Dart, streams only messages matching trackedSender.
    private val LIVE_SMS_EVENT_CHANNEL = "app.live_sms/incoming"

    // METHOD channel: Dart -> native, sets/changes which sender to filter for.
    private val LIVE_SMS_CONTROL_CHANNEL = "app.live_sms/control"
    private var smsReceiver: BroadcastReceiver? = null   // <-- must be here, at class level

    private var trackSender:String? = null

    override fun configureFlutterEngine(flutterEngine : FlutterEngine){
        super.configureFlutterEngine(flutterEngine)

        //control channel function
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_SMS_CONTROL_CHANNEL)
            .setMethodCallHandler{  call,result ->
                when(call.method){
                    "setTrackSender" -> {
                        trackSender = call.argument<String>("sender")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger,LIVE_SMS_EVENT_CHANNEL)
            .setStreamHandler(object :EventChannel.StreamHandler {

                override fun onListen(arguments: Any?, events:EventChannel.EventSink?){
                    // Allows the first sender to be passed directly into
                    // listen(sender), avoiding a race with setTrackedSender().
                    (arguments as String)?.let { trackSender = it }

                    val receiver = object : BroadcastReceiver(){
                        override fun onReceive(context:Context, intent : Intent){
                            // A message can split across multiple PDU parts
                            // (long SMS) — this reassembles them.
                            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)

                            messages?.forEach{
                                sms ->
                                val sender = sms.originatingAddress

                                if(matchesTrackedSender(sender)){
                                    val payload = mapOf(
                                        "address" to sender,
                                        "body" to sms.messageBody,
                                        "timestamp" to sms.timestampMillis
                                    )
                                    events?.success(payload)
                                }
                            }
                        }
                    }

                    smsReceiver = receiver
                    context.registerReceiver(
                        receiver,
                        IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
                    )
                }

                override fun onCancel(arguments : Any?){
                    // Prevents a leaked receiver after Dart stops listening.
                    smsReceiver?.let { context.unregisterReceiver(it) }
                    smsReceiver = null
                }
            })
    }

    private fun matchesTrackedSender(incoming : String?) : Boolean {
        val tracked = trackSender ?: return false
        if(incoming == null) return false

        val incomingDigits = incoming.filter { it.isDigit() }
        val trackedDigits = tracked.filter { it.isDigit() }

        if(incomingDigits.isEmpty() || trackedDigits.isEmpty()){
            return incoming.equals(tracked, ignoreCase = true)
        }

        val tailLength = 9

        fun tails(s:String) = if(s.length <= tailLength ) s else s.takeLast(tailLength)

        return tails(incomingDigits) == tails(trackedDigits)


    }

}
