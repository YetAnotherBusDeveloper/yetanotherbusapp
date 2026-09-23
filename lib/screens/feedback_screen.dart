import 'package:flutter/material.dart';

import '../app/bus_app.dart';
import '../core/app_controller.dart';
import '../core/app_routes.dart';
import '../core/auth_token_store.dart';
import '../core/feedback_service.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_labels.dart';
import '../widgets/background_image_wrapper.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _feedbackService = FeedbackService();
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit(AppController controller) async {
    if (_submitting) {
      return;
    }
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await _feedbackService.submitFeedback(
        title: _titleController.text,
        content: _contentController.text,
      );
      _titleController.clear();
      _contentController.clear();
      formState.reset();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.feedbackSubmitted)),
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } on AuthTokenExpiredException {
      await controller.logoutAuth();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.feedbackSessionExpired)),
      );
    } on FeedbackRateLimitException {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorRateLimited)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(_friendlyError(l10n, error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final l10n = AppLocalizations.of(context);
    final hasBackgroundImage = hasBackgroundImageForPage(
      controller.settings,
      pageKey: 'feedback',
    );

    return BackgroundImageWrapper(
      pageKey: 'feedback',
      child: Scaffold(
        backgroundColor: hasBackgroundImage ? Colors.transparent : null,
        appBar: AppBar(title: Text(l10n.feedbackTitle)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                // Card(
                //   child: Padding(
                //     padding: const EdgeInsets.all(18),
                //     child: Column(
                //       crossAxisAlignment: CrossAxisAlignment.start,
                //       children: [
                //         Text(
                //           '直接把你的想法丟給我們',
                //           style: Theme.of(context).textTheme.titleMedium,
                //         ),
                //         const SizedBox(height: 8),
                //         const Text(
                //           '可以回報 bug、提出功能需求，或告訴我們哪裡用起來卡卡的。標題上限 100 字，內文上限 4000 字。',
                //         ),
                //         const SizedBox(height: 8),
                //         const Text('送出前請避免貼上敏感個資、密碼或完整付款資訊。'),
                //       ],
                //     ),
                //   ),
                // ),
                if (!controller.isAuthenticated) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.feedbackSignInRequired,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.account);
                            },
                            icon: const Icon(Icons.login_rounded),
                            label: Text(l10n.feedbackGoToSignIn),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _titleController,
                              enabled: !_submitting,
                              maxLength: 100,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l10n.feedbackSubjectLabel,
                                hintText: l10n.feedbackSubjectHint,
                              ),
                              validator: (value) {
                                final cleaned = (value ?? '').trim();
                                if (cleaned.isEmpty) {
                                  return l10n.feedbackSubjectRequired;
                                }
                                if (cleaned.length > 100) {
                                  return l10n.feedbackSubjectTooLong(100);
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _contentController,
                              enabled: !_submitting,
                              maxLength: 4000,
                              minLines: 8,
                              maxLines: 14,
                              decoration: InputDecoration(
                                labelText: l10n.feedbackContentLabel,
                                alignLabelWithHint: true,
                                hintText: l10n.feedbackContentHint,
                              ),
                              validator: (value) {
                                final cleaned = (value ?? '').trim();
                                if (cleaned.isEmpty) {
                                  return l10n.feedbackContentRequired;
                                }
                                if (cleaned.length > 4000) {
                                  return l10n.feedbackContentTooLong(4000);
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _submitting
                                  ? null
                                  : () => _submit(controller),
                              icon: _submitting
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                              label: Text(
                                _submitting
                                    ? l10n.feedbackSubmitting
                                    : l10n.feedbackSubmit,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _friendlyError(AppLocalizations l10n, Object error) {
  final raw = '$error';
  if (raw.startsWith('Invalid argument')) {
    return l10n.feedbackInvalidFormat;
  }
  final message = localizedFriendlyError(l10n, error);
  return message == l10n.errorGeneric ? l10n.feedbackSubmitFailed : message;
}
