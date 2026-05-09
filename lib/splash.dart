import 'package:flutter/material.dart';

// Make sure to import your main and class files so it knows where to navigate
import 'main.dart';
import 'class.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.parchment, // Uses centralized theme
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --------------------------
              // TOP: TITLE
              // --------------------------
              const Text(
                'HYMNS OF PRAISE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.font,
                  fontSize: 42.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: AppTheme.leather,
                ),
              ),

              // --------------------------
              // MIDDLE: ILLUSTRATION
              // --------------------------
              Expanded(
                child: Center(
                  child: Image.asset(
                    'assets/images/choir.png',
                    fit: BoxFit.contain,
                    // color: AppTheme.ink,
                    // colorBlendMode: BlendMode.srcIn,
                  ),
                ),
              ),

              // --------------------------
              // BUTTON: ENTER
              // --------------------------
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => Contents(storage: ContentStorage()),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.leather,
                  foregroundColor: AppTheme.parchment,
                  padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  elevation: 3,
                ),
                child: const Text(
                  'Enter Hymnary',
                  style: TextStyle(
                    fontFamily: AppTheme.font,
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),

              const SizedBox(height: 48.0), // Spacing between button and footer

              // --------------------------
              // BOTTOM: CREDITS
              // --------------------------
              const Column(
                children: [
                  Text(
                    'Compiled by: Dr. Manas Ranjan Patra',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.font,
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.ink,
                    ),
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    'Donated to Oriya Baptist Church,\nChurch of North India Berhampur - 760005.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.font,
                      fontSize: 13.0,
                      color: AppTheme.leather,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    'Developed by: Obed Yameogo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.font,
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}