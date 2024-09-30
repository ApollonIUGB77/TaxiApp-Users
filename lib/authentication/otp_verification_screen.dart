import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taxi_users/methods/common_methods.dart';
import 'package:taxi_users/widgets/loading_dialog.dart';

import '../authentication/login_screen.dart'; // Ensure this path is correct
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
  final CommonMethods cMethods = CommonMethods();
  final List<TextEditingController> otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> focusNodes = List.generate(6, (index) => FocusNode());
  Timer? _timer;

  // Security Measures
  int failedAttempts = 0;
  final List<int> waitTimes = [30, 60, 120]; // Wait times in seconds

  // State variables
  int _start = 0; // Timer start value
  bool _canVerify = true; // Determines if "Verify" button is enabled
  bool _canResend = false; // Determines if "Resend OTP" button is enabled

  @override
  void initState() {
    super.initState();
    // Automatically focus on the first OTP field after the frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(focusNodes[0]);
    });
    // Add listeners to each FocusNode to update UI on focus change
    for (var node in focusNodes) {
      node.addListener(() {
        setState(() {}); // Rebuild to update border color
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Dispose all controllers and focus nodes to free resources
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void startWaitTimer(int seconds) {
    setState(() {
      _start = seconds;
      _canVerify = false;
      _canResend = false;
    });
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer timer) {
        if (_start == 0) {
          setState(() {
            _canVerify = true;
            _canResend = true;
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
    String otp =
        otpControllers.map((controller) => controller.text.trim()).join();
    if (otp.length != 6) {
      cMethods.displaySnackBar("Please enter a valid 6-digit OTP", context);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          LoadingDialog(messageText: "Verifying..."),
    );

    FirebaseAuth auth = FirebaseAuth.instance;

    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: widget.verificationId,
      smsCode: otp,
    );

    try {
      UserCredential userCredential =
          await auth.signInWithCredential(credential);
      Navigator.pop(context);
      handleSignIn(userCredential.user);
    } catch (e) {
      Navigator.pop(context);
      setState(() {
        failedAttempts += 1;
      });
      if (failedAttempts >= 3) {
        // Block the user and redirect to login
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Too Many Attempts"),
              content: const Text(
                  "You have entered the wrong OTP 3 times. Please try again later."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                    );
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      } else {
        // Determine wait time based on failed attempts
        int waitTime = waitTimes[failedAttempts - 1];
        cMethods.displaySnackBar("Invalid OTP. Please try again.", context);
        // Start the wait timer
        startWaitTimer(waitTime);
      }
    }
  }

  void handleSignIn(User? user) {
    if (user != null) {
      DatabaseReference usersRef =
          FirebaseDatabase.instance.ref().child("users").child(user.uid);
      Map<String, String> userDataMap = {
        "First Name": widget.firstName,
        "Last Name": widget.lastName,
        "phone": widget.phoneNumber,
        "id": user.uid,
        "blockStatus": "no",
      };
      usersRef.set(userDataMap);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (c) => const HomePage()),
      );
    }
  }

  void _onOtpChanged(String value, int index) {
    if (value.isNotEmpty) {
      // Move focus to the next field if available
      if (index + 1 < focusNodes.length) {
        FocusScope.of(context).requestFocus(focusNodes[index + 1]);
      } else {
        FocusScope.of(context)
            .unfocus(); // Close the keyboard if it's the last field
      }
    } else {
      // If the field is empty and user pressed backspace, move to previous
      // This will be handled in the Focus widget's onKey callback
    }
  }

  // Check if all OTP fields are filled
  bool get isOtpComplete =>
      otpControllers.every((controller) => controller.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xffdb1702),
        appBar: AppBar(
          backgroundColor: const Color(0xffdb1702),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: GestureDetector(
            // Dismiss the keyboard when tapping outside the TextFields
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: Center(
                // Center the content vertically and horizontally
                child: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset("assets/images/logo.png"),
                              const SizedBox(height: 20),
                              const Text(
                                "OTP Verification",
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 22),
                              Padding(
                                padding: const EdgeInsets.all(22),
                                child: Column(
                                  children: [
                                    const Text(
                                      "Enter the OTP sent to your phone number",
                                      style: TextStyle(color: Colors.white),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 22),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: List.generate(6, (index) {
                                        return Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4.0),
                                            child: Focus(
                                              onKey: (FocusNode node,
                                                  RawKeyEvent event) {
                                                if (event is RawKeyDownEvent &&
                                                    event.logicalKey ==
                                                        LogicalKeyboardKey
                                                            .backspace) {
                                                  if (otpControllers[index]
                                                      .text
                                                      .isEmpty) {
                                                    if (index > 0) {
                                                      FocusScope.of(context)
                                                          .requestFocus(
                                                              focusNodes[
                                                                  index - 1]);
                                                      otpControllers[index - 1]
                                                          .clear();
                                                    }
                                                    return KeyEventResult
                                                        .handled;
                                                  }
                                                }
                                                return KeyEventResult.ignored;
                                              },
                                              child: Container(
                                                width:
                                                    45, // Retained width as per request
                                                height:
                                                    45, // Retained height as per request
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0),
                                                  border: Border.all(
                                                    color: focusNodes[index]
                                                            .hasFocus
                                                        ? Colors.blue
                                                        : Colors.grey,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: TextField(
                                                  controller:
                                                      otpControllers[index],
                                                  focusNode: focusNodes[index],
                                                  keyboardType:
                                                      TextInputType.number,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontSize:
                                                        20, // Adjusted font size
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  decoration:
                                                      const InputDecoration(
                                                    // Adjusted padding to prevent border overflow
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                            vertical: 12),
                                                    border: InputBorder.none,
                                                  ),
                                                  inputFormatters: [
                                                    LengthLimitingTextInputFormatter(
                                                        1),
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                  ],
                                                  onChanged: (value) {
                                                    _onOtpChanged(value, index);
                                                  },
                                                  onTap: () {
                                                    // When tapping on a box, focus it
                                                    FocusScope.of(context)
                                                        .requestFocus(
                                                            focusNodes[index]);
                                                  },
                                                  onSubmitted: (value) {
                                                    if (index == 5) {
                                                      verifyOtp();
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 32),
                                    ElevatedButton(
                                      onPressed: _canVerify && isOtpComplete
                                          ? verifyOtp
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        minimumSize:
                                            const Size(double.infinity, 50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text(
                                        "Verify",
                                        style: TextStyle(
                                          color: Color(0xffdb1702),
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _canResend
                                        ? TextButton(
                                            onPressed: () async {
                                              // Resend OTP code
                                              FirebaseAuth auth =
                                                  FirebaseAuth.instance;
                                              showDialog(
                                                context: context,
                                                barrierDismissible: false,
                                                builder: (BuildContext
                                                        context) =>
                                                    LoadingDialog(
                                                        messageText:
                                                            "Resending OTP..."),
                                              );
                                              try {
                                                await auth.verifyPhoneNumber(
                                                  phoneNumber:
                                                      widget.phoneNumber,
                                                  timeout: const Duration(
                                                      seconds: 60),
                                                  verificationCompleted:
                                                      (PhoneAuthCredential
                                                          credential) async {
                                                    Navigator.pop(
                                                        context); // Close the dialog
                                                    // Instant verification or auto-retrieval on Android devices
                                                    await auth
                                                        .signInWithCredential(
                                                            credential);
                                                    Navigator.pushReplacement(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              const HomePage()),
                                                    );
                                                  },
                                                  verificationFailed:
                                                      (FirebaseAuthException
                                                          e) {
                                                    Navigator.pop(
                                                        context); // Close the dialog
                                                    cMethods.displaySnackBar(
                                                        e.message.toString(),
                                                        context);
                                                  },
                                                  codeSent:
                                                      (String verificationId,
                                                          int? resendToken) {
                                                    Navigator.pop(
                                                        context); // Close the dialog
                                                    // Navigate to the OTP verification screen with the new verification ID
                                                    Navigator.pushReplacement(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            OtpVerificationScreen(
                                                          verificationId:
                                                              verificationId,
                                                          phoneNumber: widget
                                                              .phoneNumber,
                                                          firstName:
                                                              widget.firstName,
                                                          lastName:
                                                              widget.lastName,
                                                        ),
                                                      ),
                                                    );
                                                    // Reset the timer with current waitTime
                                                    _timer?.cancel();
                                                    startWaitTimer(waitTimes[
                                                        failedAttempts - 1]);
                                                  },
                                                  codeAutoRetrievalTimeout:
                                                      (String
                                                          verificationId) {},
                                                );
                                              } catch (e) {
                                                Navigator.pop(context);
                                                cMethods.displaySnackBar(
                                                    "An error occurred: $e",
                                                    context);
                                              }
                                            },
                                            child: const Text(
                                              "Resend OTP",
                                              style: TextStyle(
                                                color: Colors
                                                    .blueAccent, // Visible color
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            "Resend OTP in $_start seconds",
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                  ],
                                ),
                              ),
                            ]))))));
  }
}
