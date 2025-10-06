import 'package:capstone_project/wrapper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/route_manager.dart';
import 'package:get/get.dart';


class Verify extends StatefulWidget {
  const Verify({super.key});

  @override
  State<Verify> createState() => _VerifyState();
}



class _VerifyState extends State<Verify> {

  @override
  void initState() {
    sendverifylink();
    super.initState();
  }

  sendverifylink() async {
    final user = FirebaseAuth.instance.currentUser!;
    await user.sendEmailVerification().then((value) => {
      Get.snackbar('Verification link sent', 'Please check your email',margin: EdgeInsets.all(30),snackPosition: SnackPosition.BOTTOM)
    });
  }

  reload()async{
    await FirebaseAuth.instance.currentUser!.reload().then((value) => {
      if(FirebaseAuth.instance.currentUser!.emailVerified){
        Get.offAll(Wrapper())
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Center(
          child: Text('Open your email and click on the link to verify your account'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (() => reload()),
        child: Icon(Icons.restart_alt_rounded),
      ),
    );
  }
}