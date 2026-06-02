import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const HeatRiskApp());
}

class HeatRiskApp extends StatelessWidget {
  const HeatRiskApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Heat Risk Warning',
      debugShowCheckedModeBanner: false,
      home: const HeatRiskHome(),
    );
  }
}

class StreetRisk {
  final String name;
  final double lat;
  final double lon;
  final String roadType;
  final String surface;
  final List<Map<String, dynamic>> forecasts;
  StreetRisk({
    required this.name,
    required this.lat,
    required this.lon,
    required this.roadType,
    required this.surface,
    required this.forecasts,
  });
}

class HeatRiskHome extends StatefulWidget {
  const HeatRiskHome({super.key});
  @override
  State<HeatRiskHome> createState() => _HeatRiskHomeState();
}

class _HeatRiskHomeState extends State<HeatRiskHome> {
  double? userLat;
  double? userLon;
  String placeName = '';
  int forecastIndex = 0;
  List<StreetRisk> streets = [];
  bool loading = false;
  List<String> forecastNames = [];
  final MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // --- Single declaration of functions to avoid duplicates ---
  Future<void> _getCurrentLocation() async {
    setState(() => loading = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      userLat = pos.latitude;
      userLon = pos.longitude;
      await _fetchPlace();
      await _fetchStreetsAndWeather();
    } catch (e) {
      placeName = "Location unavailable";
    }
    setState(() => loading = false);
  }

  Future<void> _fetchPlace() async {
    if (userLat == null || userLon == null) return;
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$userLat&lon=$userLon&zoom=18&addressdetails=1&accept-language=en');
    final res =
        await http.get(url, headers: {'User-Agent': 'AI-Heat-Risk-Demo/1.0'});
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      placeName = data['display_name'] ?? '';
    } else {
      placeName = '';
    }
  }

  Future<void> _fetchStreetsAndWeather() async {
    if (userLat == null || userLon == null) return;
    await _fetchStreets();
    await _fetchWeatherForStreets();
  }

  Future<void> _fetchStreets() async {
    final url = Uri.parse('https://overpass-api.de/api/interpreter');
    final query = '''
[out:json][timeout:25];
way["highway"](around:900,$userLat,$userLon);
out center tags;
''';
    final res = await http.post(url,
        headers: {'User-Agent': 'AI-Heat-Risk-Demo/1.0'}, body: {'data': query});
    if (res.statusCode != 200) return;
    final data = jsonDecode(res.body);
    List elements = data['elements'] ?? [];
    streets = [];
    final seen = <String>{};
    for (var e in elements) {
      var tags = e['tags'];
      var center = e['center'];
      if (tags == null || center == null) continue;
      String name = tags['name:en'] ?? tags['name'] ?? 'Unnamed ${tags['highway'] ?? 'road'}';
      String key = '${name}-${center['lat']}-${center['lon']}';
      if (seen.contains(key)) continue;
      seen.add(key);
      String highway = tags['highway'] ?? 'road';
      String surface = _highwayToSurface(highway);
      streets.add(StreetRisk(
          name: name,
          lat: center['lat'],
          lon: center['lon'],
          roadType: highway,
          surface: surface,
          forecasts: []));
      if (streets.length >= 20) break;
    }
  }

  Future<void> _fetchWeatherForStreets() async {
    final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$userLat&longitude=$userLon&hourly=temperature_2m,relative_humidity_2m,apparent_temperature&forecast_days=1&timezone=auto');
    final res = await http.get(url);
    if (res.statusCode != 200) return;
    final data = jsonDecode(res.body);
    List times = data['hourly']['time'];
    List temps = data['hourly']['temperature_2m'];
    List humidity = data['hourly']['relative_humidity_2m'];
    List apparent = data['hourly']['apparent_temperature'];
    forecastNames = [];
    streets = streets.map((s) {
      List<Map<String, dynamic>> fcast = [];
      for (int i = 0; i < times.length; i++) {
        fcast.add(_calcRisk(
            temps[i].toDouble(), humidity[i].toDouble(), apparent[i].toDouble(), _surfaceScore(s.surface), times[i]));
        forecastNames.add(times[i].toString().substring(11, 16));
        if (fcast.length >= 6) break; // next 6 hours
      }
      s.forecasts.addAll(fcast);
      return s;
    }).toList();
    setState(() {});
  }

  int _surfaceScore(String surface) {
    if (surface == 'Road / Concrete') return 30;
    if (surface == 'Mixed Area') return 18;
    if (surface == 'Park / Trees') return 6;
    return 15;
  }

  String _highwayToSurface(String highway) {
    final concrete = ['motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'unclassified'];
    final mixed = ['residential', 'service', 'living_street', 'pedestrian', 'footway', 'cycleway'];
    if (concrete.contains(highway)) return 'Road / Concrete';
    if (mixed.contains(highway)) return 'Mixed Area';
    return 'Park / Trees';
  }

  Map<String, dynamic> _calcRisk(double temp, double hum, double apparent, int surfaceScore, String time) {
    int score = ((temp - 24) * 3 + (hum - 55) * 0.35 + (apparent - 27) * 2 + surfaceScore).clamp(0, 100).toInt();
    String level = score >= 70 ? 'DANGER' : score >= 40 ? 'ALERT' : 'SAFE';
    String advice = level == 'DANGER'
        ? 'Avoid outdoor exposure and use shaded routes.'
        : level == 'ALERT'
            ? 'Take precautions, stay hydrated.'
            : 'Safe for outdoor activity.';
    return {'time': time, 'temperature': temp, 'humidity': hum, 'apparent_temperature': apparent, 'risk_score': score, 'level': level, 'advice': advice};
  }

  // Build UI remains same as your previous Flutter code, with headings centered, map showing tiles, agent panel, slider, etc.
  // Use Flutter Map 7.x with initialCenter and CircleMarkers
  // Implement live forecast slider using forecastNames populated dynamically
  // For map popup, show short location from placeName instead of "You are here"
}
