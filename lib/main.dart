import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
      ),
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
  final MapController mapController = MapController();

  bool loading = false;
  String status = 'Tap the button to check your heat risk.';
  String placeName = 'Location not checked yet.';

  double? userLat;
  double? userLon;

  int forecastIndex = 0;
  List<String> forecastLabels = ['Now'];
  List<StreetRisk> streets = [];

  Future<void> checkRisk() async {
    setState(() {
      loading = true;
      status = 'Getting GPS location...';
      streets = [];
      forecastIndex = 0;
      forecastLabels = ['Now'];
    });

    try {
      final position = await getPosition();

      userLat = position.latitude;
      userLon = position.longitude;

      setState(() {
        status = 'Loading real place name...';
      });

      placeName = await fetchPlaceName(userLat!, userLon!);

      setState(() {
        status = 'Loading real nearby streets...';
      });

      final realStreets = await fetchNearbyStreets(userLat!, userLon!);

      setState(() {
        status = 'Loading real weather forecast...';
      });

      final weather = await fetchWeather(userLat!, userLon!);

      final List times = weather['time'];
      final List temps = weather['temperature'];
      final List humidity = weather['humidity'];
      final List apparentTemps = weather['apparent_temperature'];

      final int startIndex = findCurrentHourIndex(times);
      final List<int> selectedIndexes = [];

      for (int i = 0; i <= 6; i++) {
        final idx = startIndex + i;
        if (idx < times.length) {
          selectedIndexes.add(idx);
        }
      }

      forecastLabels = selectedIndexes.map((idx) {
        final t = times[idx].toString();
        return t.length >= 16 ? t.substring(11, 16) : t;
      }).toList();

      final List<StreetRisk> finalStreets = [];

      for (final street in realStreets) {
        final surface = highwayToSurface(street['highway']);
        final surfaceScore = getSurfaceScore(surface);
        final forecasts = <Map<String, dynamic>>[];

        for (final idx in selectedIndexes) {
          final temp = (temps[idx] as num).toDouble();
          final hum = (humidity[idx] as num).toDouble();
          final apparent = (apparentTemps[idx] as num).toDouble();

          final risk = calculateRisk(
            temp,
            hum,
            apparent,
            surfaceScore,
          );

          forecasts.add({
            'time': times[idx],
            'temperature': temp,
            'humidity': hum,
            'apparent_temperature': apparent,
            'risk_score': risk['score'],
            'level': risk['level'],
            'advice': risk['advice'],
          });
        }

        finalStreets.add(
          StreetRisk(
            name: street['name'],
            lat: street['lat'],
            lon: street['lon'],
            roadType: street['highway'],
            surface: surface,
            forecasts: forecasts,
          ),
        );
      }

      setState(() {
        streets = finalStreets;
        loading = false;
        status = 'Loaded ${streets.length} real nearby streets.';
      });

      if (userLat != null && userLon != null) {
        mapController.move(LatLng(userLat!, userLon!), 15);
      }
    } catch (e) {
      setState(() {
        loading = false;
        status = 'Error: $e';
      });
    }
  }

  Future<Position> getPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Location service is disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied.');
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<String> fetchPlaceName(double lat, double lon) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1&accept-language=en',
    );

    final response = await http.get(
      uri,
      headers: {'User-Agent': 'AI-Heat-Risk-Demo/1.0'},
    );

    if (response.statusCode != 200) {
      return 'Unknown location';
    }

    final data = jsonDecode(response.body);
    return data['display_name'] ?? 'Unknown location';
  }

  Future<Map<String, dynamic>> fetchWeather(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&hourly=temperature_2m,relative_humidity_2m,apparent_temperature'
      '&forecast_days=1&timezone=auto',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Weather API failed.');
    }

    final data = jsonDecode(response.body);

    return {
      'time': data['hourly']['time'],
      'temperature': data['hourly']['temperature_2m'],
      'humidity': data['hourly']['relative_humidity_2m'],
      'apparent_temperature': data['hourly']['apparent_temperature'],
    };
  }

  Future<List<Map<String, dynamic>>> fetchNearbyStreets(
    double lat,
    double lon,
  ) async {
    final query = '''
[out:json][timeout:25];
way["highway"](around:900,$lat,$lon);
out center tags;
''';

    final response = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      headers: {'User-Agent': 'AI-Heat-Risk-Demo/1.0'},
      body: {'data': query},
    );

    if (response.statusCode != 200) {
      throw Exception('OpenStreetMap street API failed.');
    }

    final data = jsonDecode(response.body);
    final List elements = data['elements'] ?? [];

    final List<Map<String, dynamic>> output = [];
    final Set<String> seen = {};

    for (final element in elements) {
      final tags = element['tags'];
      final center = element['center'];

      if (tags == null || center == null) continue;

      final highway = tags['highway'] ?? 'road';
      final name = tags['name:en'] ??
          tags['name'] ??
          'Unnamed $highway road';

      final key =
          '$name-${center['lat'].toStringAsFixed(5)}-${center['lon'].toStringAsFixed(5)}';

      if (seen.contains(key)) continue;
      seen.add(key);

      output.add({
        'name': name,
        'lat': (center['lat'] as num).toDouble(),
        'lon': (center['lon'] as num).toDouble(),
        'highway': highway,
      });

      if (output.length >= 20) break;
    }

    return output;
  }

  int findCurrentHourIndex(List times) {
    final now = DateTime.now();

    for (int i = 0; i < times.length; i++) {
      final t = DateTime.tryParse(times[i].toString());
      if (t == null) continue;

      if (t.hour >= now.hour) {
        return i;
      }
    }

    return 0;
  }

  String highwayToSurface(String highway) {
    final concrete = [
      'motorway',
      'trunk',
      'primary',
      'secondary',
      'tertiary',
      'unclassified',
    ];

    final mixed = [
      'residential',
      'service',
      'living_street',
      'pedestrian',
      'footway',
      'cycleway',
    ];

    if (concrete.contains(highway)) return 'Road / Concrete';
    if (mixed.contains(highway)) return 'Mixed Area';

    return 'Park / Trees';
  }

  int getSurfaceScore(String surface) {
    if (surface == 'Road / Concrete') return 30;
    if (surface == 'Mixed Area') return 18;
    if (surface == 'Park / Trees') return 6;
    return 15;
  }

  Map<String, dynamic> calculateRisk(
    double temp,
    double humidity,
    double apparentTemp,
    int surfaceScore,
  ) {
    final tempScore = ((temp - 24) * 3).clamp(0, 100);
    final humidityScore = ((humidity - 55) * 0.35).clamp(0, 100);
    final feelsLikeScore = ((apparentTemp - 27) * 2).clamp(0, 100);

    final score = (tempScore + humidityScore + feelsLikeScore + surfaceScore)
        .clamp(0, 100)
        .toInt();

    if (score >= 70) {
      return {
        'score': score,
        'level': 'DANGER',
        'advice': 'Avoid outdoor exposure and use shaded routes.',
      };
    }

    if (score >= 40) {
      return {
        'score': score,
        'level': 'ALERT',
        'advice': 'Take precautions, stay hydrated, and avoid long exposure.',
      };
    }

    return {
      'score': score,
      'level': 'SAFE',
      'advice': 'Area is safe for outdoor activity.',
    };
  }

  Color riskColor(String level) {
    if (level == 'DANGER') return Colors.red;
    if (level == 'ALERT') return Colors.orange;
    return Colors.green;
  }

  String shortLocation(String full) {
    final parts = full.split(',');
    if (parts.length >= 3) {
      return '${parts[0]}, ${parts[1]}, ${parts[2]}';
    }
    return full;
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(userLat ?? 23.8103, userLon ?? 90.4125);

    return Scaffold(
      backgroundColor: const Color(0xfff0f3f8),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: checkRisk,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: loading ? null : checkRisk,
                icon: const Icon(Icons.my_location),
                label: Text(loading ? 'Loading...' : 'Check My Heat Risk'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _forecastSlider(),
              const SizedBox(height: 14),
              _infoCard('Current Location', shortLocation(placeName)),
              const SizedBox(height: 14),
              _map(center),
              const SizedBox(height: 18),
              _agents(),
              const SizedBox(height: 18),
              _infoCard('Status', status),
              const SizedBox(height: 10),
              ...streets.map(_streetCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.deepOrange, Colors.orangeAccent],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'AI Heat Risk Warning',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Real weather + GPS location + real place names + live nearby streets',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _forecastSlider() {
    final maxValue = forecastLabels.length > 1
        ? (forecastLabels.length - 1).toDouble()
        : 0.0;

    if (forecastIndex >= forecastLabels.length) {
      forecastIndex = 0;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Forecast Time: ${forecastLabels[forecastIndex]}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: forecastIndex.toDouble(),
            min: 0,
            max: maxValue,
            divisions: forecastLabels.length > 1
                ? forecastLabels.length - 1
                : null,
            label: forecastLabels[forecastIndex],
            onChanged: forecastLabels.length <= 1
                ? null
                : (value) {
                    setState(() {
                      forecastIndex = value.toInt();
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _map(LatLng center) {
    final circles = <CircleMarker>[];

    for (final street in streets) {
      if (street.forecasts.length <= forecastIndex) continue;

      final f = street.forecasts[forecastIndex];
      final color = riskColor(f['level']);

      circles.add(
        CircleMarker(
          point: LatLng(street.lat, street.lon),
          radius: 16,
          color: color.withOpacity(0.35),
          borderColor: color,
          borderStrokeWidth: 3,
        ),
      );
    }

    return Container(
      height: 380,
      decoration: _boxDecoration(),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 15,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.heat_risk_app',
          ),
          CircleLayer(circles: circles),
        ],
      ),
    );
  }

  Widget _agents() {
    final agents = [
      ['Heat Sensor Agent', 'Fetching real Open-Meteo weather'],
      ['Surface Scanner Agent', 'Reading real OSM streets'],
      ['People Tracker Agent', 'Estimating street exposure'],
      ['Risk Calculator Agent', 'Calculating heat danger score'],
      ['Alert Agent', 'Preparing safety warning'],
      ['Self-Learning Agent', 'Ready for future data'],
    ];

    return Column(
      children: [
        const Center(
          child: Text(
            'AI Agent System',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: agents.map((a) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: _boxDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.smart_toy, color: Colors.deepOrange),
                  const Spacer(),
                  Text(
                    a[0],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    a[1],
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _streetCard(StreetRisk street) {
    if (street.forecasts.length <= forecastIndex) {
      return const SizedBox.shrink();
    }

    final f = street.forecasts[forecastIndex];
    final level = f['level'];
    final color = riskColor(level);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(color: color, width: 6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${street.name}: $level',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text('Road Type: ${street.roadType}'),
          Text('Surface: ${street.surface}'),
          Text('Time: ${f['time']}'),
          Text('Temperature: ${f['temperature']} °C'),
          Text('Humidity: ${f['humidity']}%'),
          Text('Feels Like: ${f['apparent_temperature']} °C'),
          Text('Risk Score: ${f['risk_score']}/100'),
          const SizedBox(height: 8),
          Text(f['advice']),
        ],
      ),
    );
  }

  Widget _infoCard(String title, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(text),
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.07),
          blurRadius: 15,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}
