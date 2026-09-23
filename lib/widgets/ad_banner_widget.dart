import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../app/bus_app.dart';
import '../core/ad_service.dart';

const double _maxBannerWidth = 920;

/// A density-aware banner. Hidden and failed slots occupy no space.
class AdBannerWidget extends StatelessWidget {
  const AdBannerWidget({
    this.minimumDensity = 1,
    this.isInline = false,
    this.isActive = true,
    super.key,
  }) : assert(minimumDensity >= 1 && minimumDensity <= 4);

  final int minimumDensity;
  final bool isInline;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final settings = AppControllerScope.of(context).settings;
    if (!AdService.isSupported ||
        !isActive ||
        !TickerMode.valuesOf(context).enabled ||
        !settings.enableAds ||
        settings.adDensity < minimumDensity) {
      return const SizedBox.shrink();
    }

    final orientation = MediaQuery.orientationOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, _maxBannerWidth).floor();
        if (width <= 0) return const SizedBox.shrink();
        // A new layout owns a new ad. Disposing the old slot also invalidates
        // every pending async callback, including SDK initialization/sizing.
        return _BannerSlot(
          key: ValueKey((width, orientation, isInline)),
          width: width,
          isInline: isInline,
        );
      },
    );
  }
}

class _BannerSlot extends StatefulWidget {
  const _BannerSlot({required this.width, required this.isInline, super.key});

  final int width;
  final bool isInline;

  @override
  State<_BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<_BannerSlot> {
  BannerAd? _banner;
  AdSize? _loadedSize;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await AdService.instance.initialize();
      if (!mounted || !AdService.instance.isAvailable) return;
      final size = widget.isInline
          ? AdSize.getInlineAdaptiveBannerAdSize(widget.width, 100)
          : await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
              widget.width,
            );
      if (!mounted || size == null) return;

      final banner = BannerAd(
        adUnitId: AdService.bannerAdUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) => unawaited(_onLoaded(ad as BannerAd)),
          onAdFailedToLoad: (ad, _) => _onFailed(ad as BannerAd),
        ),
      );
      _banner = banner;
      await banner.load();
    } catch (_) {
      final banner = _banner;
      if (banner != null) _onFailed(banner);
    }
  }

  Future<void> _onLoaded(BannerAd banner) async {
    if (!mounted || !identical(_banner, banner)) return;
    try {
      final size = widget.isInline
          ? await banner.getPlatformAdSize()
          : banner.size;
      if (!mounted || !identical(_banner, banner)) return;
      if (size == null || size.width <= 0 || size.height <= 0) {
        _onFailed(banner);
        return;
      }
      setState(() => _loadedSize = size);
    } catch (_) {
      _onFailed(banner);
    }
  }

  void _onFailed(BannerAd banner) {
    if (!mounted || !identical(_banner, banner)) return;
    setState(() {
      _banner = null;
      _loadedSize = null;
    });
    unawaited(banner.dispose());
  }

  @override
  void dispose() {
    final banner = _banner;
    _banner = null;
    if (banner != null) unawaited(banner.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    final size = _loadedSize;
    if (banner == null || size == null) return const SizedBox.shrink();
    return Padding(
      padding: widget.isInline
          ? const EdgeInsets.symmetric(vertical: 12)
          : EdgeInsets.zero,
      child: Center(
        heightFactor: 1,
        child: SizedBox(
          width: size.width.toDouble(),
          height: size.height.toDouble(),
          child: AdWidget(ad: banner),
        ),
      ),
    );
  }
}
