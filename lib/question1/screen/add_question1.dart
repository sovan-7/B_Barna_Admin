import 'package:bbarna/core/widgets/app_header.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/core/widgets/save_button.dart';
import 'package:bbarna/core/widgets/sidebar.dart';
import 'package:bbarna/question1/question1_viewmodel/question1_viewmodel.dart';
import 'package:bbarna/question1/widgets/question1_html_editor.dart';
import 'package:bbarna/resources/app_colors.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:provider/provider.dart';

class AddQuestion1 extends StatelessWidget {
  const AddQuestion1({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<Question1ViewModel>(
      create: (_) => Question1ViewModel(),
      child: const _AddQuestion1Body(),
    );
  }
}

class _AddQuestion1Body extends StatefulWidget {
  const _AddQuestion1Body();

  @override
  State<_AddQuestion1Body> createState() => _AddQuestion1BodyState();
}

class _AddQuestion1BodyState extends State<_AddQuestion1Body> {
  final GlobalKey<ScaffoldState> key = GlobalKey();
  final ScrollController scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final viewModel = context.watch<Question1ViewModel>();
    return Scaffold(
      key: key,
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) Navigator.of(context).pop();
        },
        child: Column(children: [
          AppHeader(onTapIcon: () => key.currentState?.openDrawer()),
          Expanded(
            child: Row(children: [
              Visibility(
                visible: width > 900,
                child: const Expanded(
                    child: ExtraSideBar(sidebarIndex: question1ModuleIndex)),
              ),
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Container(
                    margin: width > 900
                        ? const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 30)
                        : const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
                    padding: EdgeInsets.all(width > 900 ? 30 : 20),
                    decoration: BoxDecoration(
                        border: Border.all(
                            width: 1, color: AppColorsInApp.colorGreyWhite),
                        color: AppColorsInApp.colorBlue.withValues(alpha: .1)),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10, top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 8.0, left: 10),
                            child: FormTextField(
                              label: "Question Code",
                              hint: "e.g. Q1001",
                              controller: viewModel.questionCodeController,
                            ),
                          ),
                          Question1HtmlEditor(
                            heading: "Question",
                            controller: viewModel.questionController,
                            onContentChanged: viewModel.onQuestionChanged,
                            onEditorInit: viewModel.onEditorInit,
                          ),
                          Question1HtmlEditor(
                            heading: "Question Body",
                            controller: viewModel.questionBodyController,
                            onContentChanged: viewModel.onQuestionBodyChanged,
                            onEditorInit: viewModel.onEditorInit,
                          ),
                          Question1HtmlEditor(
                            heading: "Solution",
                            controller: viewModel.solutionController,
                            onContentChanged: viewModel.onSolutionChanged,
                            onEditorInit: viewModel.onEditorInit,
                          ),
                          _optionRow(viewModel,
                              label: "Option A: ",
                              value: 1,
                              controller: viewModel.optionOneController,
                              onContentChanged: viewModel.onOption1Changed),
                          _optionRow(viewModel,
                              label: "Option B: ",
                              value: 2,
                              controller: viewModel.optionTwoController,
                              onContentChanged: viewModel.onOption2Changed),
                          _optionRow(viewModel,
                              label: "Option C: ",
                              value: 3,
                              controller: viewModel.optionThreeController,
                              onContentChanged: viewModel.onOption3Changed),
                          _optionRow(viewModel,
                              label: "Option D: ",
                              value: 4,
                              controller: viewModel.optionFourController,
                              onContentChanged: viewModel.onOption4Changed),
                          Question1HtmlEditor(
                            heading: "Hints",
                            controller: viewModel.hintController,
                            onContentChanged: viewModel.onHintsChanged,
                            onEditorInit: viewModel.onEditorInit,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 25.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SaveButton(
                                  onPRess: () => viewModel.resetForm(),
                                  buttonText: "Reset",
                                  buttonColor: AppColorsInApp.colorOrange,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 15),
                                  child: SaveButton(onPRess: () async {
                                    final error = viewModel.validate();
                                    if (error != null) {
                                      Helper.showSnackBarMessage(
                                          msg: error, isSuccess: false);
                                      return;
                                    }
                                    final success =
                                        await viewModel.addQuestion();
                                    if (success &&
                                        scrollController.hasClients) {
                                      scrollController.animateTo(0,
                                          duration:
                                              const Duration(milliseconds: 150),
                                          curve: Curves.easeIn);
                                    }
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
      drawer: width < 900
          ? const Drawer(
              child: ExtraSideBar(sidebarIndex: question1ModuleIndex))
          : null,
    );
  }

  Widget _optionRow(
    Question1ViewModel viewModel, {
    required String label,
    required int value,
    required HtmlEditorController controller,
    required ValueChanged<String?> onContentChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColorsInApp.colorGrey),
              ),
              SizedBox(
                width: 50,
                child: Radio<int>(
                  groupValue: viewModel.selectIndex,
                  value: value,
                  onChanged: (v) => viewModel.setSelectedIndex(v!),
                ),
              ),
            ],
          ),
        ),
        Question1HtmlEditor(
          heading: "",
          controller: controller,
          onContentChanged: onContentChanged,
          onEditorInit: viewModel.onEditorInit,
        ),
      ],
    );
  }
}
