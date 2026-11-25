import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/core/widgets/custom_searchbar.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/question1/question1_viewmodel/question1_viewmodel.dart';
import 'package:bbarna/question1/screen/add_question1.dart';
import 'package:bbarna/question1/widgets/question1_list_widget.dart';
import 'package:bbarna/resources/app_colors.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Question1List extends StatelessWidget {
  const Question1List({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<Question1ViewModel>(
      create: (_) => Question1ViewModel(),
      child: const _Question1ListBody(),
    );
  }
}

class _Question1ListBody extends StatefulWidget {
  const _Question1ListBody();

  @override
  State<_Question1ListBody> createState() => _Question1ListBodyState();
}

class _Question1ListBodyState extends State<_Question1ListBody> {
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<Question1ViewModel>();
    viewModel.refreshCount();
    viewModel.fetchFirstPage();
  }

  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _confirmDelete(Question1ViewModel viewModel, int index) {
    RemoveAlert.showRemoveAlert(
      title: "${index + 1}",
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        // Close the confirm dialog, then delete.
        Navigator.pop(navigatorKey.currentContext!);
        await viewModel.deleteQuestion(
            docId: viewModel.questionList[index].docId, index: index);
      },
    );
  }

  Widget _pageButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 38,
        width: 95,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: AppColorsInApp.colorLightBlue,
            borderRadius: BorderRadius.circular(20)),
        child: Text(
          label,
          style: const TextStyle(
              color: AppColorsInApp.colorBlack1,
              fontSize: 15,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    return Consumer<Question1ViewModel>(builder: (context, viewModel, child) {
      return Container(
        padding:
            const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 20),
        child: Column(
          children: [
            if (viewModel.loading) const LinearProgressIndicator(minHeight: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "QUESTION1 LIST",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                      letterSpacing: 1.0,
                      color: AppColorsInApp.colorBlack1),
                ),
                Row(
                  children: [
                    AddWidget(
                      icon: Icons.sync,
                      title: "SYNC",
                      addCall: () {
                        searchController.clear();
                        viewModel.fetchFirstPage().then((_) {
                          if (scrollController.hasClients) {
                            scrollController.animateTo(0,
                                duration: const Duration(milliseconds: 100),
                                curve: Curves.easeIn);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 15),
                    AddWidget(
                      addCall: () {
                        Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const AddQuestion1()))
                            .whenComplete(() {
                          if (searchController.text.isEmpty) {
                            viewModel.fetchFirstPage();
                            viewModel.refreshCount();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            CustomSearchBar(
              textEditingController: searchController,
              onChange: () =>
                  viewModel.searchByCode(searchController.text.toUpperCase()),
              onClear: () {
                searchController.clear();
                viewModel.searchByCode("");
              },
            ),
            Expanded(
              child: viewModel.questionList.isEmpty
                  ? const SizedBox()
                  : Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color:
                              AppColorsInApp.colorGrey.withValues(alpha: .2)),
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: viewModel.questionList.length,
                        itemBuilder: (context, index) {
                          final item = Question1ListWidget(
                            question: viewModel.questionList[index],
                            questionIndex: index,
                            onEdit: () {
                              if (searchController.text.isEmpty) {
                                viewModel.fetchFirstPage();
                              }
                            },
                            onDelete: () => _confirmDelete(viewModel, index),
                          );
                          return width < 900 ? FittedBox(child: item) : item;
                        },
                      ),
                    ),
            ),
            if (viewModel.questionListLength != 0 &&
                searchController.text.isEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _pageButton("Previous", () => viewModel.fetchPreviousPage()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      "${viewModel.questionList.length}/${viewModel.questionListLength}",
                      style: const TextStyle(
                          color: AppColorsInApp.colorBlack1,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  _pageButton("Next", () => viewModel.fetchNextPage()),
                ],
              ),
          ],
        ),
      );
    });
  }
}
