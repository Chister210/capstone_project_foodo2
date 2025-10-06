import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class OnboardingDot extends StatelessWidget {
  final int currentIndex;
  final int dotIndex;

  const OnboardingDot({
    super.key,
    required this.currentIndex,
    required this.dotIndex,
  });
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(duration: const Duration(milliseconds: 200),
    margin: const EdgeInsets.only(right:5),
    height: 10,
    width: currentIndex == dotIndex ? 20 : 10,
    decoration: BoxDecoration(
      color: currentIndex == dotIndex ?
      Colors.deepOrangeAccent : Colors.grey,
      borderRadius: BorderRadius.circular(5),
    ),
    );
  }

}