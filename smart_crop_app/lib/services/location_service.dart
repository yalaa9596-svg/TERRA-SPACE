import 'package:geolocator/geolocator.dart';

class GeoPoint {
  final double lat;
  final double lon;
  final bool fromGps;

  const GeoPoint({required this.lat, required this.lon, required this.fromGps});
}

class LocationService {
  /// جلب إحداثيات GPS الحقيقية للمزارع مع فولباك آمن لمحافظات مصر
  static Future<GeoPoint> detectFarmerLocation({
    double fallbackLat = 30.0444,
    double fallbackLon = 31.2357,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return GeoPoint(lat: fallbackLat, lon: fallbackLon, fromGps: false);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return GeoPoint(lat: fallbackLat, lon: fallbackLon, fromGps: false);
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 6));
      return GeoPoint(lat: pos.latitude, lon: pos.longitude, fromGps: true);
    } catch (_) {
      return GeoPoint(lat: fallbackLat, lon: fallbackLon, fromGps: false);
    }
  }
}

