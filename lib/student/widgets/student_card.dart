import 'package:bbarna/core/widgets/card/admin_card_shell.dart';
import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/card/image_or_initial.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/student/model/student_model.dart';
import 'package:bbarna/student/screen/settings_student.dart';
import 'package:bbarna/student/viewModel/student_view_model.dart';
import 'package:bbarna/student/widgets/student_activity.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One row of the student list: avatar, name, contact details and last
/// sign-in; a device chip that signs the student out of every device; and
/// buttons for their enrolled courses and for deleting them.
class StudentCard extends StatefulWidget {
  /// The item shown in this row.
  final Student student;

  /// Called after an edit or delete so the list can reload.
  final VoidCallback onChanged;

  const StudentCard(
      {required this.student, required this.onChanged, super.key});

  @override
  State<StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<StudentCard> {
  /// Shortcut for the item shown.
  Student get _data => widget.student;

  /// Device count as an int (the stored value may be a string).
  int get _deviceCount {
    final dynamic count = _data.deviceCount;
    if (count is int) return count;
    return int.tryParse("$count") ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return AdminCardShell(
      builder: (context, layout) {
        final bool isCompact = layout.isCompact;
        final bool showActions = layout.showActions;
        return isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _identity(),
                  const SizedBox(height: 10),
                  _deviceChip(),
                  const SizedBox(height: 6),
                  Align(
                      alignment: Alignment.centerRight,
                      child: _actions(showActions)),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _identity()),
                  const SizedBox(width: AppTokens.gapMd),
                  _deviceChip(),
                  const SizedBox(width: AppTokens.gapSm),
                  _actions(showActions),
                ],
              );
      },
    );
  }

  /// Left part of the row: picture or icon, name, code and details.
  Widget _identity() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _avatar(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableLabel(
                _value(_data.studentName, "Unnamed student"),
                style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink),
              ),
              const SizedBox(height: 4),
              // Phone, WhatsApp and email on one wrapping line.
              Wrap(
                spacing: 14,
                runSpacing: 3,
                children: [
                  _fact(Icons.phone_outlined,
                      _value(_data.studentPhoneNumber, "No phone")),
                  // Only when it differs: most students give the same
                  // number twice, and printing it again says nothing.
                  if (_whatsappNumber != null)
                    _fact(Icons.chat_outlined, _whatsappNumber!),
                  _fact(Icons.mail_outline,
                      _value(_data.studentEmail, "No email")),
                ],
              ),
              const SizedBox(height: 4),
              _lastActive(),
            ],
          ),
        ),
      ],
    );
  }

  /// The WhatsApp number, or null when there isn't one worth showing
  /// separately from the phone number.
  String? get _whatsappNumber {
    final String number = _data.studentWhatsappNumber.trim();
    if (number.isEmpty || number == stringDefault) return null;
    if (number == _data.studentPhoneNumber.trim()) return null;
    return number;
  }

  /// When the student last opened the app ("Never signed in" when they
  /// haven't), so active students stand out from inactive ones.
  Widget _lastActive() {
    final String? label = StudentActivity.lastActiveLabel(_data.lastLoginAt);
    final bool never = label == null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(never ? Icons.schedule_outlined : Icons.history,
            size: 12,
            color: never ? AppTokens.inkFaint : const Color(0xFF108460)),
        const SizedBox(width: 5),
        Text(
          label ?? StudentActivity.neverLabel,
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: never ? FontWeight.w400 : FontWeight.w500,
              color: never ? AppTokens.inkFaint : AppTokens.inkMuted),
        ),
      ],
    );
  }

  /// [value], or [fallback] when it is blank or the "NA" placeholder.
  static String _value(String value, String fallback) =>
      value.trim().isEmpty || value == stringDefault ? fallback : value;

  /// A small grey icon + text pair (e.g. "90 min").
  Widget _fact(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTokens.inkFaint),
        const SizedBox(width: 5),
        // Capped: a Wrap only wraps *between* children, so one over-wide
        // child still overflows the row it lands on.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: SelectableLabel(label,
              style:
                  const TextStyle(fontSize: 11.5, color: AppTokens.inkMuted)),
        ),
      ],
    );
  }

  /// Round profile photo, or the first letter of the name.
  Widget _avatar() {
    final String url = _data.studentProfileImage;
    return ImageOrInitial(
      // The default placeholder string counts as "no photo".
      imageUrl: url == stringDefault ? "" : url,
      initial: _value(_data.studentName, "?").characters.first,
      size: 40,
      radius: AppTokens.radiusPill,
      fontSize: 15,
    );
  }

  /// How many devices the student is signed in on; tapping it signs them
  /// out of all of them.
  Widget _deviceChip() {
    final int count = _deviceCount;
    final bool signedIn = count > 0;
    final Color color = signedIn ? const Color(0xFF2563EB) : AppTokens.inkFaint;

    return Tooltip(
      message: signedIn
          ? "Sign out of all $count device${count == 1 ? '' : 's'}"
          : "Not signed in on any device",
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: InkWell(
          key: Key('student_devices_${_data.studentId}'),
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          onTap: signedIn ? _confirmSignOut : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: signedIn
                  ? color.withValues(alpha: .10)
                  : AppTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(
                  color: signedIn
                      ? color.withValues(alpha: .28)
                      : AppTokens.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    signedIn
                        ? Icons.devices_outlined
                        : Icons.phonelink_erase_outlined,
                    size: 12,
                    color: color),
                const SizedBox(width: 5),
                Text(
                    signedIn
                        ? "$count device${count == 1 ? '' : 's'}"
                        : "No devices",
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Row buttons; faded in on hover, always shown on compact screens.
  Widget _actions(bool visible) {
    return CardActions(
      visible: visible,
      buttons: [
        CardIconButton(
          buttonKey: Key('student_courses_${_data.studentId}'),
          icon: Icons.school_outlined,
          tooltip: "Enrolled courses",
          color: AppTokens.inkMuted,
          onTap: _openSettings,
        ),
        CardDeleteButton(
          buttonKey: Key('student_delete_${_data.studentId}'),
          tooltip: "Delete student",
          onTap: _confirmDelete,
        ),
      ],
    );
  }

  /// Opens the student's enrolled-courses (settings) screen. The list is
  /// not reloaded afterwards: enrolments do not change this row.
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingStudent(
          studentId: _data.studentId,
          studentName: _data.studentName,
        ),
      ),
    );
  }

  /// Asks for confirmation, then signs the student out of every device.
  void _confirmSignOut() {
    final StudentViewModel studentViewModel =
        Provider.of<StudentViewModel>(context, listen: false);
    final String studentId = _data.studentId;

    RemoveAlert.showRemoveAlert(
      title: _value(_data.studentName, "This student"),
      description: "Sign this student out of all devices ?",
      confirmLabel: "Sign out",
      onPressYes: () async {
        Navigator.pop(navigatorKey.currentContext!);
        final bool success = await studentViewModel.clearDeviceCount(studentId);
        if (success) {
          Helper.showSnackBarMessage(
              msg: "Signed out of all devices", isSuccess: true);
        }
      },
    );
  }

  /// Asks for confirmation, then deletes this item.
  void _confirmDelete() {
    final StudentViewModel studentViewModel =
        Provider.of<StudentViewModel>(context, listen: false);
    // Captured up front (by id, not list position) so a search or refresh
    // while the dialog is open cannot change which student gets deleted.
    final String studentId = _data.studentId;

    confirmDelete(
      title: _value(_data.studentName, "This student"),
      delete: () => studentViewModel.deleteStudent(studentId),
      successMessage: "Student deleted successfully",
    );
  }
}
