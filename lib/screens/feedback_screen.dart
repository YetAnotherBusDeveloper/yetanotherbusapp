import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/ad_banner_widget.dart';
import '../app/bus_app.dart';
import '../core/app_controller.dart';
import '../core/app_routes.dart';
import '../core/auth_token_store.dart';
import '../core/feedback_service.dart';
import '../core/feedback_models.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_labels.dart';
import '../widgets/background_image_wrapper.dart';
import '../widgets/app_dropdown.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.feedbackService});

  final FeedbackService? feedbackService;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _routeContextController = TextEditingController();
  final _contactController = TextEditingController();
  late final _feedbackService = widget.feedbackService ?? FeedbackService();
  FeedbackCategory? _category;
  bool _includeDiagnostics = false;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _routeContextController.dispose();
    _contactController.dispose();
    if (widget.feedbackService == null) _feedbackService.dispose();
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
        category: _category,
        routeContext: _routeContextController.text,
        contact: _contactController.text,
        diagnostics: _includeDiagnostics ? _diagnostics(controller) : null,
      );
      if (!mounted) return;
      _titleController.clear();
      _contentController.clear();
      _routeContextController.clear();
      _contactController.clear();
      _category = null;
      _includeDiagnostics = false;
      formState.reset();
      messenger.showSnackBar(SnackBar(content: Text(l10n.feedbackSubmitted)));
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

  FeedbackDiagnostics _diagnostics(AppController controller) {
    final media = MediaQuery.of(context);
    return FeedbackDiagnostics(
      appVersion: controller.buildInfo.version,
      buildNumber: controller.buildInfo.buildNumber,
      commitHash: controller.buildInfo.gitSha,
      platform: kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase(),
      locale: Localizations.localeOf(context).toLanguageTag(),
      screenWidth: media.size.width.round(),
      screenHeight: media.size.height.round(),
      textScale: media.textScaler.scale(14) / 14,
      brightness: Theme.of(context).brightness.name,
    );
  }

  Widget _optionalDetails(AppController controller, AppLocalizations l10n) {
    final diagnostics = _includeDiagnostics ? _diagnostics(controller) : null;
    return ExpansionTile(
      maintainState: true,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 16),
      title: Text(l10n.feedbackMoreInfo),
      subtitle: Text(l10n.feedbackMoreInfoHint),
      children: [
        AppDropdownFormField<String>(
          initialValue: _category?.name ?? '',
          decoration: InputDecoration(labelText: l10n.feedbackCategoryLabel),
          items: [
            DropdownMenuItem(value: '', child: Text(l10n.feedbackCategoryNone)),
            DropdownMenuItem(
              value: 'bug',
              child: Text(l10n.feedbackCategoryBug),
            ),
            DropdownMenuItem(
              value: 'data',
              child: Text(l10n.feedbackCategoryData),
            ),
            DropdownMenuItem(
              value: 'feature',
              child: Text(l10n.feedbackCategoryFeature),
            ),
            DropdownMenuItem(
              value: 'other',
              child: Text(l10n.feedbackCategoryOther),
            ),
          ],
          onChanged: _submitting
              ? null
              : (value) {
                  setState(() {
                    _category = value == null || value.isEmpty
                        ? null
                        : FeedbackCategory.values.byName(value);
                  });
                },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _routeContextController,
          enabled: !_submitting,
          maxLength: 200,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.feedbackRouteContextLabel,
            hintText: l10n.feedbackRouteContextHint,
          ),
          validator: (value) => (value ?? '').trim().length > 200
              ? l10n.feedbackOptionalTooLong(200)
              : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _contactController,
          enabled: !_submitting,
          maxLength: 200,
          decoration: InputDecoration(
            labelText: l10n.feedbackContactLabel,
            hintText: l10n.feedbackContactHint,
          ),
          validator: (value) => (value ?? '').trim().length > 200
              ? l10n.feedbackOptionalTooLong(200)
              : null,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _includeDiagnostics,
          title: Text(l10n.feedbackIncludeDiagnostics),
          subtitle: Text(l10n.feedbackDiagnosticsHint),
          onChanged: _submitting
              ? null
              : (value) {
                  setState(() => _includeDiagnostics = value);
                },
        ),
        if (diagnostics != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SelectableText(
              [
                '${l10n.feedbackDiagnosticVersion}: ${diagnostics.appVersion}+${diagnostics.buildNumber}',
                '${l10n.feedbackDiagnosticCommit}: ${diagnostics.commitHash}',
                '${l10n.feedbackDiagnosticPlatform}: ${diagnostics.platform}',
                '${l10n.feedbackDiagnosticLocale}: ${diagnostics.locale}',
                '${l10n.feedbackDiagnosticScreen}: ${diagnostics.screenWidth} × ${diagnostics.screenHeight}',
                '${l10n.feedbackDiagnosticTextScale}: ${diagnostics.textScale.toStringAsFixed(2)}',
                '${l10n.feedbackDiagnosticTheme}: ${diagnostics.brightness == 'dark' ? l10n.themeModeDark : l10n.themeModeLight}',
              ].join('\n'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
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
                            _optionalDetails(controller, l10n),
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
                const AdBannerWidget(minimumDensity: 4, isInline: true),
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
