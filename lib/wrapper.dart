import 'package:capstone_project/MarketDonor/home_donor.dart';
import 'package:capstone_project/FoodReceiver/home_receiver.dart';
import 'package:capstone_project/role_select.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if(snapshot.hasData){
            print(snapshot.data);
          final user = snapshot.data!;
          final role = user.displayName;
          if (role == 'donor') {
            return const DonorHome();
          } else if (role == 'receiver') {
            return const ReceiverHome();
          } else {
            return const RoleSelect();
          }
          }else{
            return const RoleSelect();
          }
        },),
    );
  }
}
