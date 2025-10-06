import 'package:capstone_project/onboarding_controller.dart';
import 'package:capstone_project/onboarding_dot.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // Add this import
import 'home_donor.dart';

class OnboardingDonor extends StatefulWidget {
  const OnboardingDonor({super.key});

  @override
  _OnboardingDonorState createState() => _OnboardingDonorState();
}

class _OnboardingDonorState extends State<OnboardingDonor>{
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<Map<String, String>> onboardingData = [
    {
      "animation": "assets/lottie_files/onboarding_welcome.json",
      "title": "Welcome to Foodo",
      "description": "Connecting those in need with surplus food from local donors.",
    },
    {
      "animation": "assets/lottie_files/onboarding_donor1.json",
      "title": "Donate unsold Food",
      "description": "Join us in reducing food waste and helping families in need. Your extra market food can make a big difference.",
    },
    {
      "animation": "assets/lottie_files/onboarding_donor2.json",
      "title": "Donate in Just a Few Taps",
      "description": "List your unsold food, set pickup time, and we'll handle the rest.",
    },
    {
      "animation": "assets/lottie_files/onboarding_donor3.json",
      "title": "Why Donate?",
      "description": "Be recognized as a socially responsible vendor while helping others. Together, we can create a community where surplus food finds a purpose.",
    },
  ];

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => DonorHome()),
    );
  }

  // Custom widget for the specific screen with transparent animation
  Widget _buildCustomOnboardingScreen(int index) {
    if (onboardingData[index]['animation'] == "assets/lottie_files/onboarding_donor3.json") {
      // Special case for the donor3 animation with transparent background
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animation with transparent background
          Container(
            color: Colors.transparent,
            child: Lottie.asset(
              onboardingData[index]['animation']!,
              height: 250,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 40),
          // Centered title with margins
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              onboardingData[index]['title']!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Centered description with margins
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              onboardingData[index]['description']!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      );
    } else {
      // Use the original controller for other screens
      return OnboardingContorller(
        animation: onboardingData[index]['animation']!,
        title: onboardingData[index]['title']!,
        description: onboardingData[index]['description']!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Color(0xFFF1F5F9),
              Color(0xFFE0F7FA),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (value){
                    setState((){
                      _currentPage = value;
                    });
                  },
                  itemCount: onboardingData.length,
                  itemBuilder: (context, index) => _buildCustomOnboardingScreen(index),
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        onboardingData.length,
                        (index) => OnboardingDot(
                          currentIndex: _currentPage,
                          dotIndex: index,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      child: ElevatedButton(
                        onPressed: (){
                          if(_currentPage == onboardingData.length - 1){
                            _navigateToHome();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300), 
                              curve: Curves.ease
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.deepOrangeAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                        ),
                        child: Text(
                          _currentPage == onboardingData.length - 1 ?
                          "Get Started" : "Next",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}