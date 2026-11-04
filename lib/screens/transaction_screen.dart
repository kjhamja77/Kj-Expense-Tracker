import 'dart:math';

import 'package:exp_track/models/cash_model.dart';
import 'package:exp_track/models/transaction_model.dart';
import 'package:exp_track/screens/selection_screen.dart';
import 'package:exp_track/screens/transaction_Custom_Screen.dart';
import 'package:exp_track/services/cash_transcation_dao.dart';
import 'package:exp_track/utils/app_theme.dart';
import 'package:exp_track/widget/calendar_bottom_sheet.dart';
import 'package:exp_track/widget/period_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:exp_track/models/message_model.dart';
import 'package:exp_track/services/live_sms_channel.dart';
import 'package:exp_track/services/sms_history.dart';
import 'package:permission_handler/permission_handler.dart';

class TransactionListScreen extends StatefulWidget {
  final String bank;
  const TransactionListScreen({super.key, required this.bank});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {

  late var currentYear = DateTime.now().year;
  final List<Color> commonColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.indigo,
    Colors.cyan,
  ];

  final dao = CashTranscationDao();

  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  List<String> getMonthList(){
    return List.generate(12, (index){
      DateTime date = DateTime(currentYear,index+1);
      return '${DateFormat.MMMM().format(date)} $currentYear';
    });
  }

  List<List<DateInfo>> getDatesForMonth(){
    return List.generate(12, (index){
      int months = index+1;
      int daysInMonth = DateTime(currentYear,months+1, 0).day;
      return List.generate(daysInMonth, (day){
        DateTime fullDate = DateTime(currentYear, months,day+1);
        String days = DateFormat.EEEE().format(fullDate);
        return DateInfo(date: day+1, day: days);
      });
    });
  }
  List<int> dates = [];
  List<List<DateInfo>> datesWithDays = [];
  late List<String> monthList = getMonthList();

  // ------------------------------------------------------------------
  // REMOVED: the old hardcoded `transData` list is gone. It's replaced
  // below by `_smsMessages` (raw messages for widget.bank) and
  // `_transactions` (those messages parsed into TransactionData for
  // display) -- see the "Dynamic data" section further down.
  // ------------------------------------------------------------------

  List<int> datesOfMonth(){
    return List.generate(30, (index){
      return index +1;
    });
  }
  String? selectedMonth;
  int? currentMonthIndex;
  int? currentDateIndex;
  ScrollController scrollController = ScrollController();
  List<GlobalKey> dateKeys = [];

  // ====================================================================
  // DYNAMIC DATA -- past messages (flutter_sms_inbox) + live messages
  // (native Kotlin platform channel), both filtered to widget.bank,
  // merged into one list and re-fetched whenever the selected date
  // changes.
  // ====================================================================

  final SmsHistory _historyRepo = SmsHistory();
  final NativeLiveSmsChannel _liveChannel = NativeLiveSmsChannel();

  /// Raw messages currently shown, for widget.bank, for the currently
  /// selected date. Newest first.
  List<MessageModel> _smsMessages = [];
  List<CashTransactionModel> cashTransactions=[];

  /// The same messages, parsed into the shape the existing UI expects
  /// (name / price / dateTime). Recomputed every time _smsMessages
  /// changes -- see _refreshParsedTransactions().
  List<TransactionData> _transactions = [];

  bool _isLoadingMessages = true;
  bool _smsPermissionDenied = false;

  /// A live message is also written into the device's own SMS store,
  /// so it would reappear on the next history fetch. This avoids
  /// showing the same message twice.
  final Set<String> _seenMessageIds = {};


