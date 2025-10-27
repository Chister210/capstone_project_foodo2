import 'package:flutter/material.dart';

class ResponsiveLayout {
  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 768;
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= 768 && MediaQuery.of(context).size.width < 1024;
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 1024;

  static double getScreenWidth(BuildContext context) => MediaQuery.of(context).size.width;
  static double getScreenHeight(BuildContext context) => MediaQuery.of(context).size.height;

  // Responsive padding
  static EdgeInsets getPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24);
    } else {
      return const EdgeInsets.all(32);
    }
  }

  // Responsive font sizes
  static double getTitleFontSize(BuildContext context) {
    if (isMobile(context)) return 24;
    if (isTablet(context)) return 28;
    return 32;
  }

  static double getSubtitleFontSize(BuildContext context) {
    if (isMobile(context)) return 16;
    if (isTablet(context)) return 18;
    return 20;
  }

  static double getBodyFontSize(BuildContext context) {
    if (isMobile(context)) return 14;
    if (isTablet(context)) return 16;
    return 18;
  }

  // Responsive spacing
  static double getSpacing(BuildContext context) {
    if (isMobile(context)) return 8;
    if (isTablet(context)) return 12;
    return 16;
  }

  // Responsive grid columns
  static int getGridColumns(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 2;
    return 3;
  }

  // Responsive card width
  static double getCardWidth(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    if (isMobile(context)) return screenWidth - 32;
    if (isTablet(context)) return (screenWidth - 48) / 2;
    return (screenWidth - 64) / 3;
  }

  // Responsive button height
  static double getButtonHeight(BuildContext context) {
    if (isMobile(context)) return 48;
    if (isTablet(context)) return 52;
    return 56;
  }

  // Responsive icon size
  static double getIconSize(BuildContext context) {
    if (isMobile(context)) return 24;
    if (isTablet(context)) return 28;
    return 32;
  }

  // Responsive border radius
  static double getBorderRadius(BuildContext context) {
    if (isMobile(context)) return 12;
    if (isTablet(context)) return 16;
    return 20;
  }
}

class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayout.isDesktop(context) && desktop != null) {
      return desktop!;
    } else if (ResponsiveLayout.isTablet(context) && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}
