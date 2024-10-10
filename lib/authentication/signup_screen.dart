import 'dart:core';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taxi_users/authentication/login_screen.dart';
import 'package:taxi_users/methods/common_methods.dart';
import 'package:taxi_users/widgets/loading_dialog.dart';

import '../pages/home_page.dart';
import 'otp_verification_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  TextEditingController firstNameTextEditingController =
      TextEditingController();
  TextEditingController lastNameTextEditingController = TextEditingController();
  TextEditingController phoneTextEditingController = TextEditingController();
  String selectedCountryCode = '+225'; // Initialize with default country code
  String selectedFlag = '🇨🇮'; // Initialize with default flag
  int phoneNumberLength = 10; // Default length for Côte d'Ivoire
  String verificationId = "";
  CommonMethods cMethods = CommonMethods();

  Future<void> checkIfNetworksAvailable() async {
    bool isConnected = await cMethods.checkConnectivity(context);
    if (isConnected) {
      signUpFormValidation();
    }
  }

  void signUpFormValidation() {
    if (firstNameTextEditingController.text.isEmpty) {
      cMethods.displaySnackBar("Please add your First Name", context);
      return;
    }
    if (lastNameTextEditingController.text.isEmpty) {
      cMethods.displaySnackBar("Please add your Last Name", context);
      return;
    }
    if (phoneTextEditingController.text.isEmpty) {
      cMethods.displaySnackBar("Please add your Phone Number", context);
      return;
    } else {
      registerNewUser();
    }
  }

  void _showCountryPickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Platform.isIOS
            ? CupertinoAlertDialog(
                title: const Text('Select Country'),
                content: SizedBox(
                  height: 200,
                  child: CupertinoPicker(
                    itemExtent: 32.0,
                    onSelectedItemChanged: (int index) {
                      setState(() {
                        selectedCountryCode = countryList[index]['code']!;
                        selectedFlag = countryList[index]['flag']!;
                        switch (countryList[index]['code']) {
                          case '+225': // Côte d'Ivoire
                          case '+234': // Nigeria
                            phoneNumberLength = 10;
                            break;
                          case '+226': // Burkina Faso
                          case '+228': // Togo
                          case '+229': // Benin
                            phoneNumberLength = 8;
                            break;
                          case '+233': // Ghana
                            phoneNumberLength = 9;
                            break;
                          default:
                            phoneNumberLength = 8;
                            break;
                        }
                      });
                      Navigator.of(context).pop();
                    },
                    children: countryList.map((country) {
                      return Text('${country['flag']} ${country['name']}');
                    }).toList(),
                  ),
                ),
              )
            : AlertDialog(
                title: const Text('Select Country'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: countryList.length,
                    itemBuilder: (BuildContext context, int index) {
                      return ListTile(
                        leading: Text(countryList[index]['flag']!),
                        title: Text(countryList[index]['name']!),
                        onTap: () {
                          setState(() {
                            selectedCountryCode = countryList[index]['code']!;
                            selectedFlag = countryList[index]['flag']!;
                            switch (countryList[index]['code']) {
                              case '+225': // Côte d'Ivoire
                              case '+234': // Nigeria
                                phoneNumberLength = 10;
                                break;
                              case '+226': // Burkina Faso
                              case '+228': // Togo
                              case '+229': // Benin
                                phoneNumberLength = 8;
                                break;
                              case '+233': // Ghana
                                phoneNumberLength = 9;
                                break;
                              default:
                                phoneNumberLength = 8;
                                break;
                            }
                          });
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
              );
      },
    );
  }

  final List<Map<String, String>> countryList = [
    {'name': 'Côte d\'Ivoire', 'code': '+225', 'flag': '🇨🇮'},
    {'name': 'Burkina Faso', 'code': '+226', 'flag': '🇧🇫'},
    {'name': 'Togo', 'code': '+228', 'flag': '🇹🇬'},
    {'name': 'Benin', 'code': '+229', 'flag': '🇧🇯'},
    {'name': 'Ghana', 'code': '+233', 'flag': '🇬🇭'},
    {'name': 'Nigeria', 'code': '+234', 'flag': '🇳🇬'},
  ];

  registerNewUser() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          LoadingDialog(messageText: "Synchronization..."),
    );

    FirebaseAuth auth = FirebaseAuth.instance;

    await auth.verifyPhoneNumber(
      phoneNumber:
          "$selectedCountryCode${phoneTextEditingController.text.trim()}",
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-retrieval or instant verification on Android devices
        await auth
            .signInWithCredential(credential)
            .then((UserCredential result) {
          handleSignIn(result.user);
        }).catchError((error) {
          Navigator.pop(context);
          cMethods.displaySnackBar(error.toString(), context);
        });
      },
      verificationFailed: (FirebaseAuthException e) {
        Navigator.pop(context);
        cMethods.displaySnackBar(e.message.toString(), context);
      },
      codeSent: (String verificationId, int? resendToken) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              verificationId: verificationId,
              phoneNumber:
                  "$selectedCountryCode${phoneTextEditingController.text.trim()}",
              firstName: firstNameTextEditingController.text.trim(),
              lastName: lastNameTextEditingController.text.trim(),
            ),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        this.verificationId = verificationId;
      },
    );
  }

  void handleSignIn(User? user) {
    if (user != null) {
      DatabaseReference usersRef =
          FirebaseDatabase.instance.ref().child("users").child(user.uid);
      Map<String, String> userDataMap = {
        "First Name": firstNameTextEditingController.text.trim(),
        "Last Name": lastNameTextEditingController.text.trim(),
        "phone":
            "$selectedCountryCode${phoneTextEditingController.text.trim()}",
        "id": user.uid,
        "blockStatus": "no",
      };
      usersRef.set(userDataMap);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (c) => const HomePage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xffdb1702), // Vermillion red background color
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Image.asset(
                "assets/images/logo.png",
              ),
              const Text(
                "Create a User's Account",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: TextField(
                        controller: firstNameTextEditingController,
                        keyboardType: TextInputType.text,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z]')),
                        ],
                        decoration: const InputDecoration(
                          hintText: "First Name",
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: TextField(
                        controller: lastNameTextEditingController,
                        keyboardType: TextInputType.text,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z]')),
                        ],
                        decoration: const InputDecoration(
                          hintText: "Last Name",
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _showCountryPickerDialog,
                            child: Row(
                              children: [
                                Text(
                                  selectedFlag,
                                  style: const TextStyle(fontSize: 24.0),
                                ),
                                const SizedBox(width: 8.0),
                                Text(
                                  selectedCountryCode,
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold),
                                ),
                                const Icon(Icons.arrow_drop_down,
                                    color: Colors.black),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: TextFormField(
                              controller: phoneTextEditingController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: "Phone Number",
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                border: InputBorder.none,
                              ),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(
                                    phoneNumberLength),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        checkIfNetworksAvailable();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        minimumSize: const Size(
                            double.infinity, 50), // Make the button long
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          color: Color(0xffdb1702), // Vermillion red text color
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (c) => const LoginScreen()));
                },
                child: RichText(
                  text: const TextSpan(
                    text: "Already have an Account? ",
                    style: TextStyle(
                      color: Colors.white,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: 'Login Here',
                        style: TextStyle(
                          color: Colors
                              .yellow, // Make the "Login Here" text yellow
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