  /// Requests the SMS permission, loads history for the current
  /// selection, then starts the live listener filtered to widget.bank.
  /// Called once from initState.
  Future<void> _initialiseSmsData() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      setState(() {
        _isLoadingMessages = false;
        _smsPermissionDenied = true;
      });
      return;
    }

    await _loadToday();

    // Native filtering: only messages from widget.bank ever reach Dart.
    await _liveChannel.setTrackedSender('DIB-SMS');//widget.bank
    _liveChannel.incomingMessages('DIB-SMS').listen(//widget.bank
      _onLiveMessage,
      onError: (error) => debugPrint('Live SMS stream error: $error'),
    );
  }

  /// Re-reads past messages for widget.bank and filters them down to
  /// whatever date is currently selected. Call this any time
  /// currentYear / currentMonthIndex / currentDateIndex changes (see
  /// previousMonth / nextMonth / openCalendarPicker / openDateBottomSheet
  /// below, each of which now calls this after updating the selection).
  Future<void> _loadMessagesForSelectedDate({required String address,
    required DateTime startDate,
    required DateTime endDate}
      ) async {
    setState(() => _isLoadingMessages = true);

    final all = await _historyRepo.fetchPastMessages('DIB-SMS');//widget.bank

    final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endOfDay = DateTime(endDate.year,endDate.month,endDate.day).add(Duration(days: 1));
    //startOfDay.add(const Duration(days: 1));

    final filtered = all.where((m) {
      final d = m.date;
      return d != null && !d.isBefore(startOfDay) && d.isBefore(endOfDay);
    }).toList()
      ..sort((a, b) {
        final ad = a.date?.millisecondsSinceEpoch ?? 0;
        final bd = b.date?.millisecondsSinceEpoch ?? 0;
        return bd.compareTo(ad); // newest first
      });

    _seenMessageIds
      ..clear()
      ..addAll(filtered.map((m) => m.id));
    // Remember the active range so the live listener knows whether
    // "today" currently falls inside it (see _isTodayWithinRange below).
    _rangeStart = startOfDay;
    _rangeEnd = endOfDay;

    final cashRows = await dao.getBetween(startOfDay,endOfDay);
    setState(() {
      _smsMessages = filtered;
      cashTransactions = cashRows;
      _isLoadingMessages = false;
    });
    _refreshParsedTransactions();
  }

  /// Fires for every live message already filtered by native code to
  /// widget.bank. Only appended while the user is viewing today --
  /// otherwise skipped here, though never lost: it's already persisted
  /// in the device's SMS store, so navigating back to today picks it
  /// up via _loadMessagesForSelectedDate().
  void _onLiveMessage(MessageModel message) {
    if (!_seenMessageIds.add(message.id)) return; // duplicate guard
    if (!_isTodayWithinRange) return; // not looking at today -- skip

    setState(() {
      _smsMessages.insert(0, message);
    });
    _refreshParsedTransactions();
  }

  bool get _isTodayWithinRange {
    if (_rangeStart == null || _rangeEnd == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !today.isBefore(_rangeStart!) && today.isBefore(_rangeEnd!);
  }

  /// Today — single day, today's date on both ends.
  Future<void> _loadToday() {
    final now = DateTime.now();
    return _loadMessagesForSelectedDate(address: 'DIB-SMS', startDate: now, endDate: now);
  }

  /// Week — Monday through Sunday of the CURRENT week (adjust if you
  /// want "last 7 rolling days" instead — see note below).
  Future<void> _loadThisWeek() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: 6)); // Monday
    // final end = start.add(const Duration(days: 6));              // Sunday
    return _loadMessagesForSelectedDate(address: 'DIB-SMS', startDate: start, endDate: now);
  }

  /// Month — 1st through the last day of the CURRENT calendar month.
  Future<void> _loadThisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0); // day 0 of next month = last day of this month
    return _loadMessagesForSelectedDate(address: 'DIB-SMS', startDate: start, endDate: end);
  }

  /// Single date — from the calendar picker's "Single Date" mode.
  Future<void> _loadSingleDate(DateTime date) {
    return _loadMessagesForSelectedDate(address: 'DIB-SMS', startDate: date, endDate: date);
  }

  /// Date range — from the calendar picker's "Date Range" mode (the
  /// second screenshot you shared).
  Future<void> _loadDateRange(DateTime start, DateTime end) {
    return _loadMessagesForSelectedDate(address: 'DIB-SMS', startDate: start, endDate: end);
  }

  /// Converts the raw SMS list into TransactionData for the existing
  /// UI (name / price / dateTime), using _parseTransaction below.
  void _refreshParsedTransactions() {
    final messageParsed = _smsMessages
        .map(_parseTransaction)
        .whereType<TransactionData>();   // drops the nulls

    final cashParsed = cashTransactions.map((c){
      final dt = DateTime.fromMillisecondsSinceEpoch(c.time);
      return TransactionData(
          c.name,
          null,
          'cash',
          DateFormat('dd.MM.yy, HH:mm:ss').format(dt),
          c.amount,
          dt,
          c.id
      );
    });
    final merged = [...messageParsed, ...cashParsed]..sort((a,b) =>b.timeStamp.compareTo(a.timeStamp));

    setState(() => _transactions = merged);
  }

  /// Extracts merchant name, transaction type, amount, and available
  /// balance from one SMS body.
  ///
  /// IMPORTANT: every regex below is a generic starting point. Bank SMS
  /// wording varies a lot — paste me one real (or sanitized) message from
  /// your actual bank and I'll tune these to match it exactly. Until then,
  /// anything that fails to match falls back gracefully rather than
  /// crashing or showing blank fields.
  TransactionData? _parseTransaction(MessageModel message) {
    final body = message.body ?? '';

    if (!_isRealTransaction(body)) return null;   // gate

    final amount = _extractAmount(body);
    final availableBalance = _extractAvailableBalance(body);
    final type = _extractTransactionType(body);
    final merchant = _extractMerchantName(body);

    final dt = message.date ?? DateTime.now();
    final formattedDate = DateFormat('dd.MM.yy, HH:mm:ss').format(dt);


    return TransactionData(
      merchant,
      availableBalance,
      type,
      formattedDate,
      amount,
      dt,
      null
    );
  }

  //regex to avoid the otp messages in transaction list
  static final RegExp _otpPattern = RegExp(
    r'\b(otp|one[\s-]?time|verification\s+code|do\s+not\s+share|never\s+share|'
    r'cvv|to\s+(authori[sz]e|verify|confirm|approve)|is\s+your\s+(code|pin|password))\b',
    caseSensitive: false,
  );

  //condition check for otp messages not added in the transaction list
  bool _isRealTransaction(String body) {
    if (body.trim().isEmpty) return false;
    if (_otpPattern.hasMatch(body)) return false;

    // Positive signal: a real DIB transaction has the balance line
    // and/or a completed-action verb.
    final hasBalance = _extractAvailableBalance(body) != null;
    final hasVerb = RegExp(
      r'\b(debited|credited|spent|purchased|withdrawn|paid|received|refund(ed)?)\b',
      caseSensitive: false,
    ).hasMatch(body);

    return hasBalance || hasVerb;
  }

  /// Transaction amount — first currency figure in the message.
  double _extractAmount(String body) {
    final match =
    RegExp(r'(?:AED|USD|INR|GBP|EUR)?\s*([\d,]+\.\d{2})').firstMatch(body);
    if (match == null) return 0.0;
    return double.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0.0;
  }

  /// "Available balance" is a fixed phrase in your bank's messages, so
  /// this anchors directly on it and reads the amount that follows —
  /// with or without a currency code, and with either ":" or "-" or
  /// nothing between the phrase and the number.
  double? _extractAvailableBalance(String body) {
    final match = RegExp(
      r'available\s*balance\s*(?:is|[:\-])?\s*(?:AED|USD|INR|GBP|EUR)?\s*([\d,]+\.\d{2})',
      caseSensitive: false,
    ).firstMatch(body);

    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', ''));
  }

  /// Merchant name follows "from" in your bank's format (e.g.
  /// "...from NIKE STORE on..."), not "at" — this was the actual bug
  /// in the earlier version, which anchored on the wrong word entirely.
  /// Still runs through _cleanMerchantName to strip any stray
  /// account/card-number fragments that end up captured alongside it.
  // String _extractMerchantName(String body) {
  //   final fromMatch = RegExp(
  //     r'from\s+([A-Za-z0-9 &\-\.]+?)(?:\s+on\b|\.|,|$)',
  //     caseSensitive: false,
  //   ).firstMatch(body);
  //
  //   final rawCapture = fromMatch != null ? fromMatch.group(1)!.trim() : '';
  //   return _cleanMerchantName(rawCapture, fallback: body);
  // }
  String _extractMerchantName(String body) {
    // 1. ATM withdrawal: the message has no merchant, so use a fixed label.
    //    "withdraw\w*" covers withdrawn / withdrawal / withdrawl (typo-safe).
    if (RegExp(r'\batm\b|\bwithdraw\w*', caseSensitive: false).hasMatch(body)) {
      return 'ATM Cash Withdrawal';
    }

    // 2. Purchases: find every "from <something>" and keep the one that
    //    is NOT the account/card part.
    final matches = RegExp(
      r"from\s+([A-Za-z0-9 &\-\.\*\/'_@#]+?)(?=\s+on\b|\.\s|\.$|,|$)",
      caseSensitive: false,
    ).allMatches(body);

    final accountLike = RegExp(
      r'^(?:your\s+)?(?:a\/?c|acc(?:ount)?|card)\b|^[xX\*\d\s]+$',
      caseSensitive: false,
    );

    for (final m in matches) {
      final candidate = m.group(1)!.trim();
      if (candidate.isEmpty || accountLike.hasMatch(candidate)) continue;
      return _cleanMerchantName(candidate, fallback: 'Unknown');
    }

    return 'Unknown';
  }

  /// The word(s) immediately before "Purchase" are the actual
  /// transaction type — e.g. "POS Purchase", "Online Purchase" — so
  /// this captures whatever sits right before that word instead of
  /// checking a fixed keyword list.
  String _extractTransactionType(String body) {
    final match = RegExp(
      r'\b([A-Za-z]+)\s+Purchase\b',
      caseSensitive: false,
    ).firstMatch(body);

    if (match == null) {
      // "Purchase" appears with nothing meaningful before it, or the
      // message isn't a purchase at all (e.g. a refund/credit message).
      return body.toLowerCase().contains('purchase') ? 'Purchase' : 'Transaction';
    }

    final qualifier = match.group(1)!;
    const acronyms = {'pos', 'atm', 'ib', 'neft', 'imps', 'upi'};
    final capitalizedQualifier = acronyms.contains(qualifier.toLowerCase())
        ? qualifier.toUpperCase()
        : '${qualifier[0].toUpperCase()}${qualifier.substring(1).toLowerCase()}';

    return '$capitalizedQualifier Purchase';
  }

  /// Strips account/card-number noise out of a captured merchant string.
  String _cleanMerchantName(String raw, {required String fallback}) {
    var text = raw;

    text = text.replaceAll(
      RegExp(
        r'(?:\b(?:a\/?c|acc(?:ount)?|card(?:\s+ending)?|xx+|\*+)\s*[:\-]?\s*)?[xX\*]{0,4}\d{4,}\b',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(RegExp(r'\b\d{4,}\b'), '');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    text = text.replaceAll(RegExp(r'^[\-:,.\s]+|[\-:,.\s]+$'), '').trim();

    if (text.isEmpty) {
      return fallback.isNotEmpty ? fallback : 'Unknown';
    }
    return text;
  }
  // /// Pulls a currency amount out of the body.
  // ///
  // /// [afterKeyword] = true looks specifically for an amount following
  // /// balance-related wording ("Avl Bal", "Available Balance", "Bal:"),
  // /// so it targets the BALANCE figure rather than the transaction amount.
  // /// [afterKeyword] = false grabs the FIRST currency amount in the
  // /// message, which is almost always the transaction amount itself
  // /// (balance figures typically appear later in the text).
  // double? _extractAmount(String body, {required bool afterKeyword}) {
  //   final currencyAmount = r'(?:AED|USD|INR|GBP|EUR)?\s*([\d,]+\.\d{2})';
  //
  //   final pattern = afterKeyword
  //       ? RegExp(
  //     r'(?:avl\.?\s*bal(?:ance)?|available\s*balance|bal(?:ance)?)\s*[:\-]?\s*' +
  //         currencyAmount,
  //     caseSensitive: false,
  //   )
  //       : RegExp(currencyAmount);
  //
  //   final match = pattern.firstMatch(body);
  //   if (match == null) return null;
  //
  //   return double.tryParse(match.group(1)!.replaceAll(',', ''));
  // }
  //
  // /// Identifies the transaction type from common bank SMS keywords.
  // /// Checked in order — first match wins, so more specific terms
  // /// (e.g. "Withdrawal") are listed before generic ones (e.g. "Debit").
  // String _extractTransactionType(String body) {
  //   final lower = body.toLowerCase();
  //
  //   const typeKeywords = <String, String>{
  //     'withdrawal': 'Withdrawal',
  //     'purchase': 'Purchase',
  //     'refund': 'Refund',
  //     'reversal': 'Reversal',
  //     'credited': 'Credit',
  //     'credit': 'Credit',
  //     'debited': 'Debit',
  //     'debit': 'Debit',
  //     'payment': 'Payment',
  //     'pos': 'POS Transaction',
  //     'atm': 'ATM Transaction',
  //   };
  //
  //   for (final entry in typeKeywords.entries) {
  //     if (lower.contains(entry.key)) return entry.value;
  //   }
  //   return 'Transaction'; // fallback when no known keyword is found
  // }
  //
  // /// Extracts and cleans the merchant name — same "at <text>" anchor
  // /// and account-number stripping as before.
  // String _extractMerchantName(String body) {
  //   final atMatch = RegExp(
  //     r'at\s+([A-Za-z0-9 &\-\.]+?)(?:\s+on\b|\.|,|$)',
  //     caseSensitive: false,
  //   ).firstMatch(body);
  //
  //   final rawCapture = atMatch != null ? atMatch.group(1)!.trim() : '';
  //   return _cleanMerchantName(rawCapture, fallback: body);
  // }
  //
  // /// Strips account/card-number noise out of a captured merchant string.
  // String _cleanMerchantName(String raw, {required String fallback}) {
  //   var text = raw;
  //
  //   text = text.replaceAll(
  //     RegExp(
  //       r'(?:\b(?:a\/?c|acc(?:ount)?|card(?:\s+ending)?|xx+|\*+)\s*[:\-]?\s*)?[xX\*]{0,4}\d{4,}\b',
  //       caseSensitive: false,
  //     ),
  //     '',
  //   );
  //   text = text.replaceAll(RegExp(r'\b\d{4,}\b'), '');
  //   text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  //   text = text.replaceAll(RegExp(r'^[\-:,.\s]+|[\-:,.\s]+$'), '').trim();
  //
  //   if (text.isEmpty) {
  //     return fallback.isNotEmpty ? fallback : 'Unknown';
  //   }
  //   return text;
  // }

  // ====================================================================
  // End dynamic data section
  // ====================================================================


  @override
  void initState() {
    dates = datesOfMonth();
    datesWithDays = getDatesForMonth();
    currentMonthIndex = DateTime.now().month -1;
    currentDateIndex = DateTime.now().day - 1;
    // itemColors = List.generate(10, (index) => randomColor());
    generateKeys();
    WidgetsBinding.instance.addPostFrameCallback((callback){
      scrollToDateIndex();
    });
    _initialiseSmsData(); // starts permission -> history load -> live listener
    super.initState();
  }

  void scrollToDateIndex(){
    final keyContext = dateKeys[currentDateIndex!].currentContext;
    if(keyContext == null) return;

    Scrollable.ensureVisible(keyContext,duration: Duration(milliseconds: 300),curve: Curves.easeInOut,alignment: 0.5);
  }

  void generateKeys(){
    dateKeys = List.generate(datesWithDays[currentMonthIndex!].length, (index)=>GlobalKey());
  }

  // void previousMonth(){
  //   setState(() {
  //     if(currentMonthIndex! > 0){
  //       currentMonthIndex = currentMonthIndex! - 1;
  //     }
  //     else{
  //       currentMonthIndex = 11;
  //       currentYear = currentYear - 1;
  //       monthList = getMonthList();
  //       datesWithDays = getDatesForMonth();
  //     }
  //     updateSelectedDate();
  //     generateKeys();
  //   });
  //   WidgetsBinding.instance.addPostFrameCallback((callback){
  //     scrollToDateIndex();
  //   });
  //   _loadMessagesForSelectedDate(); // re-fetch for the newly selected date
  // }

  // void nextMonth(){
  //   setState(() {
  //     if(currentMonthIndex! < 11){
  //       currentMonthIndex = currentMonthIndex! +1;
  //     }else{
  //       currentMonthIndex = 0;
  //       currentYear = currentYear +1;
  //       monthList = getMonthList();
  //       datesWithDays = getDatesForMonth();
  //     }
  //     updateSelectedDate();
  //     generateKeys();
  //   });
  //   WidgetsBinding.instance.addPostFrameCallback((callback){
  //     scrollToDateIndex();
  //   });
  //   _loadMessagesForSelectedDate(); // re-fetch for the newly selected date
  // }

  void updateSelectedDate(){
    final now = DateTime.now();
    final bool currentMonth = (currentMonthIndex == now.month -1 ) && (currentYear == now.year);
    currentDateIndex = currentMonth ? now.day-1 : 0;
  }

  // Future<void> openCalendarPicker()async{
  //
  //   DateTime initDate = DateTime(currentYear,
  //     currentMonthIndex! +1,
  //     (datesWithDays[currentMonthIndex!].length >= (currentDateIndex! +1))
  //         ? currentDateIndex! +1
  //         : 1,
  //   );
  //
  //   final DateTime? picker = await showDatePicker(
  //       context: context,
  //       initialDate: initDate,
  //       firstDate: DateTime(currentYear - 5, 1, 1),
  //       lastDate: DateTime(currentYear + 10, 12, 31),
  //       builder: ((context, child) {
  //         return Theme(
  //           data: Theme.of(context).copyWith(
  //               colorScheme: Theme.of(context).colorScheme.copyWith(
  //                   primary: Colors.blue
  //               )
  //           ), child: child!,
  //         );
  //       })
  //   );
  //   if(picker !=null){
  //     setState(() {
  //       bool yearChange = picker.year != currentYear;
  //       currentYear = picker.year;
  //
  //       currentMonthIndex = picker.month -1;
  //       currentDateIndex = picker.day -1;
  //       if(yearChange){
  //         monthList = getMonthList();
  //         datesWithDays = getDatesForMonth();
  //       }
  //       generateKeys();
  //     });
  //     WidgetsBinding.instance.addPostFrameCallback((callback){
  //       scrollToDateIndex();
  //     });
  //     _loadMessagesForSelectedDate(); // re-fetch for the newly picked date
  //   }
  //
  // }

  void openDateBottomSheet() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // backgroundColor: Colors.transparent,
      builder: (context) {
        return const DateSelectionBottomSheet();
      },
    );

    if (result == null) return;

    final DateSelectionType? type = result['type'] as DateSelectionType?;
    final DateTime? selectedDate = result['selectedDate'] as DateTime?;
    final DateTime? startDate = result['startDate'] as DateTime?;
    final DateTime? endDate = result['endDate'] as DateTime?;

    if (type == DateSelectionType.single && selectedDate != null) {
      // Keep the month/day navigation state in sync with the picked
      // date, same as before — this drives the calendar strip/keys.
      setState(() {
        final bool yearChange = selectedDate.year != currentYear;
        currentYear = selectedDate.year;
        currentMonthIndex = selectedDate.month - 1;
        currentDateIndex = selectedDate.day - 1;
        if (yearChange) {
          monthList = getMonthList();
          datesWithDays = getDatesForMonth();
        }
        generateKeys();
      });
      WidgetsBinding.instance.addPostFrameCallback((callback) {
        scrollToDateIndex();
      });

      _loadSingleDate(selectedDate); // <-- uses the common _loadMessages()
    } else if (type == DateSelectionType.range && startDate != null && endDate != null) {
      // For a multi-day range there's no single "current date index" to
      // scroll to, so we sync the navigation state to the range's START
      // date only — keeps the month header showing something sensible
      // without implying a single selected day.
      setState(() {
        final bool yearChange = startDate.year != currentYear;
        currentYear = startDate.year;
        currentMonthIndex = startDate.month - 1;
        currentDateIndex = startDate.day - 1;
        if (yearChange) {
          monthList = getMonthList();
          datesWithDays = getDatesForMonth();
        }
        generateKeys();
      });
      WidgetsBinding.instance.addPostFrameCallback((callback) {
        scrollToDateIndex();
      });

      _loadDateRange(startDate, endDate); // <-- uses the common _loadMessages()
    }
  }
  @override
  Widget build(BuildContext context) {

    // Derived summary values for the blue "Total Spent" card, computed
    // from the dynamic _transactions list instead of the old static one.
    final double totalSpent = _transactions.fold(0.0, (sum, t) => sum + t.price);
    final int transactionCount = _transactions.length;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: ()async{
          final added = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context)=>TransactionCustomScreen(isStored: false)));
          if(added == true){
            _loadMessagesForSelectedDate(address: "DIB-SMS",
                startDate: _rangeStart!, endDate: _rangeEnd!.subtract(Duration(days: 1)));
          }
        },
        // backgroundColor: Colors.blue,
        child: Icon(Icons.add,color: Colors.white,),),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            onPressed: toggleTheme,
          ),
          IconButton(onPressed: (){
            openDateBottomSheet();
          }, icon: Icon(Icons.calendar_month_outlined,size: 20,))//color: Colors.black,
        ],
        title: Text("Expense Tracker",style: TextStyle(fontSize: 16,fontWeight: FontWeight.w600),),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0,horizontal: 13),
        child: Column(
          children: [
            widget.bank.isEmpty? SizedBox.shrink() :Container(
                alignment: Alignment.centerLeft,
                child: Container(
                    padding: EdgeInsets.all(10),
                    height: MediaQuery.of(context).size.height*0.07,
                    width: MediaQuery.of(context).size.width,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                            width: MediaQuery.of(context).size.width*0.11,
                            height: MediaQuery.of(context).size.height*0.11,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10)
                            ),
                            child: Icon(Icons.account_balance_sharp)),//color: Colors.blue
                        Container(
                          width: MediaQuery.of(context).size.width*0.63,
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(widget.bank,
                                style: TextStyle(fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    overflow: TextOverflow.ellipsis),),//color: Colors.black
                            ],
                          ),
                        ),
                        // IconButton(onPressed: (){
                        //   Navigator.push(context, MaterialPageRoute(builder: (context) => BankSelectionScreen()));
                        // }, icon: Icon(Icons.arrow_forward_ios,size: 17,))//color: Colors.blue
                      ],
                    ))
            ),
            Container(
              margin: EdgeInsets.symmetric(vertical: 10),
              padding: EdgeInsets.all(12),
              height: MediaQuery.of(context).size.height*0.11,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15)
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height:60,
                    width: 60,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40)
                    ),
                    child: Icon(Icons.account_balance_wallet_outlined,size: 25,),//color: Colors.white
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 140, 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Spent',style: TextStyle(fontSize: 14)),//color: Colors.white70
                        // Now driven by the dynamic _transactions list.
                        Text('${totalSpent.toStringAsFixed(2)} Aed',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold,),),//color: Colors.white
                        Text('$transactionCount Transactions',style: TextStyle(fontSize: 14,))//color: Colors.white70
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,size: 20,)//color: Colors.white
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  SizedBox(height: 10,),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Align(alignment: Alignment.centerLeft,child: Text('Transactions',style: TextStyle(fontWeight: FontWeight.bold),)),
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(width: MediaQuery.of(context).size.width*0.5,child: PeriodSelector(
                              onChanged: (ExpensePeriod period) {
                                switch (period) {
                                  case ExpensePeriod.today:
                                    _loadToday();
                                    break;
                                  case ExpensePeriod.week:
                                    _loadThisWeek();
                                    break;
                                  case ExpensePeriod.month:
                                    _loadThisMonth();
                                    break;
                                }
                              },
                            ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10,),
                  Expanded(
                    // Three states now instead of one: permission denied,
                    // loading, and the actual dynamic list.
                    child: _smsPermissionDenied
                        ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'SMS permission is required to show transactions.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                        : _isLoadingMessages
                        ? const Center(child: CircularProgressIndicator())
                        : _transactions.isEmpty
                        ? const Center(child: Text('No transactions on this date'))
                        : ListView.builder(
                        scrollDirection: Axis.vertical,
                        itemCount: _transactions.length,
                        itemBuilder: (context,index){
                          // modulo guards against index overflow
                          // now that the list length is dynamic
                          // instead of a fixed 8-item demo list.
                          // print('value is ${_transactions[index].name} ${_transactions[index].availableBalance}');
                          final color = commonColors[index % commonColors.length];
                          return InkWell(
                            onTap: ()async{
                              final deleted = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TransactionCustomScreen(
                                    transactionData: _transactions[index],
                                    isStored: true,
                                  ),
                                ),
                              );

                              if (deleted == true) {
                                _loadMessagesForSelectedDate(
                                  address: "DIB-SMS",
                                  startDate: _rangeStart!,
                                  endDate: _rangeEnd!.subtract(const Duration(days: 1)),
                                );
                              }
                              },
                            child: Container(
                              margin: EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                  // color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  // boxShadow: [
                                  //   BoxShadow(
                                  //       blurRadius: 0.1,
                                  //       spreadRadius: 0.1,
                                  //       // color: Colors.grey
                                  //   )
                                  // ]
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6,horizontal: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding : EdgeInsets.symmetric(vertical: 20,horizontal: 20),
                                          decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(10)
                                          ),
                                          child: Icon(Icons.restaurant,color: color,size: 25,),
                                        ),
                                        SizedBox(width: 12,),
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(width: MediaQuery.of(context).size.width*0.45,
                                                child: Text(_transactions[index].name,overflow: TextOverflow.ellipsis,
                                                    maxLines: 3,
                                                    style: TextStyle(fontWeight: FontWeight.bold))),
                                            SizedBox(height: 5,),
                                            Text(
                                                _transactions[index].type == 'POS Purchase'
                                                    ? "Debit Card Tap"
                                                    : _transactions[index].type, style: TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                            SizedBox(height: 5,),
                                            Text(_transactions[index].dateTime,style: TextStyle(fontWeight: FontWeight.bold,color: Colors.grey.shade500)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 15,),
                                    Text(_transactions[index].price.toStringAsFixed(2),style: TextStyle(fontWeight: FontWeight.bold,)),
                                    Icon(Icons.arrow_forward_ios,color: Colors.grey,size: 15,)
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color randomColor() {
    final Random random = Random();
    return Color.fromARGB(
      255,
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
    );
  }
}

class DateInfo {
  final int date;
  final String day; // e.g. "Monday"

  DateInfo({required this.date, required this.day});
}

// class TransactionListScreen extends StatefulWidget {
//   final String bank;
//   const TransactionListScreen({super.key, required this.bank});
//
//   @override
//   State<TransactionListScreen> createState() => _TransactionListScreenState();
// }
//
// class _TransactionListScreenState extends State<TransactionListScreen> {
//
//   late var currentYear = DateTime.now().year;
//   final List<Color> commonColors = [
//     Colors.red,
//     Colors.blue,
//     Colors.green,
//     Colors.orange,
//     Colors.purple,
//     Colors.teal,
//     Colors.pink,
//     Colors.amber,
//     Colors.indigo,
//     Colors.cyan,
//   ];
//
//
//   List<String> getMonthList(){
//     return List.generate(12, (index){
//       DateTime date = DateTime(currentYear,index+1);
//       return '${DateFormat.MMMM().format(date)} $currentYear';
//     });
//   }
//
//   List<List<DateInfo>> getDatesForMonth(){
//     return List.generate(12, (index){
//       int months = index+1;
//       int daysInMonth = DateTime(currentYear,months+1, 0).day;
//       return List.generate(daysInMonth, (day){
//         DateTime fullDate = DateTime(currentYear, months,day+1);
//         String days = DateFormat.EEEE().format(fullDate);
//         return DateInfo(date: day+1, day: days);
//       });
//     });
//   }
//   List<int> dates = [];
//   List<List<DateInfo>> datesWithDays = [];
//   late List<String> monthList = getMonthList();
//   List<TransactionData> transData= [
//     TransactionData("Blooms", "01.09.26, 12:45:29", 10.25),
//     TransactionData("Savis Restaurant", "04.09.26, 19:20:29", 15.25),
//     TransactionData("Koka Restaurant", "02.09.26, 21:40:29", 20.25),
//     TransactionData("Al Raffa Restaurant", "03.09.26, 10:45:29", 18.25),
//     TransactionData("City Pearl", "01.09.26, 14:20:29", 15.25),
//     TransactionData("Mudpot Restaurant", "04.09.26, 14:20:29", 19.25),
//     TransactionData("City Pearl Restaurant ", "02.09.26, 14:20:29", 10.25),
//     TransactionData("Blooms", "03.09.26, 14:20:29", 25.25),
//   ] ;
//
//   List<int> datesOfMonth(){
//     return List.generate(30, (index){
//       return index +1;
//     });
//   }
//   String? selectedMonth;
//   int? currentMonthIndex;
//   int? currentDateIndex;
//   ScrollController scrollController = ScrollController();
//   List<GlobalKey> dateKeys = [];
//
//
//   @override
//   void initState() {
//     dates = datesOfMonth();
//     datesWithDays = getDatesForMonth();
//     currentMonthIndex = DateTime.now().month -1;
//     currentDateIndex = DateTime.now().day - 1;
//     // itemColors = List.generate(10, (index) => randomColor());
//     generateKeys();
//     WidgetsBinding.instance.addPostFrameCallback((callback){
//       scrollToDateIndex();
//     });
//     super.initState();
//   }
//
//   void scrollToDateIndex(){
//     final keyContext = dateKeys[currentDateIndex!].currentContext;
//     if(keyContext == null) return;
//
//     Scrollable.ensureVisible(keyContext,duration: Duration(milliseconds: 300),curve: Curves.easeInOut,alignment: 0.5);
//   }
//
//   void generateKeys(){
//     dateKeys = List.generate(datesWithDays[currentMonthIndex!].length, (index)=>GlobalKey());
//   }
//
//   void previousMonth(){
//     // if(currentMonthIndex! > 0){
//       setState(() {
//         if(currentMonthIndex! > 0){
//           currentMonthIndex = currentMonthIndex! - 1;
//         }
//         else{
//           currentMonthIndex = 11;
//           currentYear = currentYear - 1;
//           monthList = getMonthList();
//           datesWithDays = getDatesForMonth();
//         }
//         // currentMonthIndex = currentMonthIndex! - 1;
//         updateSelectedDate();
//         generateKeys();
//       });
//       WidgetsBinding.instance.addPostFrameCallback((callback){
//         scrollToDateIndex();
//       });
//     // }
//   }
//
//   void nextMonth(){
//     // if(currentMonthIndex! < 11){
//       setState(() {
//         if(currentMonthIndex! < 11){
//           currentMonthIndex = currentMonthIndex! +1;
//         }else{
//           currentMonthIndex = 0;
//           currentYear = currentYear +1;
//           monthList = getMonthList();
//           datesWithDays = getDatesForMonth();
//         }
//         // currentMonthIndex = currentMonthIndex! + 1;
//         updateSelectedDate();
//         generateKeys();
//       });
//       WidgetsBinding.instance.addPostFrameCallback((callback){
//         scrollToDateIndex();
//       });
//     // }
//   }
//
//   void updateSelectedDate(){
//     final now = DateTime.now();
//     final bool currentMonth = (currentMonthIndex == now.month -1 ) && (currentYear == now.year);
//     currentDateIndex = currentMonth ? now.day-1 : 0;
//   }
//
//   Future<void> openCalendarPicker()async{
//
//     DateTime initDate = DateTime(currentYear,
//       currentMonthIndex! +1,
//         (datesWithDays[currentMonthIndex!].length >= (currentDateIndex! +1))
//             ? currentDateIndex! +1
//             : 1,
//     );
//
//     final DateTime? picker = await showDatePicker(
//         context: context,
//         initialDate: initDate,
//         firstDate: DateTime(currentYear - 5, 1, 1),
//         lastDate: DateTime(currentYear + 10, 12, 31),
//         builder: ((context, child) {
//           return Theme(
//             data: Theme.of(context).copyWith(
//               colorScheme: Theme.of(context).colorScheme.copyWith(
//                 primary: Colors.blue
//               )
//             ), child: child!,
//           );
//         })
//     );
//     if(picker !=null){
//       setState(() {
//         bool yearChange = picker.year != currentYear;
//         currentYear = picker.year;
//
//         currentMonthIndex = picker.month -1;
//         currentDateIndex = picker.day -1;
//         if(yearChange){
//           monthList = getMonthList();
//           datesWithDays = getDatesForMonth();
//         }
//         generateKeys();
//       });
//       WidgetsBinding.instance.addPostFrameCallback((callback){
//         scrollToDateIndex();
//       });
//     }
//
//   }
//
//   void openDateBottomSheet() async {
//
//     final result = await showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) {
//         return const DateSelectionBottomSheet();
//       },
//     );
//
//     if (result != null) {
//
//       print('Type: ${result['type']}');
//
//       print(
//         'Selected Date: ${result['selectedDate']}',
//       );
//
//       print(
//         'Start Date: ${result['startDate']}',
//       );
//
//       print(
//         'End Date: ${result['endDate']}',
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     List<DateInfo> currentDates = datesWithDays[currentMonthIndex!];
//     return Scaffold(
//       floatingActionButton: FloatingActionButton(
//         onPressed: (){
//           Navigator.push(context, MaterialPageRoute(builder: ((context) =>
//               TransactionCustomScreen(isStored: false,))));
//         },
//         backgroundColor: Colors.blue,
//         child: Icon(Icons.add,color: Colors.white,),),
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         actions: [
//           IconButton(onPressed: (){
//             openDateBottomSheet();
//           }, icon: Icon(Icons.calendar_month_outlined,color: Colors.black,size: 20,))
//         ],
//         title: Text("Expense Tracker",style: TextStyle(fontSize: 16,fontWeight: FontWeight.w600),),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 0,horizontal: 13),
//         child: Column(
//           children: [
//             widget.bank.isEmpty? SizedBox.shrink() :Container(
//                 // padding: EdgeInsets.symmetric(horizontal: 15,vertical: 0),
//                 alignment: Alignment.centerLeft,
//                 child: Container(
//                   padding: EdgeInsets.all(10),
//                   height: MediaQuery.of(context).size.height*0.07,
//                   width: MediaQuery.of(context).size.width,
//                   alignment: Alignment.center,
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.grey,
//                         spreadRadius: 0.05,
//                         blurRadius: 0.1,
//                         // offset: Offset(0.1, 0.2)
//                       )
//                     ],
//                     borderRadius: BorderRadius.circular(15)
//                   ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       crossAxisAlignment: CrossAxisAlignment.center,
//                       children: [
//                         Container(
//                           width: MediaQuery.of(context).size.width*0.11,
//                           height: MediaQuery.of(context).size.height*0.11,
//                             alignment: Alignment.center,
//                             decoration: BoxDecoration(
//                               color: Colors.white70,
//                               // shape: BoxShape.circle,
//                               borderRadius: BorderRadius.circular(10)
//                             ),
//                             child: Icon(Icons.account_balance_sharp,color: Colors.blue)),
//                         Container(
//                           width: MediaQuery.of(context).size.width*0.63,
//                           padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Text(widget.bank,
//                                 style: TextStyle(fontWeight: FontWeight.w600,
//                                     fontSize: 13,
//                                     color: Colors.black,overflow: TextOverflow.ellipsis),),
//                             ],
//                           ),
//                         ),
//                         IconButton(onPressed: (){
//                           Navigator.push(context, MaterialPageRoute(builder: (context) => BankSelectionScreen()));
//                         }, icon: Icon(Icons.arrow_forward_ios,color: Colors.blue,size: 17,))
//                       ],
//                     ))
//             ),
//             // Container(
//             //   // color: Colors.grey,
//             //   width: MediaQuery.of(context).size.width,
//             //   // padding: EdgeInsets.symmetric(horizontal: ),
//             //   height: MediaQuery.of(context).size.height*0.07,
//             //   margin: EdgeInsets.symmetric(horizontal: 7),
//             //   child: Row(
//             //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             //     children: [
//             //       Container(
//             //           height: MediaQuery.of(context).size.height*0.05,
//             //           decoration: BoxDecoration(
//             //               borderRadius: BorderRadius.circular(10),
//             //               boxShadow: [
//             //                 BoxShadow(
//             //                     offset: Offset(0.2, 0.2),
//             //                     blurRadius: 0.2,
//             //                     spreadRadius: 0.2,
//             //                     color: Colors.grey
//             //                 )
//             //               ],
//             //               // border: Border.all(color: Colors.black,style: BorderStyle.solid,width: 0.3),
//             //               color: Colors.white
//             //           ),
//             //           child: IconButton(onPressed: (){
//             //             if(currentMonthIndex! > 0){
//             //               previousMonth();
//             //             }
//             //           }, icon: Icon(Icons.arrow_back_ios,size: 15,))),
//             //       Container(
//             //         height: MediaQuery.of(context).size.height*0.05,
//             //         width: MediaQuery.of(context).size.width*0.49,
//             //         decoration: BoxDecoration(
//             //           borderRadius: BorderRadius.circular(10),
//             //           // border: Border.all(color: Colors.black,style: BorderStyle.solid,width: 0.3),
//             //             boxShadow: [
//             //               BoxShadow(
//             //                   offset: Offset(0.2, 0.2),
//             //                   blurRadius: 0.2,
//             //                   spreadRadius: 0.2,
//             //                   color: Colors.grey
//             //               )
//             //             ],
//             //           color: Colors.white
//             //         ),
//             //         // padding: EdgeInsets.all(10),
//             //         child: DropdownButton<int>(
//             //           value: currentMonthIndex,
//             //
//             //           isExpanded: true,
//             //
//             //           underline: const SizedBox(),
//             //
//             //           items:
//             //               List.generate(monthList.length, (banks){
//             //                 return DropdownMenuItem(
//             //                   value: banks,
//             //                     child: Padding(
//             //                       padding: const EdgeInsets.symmetric(horizontal: 15),
//             //                       child: Text(monthList[banks]),
//             //                     ),
//             //                 );
//             //               }),
//             //           // monthList.map((bank) {
//             //           //   return DropdownMenuItem<int>(
//             //           //     value: bank,
//             //           //     child: Padding(
//             //           //       padding: const EdgeInsets.symmetric(
//             //           //         horizontal: 20,
//             //           //       ),
//             //           //       child: Text(
//             //           //         bank,
//             //           //         textAlign: TextAlign.center,
//             //           //         style: const TextStyle(
//             //           //             fontSize: 16,
//             //           //             color: Colors.black87,
//             //           //             overflow: TextOverflow.ellipsis
//             //           //         ),
//             //           //       ),
//             //           //     ),
//             //           //   );
//             //           // }).toList(),
//             //
//             //           onChanged: (value) {
//             //             if(value !=null){
//             //               setState(() {
//             //                 currentMonthIndex = value;
//             //
//             //                 final now = DateTime.now();
//             //                 bool isCurrentMonth = (value == now.month - 1);
//             //
//             //                 if(isCurrentMonth){
//             //                   currentDateIndex = now.day -1;
//             //                 }else{
//             //                   currentDateIndex = 0;
//             //                 }
//             //                 // int maxDays = datesWithDays[value].length;
//             //                 // if(currentDateIndex! >= maxDays) currentDateIndex = 0;
//             //                 generateKeys();
//             //                 updateSelectedDate();
//             //               });
//             //
//             //               WidgetsBinding.instance.addPostFrameCallback((callback){
//             //                 scrollToDateIndex();
//             //               });
//             //             }
//             //           },
//             //
//             //           // MENU
//             //           menuWidth: 350,
//             //           menuMaxHeight: 250,
//             //           itemHeight: 50,
//             //
//             //           dropdownColor: Colors.white,
//             //
//             //           borderRadius: BorderRadius.circular(10),
//             //
//             //           elevation: 4,
//             //
//             //           icon: const Icon(
//             //             Icons.keyboard_arrow_down_rounded,
//             //           ),
//             //         )
//             //       ),
//             //       Container(
//             //           height: MediaQuery.of(context).size.height*0.05,
//             //           decoration: BoxDecoration(
//             //               borderRadius: BorderRadius.circular(10),
//             //               boxShadow: [
//             //                 BoxShadow(
//             //                     offset: Offset(0.2, 0.2),
//             //                     blurRadius: 0.2,
//             //                     spreadRadius: 0.2,
//             //                     color: Colors.grey
//             //                 )
//             //               ],
//             //               // border: Border.all(color: Colors.black,style: BorderStyle.solid,width: 0.3),
//             //               color: Colors.white
//             //           ),
//             //           child: IconButton(onPressed: (){
//             //             if(currentMonthIndex! <11 ){
//             //               nextMonth();
//             //             }
//             //           }, icon: Icon(Icons.arrow_forward_ios,size: 15,))),
//             //       Container(
//             //           height: MediaQuery.of(context).size.height*0.05,
//             //           decoration: BoxDecoration(
//             //               borderRadius: BorderRadius.circular(10),
//             //               boxShadow: [
//             //                 BoxShadow(
//             //                     offset: Offset(0.2, 0.2),
//             //                     blurRadius: 0.2,
//             //                     spreadRadius: 0.2,
//             //                     color: Colors.grey
//             //                 )
//             //               ],
//             //               // border: Border.all(color: Colors.black,style: BorderStyle.solid,width: 0.3),
//             //               color: Colors.white
//             //           ),
//             //           child: IconButton(onPressed: (){
//             //             openCalendarPicker();
//             //           }, icon: Icon(Icons.date_range_rounded))),
//             //     ],
//             //   ),
//             // ),
//             // Container(
//             //   height: MediaQuery.of(context).size.height*0.102,
//             //   width: MediaQuery.of(context).size.width,
//             //   // color: Colors.grey,
//             //   padding: EdgeInsets.symmetric(vertical: 5,horizontal: 0),
//             //   margin: EdgeInsets.symmetric(horizontal: 10),
//             //   child: ListView.builder(
//             //       scrollDirection: Axis.horizontal,
//             //       itemCount: currentDates.length,
//             //       itemBuilder: (context,index){
//             //         final info = currentDates[index];
//             //         final bool selected = index == currentDateIndex;
//             //         return GestureDetector(
//             //           onTap: (){
//             //             setState(() {
//             //               currentDateIndex = index;
//             //             });
//             //           },
//             //           child: Container(
//             //             // height: MediaQuery.of(context).size.height*0.12,
//             //             width: MediaQuery.of(context).size.width*0.125,
//             //             key: dateKeys[index],
//             //             margin: EdgeInsets.all(5),
//             //             decoration: BoxDecoration(
//             //               color: selected ? Colors.blue.shade100:Colors.white,
//             //               borderRadius: BorderRadius.circular(10),
//             //               boxShadow: [
//             //                 BoxShadow(
//             //                   offset: Offset(0.2, 0.2),
//             //                   blurRadius: 0.2,
//             //                   spreadRadius: 0.2,
//             //                   color: selected ? Colors.blue:Colors.grey
//             //                 )
//             //               ]
//             //             ),
//             //             child: Column(
//             //               mainAxisAlignment: MainAxisAlignment.center,
//             //               crossAxisAlignment: CrossAxisAlignment.center,
//             //               children: [
//             //                 Text(currentDates[index].day.substring(0,3),style: TextStyle(fontWeight: FontWeight.w400,color: Colors.grey.shade600,fontSize: 13)),
//             //                 Text(currentDates[index].date.toString(),style: TextStyle(fontWeight: FontWeight.w600,fontSize: 15),),
//             //               ],
//             //             ),
//             //           ),
//             //         );
//             //       }),
//             // ),
//             Container(
//               margin: EdgeInsets.symmetric(vertical: 10),
//               padding: EdgeInsets.all(12),
//               height: MediaQuery.of(context).size.height*0.11,
//               decoration: BoxDecoration(
//               gradient: LinearGradient(colors: [Colors.blue.shade300,Colors.blue.shade600]),
//                 borderRadius: BorderRadius.circular(15)
//               ),
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Container(
//                     height:60,
//                     width: 60,
//                     decoration: BoxDecoration(
//                         gradient: LinearGradient(colors: [Colors.blue.shade300,Colors.blue.shade600]),
//                         // boxShadow: [
//                         //   BoxShadow(
//                         //     color: Colors.white,
//                         //     blurRadius: 0.4,
//                         //     spreadRadius: 0.2,
//                         //     offset: Offset(0.3,0.8)
//                         //   )
//                         // ],
//                         borderRadius: BorderRadius.circular(40)
//                     ),
//                     child: Icon(Icons.account_balance_wallet_outlined,color: Colors.white,size: 25,),
//                   ),
//                   Padding(
//                     // color: Colors.grey,
//                     padding: const EdgeInsets.fromLTRB(10, 0, 140, 0),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text('Total Spent',style: TextStyle(fontSize: 14,color: Colors.white70)),
//                         Text('10.25 Aed',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold,color: Colors.white),),
//                         Text('5 Transactions',style: TextStyle(fontSize: 14,color: Colors.white70))
//                       ],
//                     ),
//                   ),
//                   Icon(Icons.arrow_forward_ios,color: Colors.white,size: 20,)
//                 ],
//               ),
//             ),
//             Expanded(
//               child: Column(
//                 children: [
//                   SizedBox(height: 10,),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Align(alignment: Alignment.centerLeft,child: Text('Transactions',style: TextStyle(fontWeight: FontWeight.bold),)),
//                       Container(
//                         // color: Colors.grey,
//                         padding: EdgeInsets.symmetric(vertical: 0),
//                         // width: MediaQuery.of(context).size.width,
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.end,
//                           children: [
//                             SizedBox(width: MediaQuery.of(context).size.width*0.5,child: PeriodSelector()),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 10,),
//                   Expanded(
//                     child: ListView.builder(
//                         scrollDirection: Axis.vertical,
//                         itemCount: transData.length,
//                         itemBuilder: (context,index){
//                           return InkWell(
//                             onTap: (){
//                               Navigator.push(context, MaterialPageRoute(builder: ((context) =>
//                                   TransactionCustomScreen(name: transData[index].name,
//                                       price: transData[index].price, time: transData[index].dateTime, isStored: true,))));
//                             },
//                             child: Container(
//                               margin: EdgeInsets.all(5),
//                               decoration: BoxDecoration(
//                                   color: Colors.white,
//                                   borderRadius: BorderRadius.circular(15),
//                                   boxShadow: [
//                                     BoxShadow(
//                                         // offset: Offset(0.1, 0.1),
//                                         blurRadius: 0.1,
//                                         spreadRadius: 0.1,
//                                         color: Colors.grey
//                                     )
//                                   ]
//                               ),
//                               child: Padding(
//                                 padding: const EdgeInsets.symmetric(vertical: 6,horizontal: 6),
//                                 child: Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   crossAxisAlignment: CrossAxisAlignment.center,
//                                   children: [
//                                     Row(
//                                       children: [
//                                         Container(
//                                           padding : EdgeInsets.all(10),
//                                           decoration: BoxDecoration(
//                                               color: commonColors[index].withValues(alpha: 0.15),
//                                               borderRadius: BorderRadius.circular(10)
//                                           ),
//                                           child: Icon(Icons.restaurant,color: commonColors[index],size: 20,),
//                                         ),
//                                         SizedBox(width: 20,),
//                                         Column(
//                                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                                           crossAxisAlignment: CrossAxisAlignment.start,
//                                           children: [
//                                             Text(transData[index].name,style: TextStyle(fontWeight: FontWeight.bold,)),
//                                             SizedBox(height: 7,),
//                                             Text(transData[index].dateTime,style: TextStyle(fontWeight: FontWeight.bold,color: Colors.grey.shade500)),
//                                           ],
//                                         ),
//                                       ],
//                                     ),
//                                     SizedBox(width: 15,),
//                                     Text("${transData[index].price.toString()} Dhs",style: TextStyle(fontWeight: FontWeight.bold,)),
//                                     Icon(Icons.arrow_forward_ios,color: Colors.grey,size: 15,)
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           );
//                         }),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Color randomColor() {
//     final Random random = Random();
//     return Color.fromARGB(
//       255,
//       random.nextInt(256),
//       random.nextInt(256),
//       random.nextInt(256),
//     );
//   }
// }
//
// class TransactionData{
//   String name;
//   double price;
//   String dateTime;
//
//   TransactionData(this.name,this.dateTime,this.price);
// }
//
// class DateInfo {
//   final int date;
//   final String day; // e.g. "Monday"
//
//   DateInfo({required this.date, required this.day});
// }