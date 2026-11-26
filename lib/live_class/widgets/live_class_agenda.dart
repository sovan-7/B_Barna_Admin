import 'package:bbarna/live_class/model/live_class_model.dart';

/// One day of the agenda: a date and the classes that start on it.
class LiveClassDay {
  /// Midnight (local time) of the day.
  final DateTime day;

  /// The classes starting that day, in the order they were given.
  final List<LiveClassModel> classes;

  const LiveClassDay({required this.day, required this.classes});
}

/// Midnight (local time) of the day [at] falls on.
DateTime dayOf(DateTime at) => DateTime(at.year, at.month, at.day);

/// Groups [sorted] by the local date each class starts on.
///
/// The order is kept, both of the days and within each day, so Upcoming
/// stays soonest-first and Past stays most-recent-first (the order
/// `LiveClassViewModel.classesFor` returns). A day only appears once even
/// if the input is not sorted by day.
List<LiveClassDay> groupByDay(List<LiveClassModel> sorted) {
  final Map<DateTime, List<LiveClassModel>> byDay = {};
  for (final LiveClassModel liveClass in sorted) {
    byDay.putIfAbsent(dayOf(liveClass.startDateTime), () => []).add(liveClass);
  }
  return [
    for (final MapEntry<DateTime, List<LiveClassModel>> entry in byDay.entries)
      LiveClassDay(day: entry.key, classes: entry.value),
  ];
}

/// Counts shown in the stats strip above the class list.
class LiveClassStats {
  /// Classes starting today, whatever their status.
  final int today;

  /// Upcoming classes starting within the next 7 days.
  final int nextWeek;

  /// Finished classes with no notes PDF yet.
  final int missingNotes;

  /// Finished classes whose chat has not been deleted.
  final int chatsToClear;

  const LiveClassStats({
    required this.today,
    required this.nextWeek,
    required this.missingNotes,
    required this.chatsToClear,
  });

  /// Works the counts out over [classes] at [now].
  factory LiveClassStats.of(List<LiveClassModel> classes, DateTime now) {
    final DateTime today = dayOf(now);
    final DateTime weekEnd = now.add(const Duration(days: 7));
    int startingToday = 0, nextWeek = 0, missingNotes = 0, chats = 0;
    for (final LiveClassModel liveClass in classes) {
      if (dayOf(liveClass.startDateTime) == today) startingToday++;
      switch (liveClass.statusAt(now)) {
        case LiveClassStatus.upcoming:
          if (liveClass.startDateTime.isBefore(weekEnd)) nextWeek++;
        case LiveClassStatus.live:
          break;
        case LiveClassStatus.past:
          if (!liveClass.hasPdf) missingNotes++;
          if (liveClass.chatState == LiveClassChatState.none) chats++;
      }
    }
    return LiveClassStats(
      today: startingToday,
      nextWeek: nextWeek,
      missingNotes: missingNotes,
      chatsToClear: chats,
    );
  }
}
