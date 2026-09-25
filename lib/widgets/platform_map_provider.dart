import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'
    show TileBuilder, darkModeTileBuilder;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:url_launcher/url_launcher.dart';

import '../core/models.dart';

const double mapBoundsDefaultPadding = 28;

bool get supportsGoogleMapsProvider {
  if (kIsWeb) {
    return false;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    _ => false,
  };
}

bool useGoogleMapsProviderFor(MobileMapProvider provider) {
  return supportsGoogleMapsProvider && provider == MobileMapProvider.googleMaps;
}

/// Identifies this app to the tile servers it talks to.
///
/// The OpenStreetMap tile usage policy requires a clear, stable, contactable
/// `User-Agent` and forbids relying on a library default:
/// https://operations.osmfoundation.org/policies/tiles/
const String mapTileUserAgent =
    'tw.avianjay.taiwanbus.flutter '
    '(+https://github.com/YetAnotherBusDeveloper/yetanotherbusapp)';

/// URL template for the OpenStreetMap standard raster tiles.
///
/// This is deliberately brightness-independent. Dark mode used to point at
/// CARTO's `dark_all` basemap, but CARTO now serves an "API KEY REQUIRED"
/// watermark instead of map data to keyless requests (raster basemaps require
/// a key, and the free commercial tier is 1M tiles/month). Instead we render
/// the same light tiles in both themes and darken them client-side via
/// [mapTileBuilder], which keeps the map key-free on every platform.
String mapTileUrlTemplate() {
  return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}

/// Wraps each tile so dark mode can recolour the light basemap in place.
///
/// Returns `null` in light mode, which leaves the tiles untouched.
TileBuilder? mapTileBuilder(Brightness brightness) {
  if (brightness == Brightness.dark) {
    return darkModeTileBuilder;
  }
  return null;
}

/// Attribution overlay required by the OpenStreetMap tile usage policy.
///
/// The policy requires visible licence attribution that is never hidden
/// beneath other UI or moved off-screen, so this is a permanently visible box
/// rather than a collapsed popup. Only add it to the OSM-backed map: the
/// Google Maps backend carries its own attribution.
///
/// [alignment] must be a corner the map's own controls do not occupy.
Widget mapTileAttribution({Alignment alignment = Alignment.bottomRight}) {
  return SafeArea(
    child: Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: const _MapTileAttribution(),
      ),
    ),
  );
}

/// Deliberately not [SimpleAttributionWidget]: that lays its label out in a
/// [Row], so the full licence text cannot wrap and overflows narrow maps.
/// Here the text is allowed to wrap instead, which keeps the attribution
/// complete and on-screen at every width.
class _MapTileAttribution extends StatelessWidget {
  const _MapTileAttribution();

  static final Uri _copyrightUri = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          launchUrl(_copyrightUri, mode: LaunchMode.externalApplication);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            '© OpenStreetMap contributors',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

Set<Factory<OneSequenceGestureRecognizer>> buildGoogleMapGestureRecognizers() {
  return <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
  };
}

String googleMapStyleForBrightness(Brightness brightness) {
  if (brightness == Brightness.dark) {
    return _googleDarkMapStyle;
  }
  return '[]';
}

gmaps.LatLng toGoogleLatLng(latlong.LatLng point) {
  return gmaps.LatLng(point.latitude, point.longitude);
}

latlong.LatLng fromGoogleLatLng(gmaps.LatLng point) {
  return latlong.LatLng(point.latitude, point.longitude);
}

gmaps.LatLngBounds googleBoundsFromLatLngs(Iterable<latlong.LatLng> points) {
  final iterator = points.iterator;
  if (!iterator.moveNext()) {
    const fallback = gmaps.LatLng(23.7, 121.0);
    return gmaps.LatLngBounds(southwest: fallback, northeast: fallback);
  }

  var south = iterator.current.latitude;
  var north = iterator.current.latitude;
  var west = iterator.current.longitude;
  var east = iterator.current.longitude;

  while (iterator.moveNext()) {
    final point = iterator.current;
    if (point.latitude < south) south = point.latitude;
    if (point.latitude > north) north = point.latitude;
    if (point.longitude < west) west = point.longitude;
    if (point.longitude > east) east = point.longitude;
  }

  return gmaps.LatLngBounds(
    southwest: gmaps.LatLng(
      south.clamp(-85.0, 85.0),
      west.clamp(-180.0, 180.0),
    ),
    northeast: gmaps.LatLng(
      north.clamp(-85.0, 85.0),
      east.clamp(-180.0, 180.0),
    ),
  );
}

double googleMarkerHueForColor(Color color) {
  return HSVColor.fromColor(color).hue;
}

const String _googleDarkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1f2733"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#9aa8b6"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#11161d"
      }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#33404c"
      }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#202b36"
      }
    ]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#16202a"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#22303d"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#7f93a6"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#314150"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#1c2630"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#bdc8d3"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#263544"
      }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#c2ccd6"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#0f1a24"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#5f7487"
      }
    ]
  }
]
''';
