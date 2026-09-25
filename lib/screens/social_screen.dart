import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';

import '../app/bus_app.dart';
import '../core/app_routes.dart';
import '../core/friendly_error.dart';
import '../core/location_share.dart';
import '../core/user_location.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  LocationSharePrecision _precision = LocationSharePrecision.approximate;
  bool _sharing = false;

  Future<void> _shareLocation() async {
    if (_sharing) {
      return;
    }
    setState(() => _sharing = true);

    try {
      final position = await resolveUserPosition(
        timeLimit: const Duration(seconds: 8),
        accuracy: _precision == LocationSharePrecision.exact
            ? LocationAccuracy.high
            : LocationAccuracy.medium,
      );
      final shareText = LocationShareMessage.text(
        position: position,
        precision: _precision,
      );
      final result = await SharePlus.instance.share(
        ShareParams(text: shareText, subject: 'YetAnotherBusApp 位置分享'),
      );

      if (!mounted) {
        return;
      }
      if (result.status == ShareResultStatus.unavailable) {
        await Clipboard.setData(ClipboardData(text: shareText));
        _showMessage('無法開啟系統分享面板，已將位置連結複製到剪貼簿。');
      } else {
        _showMessage('已開啟分享面板。');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final failure = error is LocationFailure ? error : null;
      _showMessage(
        failure?.message ?? '分享位置失敗：${friendlyErrorMessage(error)}',
        action: failure?.serviceDisabled == true
            ? SnackBarAction(
                label: '定位設定',
                onPressed: () => unawaited(Geolocator.openLocationSettings()),
              )
            : failure?.deniedForever == true
            ? SnackBarAction(
                label: '權限設定',
                onPressed: () => unawaited(Geolocator.openAppSettings()),
              )
            : null,
      );
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  void _showMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), action: action));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppControllerScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('社交與位置分享')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              if (!controller.isAuthenticated)
                _LoginRequiredCard(theme: theme)
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('分享你現在在哪裡', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          '只有在你按下按鈕後才會取得位置。位置不會寫入帳號同步，也不會持續追蹤。',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        Text('分享精度', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        SegmentedButton<LocationSharePrecision>(
                          expandedInsets: EdgeInsets.zero,
                          segments: [
                            for (final option in LocationSharePrecision.values)
                              ButtonSegment(
                                value: option,
                                label: Text(option.label),
                                icon: Icon(
                                  option == LocationSharePrecision.exact
                                      ? Icons.gps_fixed_rounded
                                      : Icons.location_searching_rounded,
                                ),
                              ),
                          ],
                          selected: {_precision},
                          onSelectionChanged: _sharing
                              ? null
                              : (selected) =>
                                    setState(() => _precision = selected.first),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _precision.description,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _sharing ? null : _shareLocation,
                            icon: _sharing
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.share_location_rounded),
                            label: Text(_sharing ? '正在取得位置…' : '分享目前位置'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _PrivacyCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginRequiredCard extends StatelessWidget {
  const _LoginRequiredCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 32),
            const SizedBox(height: 12),
            Text('請先登入', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('登入後才能使用社交與位置分享功能。'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.account),
              icon: const Icon(Icons.login_rounded),
              label: const Text('前往登入'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '安全提醒：位置連結可以被轉傳，請確認收件人可信任。這個功能目前是一次性分享，不是好友即時定位或背景追蹤。',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
