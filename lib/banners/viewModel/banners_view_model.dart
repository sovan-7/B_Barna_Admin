import 'dart:typed_data';

import 'package:bbarna/banners/model/banners_model.dart';
import 'package:bbarna/banners/repo/banners_repo.dart';
import 'package:bbarna/core/mixins/safe_notifier.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';

/// State and actions for the Banners module: the banner grid, adding a
/// banner (document + image upload) and deleting one.
class BannersViewModel extends ChangeNotifier with SafeNotifier {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final BannersRepo _bannersRepo;
  BannersViewModel({BannersRepo? bannersRepo})
      : _bannersRepo = bannersRepo ?? BannersRepo();

  /// Every banner.
  List<BannersModel> bannersList = [];

  /// True while the grid is loading (drives the skeleton tiles). Starts
  /// true so the first frame shows placeholders rather than briefly
  /// claiming there are no banners.
  bool isLoading = true;

  /// Loads every banner into [bannersList].
  Future<void> getBannerList() async {
    // Skeleton only when nothing is on screen yet; otherwise keep the
    // current rows visible while refreshing.
    isLoading = bannersList.isEmpty;
    notifyListeners();
    try {
      bannersList = await _bannersRepo.getBannersList();
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching banners", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Creates the document and uploads its image as one operation.
  ///
  /// A banner only exists to point at a picture, so if the upload fails
  /// the empty document is deleted again and `false` is returned.
  Future<bool> createBanner(Uint8List image) async {
    String? docId;
    try {
      docId = await _bannersRepo.addBanner(BannersModel(bannerImage: ""));
      await _bannersRepo.uploadBannerImage(image, docId);
      return true;
    } catch (e) {
      if (docId != null) {
        // Best effort: if this fails too there is nothing further to try,
        // and the grid renders such a document as "image unavailable"
        // rather than as a broken picture.
        try {
          await _bannersRepo.deleteBanner(docId);
        } catch (_) {}
      }
      Helper.showSnackBarMessage(
          msg: "Error while uploading the banner", isSuccess: false);
      return false;
    }
  }

  /// Deletes banner [docId]. Returns `false` (and shows a toast) on
  /// failure.
  Future<bool> deleteBanner(String docId) async {
    try {
      await _bannersRepo.deleteBanner(docId);
      // Drop it locally instead of refetching every banner.
      bannersList = bannersList.where((b) => b.docId != docId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the banner", isSuccess: false);
      return false;
    }
  }
}
