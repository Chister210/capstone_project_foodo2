import 'package:capstone_project/role_select.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_project/MarketDonor/home_donor.dart';
import 'package:capstone_project/FoodReceiver/home_receiver.dart';
import 'package:capstone_project/config/firebase_config.dart';
import 'package:capstone_project/services/receiver_notification_service.dart';
import 'package:capstone_project/services/donor_notification_service.dart';
import 'package:capstone_project/services/push_token_service.dart';
import 'package:capstone_project/theme/app_theme.dart';
import 'package:capstone_project/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  await FirebaseConfig.initialize();
  await PushTokenService().initialize();
  
  // Initialize notification listeners (free plan, client-only)
  Get.put(ReceiverNotificationService());
  Get.put(DonorNotificationService());
  
  // No global notification initialization required
  
  // Initialize database (optional - for development/testing)
  // await DatabaseSetupService.initializeDatabase();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'FOODO App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          
          if (snapshot.hasData && snapshot.data != null) {
            final User user = snapshot.data!;
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen();
                }
                
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;

                  // read role and displayName separately (safe null-aware fallbacks)
                  final userType = (userData['userType'] as String?) ?? '';
                  final displayName = (userData['displayName'] as String?)
                    ?? (userData['name'] as String?)
                    ?? user.displayName
                    ?? user.email?.split('@')[0]
                    ?? 'User';

                  // Pass displayName into the appropriate home screen
                  if (userType == 'donor') {
                    return DonorHome(displayName: displayName);
                  } else if (userType == 'receiver') {
                    return ReceiverHome(displayName: displayName);
                  }
                }
                
                // If role is not set or user doesn't exist in Firestore, default to RoleSelect
                return const RoleSelect();
              },
            );
          }
          
          return const RoleSelect();
        },
      ),
    );
  }

  Widget _getHomePageBasedOnRole(User user) {
    // Check user's displayName to determine role
    if (user.displayName == 'donor') {
      return const DonorHome();
    } else if (user.displayName == 'receiver') {
      return const ReceiverHome();
    } else {
      // If role is not set, default to RoleSelect
      return const RoleSelect();
    }
  }
}