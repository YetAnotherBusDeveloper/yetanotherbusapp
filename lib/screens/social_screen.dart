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
  final TextEditingController _noteController = TextEditingController();
  SocialShareActivity _activity = SocialShareActivity.waiting;
  SocialShareDuration _duration = SocialShareDuration.oneHour;
  LocationSharePrecision _precision = LocationSharePrecision.approximate;
  bool _includeLocation = false;
  bool _sharing = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _shareUpdate() async {
    if (_sharing) {
      return;
    }
    final displayName =
        AppControllerScope.of(context).authSession?.displayName ?? '';
    setState(() => _sharing = true);

    try {
      final position = _includeLocation
          ? await resolveUserPosition(
              timeLimit: const Duration(seconds: 8),
              accuracy: _precision == LocationSharePrecision.exact
                  ? LocationAccuracy.high
                  : LocationAccuracy.medium,
            )
          : null;
      final shareText = SocialShareMessage.compose(
        displayName: displayName,
        activity: _activity,
        duration: _duration,
        note: _noteController.text,
        position: position,
        precision: _precision,
      );
      final result = await SharePlus.instance.share(
        ShareParams(text: shareText, subject: 'YetAnotherBusApp 動態分享'),
      );

      if (!mounted) {
        return;
      }
      if (result.status == ShareResultStatus.unavailable) {
        await Clipboard.setData(ClipboardData(text: shareText));
        _showMessage('無法開啟系統分享面板，已將動態複製到剪貼簿。');
      } else {
        _showMessage('已開啟分享面板。');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final failure = error is LocationFailure ? error : null;
      _showMessage(
        failure?.message ?? '分享動態失敗：${friendlyErrorMessage(error)}',
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
    final displayName = controller.authSession?.displayName.trim();
    final senderName = displayName == null || displayName.isEmpty
        ? '你'
        : displayName;

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
                        Row(
                          children: [
                            CircleAvatar(
                              child: Text(
                                senderName.characters.first.toUpperCase(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '分享新動態',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  Text(
                                    '以 $senderName 的身分分享',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '告訴朋友你的交通狀態，也可選擇性附上目前位置。',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        Text('你正在做什麼？', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final option in SocialShareActivity.values)
                              ChoiceChip(
                                label: Text(option.label),
                                selected: _activity == option,
                                onSelected: _sharing
                                    ? null
                                    : (_) => setState(() => _activity = option),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _noteController,
                          enabled: !_sharing,
                          maxLength: SocialShareMessage.noteMaxLength,
                          maxLines: 3,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: '想說什麼？（選填）',
                            hintText: '例如：我在 2 號出口等你',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _includeLocation,
                          onChanged: _sharing
                              ? null
                              : (value) =>
                                    setState(() => _includeLocation = value),
                          title: const Text('附上目前位置'),
                          subtitle: const Text('關閉時不會請求定位權限'),
                          secondary: const Icon(Icons.location_on_outlined),
                        ),
                        if (_includeLocation) ...[
                          const SizedBox(height: 8),
                          SegmentedButton<LocationSharePrecision>(
                            expandedInsets: EdgeInsets.zero,
                            segments: [
                              for (final option
                                  in LocationSharePrecision.values)
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
                                : (selected) => setState(
                                    () => _precision = selected.first,
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _precision.description,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 16),
                        DropdownButtonFormField<SocialShareDuration>(
                          initialValue: _duration,
                          decoration: const InputDecoration(
                            labelText: '建議查看期限',
                            prefixIcon: Icon(Icons.timer_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final option in SocialShareDuration.values)
                              DropdownMenuItem(
                                value: option,
                                child: Text(option.label),
                              ),
                          ],
                          onChanged: _sharing
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _duration = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 16),
                        _UpdatePreview(
                          activity: _activity,
                          note: _noteController.text,
                          includeLocation: _includeLocation,
                          precision: _precision,
                          duration: _duration,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _sharing ? null : _shareUpdate,
                            icon: _sharing
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.ios_share_rounded),
                            label: Text(
                              _sharing
                                  ? (_includeLocation ? '正在取得位置…' : '正在開啟分享…')
                                  : '分享動態',
                            ),
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

class _UpdatePreview extends StatelessWidget {
  const _UpdatePreview({
    required this.activity,
    required this.note,
    required this.includeLocation,
    required this.precision,
    required this.duration,
  });

  final SocialShareActivity activity;
  final String note;
  final bool includeLocation;
  final LocationSharePrecision precision;
  final SocialShareDuration duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedNote = SocialShareMessage.normalizeNote(note);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('分享預覽', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 10),
            Text(activity.label, style: theme.textTheme.titleMedium),
            if (normalizedNote.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(normalizedNote),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _PreviewChip(
                  icon: includeLocation
                      ? Icons.location_on_outlined
                      : Icons.location_off_outlined,
                  label: includeLocation ? precision.label : '不分享位置',
                ),
                _PreviewChip(icon: Icons.timer_outlined, label: duration.label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
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
                '安全提醒：只有按下分享時才會取得位置，不會背景追蹤。建議查看期限不會自動刪除其他 App 中的內容，位置連結也可能被轉傳，請只分享給信任的人。',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
