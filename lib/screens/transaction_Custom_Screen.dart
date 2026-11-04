import 'package:exp_track/models/cash_model.dart';
import 'package:exp_track/models/transaction_model.dart';
import 'package:exp_track/services/cash_transcation_dao.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionCustomScreen extends StatefulWidget {
  final TransactionData? transactionData;
  final bool isStored;
  const TransactionCustomScreen({super.key,
    this.transactionData,
    required this.isStored,
  });

  @override
  State<TransactionCustomScreen> createState() => _TransactionCustomScreenState();
}

class _TransactionCustomScreenState extends State<TransactionCustomScreen> {
  TextEditingController dateController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  DateTime? selectedDate;
  final cashDao = CashTranscationDao();
  bool deleting = false;

  Future<void> _delete() async {
    final id = widget.transactionData!.cashId;
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This cash expense will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            // Delete is a destructive action, so it uses the theme's error color
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => deleting = true);
    try {
      final rows = await cashDao.delete(id);   // returns number of rows deleted
      if (!mounted) return;

      if (rows > 0) {
        Navigator.pop(context, true);       // tell the list screen to refresh
      } else {
        setState(() => deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense not found')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed. Try again.')),
      );
    }
  }

  Future<void> pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );

    if (pickedDate == null) return; // user cancelled

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null) return; // user cancelled

    final DateTime combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      selectedDate = combined;
      dateController.text = DateFormat('dd.MM.yy, HH:mm:ss').format(combined);
    });
  }

  Future<void> saveCashExpense()async{
    final name = nameController.text.trim();
    final amount = double.parse(amountController.text.trim());

    if (name.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid name and amount')),
      );
      return;
    }
    await cashDao.insert(CashTransactionModel(
        name: name,
        amount: amount, type: 'Paid in cash', time:selectedDate!.millisecondsSinceEpoch));

    if(!mounted) return;
    Navigator.pop(context,true);
  }

  @override
  void initState() {
    final data = widget.transactionData;   // null when adding a new cash entry

    nameController = TextEditingController(text: data?.name ?? '');

    amountController = TextEditingController(
      text: data != null ? data.price.toString() : '',
    );

    selectedDate = DateTime.now();    // default for add mode
    dateController = TextEditingController(
      text: data?.dateTime ??
          DateFormat('dd.MM.yy, HH:mm:ss').format(selectedDate!),
    );
    super.initState();
  }

  // Small rounded icon box used at the start of each field.
  // The box is a soft tint of the accent color, so it works in light and dark.
  Widget _iconChip(IconData icon, Color color, {double size = 20}) {
    return Container(
      margin: const EdgeInsets.all(7.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: color.withValues(alpha: 0.16),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Field text: normal color when editable, softer when the field is read-only
    final fieldStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: widget.isStored ? scheme.onSurfaceVariant : scheme.onSurface,
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: SafeArea(
        child: InkWell(
          onTap: (){
            saveCashExpense();
          },
          child: Container(
              padding: EdgeInsets.symmetric(vertical: 5,horizontal: 10),
              margin: EdgeInsets.symmetric(vertical: 0,horizontal: 15),
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height*0.056,
              decoration: BoxDecoration(
                // color: Colors.blue.shade600,
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(10)
              ),
              child: Center(child: Text('Save',style: TextStyle(color: scheme.onPrimary,fontSize: 18,fontWeight: FontWeight.w600),))),
        ),
      ),
      appBar: AppBar(
        title: Text(widget.isStored ? 'Add Notes':'Add Cash Details',style: TextStyle(fontSize: 18,fontWeight: FontWeight.w500),),
        centerTitle: true,
        automaticallyImplyActions: false,
        actions: [
          widget.transactionData?.cashId != null ?
          IconButton(onPressed: (){
            _delete();
          },
              icon: Icon(Icons.delete_outline,color: scheme.error,))
              :SizedBox.shrink()
        ],
        leading: IconButton(onPressed: (){
          Navigator.pop(context);
        }, icon: Icon(Icons.arrow_back_ios,size: 20,)),
      ),
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height*0.7,
            width: MediaQuery.of(context).size.width,
            margin: EdgeInsets.all(10),
            padding: EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              // color: Colors.white,
              // boxShadow: [
              //   BoxShadow(
              //     offset: Offset(0.2, 0.2),
              //     spreadRadius: 0.2,
              //     blurRadius: 0.2,
              //     color: Colors.grey
              //   )
              // ]
              // Card color follows the theme (white in light, navy in dark).
              // A thin border replaces the old shadow so it shows in dark mode too.
              color: scheme.surfaceContainer,
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Form(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextFormField(
                        decoration: InputDecoration(
                          prefixIcon: _iconChip(Icons.store_outlined, scheme.secondary),
                          label: Text('Purchase Name'),
                          // contentPadding: EdgeInsets.symmetric(vertical: 15,horizontal: 15),
                          // border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          // Borders now come from inputDecorationTheme in AppTheme
                        ),
                        controller: nameController,
                        // initialValue: widget.name,
                        style: fieldStyle,
                        enabled: widget.isStored ? false : true,
                      ),
                      SizedBox(height: 17,),
                      TextFormField(
                        decoration: InputDecoration(
                          hint: Text('Purchase Name'),
                          label: Text('Price AED'),
                          prefixIcon: _iconChip(Icons.payments_outlined, scheme.primary),
                          // border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        controller: amountController,
                        // initialValue: widget.isStored ? widget.price.toString() : '',
                        style: fieldStyle,
                        enabled: widget.isStored ? false : true,
                      ),
                      widget.isStored && widget.transactionData?.cashId == null ?SizedBox(height: 17,):SizedBox.shrink(),
                      widget.isStored && widget.transactionData?.cashId == null? TextFormField(
                        decoration: InputDecoration(
                          hint: Text('Available Balance'),
                          label: Text('Available Balance AED'),
                          prefixIcon: _iconChip(Icons.payments_outlined, scheme.primary),
                          // border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        initialValue: widget.isStored ? widget.transactionData!.availableBalance.toString() : '',
                        style: fieldStyle,
                        enabled: widget.isStored ? false : true,
                      ):SizedBox.shrink(),
                      SizedBox(height: 17,),
                      TextFormField(
                        controller: dateController,
                        onTap: (){
                          pickDateTime();
                        },
                        readOnly: true,
                        decoration: InputDecoration(
                          suffixIcon: widget.isStored ? SizedBox.shrink():InkWell(onTap: (){},
                              child: Icon(Icons.edit_calendar,color: scheme.tertiary,)) ,
                          prefixIcon: _iconChip(Icons.calendar_today, scheme.tertiary, size: 17),
                          hint: Text('Purchase Date and Time'),
                          label: Text('Date and Time'),
                          // border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        // initialValue: widget.time,
                        style: fieldStyle,
                        enabled: widget.isStored ? false : true,
                      ),
                      SizedBox(height: 17,),
                      Stack(
                        children: [
                          TextFormField(
                            maxLines: 5,
                            textAlignVertical: TextAlignVertical.top,
                            textAlign: TextAlign.start,
                            initialValue: "",
                            enabled: true,
                            // No fixed color: the text follows the theme
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                            decoration: InputDecoration(
                              alignLabelWithHint: true,
                              contentPadding: const EdgeInsets.only(left: 52, top: 16, right: 16, bottom: 16),
                              hint: const Text(
                                'Add your notes here',
                                style: TextStyle(fontWeight: FontWeight.w400),
                              ),
                              label: const Text(
                                'Notes (Optional)',
                                style: TextStyle(fontWeight: FontWeight.w400),
                                textAlign: TextAlign.start,
                              ),
                              // border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 8,
                            child: Container(
                              // margin: const EdgeInsets.all(7.5),
                              padding: const EdgeInsets.all(7.5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(7),
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.16),
                              ),
                              child: Icon(Icons.edit_note_sharp, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                )),
          ),
        ],
      ),
    );
  }
}