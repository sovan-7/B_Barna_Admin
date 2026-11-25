import 'package:flutter/material.dart';
import 'package:bbarna/resources/app_colors.dart';

class ActiveButton extends StatelessWidget {
  final bool isActive;
  const ActiveButton({this.isActive = true, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 15, right: 15, top: 10, bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isActive
            ? AppColorsInApp.colorSecondary!.withValues(alpha: .7)
            : AppColorsInApp.colorLightRed,
      ),
      child: const Text(
        "ACTIVE",
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: AppColorsInApp.colorWhite),
      ),
    );
  }
}
