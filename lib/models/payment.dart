class Payment {
  final String paymentId;
  final String allocationId;
  final String journeyId;
  final String method; // 'card', 'mobile_wallet', 'conductor'
  final double amountLkr;
  final String status; // 'completed', 'pay_on_board'
  final DateTime timestamp;
  final String reference; // e.g. "Card •••• 4242" or "Pay to conductor onboard"

  Payment({
    required this.paymentId,
    required this.allocationId,
    required this.journeyId,
    required this.method,
    required this.amountLkr,
    required this.status,
    required this.timestamp,
    required this.reference,
  });

  bool get isPaid => status == 'completed';

  Map<String, dynamic> toMap() {
    return {
      'payment_id': paymentId,
      'allocation_id': allocationId,
      'journey_id': journeyId,
      'method': method,
      'amount_lkr': amountLkr,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'reference': reference,
    };
  }
}
