import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
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
  bool loading = false;
  String status = 'Tap the button to check your heat risk.';
  String placeName = 'Location not checked yet.';
  double? userLat;
  double? userLon;
  int forecastIndex = 0;
  List<StreetRisk> streets = [];

  final List<String> forecastNames = ['Now', '+2 Hours', '+6 Hours'];

  Future<void> checkRisk() async {
    setState(() {
      loading = true;
      status = 'Getting GPS location...';
      streets = [];
    });

    try {
      final position = await _getPosition();

      userLat = position.latitude;
      userLon = position.longitude;

      setState(() {
        status = 'Loading real place, streets, and weather...';
      });

      final place = await fetchPlaceName(userLat!, userLon!);
      final weather = await fetchWeather(userLat!, userLon!);
      final realStreets = await fetchNearbyStreets(userLat!, userLon!);

      final List<StreetRisk> result = [];

      for (final street in realStreets) {
        final surface = highwayToSurface(street['highway']);
        final surfaceScore = getSurfaceScore(surface);

        final forecasts = <Map<String, dynamic>>[];

        for (final item in [
          {'label': 'Now', 'index': 0},
          {'label': '+2 Hours', 'index': 2},
          {'label': '+6 Hours', 'index': 6},
        ]) {
          final i = item['index'] as int;

          final temp = weather['temperature'][i];
          final humidity = weather['humidity'][i];
          final apparentTemp = weather['apparent_temperature'][i];

          final risk = calculateRisk(
            temp.toDouble(),
            humidity.toDouble(),
            apparentTemp.toDouble(),
            surfaceScore,
          );

          forecasts.add({
            'forecast': item['label'],
            'time': weather['time'][i],
            'temperature': temp,
            'humidity': humidity,
            'apparent_temperature': apparentTemp,
            'risk_score': risk['score'],
            'level': risk['level'],
            'advice': risk['advice'],
          });
        }

        result.add(
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
        placeName = place;
        streets = result;
        status = 'Loaded ${streets.length} real nearby streets.';
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        status = 'Error: $e';
      });
    }
  }

  Future<Position> _getPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

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
        'lat': center['lat'],
        'lon': center['lon'],
        'highway': highway,
      });

      if (output.length >= 20) break;
    }

    return output;
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

    if (concrete.contains(highway)) {
      return 'Road / Concrete';
    }

    if (mixed.contains(highway)) {
      return 'Mixed Area';
    }

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
        'advice': 'Stay hydrated and avoid long outdoor exposure.',
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

  @override
  Widget build(BuildContext context) {
    final center = LatLng(userLat ?? 23.8103, userLon ?? 90.4125);

    return Scaffold(
      backgroundColor: const Color(0xfff4f6f8),
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
              _infoCard('Current Location', placeName),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.deepOrange, Colors.orangeAccent],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Heat Risk Warning',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Live GPS + real streets + real weather + heat risk prediction',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _forecastSlider() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Forecast Time: ${forecastNames[forecastIndex]}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: forecastIndex.toDouble(),
            min: 0,
            max: 2,
            divisions: 2,
            label: forecastNames[forecastIndex],
            onChanged: (value) {
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
    final markers = <CircleMarker>[];

    for (final street in streets) {
      final forecast = street.forecasts[forecastIndex];
      final level = forecast['level'];

      markers.add(
        CircleMarker(
          point: LatLng(street.lat, street.lon),
          radius: 16,
          color: riskColor(level).withOpacity(0.35),
          borderColor: riskColor(level),
          borderStrokeWidth: 3,
        ),
      );
    }

    return Container(
      height: 380,
      decoration: _boxDecoration(),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
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
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 42,
                height: 42,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.blue,
                  size: 42,
                ),
              ),
            ],
          ),
          CircleLayer(circles: markers),
        ],
      ),
    );
  }

  Widget _agents() {
    final agents = [
      ['Heat Sensor Agent', 'Fetching Open-Meteo weather'],
      ['Surface Scanner Agent', 'Reading OpenStreetMap roads'],
      ['People Tracker Agent', 'Estimating exposure zone'],
      ['Risk Calculator Agent', 'Calculating danger score'],
      ['Alert Agent', 'Preparing safety advice'],
      ['Self-Learning Agent', 'Ready for future data'],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Agent System',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.65,
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
    final f = street.forecasts[forecastIndex];
    final level = f['level'];
    final color = riskColor(level);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: color, width: 6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${street.name}: $level',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Road Type: ${street.roadType}'),
          Text('Surface: ${street.surface}'),
          Text('Forecast: ${f['forecast']}'),
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
