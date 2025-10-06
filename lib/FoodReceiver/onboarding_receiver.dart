import 'package:capstone_project/onboarding_controller.dart';
import 'package:capstone_project/onboarding_dot.dart';
import 'package:flutter/material.dart';
import 'home_receiver.dart'; // Adjust the import path as needed

class OnboardingReceiver extends StatefulWidget {
  const OnboardingReceiver({super.key});

  @override
  _OnboardingReceiverState createState() => _OnboardingReceiverState();
}

class _OnboardingReceiverState extends State<OnboardingReceiver>{
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<Map<String, String>> onboardingData = [
    {
      "animation": "assets/lottie_files/onboarding_welcome.json",
      "title": "Welcome to Foodo",
      "description": "Connecting those in need with surplus food from local donors.",
    },
    {
      "animation": "assets/lottie_files/onboarding_receiver2.json",
      "title": "Find Nearby Donations",
      "description": "Easily locate food donations in your area and claim them.",
    },
    {
      "animation": "assets/lottie_files/onboarding_receiver1.json",
      "title": "Fair & Safe Sharing",
      "description": "Every receiver gets a fair chance. Donations follow food safety guidelines to ensure quality and care.",
    },
    {
      "animation": "assets/lottie_files/onboarding_receiver3.json",
      "title": "Let's Share the Blessings",
      "description": "Start exploring available food donations near you and enjoy fresh, nutritious meals while being part of our community.",
    },
  ];

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ReceiverHome()), // Navigate to ReceiverHome
    );
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
                  itemBuilder: (context, index) => OnboardingContorller(
                    animation: onboardingData[index]['animation']!,
                    title: onboardingData[index]['title']!,
                    description: onboardingData[index]['description']!,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    // Spacer to push dots to bottom
                    Spacer(),
                    // Navigation dots at the bottom
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
                    const SizedBox(height: 20), // Add some space between dots and button
                    // Wider button with horizontal margin
                    Container(
                      width: double.infinity, // Make button take full width
                      margin: const EdgeInsets.symmetric(horizontal: 40), // Add left and right margin
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
                    const SizedBox(height: 20), // Add some space at the bottom
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