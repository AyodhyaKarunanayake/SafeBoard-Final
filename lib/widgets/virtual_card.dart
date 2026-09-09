import 'package:flutter/material.dart';

enum _CardBrand { visa, mastercard, amex, generic }

_CardBrand _detectCardBrand(String digits) {
  if (digits.isEmpty) return _CardBrand.generic;
  if (digits.startsWith('4')) return _CardBrand.visa;
  if (RegExp(r'^5[1-5]').hasMatch(digits) || RegExp(r'^2(2[2-9]|[3-6]\d|7[01])').hasMatch(digits)) return _CardBrand.mastercard;
  if (digits.startsWith('34') || digits.startsWith('37')) return _CardBrand.amex;
  return _CardBrand.generic;
}

class _BrandTheme {
  final List<Color> gradient;
  final Widget mark;
  const _BrandTheme(this.gradient, this.mark);
}

_BrandTheme _themeFor(_CardBrand brand) {
  switch (brand) {
    case _CardBrand.visa:
      return const _BrandTheme(
        [Color(0xFF16195B), Color(0xFF2A3FA0)],
        Text('VISA', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 1)),
      );
    case _CardBrand.mastercard:
      return _BrandTheme(
        [const Color(0xFF232526), const Color(0xFF1C1C1C)],
        SizedBox(
          width: 46,
          height: 30,
          child: Stack(
            children: [
              Positioned(left: 0, child: Container(width: 30, height: 30, decoration: const BoxDecoration(color: Color(0xFFEB001B), shape: BoxShape.circle))),
              Positioned(
                right: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: const Color(0xFFF79E1B).withOpacity(0.9), shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ),
      );
    case _CardBrand.amex:
      return const _BrandTheme(
        [Color(0xFF006B54), Color(0xFF00A377)],
        Text('AMEX', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      );
    case _CardBrand.generic:
      return const _BrandTheme(
        [Color(0xFF1B2859), Color(0xFF2D4A9A)],
        Icon(Icons.shield_rounded, color: Colors.white70, size: 26),
      );
  }
}

// A live, real-looking virtual debit/credit card that updates as the
// passenger types, with brand auto-detected from the card number's IIN
// prefix (Visa/Mastercard/Amex) and a flip-to-back animation while the CVV
// field is focused - a more familiar, trustworthy checkout feel than a bare
// form.
class VirtualCardPreview extends StatelessWidget {
  final String holderName;
  final String cardNumberDigits;
  final String expiry;
  final String cvv;
  final bool showBack;

  const VirtualCardPreview({
    super.key,
    required this.holderName,
    required this.cardNumberDigits,
    required this.expiry,
    required this.cvv,
    required this.showBack,
  });

  String _maskedNumber() {
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i != 0 && i % 4 == 0) buffer.write('  ');
      buffer.write(i < cardNumberDigits.length ? cardNumberDigits[i] : '•');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final brand = _detectCardBrand(cardNumberDigits);
    final theme = _themeFor(brand);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width * 0.6;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: showBack ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic,
          builder: (context, t, _) {
            final angle = t * 3.14159265;
            final isBackVisible = t > 0.5;
            final content = isBackVisible
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(3.14159265),
                    child: _buildBack(theme, height),
                  )
                : _buildFront(theme, brand, height);

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: SizedBox(width: width, height: height, child: content),
            );
          },
        );
      },
    );
  }

  Widget _buildFront(_BrandTheme theme, _CardBrand brand, double height) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: theme.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFE8C36A), Color(0xFFC9A24A)]),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Container(width: 24, height: 16, decoration: BoxDecoration(border: Border.all(color: Colors.black26, width: 1), borderRadius: BorderRadius.circular(3))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: const Text('DEBIT', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ],
              ),
              theme.mark,
            ],
          ),
          const Spacer(),
          Text(
            _maskedNumber(),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 2, fontFeatures: [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CARD HOLDER', style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(
                      holderName.trim().isEmpty ? 'YOUR NAME' : holderName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('EXPIRES', style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(
                    expiry.isEmpty ? 'MM/YY' : expiry,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBack(_BrandTheme theme, double height) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: theme.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 22),
          Container(width: double.infinity, height: 40, color: Colors.black87),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 32,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      cvv.isEmpty ? '•••' : cvv.padRight(3, '•'),
                      style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'This is a simulated card for demo checkout - no real card is charged.',
              style: TextStyle(color: Colors.white60, fontSize: 9, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
