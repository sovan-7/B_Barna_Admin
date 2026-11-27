import 'package:bbarna/core/widgets/list_page/admin_table.dart';
import 'package:bbarna/core/widgets/list_page/table_cells.dart';
import 'package:bbarna/core/widgets/list_page/table_identity.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/subject/viewModel/subject_view_model.dart';
import 'package:bbarna/subject/widgets/subject_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The subject list on wide screens: one row per subject with its code and
/// course, price, coupon, visibility, a Popular star, an inline lock
/// switch, and group / edit / delete on hover.
class SubjectTable extends StatelessWidget {
  /// The subjects shown, already searched and filtered.
  final List<SubjectModel> subjects;

  /// Called after an edit so the list can reload.
  final VoidCallback onChanged;

  const SubjectTable(
      {required this.subjects, required this.onChanged, super.key});

  /// Narrowest list width the table is used at (cards below it).
  static const double minWidth = 960;

  static const List<AdminTableColumn> _columns = [
    AdminTableColumn("Subject", flex: 5),
    AdminTableColumn("Price", width: 120, alignment: Alignment.centerRight),
    AdminTableColumn("Coupon", width: 150),
    AdminTableColumn("Status", width: 80),
    AdminTableColumn("Popular", width: 60, alignment: Alignment.center),
    AdminTableColumn("Locked", width: 60),
    AdminTableColumn("", width: 108, alignment: Alignment.centerRight),
  ];

  @override
  Widget build(BuildContext context) {
    return AdminTable(
      columns: _columns,
      rowCount: subjects.length,
      rowKey: (i) => ValueKey('subject_row_${subjects[i].docId}'),
      cellsBuilder: (context, i, hovered) {
        final SubjectModel subject = subjects[i];
        final List<String> about = [
          if (TableIdentity.hasText(subject.code)) subject.code,
          TableIdentity.hasText(subject.courseName)
              ? subject.courseName
              : "No course",
          if (TableIdentity.hasText(subject.courseType)) subject.courseType,
        ];
        return [
          TableIdentity(
            title: subject.name,
            subtitle: about.join(" · "),
            imageUrl: subject.image,
            initial: subject.code.isEmpty ? "?" : subject.code.characters.first,
          ),
          subjectPrice(subject),
          subjectCouponChip(subject) ?? const TableText(null),
          StatusPill(subject.willDisplay ? "Visible" : "Hidden",
              tone: subject.willDisplay
                  ? StatusTone.success
                  : StatusTone.neutral),
          _PopularStar(subject: subject),
          Selector<SubjectViewModel, bool>(
            selector: (_, vm) => vm.isFlagBusy(subject.docId, "isLocked"),
            builder: (context, busy, _) => LockSwitch(
              switchKey: Key('subject_lock_${subject.docId}'),
              locked: subject.isLocked,
              busy: busy,
              itemLabel: "this subject",
              onChanged: (_) =>
                  Provider.of<SubjectViewModel>(context, listen: false)
                      .toggleLocked(subject),
            ),
          ),
          subjectActions(context, subject, onChanged, hovered),
        ];
      },
    );
  }
}

/// The Popular flag as a star button; a spinner while its write is in
/// flight. Same key as the card's Popular chip.
class _PopularStar extends StatelessWidget {
  final SubjectModel subject;
  const _PopularStar({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Selector<SubjectViewModel, bool>(
      selector: (_, vm) => vm.isFlagBusy(subject.docId, "isPopular"),
      builder: (context, busy, _) {
        if (busy) {
          return const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTokens.warningText),
          );
        }
        final bool popular = subject.isPopular;
        return Tooltip(
          message: popular ? "Remove from popular" : "Mark as popular",
          child: InkWell(
            key: Key('subject_popular_${subject.docId}'),
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            onTap: () => Provider.of<SubjectViewModel>(context, listen: false)
                .togglePopular(subject),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(popular ? Icons.star : Icons.star_border,
                  size: 20,
                  color: popular ? AppTokens.warningText : AppTokens.inkFaint),
            ),
          ),
        );
      },
    );
  }
}
