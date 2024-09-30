import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:taxi_users/methods/common_methods.dart';
import 'package:taxi_users/widgets/loading_dialog.dart';


import '../pages/home_page.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final String firstName;
  final String lastName;

  const OtpVerificationScreen({
    required this.verificationId,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    Key? key,
  }) : super(key: key);

  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  CommonMethods cMethods = CommonMethods();
  List<TextEditingController> otpControllers = List.generate(6, (index) => TextEditingController());
  int _start = 60;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void startTimer() {
    _start = 60;
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
          (Timer timer) {
        if (_start == 0) {
          setState(() {
            timer.cancel();
          });
        } else {
          setState(() {
            _start--;
          });
        }
      },
    );
  }

  void verifyOtp() async {
    String otp = otpControllers.map((controller) => controller.text.trim()).join();
    if (otp.length != 6) {
      cMethods.displaySnackBar("Please enter a valid 6-digit OTP", context);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => LoadingDialog(messageText: "Verifying..."),
    );

    FirebaseAuth auth = FirebaseAuth.instance;

    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: widget.verificationId,
      smsCode: otp,
    );

    try {
      UserCredential userCredential = await auth.signInWithCredential(credential);
      Navigator.pop(context);
      handleSignIn(userCredential.user);
    } catch (e) {
      Navigator.pop(context);
      cMethods.displaySnackBar(e.toString(), context);
    }
  }

  void handleSignIn(User? user) {
    if (user != null) {
      DatabaseReference usersRef = FirebaseDatabase.instance.ref().child("users").child(user.uid);
      Map<String, String> userDataMap = {
        "First Name": widget.firstName,
        "Last Name": widget.lastName,
        "phone": widget.phoneNumber,
        "id": user.uid,
        "blockStatus": "no",
      };
      usersRef.set(userDataMap);
      Navigator.push(context, MaterialPageRoute(builder: (c) => HomePage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffdb1702),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/images/logo.png"),
              const Text(
                "OTP Verification",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const Text(
                      "Enter the OTP sent to your phone number",
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        return Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: TextField(
                            controller: otpControllers[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(1),
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Verify",
                        style: TextStyle(color: Color(0xffdb1702)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _start == 0
                        ? TextButton(
                      onPressed: () {
                        // Resend OTP code
                      },
                      child: const Text(
                        "Resend OTP",
                        style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
                      ),
                    )
                        : Text(
                      "Resend OTP in $_start seconds",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}