import 'package:capstone_project/role_select.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:capstone_project/MarketDonor/home_donor.dart';
import 'package:capstone_project/FoodReceiver/home_receiver.dart';
import 'package:capstone_project/config/firebase_config.dart';
import 'package:capstone_project/services/database_setup_service.dart';
import 'package:capstone_project/services/notification_service.dart';
import 'package:capstone_project/services/background_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  await FirebaseConfig.initialize();
  
  // Initialize background notification service
  await BackgroundNotificationService.initialize();
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Initialize notification service
  await NotificationService().initialize();
  
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
      debugShowCheckedModeBanner: false, // Add this line to remove DEBUG banner
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          if (snapshot.hasData && snapshot.data != null) {
            final User user = snapshot.data!;
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final userType = userData['userType'] ?? user.displayName;
                  
                  if (userType == 'donor') {
                    return const DonorHome();
                  } else if (userType == 'receiver') {
                    return const ReceiverHome();
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