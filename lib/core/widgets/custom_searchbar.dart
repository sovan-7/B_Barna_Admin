// ignore_for_file: must_be_immutable

import 'package:bbarna/resources/app_colors.dart';
import 'package:flutter/material.dart';

class CustomSearchBar extends StatelessWidget {
  Function onChange;
  Function onClear;
  TextEditingController textEditingController;
  CustomSearchBar(
      {required this.onChange,
      required this.onClear,
      required this.textEditingController,
      super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(
        top: 10,
      ),
      child: TextField(
        controller: textEditingController,
        decoration: InputDecoration(
            hintText: 'Search',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: Icon(
              Icons.search,
              color: AppColorsInApp.colorGreyWhite,
              size: 25,
            ),
            suffix: textEditingController.text.isEmpty
                ? const SizedBox()
                : Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: InkWell(
                        onTap: () {
                          onClear();
                        },
                        child: const Icon(
                          Icons.close,
                          color: AppColorsInApp.colorBlack1,
                          size: 25,
                        )),
                  )),
        onChanged: (value) {
          onChange();
        },
      ),
    );
  }
}
