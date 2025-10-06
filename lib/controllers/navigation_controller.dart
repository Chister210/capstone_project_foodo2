import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:capstone_project/screens/map_screen.dart';
import 'package:capstone_project/screens/profile_screen.dart';

class NavigationController extends GetxController {
  final RxInt currentIndex = 0.obs;
  final PageController pageController = PageController();

  void changePage(int index) {
    currentIndex.value = index;
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
