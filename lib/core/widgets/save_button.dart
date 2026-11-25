// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:bbarna/resources/app_colors.dart';

class SaveButton extends StatelessWidget {
  Function onPRess;
  String? buttonText;
  Color? buttonColor;
  SaveButton(
      {required this.onPRess,
      this.buttonText = "Save",
      this.buttonColor = Colors.green,
      super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onPRess();
      },
      child: Container(
        height: 40,
        width: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10), color: buttonColor),
        child: Text(buttonText!,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: buttonText == "Save"
                    ? AppColorsInApp.colorWhite
                    : AppColorsInApp.colorBlack1)),
      ),
    );
  }
}
