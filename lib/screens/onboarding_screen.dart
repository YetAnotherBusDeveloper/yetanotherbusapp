import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../app/bus_app.dart';
import '../core/app_motion.dart';
import '../widgets/app_content_transition.dart';
import '../core/app_controller.dart';
import '../core/app_routes.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_labels.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _stepCount = 3;

  final PageController _pageController = PageController();
  int _stepIndex = 0;
  bool _requestingPermission = false;
  bool _resolvingLocation = false;
  bool _manualProviderSelection = false;
  String? _permissionMessage;
  BusProvider? _suggestedProvider;

  bool get _hasDatabaseStep => !kIsWeb;
  int get _effectiveStepCount => _hasDatabaseStep ? _stepCount : _stepCount - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToStep(int index) async {
    _pageController.jumpToPage(index);
  }

  Future<void> _nextStep() async {
    if (_stepIndex >= _effectiveStepCount - 1) {
      final controller = AppControllerScope.read(context);
      await controller.completeOnboarding();
      return;
    }
    await _goToStep(_stepIndex + 1);
  }

  Future<void> _applySuggestedProvider(
    AppController controller,
    Position position,
  ) async {
    final suggested = nearestBusProvider(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    _suggestedProvider = suggested;
    final hasExactSuggestedSelection =
        controller.settings.provider == suggested &&
        controller.selectedProviders.length == 1 &&
        controller.selectedProviders.first == suggested;
    if (_manualProviderSelection || hasExactSuggestedSelection) {
      return;
    }
    await controller.updateSelectedProviders([suggested]);
  }

  Future<Position?> _resolveCurrentPosition() async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {
        return lastKnown;
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _requestLocationPermissionAndContinue() async {
    final controller = AppControllerScope.read(context);
    final l10n = AppLocalizations.of(context);
    setState(() {
      _requestingPermission = true;
      _resolvingLocation = false;
      _permissionMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (!serviceEnabled) {
        setState(() {
          _permissionMessage = l10n.onboardingLocationServiceDisabled;
        });
      } else if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        setState(() {
          _permissionMessage = l10n.onboardingLocationPermissionDenied;
        });
      } else {
        setState(() {
          _resolvingLocation = true;
        });
        final position = await _resolveCurrentPosition();
        if (!mounted) {
          return;
        }
        if (position == null) {
          setState(() {
            _permissionMessage = l10n.onboardingLocationUnavailable;
          });
        } else {
          await _applySuggestedProvider(controller, position);
          if (!mounted) {
            return;
          }
          setState(() {
            _permissionMessage = l10n.onboardingProviderSelected(
              controller.settings.provider.label,
            );
          });
        }
      }
    } catch (error) {
      setState(() {
        _permissionMessage = l10n.onboardingLocationFailed(
          localizedFriendlyError(l10n, error),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _requestingPermission = false;
          _resolvingLocation = false;
        });
      }
    }

    if (mounted && _stepIndex == 1) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _nextStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  Row(
                    children: List.generate(_effectiveStepCount, (index) {
                      final active = index <= _stepIndex;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == _effectiveStepCount - 1 ? 0 : 8,
                          ),
                          child: AnimatedContainer(
                            duration: AppMotion.duration(context),
                            curve: AppMotion.curve,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? colorScheme.primary
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: AppContentTransition(
                      state: _stepIndex,
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (index) {
                          setState(() {
                            _stepIndex = index;
                          });
                        },
                        children: [
                          _IntroStep(onNext: _nextStep),
                          _PermissionStep(
                            requestingPermission: _requestingPermission,
                            resolvingLocation: _resolvingLocation,
                            permissionMessage: _permissionMessage,
                            onRequestPermission:
                                _requestLocationPermissionAndContinue,
                            onSkip: _nextStep,
                            onBack: () => _goToStep(_stepIndex - 1),
                          ),
                          if (_hasDatabaseStep)
                            _DatabaseStep(
                              controller: controller,
                              suggestedProvider: _suggestedProvider,
                              onProviderToggled: (provider, selected) async {
                                _manualProviderSelection = true;
                                if (selected) {
                                  await controller.updateProvider(provider);
                                } else {
                                  await controller.toggleSelectedProvider(
                                    provider,
                                    false,
                                  );
                                }
                              },
                              onBack: () => _goToStep(_stepIndex - 1),
                              onFinish: _nextStep,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep({required this.onNext});

  final Future<void> Function() onNext;

  Widget _buildLegalLink(
    BuildContext context, {
    required String label,
    required String routeName,
  }) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: () => Navigator.of(context).pushNamed(routeName),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: theme.colorScheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return _OnboardingStepLayout(
      content: [
        const SizedBox(height: 12),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(
            Icons.directions_bus_rounded,
            size: 44,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.onboardingWelcome,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        _OnboardingFeature(
          icon: Icons.search_rounded,
          title: l10n.homeSearchTitle,
          subtitle: l10n.onboardingSearchDescription,
        ),
        const SizedBox(height: 12),
        _OnboardingFeature(
          icon: Icons.favorite_outline_rounded,
          title: l10n.onboardingFavoritesTitle,
          subtitle: l10n.onboardingFavoritesDescription,
        ),
        const SizedBox(height: 12),
        _OnboardingFeature(
          icon: Icons.near_me_outlined,
          title: l10n.nearbyTitle,
          subtitle: l10n.onboardingNearbyDescription,
        ),
      ],
      footer: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.onboardingLegalPrefix,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                _buildLegalLink(
                  context,
                  label: l10n.termsOfService,
                  routeName: AppRoutes.termsOfService,
                ),
                Text(
                  l10n.onboardingLegalAnd,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                _buildLegalLink(
                  context,
                  label: l10n.privacyPolicy,
                  routeName: AppRoutes.privacyPolicy,
                ),
                Text(
                  l10n.onboardingLegalSuffix,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(l10n.onboardingStart),
          ),
        ),
      ],
    );
  }
}

class _PermissionStep extends StatelessWidget {
  const _PermissionStep({
    required this.requestingPermission,
    required this.resolvingLocation,
    required this.permissionMessage,
    required this.onRequestPermission,
    required this.onSkip,
    required this.onBack,
  });

  final bool requestingPermission;
  final bool resolvingLocation;
  final String? permissionMessage;
  final Future<void> Function() onRequestPermission;
  final Future<void> Function() onSkip;
  final Future<void> Function() onBack;

  @override
  Widget build(BuildContext context) {
    final busy = requestingPermission || resolvingLocation;
    final l10n = AppLocalizations.of(context);
    return _OnboardingStepLayout(
      content: [
        const SizedBox(height: 12),
        Text(
          l10n.onboardingLocationTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          l10n.onboardingLocationDescription,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.onboardingLocationConsent),
                Text(l10n.onboardingLocationServerUse),
                if (permissionMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(permissionMessage!),
                ],
              ],
            ),
          ),
        ),
      ],
      footer: [
        _OnboardingButtonRow(
          leading: OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(l10n.commonBack),
          ),
          trailing: FilledButton(
            onPressed: busy ? null : onRequestPermission,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(
              busy ? l10n.onboardingProcessing : l10n.onboardingAllowContinue,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: busy ? null : onSkip,
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text(l10n.onboardingChooseManually),
          ),
        ),
      ],
    );
  }
}

class _DatabaseStep extends StatelessWidget {
  const _DatabaseStep({
    required this.controller,
    required this.suggestedProvider,
    required this.onProviderToggled,
    required this.onBack,
    required this.onFinish,
  });

  final AppController controller;
  final BusProvider? suggestedProvider;
  final Future<void> Function(BusProvider provider, bool selected)
  onProviderToggled;
  final Future<void> Function() onBack;
  final Future<void> Function() onFinish;

  @override
  Widget build(BuildContext context) {
    final provider = controller.settings.provider;
    final selectedProviders = controller.selectedProviders;
    final downloadedCount = selectedProviders
        .where(controller.isDatabaseReady)
        .length;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return _OnboardingStepLayout(
      content: [
        const SizedBox(height: 12),
        Text(
          l10n.onboardingDownloadTitle,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          l10n.onboardingDownloadDescription,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Text(l10n.onboardingRegionList, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: downloadableBusProviders().map((item) {
                return FilterChip(
                  label: Text(item.label),
                  selected: selectedProviders.contains(item),
                  onSelected: (selected) {
                    onProviderToggled(item, selected);
                  },
                  avatar: controller.isDatabaseReady(item)
                      ? const Icon(Icons.download_done_rounded, size: 18)
                      : const Icon(Icons.cloud_outlined, size: 18),
                );
              }).toList(),
            ),
          ),
        ),
        if (suggestedProvider != null) ...[
          const SizedBox(height: 12),
          Text(
            l10n.onboardingNearestSuggestion(suggestedProvider!.label),
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.onboardingDefaultSource(provider.label)),
                const SizedBox(height: 8),
                Text(
                  l10n.onboardingSelectedDatabases(
                    localizedList(
                      l10n,
                      selectedProviders.map((item) => item.label),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.onboardingDatabaseProgress(
                    downloadedCount,
                    selectedProviders.length,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      footer: [
        _OnboardingButtonRow(
          leading: OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(l10n.commonBack),
          ),
          trailing: FilledButton(
            onPressed: controller.downloadingDatabase
                ? null
                : () async {
                    try {
                      await controller.downloadSelectedProviderDatabases();
                      if (!context.mounted) {
                        return;
                      }
                      await onFinish();
                    } catch (error) {
                      if (!context.mounted) {
                        return;
                      }
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.onboardingDownloadFailed(
                              localizedFriendlyError(l10n, error),
                            ),
                          ),
                        ),
                      );
                    }
                  },
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(
              controller.downloadingDatabase
                  ? l10n.commonDownloading
                  : l10n.commonDownload,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: onFinish,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(
              controller.databaseReady ? l10n.commonDone : l10n.commonLater,
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingStepLayout extends StatelessWidget {
  const _OnboardingStepLayout({required this.content, required this.footer});

  final List<Widget> content;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scrollBottomPadding = bottomInset + 20.0;
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.only(bottom: scrollBottomPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - scrollBottomPadding,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...content,
                  const Spacer(),
                  const SizedBox(height: 20),
                  ...footer,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingButtonRow extends StatelessWidget {
  const _OnboardingButtonRow({required this.leading, required this.trailing});

  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final shouldStack =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.15;
    if (shouldStack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [trailing, const SizedBox(height: 12), leading],
      );
    }
    return Row(
      children: [
        Expanded(child: leading),
        const SizedBox(width: 12),
        Expanded(child: trailing),
      ],
    );
  }
}

class _OnboardingFeature extends StatelessWidget {
  const _OnboardingFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
