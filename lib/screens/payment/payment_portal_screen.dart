import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/booking_provider.dart';
import '../../providers/journey_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/tickets_provider.dart';
import '../../models/seat_allocation.dart';
import '../../models/ticket.dart';
import '../../constants/colors.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../widgets/qr_code_widget.dart';
import '../../widgets/virtual_card.dart';

class PaymentPortalScreen extends StatefulWidget {
  const PaymentPortalScreen({super.key});

  @override
  State<PaymentPortalScreen> createState() => _PaymentPortalScreenState();
}

class _PaymentPortalScreenState extends State<PaymentPortalScreen> {
  final _formKey = GlobalKey<FormState>();

  String _method = 'card'; // 'card' or 'wallet'
  String _walletProvider = 'eZ Cash';

  final _cardNameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _walletPhoneController = TextEditingController();
  final _cvvFocusNode = FocusNode();

  @override
  void dispose() {
    _cardNameController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _walletPhoneController.dispose();
    _cvvFocusNode.dispose();
    super.dispose();
  }

  // A bulk booking is charged once for the whole group (one card swipe)
  // and kept as a single ticket, so [totalAmount] covers every seat.
  Future<void> _submit(BuildContext context, SeatAllocation allocation, double totalAmount) async {
    if (!_formKey.currentState!.validate()) return;
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final ticketsProvider = Provider.of<TicketsProvider>(context, listen: false);
    final bus = bookingProvider.selectedBus;
    final route = bookingProvider.selectedRoute ?? bookingProvider.sampleRoutes.first;
    final group = bookingProvider.groupAllocations;
    final isGroup = group.length > 1;

    if (_method == 'card') {
      await paymentProvider.payWithCard(
        allocation: allocation,
        amountLkr: totalAmount,
        cardNumber: _cardNumberController.text,
      );
    } else {
      await paymentProvider.payWithMobileWallet(
        allocation: allocation,
        amountLkr: totalAmount,
        walletProvider: _walletProvider,
        phoneNumber: _walletPhoneController.text,
      );
    }

    final payment = paymentProvider.payment;
    if (payment == null || bus == null) return;

    if (isGroup) {
      ticketsProvider.addTicket(Ticket(
        allocation: group.first,
        extraAllocations: group.skip(1).toList(),
        payment: payment,
        bus: bus,
        route: route,
      ));
    } else {
      ticketsProvider.addTicket(Ticket(allocation: allocation, payment: payment, bus: bus, route: route));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final journeyProvider = Provider.of<JourneyProvider>(context);
    final paymentProvider = Provider.of<PaymentProvider>(context);

    final alloc = journeyProvider.currentAllocation ?? bookingProvider.lastAllocation;
    final route = bookingProvider.selectedRoute ?? bookingProvider.sampleRoutes.first;
    final bus = bookingProvider.selectedBus;
    final boarding = alloc?.boardingStop ?? bookingProvider.boardingStop ?? route.stops.first;
    final alighting = alloc?.alightingStop ?? bookingProvider.alightingStop ?? route.stops.last;
    final perSeatAmount = bus?.journeyFareLkr(route, boarding, alighting) ?? 0.0;
    final groupSize = bookingProvider.groupAllocations.length;
    final amount = groupSize > 1 ? perSeatAmount * groupSize : perSeatAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Now'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/payment-options');
            }
          },
        ),
      ),
      body: SafeArea(
        child: paymentProvider.payment != null && alloc != null
            ? _buildSuccess(context, paymentProvider, alloc)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: alloc == null
                    ? const Text(
                        'No booking found. Please go back and complete your booking first.',
                        style: TextStyle(color: AppColors.textMuted),
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.priorityBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Amount due', style: TextStyle(fontSize: 12, color: AppColors.priorityText, fontWeight: FontWeight.bold)),
                                  Text(
                                    'Rs. ${amount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.priorityText),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            _buildMethodToggle(),
                            const SizedBox(height: 16),

                            if (_method == 'card') _buildCardForm() else _buildWalletForm(),

                            if (paymentProvider.errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(paymentProvider.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                            ],
                            const SizedBox(height: 24),

                            ElevatedButton(
                              onPressed: paymentProvider.isProcessing
                                  ? null
                                  : () => _submit(context, alloc, amount),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryNavy,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: paymentProvider.isProcessing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text('Pay Rs. ${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            const SizedBox(height: 10),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_outline, size: 12, color: AppColors.textMuted),
                                SizedBox(width: 4),
                                Text('Simulated secure checkout - no real charge is made.', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildMethodToggle() {
    return Row(
      children: [
        Expanded(child: _methodTab('card', Icons.credit_card, 'Card')),
        const SizedBox(width: 10),
        Expanded(child: _methodTab('wallet', Icons.phone_android, 'Mobile Wallet')),
      ],
    );
  }

  Widget _methodTab(String value, IconData icon, String label) {
    final selected = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryNavy : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primaryNavy : AppColors.borderLight),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : AppColors.textMuted),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: selected ? Colors.white : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_cardNameController, _cardNumberController, _expiryController, _cvvController, _cvvFocusNode]),
          builder: (context, _) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: VirtualCardPreview(
              holderName: _cardNameController.text,
              cardNumberDigits: _cardNumberController.text.replaceAll(RegExp(r'\D'), ''),
              expiry: _expiryController.text,
              cvv: _cvvController.text,
              showBack: _cvvFocusNode.hasFocus,
            ),
          ),
        ),
        _label('Cardholder Name'),
        TextFormField(
          controller: _cardNameController,
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration('e.g. K. Perera'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the cardholder name' : null,
        ),
        const SizedBox(height: 14),
        _label('Card Number'),
        TextFormField(
          controller: _cardNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16), _CardNumberFormatter()],
          decoration: _fieldDecoration('e.g. 4242 4242 4242 4242'),
          validator: (v) {
            final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
            if (digits.length != 16) return 'Enter a valid 16-digit card number';
            if (!_passesLuhnCheck(digits)) return 'That card number doesn\'t look right';
            return null;
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Expiry (MM/YY)'),
                  TextFormField(
                    controller: _expiryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4), _ExpiryFormatter()],
                    decoration: _fieldDecoration('MM/YY'),
                    validator: _validateExpiry,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('CVV'),
                  TextFormField(
                    controller: _cvvController,
                    focusNode: _cvvFocusNode,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                    decoration: _fieldDecoration('•••'),
                    validator: (v) => (v == null || v.length < 3) ? 'Enter a valid CVV' : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWalletForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Mobile Wallet Provider'),
        Row(
          children: [
            Expanded(child: _walletChip('eZ Cash')),
            const SizedBox(width: 10),
            Expanded(child: _walletChip('mCash')),
          ],
        ),
        const SizedBox(height: 14),
        _label('Mobile Number'),
        TextFormField(
          controller: _walletPhoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          decoration: _fieldDecoration('e.g. 0771234567'),
          validator: (v) {
            final digits = (v ?? '').trim();
            if (digits.length != 10 || !digits.startsWith('0')) return 'Enter a valid 10-digit mobile number';
            return null;
          },
        ),
      ],
    );
  }

  Widget _walletChip(String provider) {
    final selected = _walletProvider == provider;
    return GestureDetector(
      onTap: () => setState(() => _walletProvider = provider),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.generalBg : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.generalAccent : AppColors.borderLight),
        ),
        child: Text(
          provider,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? AppColors.generalText : AppColors.textMuted),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5), fontWeight: FontWeight.normal, fontSize: 13),
      isDense: true,
      filled: true,
      fillColor: AppColors.backgroundLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      errorMaxLines: 2,
    );
  }

  String? _validateExpiry(String? v) {
    final text = v ?? '';
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(text);
    if (match == null) return 'Use MM/YY format';
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    if (month < 1 || month > 12) return 'Enter a valid month';
    final expiry = DateTime(year, month + 1); // first day of the month after expiry
    if (expiry.isBefore(DateTime.now())) return 'This card has expired';
    return null;
  }

  bool _passesLuhnCheck(String digits) {
    var sum = 0;
    var alternate = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var n = int.parse(digits[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  // The boarding QR only ever appears here - once the fare is actually
  // paid - so scanning it confirms both "paid" and "seat" in one step.
  Widget _buildSuccess(BuildContext context, PaymentProvider paymentProvider, SeatAllocation alloc) {
    final payment = paymentProvider.payment!;
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final group = bookingProvider.groupAllocations;
    final isGroup = group.length > 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: AppColors.generalBg, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, size: 44, color: AppColors.generalAccent),
          ),
          const SizedBox(height: 16),
          Text(
            isGroup ? 'Payment & ${group.length} Seats Confirmed' : 'Payment & Seat Confirmed',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 6),
          Text(
            'Rs. ${payment.amountLkr.toStringAsFixed(0)} paid via ${payment.reference}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryNavy.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(color: AppColors.primaryNavy.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              children: [
                QRCodeWidget(data: alloc.qrCode, size: 150),
                const SizedBox(height: 12),
                const Text(
                  'Show this QR to the conductor when boarding',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                ),
                const SizedBox(height: 4),
                Text(
                  'Seat ${alloc.seatNumber} · ${alloc.boardingStop.split(' ').first} → ${alloc.alightingStop.split(' ').first}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                if (isGroup) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in group.skip(1))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.priorityBg, borderRadius: BorderRadius.circular(8)),
                          child: Text(a.seatNumber, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.priorityText)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This one ticket covers all ${group.length} seats under your account. Only you can start, end or report on this journey - it ends for everyone when you end it.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                _receiptRow('Payment ID', payment.paymentId),
                const Divider(height: 20),
                _receiptRow('Booking Reference', alloc.referenceCode),
                const Divider(height: 20),
                _receiptRow('Paid at', _formatTimestamp(payment.timestamp)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your QR is saved to My Ticket on the home screen - pull it up any time before boarding.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done — Go to Home', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${dt.day}/${dt.month}/${dt.year} · ${formattedHour.toString().padLeft(2, '0')}:$minute $period';
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i != 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return TextEditingValue(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    return TextEditingValue(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.length));
  }
}
