import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class OnboardingContorller extends StatelessWidget{
  final String animation;
  final String title;
  final String description;

  const OnboardingContorller({
    super.key,
    required this.animation,
    required this.title,
    required this.description,
  });


  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children:[
        Lottie.asset(animation, height: 300, width: 300),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold
          ),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey
          ),
        ),
      ],
    );
  }
}