import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taxi_users/authentication/signup_screen.dart';
import 'package:taxi_users/methods/common_methods.dart';
import 'package:taxi_users/widgets/loading_dialog.dart'; // Assuming you have a loading dialog

import '../pages/home_page.dart';
import 'otp_verification_screen.dart'; // Assuming you have an OTP verification screen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController phoneTextEditingController = TextEditingController();
  String selectedCountryCode = '+225'; // Initialize with default country code
  String selectedFlag = '🇨🇮'; // Initialize with default flag
  int phoneNumberLength = 10; // Default length for Côte d'Ivoire
  CommonMethods cMethods = CommonMethods();

  final FirebaseAuth _auth = FirebaseAuth.instance; // Firebase Auth instance

  Future<void> checkIfNetworksAvailable() async {
    bool isConnected = await cMethods.checkConnectivity(context);
    if (isConnected) {
      loginFormValidation();
    }
  }

  Future<void> loginFormValidation() async {
    // Check if the phone number field is empty
    if (phoneTextEditingController.text.isEmpty) {
      cMethods.displaySnackBar("Please enter your Phone Number", context);
      return;
    }

    // Check if the phone number length matches the required length for the selected country code
    if (phoneTextEditingController.text.length != phoneNumberLength) {
      cMethods.displaySnackBar(
          "Please enter a valid phone number of length $phoneNumberLength",
          context);
      return;
    }

    String fullPhoneNumber =
        selectedCountryCode + phoneTextEditingController.text;

    // Display a loading dialog while sending OTP
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          LoadingDialog(messageText: "Sending OTP..."),
    );

    // Send OTP to phone number
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          Navigator.pop(
              context); // Close the loading dialog if verification is completed automatically
          // Auto-retrieval or instant verification on Android devices
          await _auth.signInWithCredential(credential);
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const HomePage()));
        },
        verificationFailed: (FirebaseAuthException e) {
          Navigator.pop(context); // Close the loading dialog
          cMethods.displaySnackBar(e.message.toString(), context);
        },
        codeSent: (String verificationId, int? resendToken) {
          Navigator.pop(context); // Close the loading dialog
          // Navigate to OTP verification screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(
                verificationId:
                    verificationId, // This should be the verification ID from Firebase
                phoneNumber: fullPhoneNumber,
                firstName: '',
                lastName:
                    '', // The phone number in the correct format with country code
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      Navigator.pop(context); // Close the loading dialog
      cMethods.displaySnackBar("An error occurred: $e", context);
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
                "Login as a User",
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
                        "Login",
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
                      MaterialPageRoute(builder: (c) => const SignUpScreen()));
                },
                child: RichText(
                  text: const TextSpan(
                    text: "Don't have an Account? ",
                    style: TextStyle(
                      color: Colors.white,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: 'Register Here',
                        style: TextStyle(
                          color: Colors
                              .yellow, // Make the "Register Here" text yellow
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
