import 'package:bbarna/core/widgets/card/admin_card_shell.dart';
import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/card/image_or_initial.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/subject/screen/edit_subject.dart';
import 'package:bbarna/subject/viewModel/subject_view_model.dart';
import 'package:bbarna/subject_group/screen/subject_group_page.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One row of the subject list: thumbnail, name, code and course; price
/// (with discount / coupon); visibility, lock and "popular" chips; edit /
/// delete buttons.
class SubjectCard extends StatefulWidget {
  /// The item shown in this row.
  final SubjectModel subjectData;

  /// Called after something changed, so the list can refresh.
  final VoidCallback onChanged;

  const SubjectCard(
      {required this.subjectData, required this.onChanged, super.key});

  @override
  State<SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<SubjectCard> {
  /// Shortcut for the item shown.
  SubjectModel get _data => widget.subjectData;

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
                  Row(
                    children: [
                      _price(),
                      const Spacer(),
                      _actions(showActions),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _chips(),
                ],
              )
            : Row(
                children: [
                  Expanded(flex: 5, child: _identity()),
                  const SizedBox(width: AppTokens.gapMd),
                  _price(),
                  const SizedBox(width: AppTokens.gapMd),
                  // Flexible, not bare: an unbounded Wrap here takes its
                  // whole intrinsic width and starves the name column.
                  // Bounded, it wraps onto a second line instead.
                  Flexible(flex: 4, child: _chips()),
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
        _thumbnail(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: SelectableLabel(
                      _data.name,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppTokens.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CodeChip(_data.code),
                ],
              ),
              const SizedBox(height: 4),
              // Which course this sits under, and what kind it is — the
              // two things that tell one "Chapter 1" apart from another.
              Row(
                children: [
                  const Icon(Icons.menu_book_outlined,
                      size: 12, color: AppTokens.inkFaint),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _data.courseName.isEmpty ||
                              _data.courseName == stringDefault
                          ? "No course"
                          : _data.courseName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppTokens.inkMuted),
                    ),
                  ),
                  if (_data.courseType.isNotEmpty &&
                      _data.courseType != stringDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                          color: AppTokens.inkFaint, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(_data.courseType,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppTokens.inkMuted)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The item's picture, or the first letter of its code when there is
  /// none (or it fails to load).
  Widget _thumbnail() {
    return ImageOrInitial(
      imageUrl: _data.image,
      initial: _data.code.isEmpty ? "?" : _data.code.characters.first,
      size: 42,
    );
  }

  /// Status chips shown beside (or, when compact, under) the identity.
  Widget _chips() {
    final Widget? coupon = _couponChip();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (coupon != null) coupon,
        StatusChip(
          icon: Icons.low_priority,
          label: "Priority ${_data.displayPriority}",
          color: AppTokens.inkMuted,
        ),
        StatusChip(
          icon: _data.willDisplay
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          label: _data.willDisplay ? "Visible" : "Hidden",
          color:
              _data.willDisplay ? const Color(0xFF108460) : AppTokens.inkFaint,
          filled: _data.willDisplay,
        ),
        subjectPopularToggle(context, _data),
        // Rebuilds just this chip while its write is in flight.
        Selector<SubjectViewModel, bool>(
          selector: (_, vm) => vm.isFlagBusy(_data.docId, "isLocked"),
          builder: (context, busy, _) => ToggleChip(
            buttonKey: Key('subject_lock_${_data.docId}'),
            icon: _data.isLocked
                ? Icons.lock_outline_rounded
                : Icons.lock_open_outlined,
            label: _data.isLocked ? "Locked" : "Unlocked",
            on: _data.isLocked,
            onColor: const Color(0xFFB54708),
            tooltip:
                _data.isLocked ? "Unlock this subject" : "Lock this subject",
            onTap: () => Provider.of<SubjectViewModel>(context, listen: false)
                .toggleLocked(_data),
            busy: busy,
          ),
        ),
      ],
    );
  }

  /// Price column.
  Widget _price() => subjectPrice(_data);

  /// Coupon chip, or null.
  Widget? _couponChip() => subjectCouponChip(_data);

  /// Row buttons; faded in on hover, always shown on compact screens.
  Widget _actions(bool visible) =>
      subjectActions(context, _data, widget.onChanged, visible);
}

/// What a student actually pays (`selling_price`), with the list price
/// (`subject_price`) struck through and the saving named when there is a
/// discount.
Widget subjectPrice(SubjectModel data) {
  final double list = data.price;
  final double selling = data.sellingPrice;
  final bool discounted = selling > 0 && list > selling;
  final double headline = selling > 0 ? selling : list;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        subjectMoney(headline),
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: AppTokens.ink),
      ),
      if (discounted) ...[
        const SizedBox(height: 2),
        // Wraps under a narrow table column instead of overflowing it.
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 5,
          children: [
            Text(
              subjectMoney(list),
              style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTokens.inkFaint,
                  decoration: TextDecoration.lineThrough),
            ),
            // Shown as "25% OFF" (the value is always positive here: the guard above
            // needs list > selling > 0).
            Text(
              "${(((list - selling) / list) * 100).round()}% OFF",
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF108460)),
            ),
          ],
        ),
      ],
    ],
  );
}

