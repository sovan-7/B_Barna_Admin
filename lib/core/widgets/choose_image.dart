// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:bbarna/resources/app_colors.dart';

class ChooseImage extends StatelessWidget {
  Function onSelectImage;
  final String title;
  ChooseImage(
      {required this.onSelectImage, this.title = "Choose Image", super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: InkWell(
          onTap: () {
            onSelectImage();
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColorsInApp.colorGrey.withValues(alpha: .2),
            ),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.normal,
                    color: AppColorsInApp.colorBlack1)),
          ),
        ));
  }
}
