import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Preload the image to ensure it's available
    _preloadImage();
  }

  Future<void> _preloadImage() async {
    try {
      await precacheImage(
        const AssetImage('assets/logos/icon_foodo2.jpg'),
        context,
      );
    } catch (e) {
      debugPrint('Error precaching splash image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/logos/icon_foodo2.jpg',
          width: 300,
          height: 300,
          fit: BoxFit.contain,
          key: const ValueKey('splash_image'),
          errorBuilder: (context, error, stackTrace) {
            // If image fails to load, show a placeholder
            debugPrint('Error loading splash image: $error');
            return const Icon(
              Icons.restaurant,
              size: 100,
              color: Colors.grey,
            );
          },
        ),
      ),
    );
  }
}

