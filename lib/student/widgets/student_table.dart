import 'package:bbarna/core/widgets/list_page/admin_table.dart';
import 'package:bbarna/core/widgets/list_page/table_cells.dart';
import 'package:bbarna/core/widgets/list_page/table_identity.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/student/model/student_model.dart';
import 'package:bbarna/student/widgets/student_activity.dart';
import 'package:bbarna/student/widgets/student_card.dart';
import 'package:flutter/material.dart';

/// The student list on wide screens: one row per student with photo, name
/// and email, phone (and whether there is a WhatsApp number), the phone
/// holding their login (tap to sign them out of it), last sign-in, and
/// enrolments / delete on hover.
class StudentTable extends StatelessWidget {
  /// The students shown, already searched.
  final List<Student> students;

  const StudentTable({required this.students, super.key});

  /// Narrowest list width the table is used at (cards below it).
  static const double minWidth = 820;

  static const List<AdminTableColumn> _columns = [
    AdminTableColumn("Student", flex: 4),
    AdminTableColumn("Phone", width: 140),
    AdminTableColumn("Device", width: 180),
    AdminTableColumn("Last active", width: 150),
    AdminTableColumn("", width: 76, alignment: Alignment.centerRight),
  ];

  @override
  Widget build(BuildContext context) {
    return AdminTable(
      columns: _columns,
      rowCount: students.length,
      rowKey: (i) => ValueKey('student_row_${students[i].studentId}'),
      cellsBuilder: (context, i, hovered) {
        final Student student = students[i];
        final String name =
            studentValue(student.studentName, "Unnamed student");
        return [
          TableIdentity(
            title: name,
            subtitle: studentValue(student.studentEmail, "No email"),
            imageUrl: student.studentProfileImage,
            initial: name.characters.first,
          ),
          _phone(student),
          studentDeviceChip(context, student),
          activityPill(student.lastLoginAt),
          studentActions(context, student, hovered),
        ];
      },
    );
  }

  /// The mobile number (selectable) with a WhatsApp mark when the student
  /// gave a WhatsApp number too.
  Widget _phone(Student student) {
    final String phone = studentValue(student.studentPhoneNumber, "");
    if (phone.isEmpty) return const TableText(null);
    // Like the card: only worth a mark when it is a different number.
    final String whatsapp = student.studentWhatsappNumber.trim();
    final bool hasWhatsapp = whatsapp.isNotEmpty &&
        whatsapp != stringDefault &&
        whatsapp != phone.trim();
    return Row(
      children: [
        Flexible(
          child: SelectableLabel(phone,
              style:
                  const TextStyle(fontSize: 12.5, color: AppTokens.inkMuted)),
        ),
        if (hasWhatsapp) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: "WhatsApp ${student.studentWhatsappNumber}",
            child: const Icon(Icons.chat_outlined,
                size: 14, color: AppTokens.successText),
          ),
        ],
      ],
    );
  }
}

/// "Active today" (green) … "No sign-in recorded" (grey).
Widget activityPill(DateTime? lastLoginAt, {DateTime? now}) {
  final String? label = StudentActivity.lastActiveLabel(lastLoginAt, now: now);
  if (label == null) return const StatusPill(StudentActivity.neverLabel);
  final bool recent = label == "Active today" || label == "Active yesterday";
  return StatusPill(label,
      tone: recent ? StatusTone.success : StatusTone.neutral);
}
