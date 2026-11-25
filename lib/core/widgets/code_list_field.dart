import 'package:flutter/material.dart';
import 'package:bbarna/resources/app_colors.dart';

class CodeListField extends StatelessWidget {
  final String label;
  final List<TextEditingController> controllerList;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const CodeListField({
    required this.label,
    required this.controllerList,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(
                  left: 10,
                  top: 10,
                  bottom: 10,
                ),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                    border: Border.all(
                  width: 1,
                  color: AppColorsInApp.colorGrey,
                )),
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppColorsInApp.colorBlack1),
                ),
              ),
            ),
          ],
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(controllerList.length, (index) {
            return Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(
                      top: 20,
                      bottom: 20,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(
                            width: 1, color: AppColorsInApp.colorGrey),
                        right: BorderSide(
                            width: 1, color: AppColorsInApp.colorGrey),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.only(
                        left: 10,
                        right: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: AppColorsInApp.colorWhite,
                      ),
                      child: TextField(
                        controller: controllerList[index],
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(
                              borderSide: BorderSide(
                                  width: 1, color: AppColorsInApp.colorGrey)),
                          labelText: label,
                          labelStyle: const TextStyle(
                              color: AppColorsInApp.colorGrey, fontSize: 12),
                          contentPadding: const EdgeInsets.only(
                            left: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                    width: 60,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        border: Border(
                            right: BorderSide(
                                width: 1, color: AppColorsInApp.colorGrey))),
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 24,
                        color: AppColorsInApp.colorPrimary,
                      ),
                      onPressed: () {
                        // Deferred to after the current frame: removing this
                        // button's own row synchronously (still under the
                        // pointer that triggered the click) re-enters
                        // MouseTracker's device-update phase and trips its
                        // `!_debugDuringDeviceUpdate` assertion on web.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          onRemove(index);
                        });
                      },
                    )),
              ],
            );
          }),
        ),
        Container(
          height: 50,
          decoration: BoxDecoration(
              border: controllerList.isNotEmpty
                  ? Border.all(width: 1, color: AppColorsInApp.colorGrey)
                  : const Border(
                      bottom:
                          BorderSide(width: 1, color: AppColorsInApp.colorGrey),
                      left:
                          BorderSide(width: 1, color: AppColorsInApp.colorGrey),
                      right:
                          BorderSide(width: 1, color: AppColorsInApp.colorGrey),
                    )),
          child: InkWell(
            onTap: () {
              onAdd();
            },
            child: Container(
              height: 40,
              alignment: Alignment.center,
              padding:
                  const EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 5),
              margin: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: AppColorsInApp.colorBlue,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add,
                    size: 20,
                    color: Colors.white,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text(
                      "Add more line",
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: AppColorsInApp.colorWhite),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
