import 'package:flutter/material.dart';
import '../models/payment.dart';
import '../models/seat_allocation.dart';
import '../services/payment_service.dart';

class PaymentProvider with ChangeNotifier {
  final PaymentService _paymentService = PaymentService();

  Payment? _payment;
  bool _isProcessing = false;
  String? _errorMessage;

  Payment? get payment => _payment;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;

  void reset() {
    _payment = null;
    _isProcessing = false;
    _errorMessage = null;
    notifyListeners();
  }

  void payOnBoard(SeatAllocation allocation, double amountLkr) {
    _payment = _paymentService.payOnBoard(allocation: allocation, amountLkr: amountLkr);
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> payWithCard({
    required SeatAllocation allocation,
    required double amountLkr,
    required String cardNumber,
  }) async {
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _payment = await _paymentService.payWithCard(
        allocation: allocation,
        amountLkr: amountLkr,
        cardNumber: cardNumber,
      );
    } catch (e) {
      _errorMessage = 'Payment could not be completed. Please try again.';
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> payWithMobileWallet({
    required SeatAllocation allocation,
    required double amountLkr,
    required String walletProvider,
    required String phoneNumber,
  }) async {
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _payment = await _paymentService.payWithMobileWallet(
        allocation: allocation,
        amountLkr: amountLkr,
        walletProvider: walletProvider,
        phoneNumber: phoneNumber,
      );
    } catch (e) {
      _errorMessage = 'Payment could not be completed. Please try again.';
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