/// Rupee amount with two decimals, e.g. "₹450.00".
String subjectMoney(double value) => "₹${value.toStringAsFixed(2)}";

/// The coupon live on this subject, or null when there isn't one.
///
/// Shows the code (selectable, for copying), the discount and whether it
/// has expired.
Widget? subjectCouponChip(SubjectModel data) {
  final String code = data.couponCode.trim();
  if (code.isEmpty || code == stringDefault) return null;

  final bool expired = data.couponValidTill > 0 &&
      data.couponValidTill < DateTime.now().millisecondsSinceEpoch;
  final Color color = expired ? AppTokens.inkFaint : const Color(0xFFB54708);
  // A flat rupee amount off the selling price, not a percentage — that is
  // how the student app applies it at checkout.
  final double off = data.couponDiscount;

  return Tooltip(
    message: expired
        ? "Coupon expired on ${subjectDate(data.couponValidTill)}"
        : data.couponValidTill > 0
            ? "Valid until ${subjectDate(data.couponValidTill)}"
            : "No expiry set",
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: expired ? AppTokens.surfaceMuted : color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(
            color: expired ? AppTokens.hairline : color.withValues(alpha: .28)),
      ),
      // Wraps the saving onto a second line in a narrow table column
      // rather than overflowing it.
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.local_offer_outlined, size: 12, color: color),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: SelectableLabel(
              code,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: color),
            ),
          ),
          if (off > 0)
            Text(" · ₹${off.toStringAsFixed(0)} off",
                style: TextStyle(fontSize: 11.5, color: color)),
          if (expired)
            Text(" · expired",
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    ),
  );
}

/// "12 Mar 2026" from epoch milliseconds.
String subjectDate(int millis) {
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(millis);
  const List<String> months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${d.day} ${months[d.month]} ${d.year}';
}

/// Row buttons; faded in on hover, always shown on compact screens.
Widget subjectActions(BuildContext context, SubjectModel data,
    VoidCallback onChanged, bool visible) {
  return CardActions(
    visible: visible,
    buttons: [
      // Groups are kept per subject code, so only a subject with one has
      // a group (the app shows no Group tab without it either).
      if (data.code.trim().isNotEmpty && data.code != stringDefault)
        CardIconButton(
          buttonKey: Key('subject_group_${data.docId}'),
          icon: Icons.forum_outlined,
          tooltip: "Open group",
          color: AppTokens.inkMuted,
          onTap: () => openSubjectGroup(context, data),
        ),
      CardEditButton(
        buttonKey: Key('subject_edit_${data.docId}'),
        tooltip: "Edit subject",
        onTap: () => openEditSubject(context, data, onChanged),
      ),
      CardDeleteButton(
        buttonKey: Key('subject_delete_${data.docId}'),
        tooltip: "Delete subject",
        onTap: () => confirmDeleteSubject(context, data),
      ),
    ],
  );
}

/// Opens this subject's group: its messages, and the box to post one.
void openSubjectGroup(BuildContext context, SubjectModel data) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => SubjectGroupPage(subject: data)),
  );
}

/// Opens the edit screen; the list reloads if it saved or deleted
/// something.
void openEditSubject(
    BuildContext context, SubjectModel data, VoidCallback onChanged) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => EditSubject(subjectData: data)),
  ).ifSaved(onChanged);
}

/// Asks for confirmation, then deletes this item.
void confirmDeleteSubject(BuildContext context, SubjectModel data) {
  final SubjectViewModel subjectViewModel =
      Provider.of<SubjectViewModel>(context, listen: false);
  final String docId = data.docId;

  confirmDelete(
    title: data.name,
    delete: () => subjectViewModel.deleteSubject(docId),
    successMessage: "Subject deleted successfully",
  );
}

/// The Popular toggle chip; rebuilds just itself while its write is in
/// flight. Shared by the card and the table row.
Widget subjectPopularToggle(BuildContext context, SubjectModel data) {
  return Selector<SubjectViewModel, bool>(
    selector: (_, vm) => vm.isFlagBusy(data.docId, "isPopular"),
    builder: (context, busy, _) => ToggleChip(
      buttonKey: Key('subject_popular_${data.docId}'),
      icon: data.isPopular ? Icons.star : Icons.star_border,
      label: "Popular",
      on: data.isPopular,
      onColor: const Color(0xFFB54708),
      tooltip: data.isPopular ? "Remove from popular" : "Mark as popular",
      onTap: () => Provider.of<SubjectViewModel>(context, listen: false)
          .togglePopular(data),
      busy: busy,
    ),
  );
}
