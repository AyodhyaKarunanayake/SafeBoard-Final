import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment.dart';
import '../models/seat_allocation.dart';

class PaymentService {
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  Future<Payment> payWithCard({
    required SeatAllocation allocation,
    required double amountLkr,
    required String cardNumber,
  }) async {
    // Simulated gateway round-trip.
    await Future.delayed(const Duration(milliseconds: 1400));
    final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
    return _finalize(
      allocation: allocation,
      amountLkr: amountLkr,
      method: 'card',
      reference: 'Card •••• $last4',
    );
  }

  Future<Payment> payWithMobileWallet({
    required SeatAllocation allocation,
    required double amountLkr,
    required String walletProvider,
    required String phoneNumber,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1400));
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
    return _finalize(
      allocation: allocation,
      amountLkr: amountLkr,
      method: 'mobile_wallet',
      reference: '$walletProvider •••• $last4',
    );
  }

  Payment payOnBoard({
    required SeatAllocation allocation,
    required double amountLkr,
  }) {
    final payment = Payment(
      paymentId: 'pay_${DateTime.now().millisecondsSinceEpoch}',
      allocationId: allocation.allocationId,
      journeyId: allocation.journeyId,
      method: 'conductor',
      amountLkr: amountLkr,
      status: 'pay_on_board',
      timestamp: DateTime.now(),
      reference: 'Pay to conductor onboard',
    );
    _persist(payment);
    return payment;
  }

  Payment _finalize({
    required SeatAllocation allocation,
    required double amountLkr,
    required String method,
    required String reference,
  }) {
    final payment = Payment(
      paymentId: 'pay_${DateTime.now().millisecondsSinceEpoch}',
      allocationId: allocation.allocationId,
      journeyId: allocation.journeyId,
      method: method,
      amountLkr: amountLkr,
      status: 'completed',
      timestamp: DateTime.now(),
      reference: reference,
    );
    _persist(payment);
    return payment;
  }

  void _persist(Payment payment) {
    try {
      final firestore = _firestore;
      if (firestore != null) {
        firestore.collection('payments').doc(payment.paymentId).set(payment.toMap());
      }
    } catch (_) {
      // Best-effort only - the app already has the payment result in memory.
    }
  }
}
