import 'dart:async';

import 'package:bbarna/core/mixins/safe_notifier.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/foundation.dart';

/// Shared logic for every list screen whose data is paged from Firestore
/// and searched on the server (Audio, PDF, Video, Quiz, Question, Unit,
/// Topic).
///
/// What it handles:
/// * **Paging** – [loadFirstPage] fetches the first [limit] rows plus the
///   total count; [loadNextPage] appends the next [limit] rows.
/// * **Search** – [search] stores the text and runs a debounced (400 ms)
///   server-side prefix search. Results replace [items]; paging is turned
///   off while a search is showing.
/// * **Refresh** – [refresh] reloads whatever the list is currently showing
///   (the search results if there is a search, otherwise the first page).
///   List screens call it after returning from Add/Edit.
/// * **Errors** – failures show a toast built from [itemsLabel], e.g.
///   "Error while fetching PDFs", and never throw to the UI.
///
/// A subclass only says *how* to fetch, by implementing [fetchFirstPage],
/// [fetchNextPage], [fetchTotalCount] and [fetchSearchResults]. Each
/// subclass also keeps its old public names (`pdfList`, `getFirstPdfList`,
/// …) as thin forwards to the members here, so screens and tests did not
/// have to change.
abstract class PagedListViewModel<T> extends ChangeNotifier with SafeNotifier {
  /// Rows currently on screen: the loaded pages, or the search results.
  List<T> items = [];

  /// How many rows the whole collection holds, so the footer can say
  /// "showing 50 of 320" rather than just "50".
  int totalCount = 0;

  /// Rows fetched per page.
  final int limit = 50;

  /// True while the first page (or a search) is in flight — drives the
  /// skeleton rows.
  bool isLoading = true;

  /// True while a further page is in flight, so "Load more" can show a
  /// spinner without blanking the rows already on screen.
  bool isLoadingMore = false;

  /// True while search results are showing. Search is a separate server
  /// query, so paging does not apply to its result.
  bool isSearching = false;

  /// What the search box last held. Kept here rather than on the screen so
  /// it survives the round trip to Add/Edit, and so [refresh] puts the same
  /// results back instead of the unfiltered first page.
  String searchText = "";

  /// Pending search; restarted on every keystroke (debounce).
  Timer? _debounce;

  /// Why the list could not be loaded (first page or search), or null.
  /// While set and nothing is on screen, the list shows an error state
  /// with Retry instead of pretending it is empty.
  String? loadError;

  /// Counts searches, so only the newest one updates the screen.
  int _searchSeq = 0;

  /// Whether another page can be loaded.
  bool get hasMore => !isSearching && items.length < totalCount;

  // ---- What a subclass must provide ---------------------------------------

  /// Plural noun used in error toasts, e.g. `"PDFs"`, `"audio clips"`.
  String get itemsLabel;

  /// First [limit] rows, newest first. Must reset the repo's paging cursor.
  Future<List<T>> fetchFirstPage(int limit);

  /// The [limit] rows after the last page returned.
  Future<List<T>> fetchNextPage(int limit);

  /// Total number of rows in the collection.
  Future<int> fetchTotalCount();

  /// Server-side prefix search. [query] is already trimmed and upper-cased.
  Future<List<T>> fetchSearchResults(String query);

  // ---- Paging -------------------------------------------------------------

  /// The first-page load currently running, so overlapping calls (e.g. the
  /// first-frame refresh and a save landing at the same time) share it
  /// instead of each querying Firestore.
  Future<void>? _firstPageInFlight;

  /// Loads the first page and the total count together. Clears any search
  /// state so the full list shows again.
  ///
  /// The skeleton ([isLoading]) is only shown when nothing is on screen yet;
  /// otherwise the current rows stay visible while the refresh runs.
  Future<void> loadFirstPage() =>
      _firstPageInFlight ??= _loadFirstPage().whenComplete(() {
        _firstPageInFlight = null;
      });

  Future<void> _loadFirstPage() async {
    _searchSeq++; // any search still in flight is now stale
    isLoading = items.isEmpty;
    isSearching = false;
    loadError = null;
    notifyListeners();
    // Page and count are independent queries, so run them at the same time.
    // Future.sync turns a synchronous throw into a failed future.
    final Future<List<T>> page = Future.sync(() => fetchFirstPage(limit));
    final Future<int> count = Future.sync(fetchTotalCount);
    try {
      items = await page;
    } catch (e) {
      count.ignore();
      loadError = "Couldn't load $itemsLabel";
      Helper.showSnackBarMessage(
          msg: "Error while fetching $itemsLabel", isSuccess: false);
      isLoading = false;
      notifyListeners();
      return;
    }
    try {
      totalCount = await count;
    } catch (e) {
      // The rows loaded; only the total is out of date.
      Helper.showSnackBarMessage(
          msg: "Error while fetching $itemsLabel", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Appends the next page to [items]. Does nothing if a page is already
  /// loading or there is nothing more to load.
  Future<void> loadNextPage() async {
    if (isLoadingMore || !hasMore) return;

    isLoadingMore = true;
    notifyListeners();
    try {
      items.addAll(await fetchNextPage(limit));
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching more $itemsLabel", isSuccess: false);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Drops the rows matching [test] (after a successful delete) and lowers
  /// the total, so the list updates without another Firestore query.
  void removeLocally(bool Function(T item) test) {
    final int before = items.length;
    items = items.where((item) => !test(item)).toList();
    final int removed = before - items.length;
    if (removed > 0 && totalCount > 0) {
      totalCount = (totalCount - removed).clamp(0, totalCount);
    }
    notifyListeners();
  }

  // ---- Search -------------------------------------------------------------

  /// Remembers [text] and runs the search 400 ms after the last keystroke.
  /// An empty [text] brings the normal first page back.
  Future<void> search(String text) async {
    searchText = text;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  /// Reloads what the list is showing: the current search's results if
  /// there is one, otherwise the first page. Cancels any pending debounce
  /// so the reload happens now.
  ///
  /// If a load is already running it is waited for first and then a fresh
  /// one runs, so a refresh after a save never returns pre-save data.
  Future<void> refresh() async {
    _debounce?.cancel();
    final Future<void>? inFlight = _firstPageInFlight;
    if (inFlight != null) await inFlight;
    return _runSearch();
  }

  /// Runs the search for [searchText], or loads the first page when it is
  /// empty.
  Future<void> _runSearch() async {
    final String query = searchText.trim();
    if (query.isEmpty) {
      await loadFirstPage();
      return;
    }

    final int seq = ++_searchSeq;
    isSearching = true;
    isLoading = true;
    loadError = null;
    notifyListeners();
    try {
      // Codes are stored upper-case, so the prefix match is too.
      final List<T> results = await fetchSearchResults(query.toUpperCase());
      // A newer search (or a refresh) has taken over meanwhile — drop these
      // stale results.
      if (seq != _searchSeq) return;
      items = results;
    } catch (e) {
      if (seq != _searchSeq) return;
      items = [];
      loadError = "Search failed";
      Helper.showSnackBarMessage(
          msg: "Error while searching $itemsLabel", isSuccess: false);
    } finally {
      // Only the newest search decides when loading has finished.
      if (seq == _searchSeq) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    // Stop a pending search from firing after the screen has gone.
    _debounce?.cancel();
    super.dispose();
  }
}
