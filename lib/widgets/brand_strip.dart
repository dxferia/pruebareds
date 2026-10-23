import 'package:flutter/material.dart';

class BrandStrip extends StatelessWidget {
  const BrandStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 38,
            child: Image.asset('assets/images/logo_universidad_amazonia.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 36,
            height: 38,
            child: Image.asset('assets/images/logo_ingenieria_sistemas.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 28,
            height: 38,
            child: Image.asset('assets/images/logo_red_comunitaria.png', fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}
