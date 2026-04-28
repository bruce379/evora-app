import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// PhoneShell wraps the app in a phone-shaped container on web desktop.
/// On mobile web or native, renders full screen.
class PhoneShell extends StatelessWidget {
  final Widget child;

  const PhoneShell({super.key, required this.child});

  // iPhone 14 Pro dimensions
  static const double _phoneWidth = 393.0;
  static const double _phoneHeight = 852.0;
  static const double _borderRadius = 44.0;
  static const double _shellBreakpoint = 768.0; // below this = full screen

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Mobile web: full screen
        if (constraints.maxWidth < _shellBreakpoint) {
          return child;
        }

        // Desktop web: centered phone shell
        return Container(
          color: const Color(0xFF060606),
          child: Center(
            child: Container(
              width: _phoneWidth,
              height: _phoneHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 60,
                    spreadRadius: 10,
                    offset: const Offset(0, 20),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.04),
                    blurRadius: 0,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_borderRadius),
                child: Stack(
                  children: [
                    // App content
                    child,
                    // Dynamic island overlay
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 120,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
