import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/units/widgets/unit_form.dart';
import 'package:flutter/material.dart';

/// Edit Unit screen — the shared [UnitForm] pre-populated with [unitData];
/// also offers Delete.
class EditUnit extends StatelessWidget {
  /// The item being edited.
  final UnitModel unitData;
  const EditUnit({required this.unitData, super.key});

  @override
  Widget build(BuildContext context) => UnitForm(existing: unitData);
}
