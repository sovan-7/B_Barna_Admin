import 'package:flutter/material.dart';
import 'package:bbarna/resources/app_colors.dart';

/// The black "+ NEW …" button at the top-right of every list screen.
// ignore: must_be_immutable
class AddWidget extends StatelessWidget {
  /// Opens the Add screen.
  final Function addCall;

  /// Button text, e.g. "NEW PDF".
  String title;

  /// Leading icon.
  IconData icon;
  AddWidget(
      {required this.addCall,
      this.title = "NEW",
      this.icon = Icons.add,
      super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        addCall();
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColorsInApp.colorBlack1,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: AppColorsInApp.colorWhite,
            ),
            const SizedBox(
              width: 5,
            ),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColorsInApp.colorWhite),
            ),
          ],
        ),
      ),
    );
  }
}
