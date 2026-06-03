import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.locationWhenInUse.request();
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
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      home: const HeatRiskWebView(),
    );
  }
}

class HeatRiskWebView extends StatefulWidget {
  const HeatRiskWebView({super.key});

  @override
  State<HeatRiskWebView> createState() => _HeatRiskWebViewState();
}

class _HeatRiskWebViewState extends State<HeatRiskWebView> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_html, baseUrl: 'https://heat-risk.local');

    if (controller.platform is AndroidWebViewController) {
      final androidController =
          controller.platform as AndroidWebViewController;

      androidController.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          return GeolocationPermissionsResponse(
            allow: true,
            retain: true,
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: WebViewWidget(controller: controller)),
    );
  }
}

const String _html = """
<!DOCTYPE html>
<html>
<head>
  <title>AI Heat Risk Warning</title>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'Inter', sans-serif; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); min-height: 100vh; }
    .tab-bar { display: flex; background: rgba(255,255,255,0.95); border-radius: 30px; margin: 16px; padding: 6px; box-shadow: 0 10px 25px rgba(0,0,0,0.2); }
    .tab { flex: 1; text-align: center; padding: 14px; border-radius: 25px; font-weight: 700; font-size: 16px; cursor: pointer; transition: all 0.3s ease; color: #666; }
    .tab.active { background: linear-gradient(135deg, #ff7e5f, #feb47b); color: white; box-shadow: 0 4px 12px rgba(255,126,95,0.3); }
    .app-container { max-width: 550px; margin: 0 auto; padding: 0 16px 20px 16px; }
    .tab-content { display: none; }
    .tab-content.active { display: block; }
    .header { background: rgba(255,255,255,0.95); border-radius: 28px; padding: 20px; margin-bottom: 16px; text-align: center; box-shadow: 0 20px 35px -10px rgba(0,0,0,0.2); }
    .header h1 { font-size: 28px; font-weight: 800; background: linear-gradient(135deg, #ff6b6b, #ff8e53); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 4px; }
    .header p { color: #666; font-size: 13px; font-weight: 500; }
    .warning-card { background: linear-gradient(135deg, #1a1a2e, #16213e); border-radius: 24px; padding: 20px; margin-bottom: 16px; cursor: pointer; transition: transform 0.3s ease; border-left: 6px solid; }
    .warning-card:hover { transform: translateY(-2px); }
    .warning-card.safe { border-left-color: #4caf50; background: linear-gradient(135deg, #1b4332, #2d6a4f); }
    .warning-card.alert { border-left-color: #ffa500; background: linear-gradient(135deg, #e85d04, #f48c06); }
    .warning-card.danger { border-left-color: #ff4b4b; background: linear-gradient(135deg, #9d0208, #dc2f02); animation: pulseGlow 1s ease-in-out infinite; }
    @keyframes pulseGlow { 0%, 100% { box-shadow: 0 0 0 0 rgba(255,75,75,0.4); } 50% { box-shadow: 0 0 0 15px rgba(255,75,75,0); } }
    .warning-header { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }
    .warning-icon { font-size: 40px; }
    .warning-title { font-size: 22px; font-weight: 800; color: white; }
    .warning-message { color: rgba(255,255,255,0.95); font-size: 15px; line-height: 1.5; margin-bottom: 12px; font-weight: 500; }
    .warning-details { color: rgba(255,255,255,0.85); font-size: 13px; line-height: 1.5; margin-bottom: 12px; padding: 10px; background: rgba(0,0,0,0.2); border-radius: 12px; white-space: pre-line; }
    .warning-location { color: rgba(255,255,255,0.9); font-size: 13px; display: flex; align-items: center; gap: 8px; flex-wrap: wrap; margin-bottom: 10px; }
    .risk-badge { display: inline-block; background: rgba(255,255,255,0.2); border-radius: 20px; padding: 6px 14px; font-size: 14px; font-weight: 700; color: white; }
    .map-container { background: rgba(255,255,255,0.95); border-radius: 24px; padding: 12px; margin-bottom: 16px; }
    .map-container h3 { font-size: 16px; font-weight: 700; color: #333; margin-bottom: 12px; padding-left: 8px; }
    #heatMap, #routeMap { height: 400px; border-radius: 20px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
    .control-panel { background: rgba(255,255,255,0.95); border-radius: 24px; padding: 16px; margin-bottom: 16px; }
    .slider-container { margin-bottom: 16px; }
    .slider-label { display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 13px; font-weight: 600; color: #555; }
    input[type="range"] { width: 100%; height: 6px; border-radius: 10px; background: linear-gradient(90deg, #4caf50, #ffa500, #ff4b4b); -webkit-appearance: none; }
    input[type="range"]:focus { outline: none; }
    input[type="range"]::-webkit-slider-thumb { -webkit-appearance: none; width: 22px; height: 22px; border-radius: 50%; background: #ff7e5f; cursor: pointer; box-shadow: 0 2px 8px rgba(0,0,0,0.2); border: 2px solid white; }
    .refresh-btn { width: 100%; padding: 14px; background: linear-gradient(135deg, #ff7e5f, #feb47b); color: white; border: none; border-radius: 25px; font-weight: 700; font-size: 15px; cursor: pointer; transition: all 0.2s; }
    .location-details { background: rgba(255,255,255,0.95); border-radius: 20px; padding: 16px; margin-bottom: 16px; }
    .location-details h4 { font-size: 12px; color: #888; margin-bottom: 8px; letter-spacing: 1px; }
    .location-address { font-size: 15px; font-weight: 600; color: #333; margin-bottom: 8px; }
    .location-coords { font-size: 12px; color: #666; font-family: monospace; }
    .location-stats { display: flex; gap: 16px; margin-top: 12px; padding-top: 12px; border-top: 1px solid #eee; }
    .stat { flex: 1; text-align: center; }
    .stat-value { font-size: 20px; font-weight: 800; color: #ff7e5f; }
    .stat-label { font-size: 11px; color: #888; }
    .results-container { background: rgba(255,255,255,0.95); border-radius: 24px; padding: 16px; margin-bottom: 16px; }
    .results-container h3 { font-size: 16px; margin-bottom: 12px; color: #333; }
    .street-card { background: white; border-radius: 14px; padding: 14px; margin-bottom: 10px; border-left: 5px solid; box-shadow: 0 2px 8px rgba(0,0,0,0.05); }
    .street-card.DANGER { border-left-color: #ff4b4b; }
    .street-card.ALERT { border-left-color: #ffa500; }
    .street-card.SAFE { border-left-color: #4caf50; }
    .street-name { font-weight: 700; font-size: 15px; margin-bottom: 6px; }
    .street-details { font-size: 12px; color: #666; display: flex; flex-wrap: wrap; gap: 12px; margin-top: 6px; }
    .route-header { background: rgba(255,255,255,0.95); border-radius: 28px; padding: 20px; margin-bottom: 16px; text-align: center; }
    .route-header h2 { font-size: 24px; font-weight: 800; background: linear-gradient(135deg, #667eea, #764ba2); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
    .search-section { background: rgba(255,255,255,0.95); border-radius: 24px; padding: 16px; margin-bottom: 16px; }
    .search-box { display: flex; gap: 10px; margin-bottom: 12px; }
    .search-input { flex: 1; padding: 14px 18px; border: 1px solid #ddd; border-radius: 30px; font-size: 14px; outline: none; }
    .search-input:focus { border-color: #667eea; }
    .search-btn, .plan-btn { padding: 12px 24px; background: linear-gradient(135deg, #667eea, #764ba2); color: white; border: none; border-radius: 30px; font-weight: 600; cursor: pointer; }
    .plan-btn { width: 100%; margin-top: 10px; padding: 14px; font-size: 16px; }
    .suggestions { max-height: 200px; overflow-y: auto; background: white; border-radius: 16px; margin-top: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
    .suggestion-item { padding: 12px 16px; border-bottom: 1px solid #eee; cursor: pointer; }
    .suggestion-item:hover { background: #f5f5f5; }
    .route-results { background: rgba(255,255,255,0.95); border-radius: 24px; padding: 16px; }
    .route-card { background: white; border-radius: 16px; padding: 16px; margin-bottom: 12px; cursor: pointer; border: 2px solid transparent; transition: all 0.2s; }
    .route-card:hover { transform: translateX(5px); }
    .route-card.best { background: linear-gradient(135deg, #2ecc71, #27ae60); color: white; }
    .route-name { font-weight: 800; font-size: 16px; margin-bottom: 8px; }
    .route-stats { display: flex; gap: 16px; font-size: 13px; margin-top: 8px; flex-wrap: wrap; }
    .agents-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin-top: 12px; }
    .agent-card { background: linear-gradient(135deg, #f5f7fa, #e8ecf1); padding: 12px; border-radius: 14px; position: relative; }
    .agent-card.active { background: linear-gradient(135deg, #ff7e5f, #feb47b); color: white; }
    .agent-name { font-weight: 700; font-size: 12px; margin-bottom: 4px; }
    .agent-status { font-size: 10px; opacity: 0.8; }
    .agent-dot { position: absolute; top: 10px; right: 10px; width: 8px; height: 8px; border-radius: 50%; background: #4caf50; animation: blink 1s infinite; }
    @keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0.3; } }
    .loading { text-align: center; padding: 30px; color: #888; }
    .hidden { display: none; }
    .success { color: #4caf50; }
    .error { color: #ff4b4b; }
  </style>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
</head>
<body>

<div class="tab-bar">
  <div class="tab active" onclick="switchTab('heatMap')">🌡️ Heat Map</div>
  <div class="tab" onclick="switchTab('route')">🗺️ Route Planner</div>
</div>

<!-- HEAT MAP TAB -->
<div id="heatMapContent" class="tab-content active">
  <div class="app-container">
    <div class="header">
      <h1>🌡️ AI Heat Risk Warning</h1>
      <p>Real-time thermal mapping & street analysis</p>
    </div>
    
    <div id="warningCard" class="warning-card safe" onclick="refreshHeatMap()">
      <div class="warning-header">
        <span class="warning-icon" id="warningIcon">✅</span>
        <span class="warning-title" id="warningTitle">Safe Zone</span>
      </div>
      <div class="warning-message" id="warningMessage">Tap to check your current heat risk level</div>
      <div class="warning-details" id="warningDetails">Stay hydrated and enjoy your day</div>
      <div class="warning-location"><span>📍</span><span id="warningLocation">--</span></div>
      <div class="risk-badge" id="riskBadge">Risk Score: --</div>
    </div>
    
    <div class="map-container">
      <h3>🗺️ Heat Risk Map</h3>
      <div id="heatMap"></div>
    </div>
    
    <div class="control-panel">
      <div class="slider-container">
        <div class="slider-label"><span>⏰ Forecast Time</span><span id="forecastValue">Now</span></div>
        <input type="range" id="forecastSlider" min="0" max="12" value="0" oninput="updateForecast(this.value)">
      </div>
      <button class="refresh-btn" onclick="refreshHeatMap()">🔄 Refresh Heat Data</button>
    </div>
    
    <div class="location-details">
      <h4>📍 CURRENT LOCATION</h4>
      <div class="location-address" id="locationAddress">Getting location...</div>
      <div class="location-coords" id="locationCoords">--</div>
      <div class="location-stats">
        <div class="stat"><div class="stat-value" id="tempValue">--</div><div class="stat-label">Temperature</div></div>
        <div class="stat"><div class="stat-value" id="humidityValue">--</div><div class="stat-label">Humidity</div></div>
        <div class="stat"><div class="stat-value" id="feelsLikeValue">--</div><div class="stat-label">Feels Like</div></div>
      </div>
    </div>
    
    <div class="control-panel">
      <h4 style="margin-bottom:12px;">🤖 AI Agent Network</h4>
      <div class="agents-grid" id="agentsGrid"></div>
    </div>
    
    <div class="results-container">
      <h3>📊 Nearby Street Heat Analysis</h3>
      <div id="resultsContent">Waiting for location data...</div>
    </div>
  </div>
</div>

<!-- ROUTE PLANNER TAB -->
<div id="routeContent" class="tab-content">
  <div class="app-container">
    <div class="route-header">
      <h2>🗺️ Smart Route Planner</h2>
      <p style="color:#666; margin-top:8px;">Find the coolest path to your destination</p>
    </div>
    
    <div id="routeMap"></div>
    
    <div class="search-section">
      <div class="search-box">
        <input type="text" class="search-input" id="destinationInput" placeholder="Enter destination (e.g., Central Park, Times Square)">
        <button class="search-btn" onclick="searchDestination()">Search</button>
      </div>
      <div id="suggestions" class="suggestions hidden"></div>
      <button class="plan-btn" id="planRouteBtn" onclick="planRoutes()" style="display:none;">🌿 Find Coolest Routes</button>
    </div>
    
    <div class="route-results">
      <h3>🎯 Route Options</h3>
      <div id="routeResultsContent">Enter a destination to see route options</div>
    </div>
  </div>
</div>

<script>
var heatMap, routeMap;
var userMarker, userCircle, heatOverlays = [];
var currentLat = null, currentLon = null;
var cachedWeather = null;
var currentForecast = 0;
var forecastNames = [];
var streetMarkers = [];
var destinationLat = null, destinationLon = null;

function switchTab(tab) {
  var tabs = document.querySelectorAll('.tab');
  for (var i = 0; i < tabs.length; i++) {
    tabs[i].classList.remove('active');
  }
  if (tab === 'heatMap') {
    tabs[0].classList.add('active');
    document.getElementById('heatMapContent').classList.add('active');
    document.getElementById('routeContent').classList.remove('active');
    if (heatMap) setTimeout(function() { heatMap.invalidateSize(); }, 100);
  } else {
    tabs[1].classList.add('active');
    document.getElementById('routeContent').classList.add('active');
    document.getElementById('heatMapContent').classList.remove('active');
    if (routeMap) setTimeout(function() { routeMap.invalidateSize(); }, 100);
  }
}

function initHeatMap(lat, lon) {
  if (!heatMap) {
    heatMap = L.map("heatMap").setView([lat, lon], 15);
    L.tileLayer("https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png", {
      attribution: '&copy; OSM',
      subdomains: 'abcd',
      maxZoom: 19
    }).addTo(heatMap);
  } else {
    heatMap.setView([lat, lon], 15);
  }
  if (!userMarker) {
    userMarker = L.marker([lat, lon]).addTo(heatMap);
  } else {
    userMarker.setLatLng([lat, lon]);
  }
  updateUserCircle(lat, lon);
}

function initRouteMap(lat, lon) {
  if (!routeMap) {
    routeMap = L.map("routeMap").setView([lat, lon], 13);
    L.tileLayer("https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png", {
      attribution: '&copy; OSM',
      subdomains: 'abcd',
      maxZoom: 19
    }).addTo(routeMap);
  } else {
    routeMap.setView([lat, lon], 13);
  }
  if (!window.routeUserMarker) {
    window.routeUserMarker = L.marker([lat, lon]).addTo(routeMap).bindPopup('Your location');
  } else {
    window.routeUserMarker.setLatLng([lat, lon]);
  }
}

function updateUserCircle(lat, lon) {
  if (userCircle) heatMap.removeLayer(userCircle);
  var color = '#4caf50';
  var radius = 70;
  if (cachedWeather) {
    var temp = cachedWeather.temperature[currentForecast];
    if (temp >= 35) { color = '#ff4b4b'; radius = 140; }
    else if (temp >= 30) { color = '#ff4b4b'; radius = 120; }
    else if (temp >= 25) { color = '#ffa500'; radius = 90; }
  }
  userCircle = L.circle([lat, lon], { radius: radius, color: color, fillColor: color, fillOpacity: 0.3, weight: 3 }).addTo(heatMap);
}

function fetchWeather(lat, lon) {
  var url = 'https://api.open-meteo.com/v1/forecast?latitude=' + lat + '&longitude=' + lon + '&hourly=temperature_2m,relative_humidity_2m,apparent_temperature&forecast_days=1&timezone=auto';
  return fetch(url).then(function(response) { return response.json(); }).then(function(data) {
    var now = new Date();
    var resultTemp = [], resultHumidity = [], resultApparent = [], resultTime = [];
    for (var step = 0; step <= 12; step++) {
      var targetTime = new Date(now.getTime() + step * 30 * 60 * 1000);
      var beforeIndex = 0;
      for (var i = 0; i < data.hourly.time.length - 1; i++) {
        var t1 = new Date(data.hourly.time[i]);
        var t2 = new Date(data.hourly.time[i + 1]);
        if (targetTime >= t1 && targetTime <= t2) { beforeIndex = i; break; }
      }
      var t1 = new Date(data.hourly.time[beforeIndex]);
      var t2 = new Date(data.hourly.time[beforeIndex + 1]);
      var ratio = (targetTime - t1) / (t2 - t1);
      resultTime.push(targetTime);
      resultTemp.push(Number((data.hourly.temperature_2m[beforeIndex] + (data.hourly.temperature_2m[beforeIndex + 1] - data.hourly.temperature_2m[beforeIndex]) * ratio).toFixed(1)));
      resultHumidity.push(Math.round(data.hourly.relative_humidity_2m[beforeIndex] + (data.hourly.relative_humidity_2m[beforeIndex + 1] - data.hourly.relative_humidity_2m[beforeIndex]) * ratio));
      resultApparent.push(Number((data.hourly.apparent_temperature[beforeIndex] + (data.hourly.apparent_temperature[beforeIndex + 1] - data.hourly.apparent_temperature[beforeIndex]) * ratio).toFixed(1)));
    }
    cachedWeather = { temperature: resultTemp, humidity: resultHumidity, apparent_temperature: resultApparent, time: resultTime };
    forecastNames = resultTime.map(function(t) { return t.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }); });
    document.getElementById('forecastSlider').max = forecastNames.length - 1;
    return cachedWeather;
  });
}

function getLocationName(lat, lon) {
  var url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=' + lat + '&lon=' + lon + '&zoom=18&addressdetails=1&accept-language=en';
  return fetch(url, { headers: { "User-Agent": "AI-Heat-Risk-Demo/1.0" } }).then(function(response) { return response.json(); }).then(function(data) {
    return data.display_name || lat.toFixed(4) + ', ' + lon.toFixed(4);
  });
}

function calculateRiskScore(temp) {
  if (temp >= 35) return 95;
  if (temp >= 32) return 85;
  if (temp >= 30) return 75;
  if (temp >= 28) return 60;
  if (temp >= 25) return 45;
  if (temp >= 22) return 30;
  return 15;
}

function updateWarningCard(riskLevel, riskScore, location, temp, humidity, feelsLike) {
  var card = document.getElementById('warningCard');
  var icon = document.getElementById('warningIcon');
  var title = document.getElementById('warningTitle');
  var message = document.getElementById('warningMessage');
  var details = document.getElementById('warningDetails');
  var locationSpan = document.getElementById('warningLocation');
  var riskBadge = document.getElementById('riskBadge');
  
  card.className = 'warning-card';
  var fullMessage = '', fullDetails = '';
  
  if (riskLevel === 'DANGER') {
    card.classList.add('danger');
    icon.innerHTML = '🔥';
    title.innerHTML = 'DANGER - Extreme Heat Risk!';
    fullMessage = '⚠️ AVOID outdoor exposure! Stay indoors if possible.';
    fullDetails = '📍 Current: ' + temp + '°C (Feels like ' + feelsLike + '°C) | Humidity: ' + humidity + '%\n\n🚨 SAFETY MEASURES:\n• Stay in air-conditioned spaces\n• Drink water every 15-20 minutes\n• Apply sunscreen SPF 50+\n• Wear light clothing\n• Avoid sun 11am-4pm';
  } else if (riskLevel === 'ALERT') {
    card.classList.add('alert');
    icon.innerHTML = '⚠️';
    title.innerHTML = 'ALERT - High Heat Risk';
    fullMessage = '⚠️ Take precautions! Limit outdoor exposure.';
    fullDetails = '📍 Current: ' + temp + '°C (Feels like ' + feelsLike + '°C) | Humidity: ' + humidity + '%\n\n🛡️ PRECAUTIONS:\n• Stay hydrated\n• Use sunscreen SPF 30+\n• Take umbrella or hat\n• Take breaks in shade';
  } else {
    card.classList.add('safe');
    icon.innerHTML = '✅';
    title.innerHTML = 'SAFE - Low Heat Risk';
    fullMessage = '✅ Conditions are favorable for outdoor activities.';
    fullDetails = '📍 Current: ' + temp + '°C (Feels like ' + feelsLike + '°C) | Humidity: ' + humidity + '%\n\n💧 HEALTHY TIPS:\n• Drink water regularly\n• Use basic sun protection\n• Enjoy outdoor activities';
  }
  message.innerHTML = fullMessage;
  details.innerHTML = fullDetails.replace(/\\n/g, '<br>');
  locationSpan.innerHTML = location || '--';
  riskBadge.innerHTML = 'Risk Score: ' + riskScore + '/100 | Level: ' + riskLevel;
}

function updateAgents(loading) {
  var agents = [
    { name: '🌡️ Heat Sensor', status: loading ? 'Scanning...' : 'Active' },
    { name: '🗺️ Street Scanner', status: loading ? 'Analyzing...' : 'Ready' },
    { name: '⚖️ Risk Calculator', status: loading ? 'Computing...' : 'Online' },
    { name: '🔔 Alert Agent', status: loading ? 'Preparing...' : 'Monitoring' }
  ];
  var html = '';
  for (var i = 0; i < agents.length; i++) {
    var agent = agents[i];
    html += '<div class="agent-card' + (loading ? ' active' : '') + '">' +
      '<div class="agent-name">' + agent.name + '</div>' +
      '<div class="agent-status">' + agent.status + '</div>' +
      '<div class="agent-dot"></div></div>';
  }
  document.getElementById('agentsGrid').innerHTML = html;
}

function refreshHeatMap() {
  updateAgents(true);
  document.getElementById('resultsContent').innerHTML = '<div class="loading">🌍 Getting your location...</div>';
  
  navigator.geolocation.getCurrentPosition(
    function(position) {
      currentLat = position.coords.latitude;
      currentLon = position.coords.longitude;
      initHeatMap(currentLat, currentLon);
      
      fetchWeather(currentLat, currentLon).then(function() {
        return getLocationName(currentLat, currentLon);
      }).then(function(locationName) {
        var shortName = locationName.split(',').slice(0, 2).join(',');
        var temp = cachedWeather.temperature[0];
        var humidity = cachedWeather.humidity[0];
        var feelsLike = cachedWeather.apparent_temperature[0];
        var riskScore = calculateRiskScore(temp);
        var riskLevel = riskScore >= 70 ? 'DANGER' : (riskScore >= 40 ? 'ALERT' : 'SAFE');
        
        document.getElementById('locationAddress').innerHTML = locationName;
        document.getElementById('locationCoords').innerHTML = currentLat.toFixed(6) + '°, ' + currentLon.toFixed(6) + '°';
        document.getElementById('tempValue').innerHTML = temp + '°C';
        document.getElementById('humidityValue').innerHTML = humidity + '%';
        document.getElementById('feelsLikeValue').innerHTML = feelsLike + '°C';
        
        updateWarningCard(riskLevel, riskScore, shortName, temp, humidity, feelsLike);
        updateUserCircle(currentLat, currentLon);
        document.getElementById('resultsContent').innerHTML = '<div class="loading success">✅ Data refreshed successfully<br>Temperature: ' + temp + '°C | Risk: ' + riskLevel + '</div>';
        updateAgents(false);
      });
    },
    function(error) {
      document.getElementById('resultsContent').innerHTML = '<div class="loading error">❌ Location access denied. Please enable location services.</div>';
      updateAgents(false);
    }
  );
}

function updateForecast(value) {
  currentForecast = parseInt(value);
  document.getElementById('forecastValue').innerText = forecastNames[currentForecast];
  if (currentLat && cachedWeather) {
    var temp = cachedWeather.temperature[currentForecast];
    var humidity = cachedWeather.humidity[currentForecast];
    var feelsLike = cachedWeather.apparent_temperature[currentForecast];
    var riskScore = calculateRiskScore(temp);
    var riskLevel = riskScore >= 70 ? 'DANGER' : (riskScore >= 40 ? 'ALERT' : 'SAFE');
    updateWarningCard(riskLevel, riskScore, document.getElementById('warningLocation').innerText, temp, humidity, feelsLike);
    updateUserCircle(currentLat, currentLon);
  }
}

function searchDestination() {
  var query = document.getElementById('destinationInput').value.trim();
  if (!query) return;
  
  var suggestionsDiv = document.getElementById('suggestions');
  suggestionsDiv.classList.remove('hidden');
  suggestionsDiv.innerHTML = '<div class="loading">Searching...</div>';
  
  var url = 'https://nominatim.openstreetmap.org/search?format=json&q=' + encodeURIComponent(query) + '&limit=5&accept-language=en';
  fetch(url, { headers: { "User-Agent": "AI-Heat-Risk-Demo/1.0" } })
    .then(function(response) { return response.json(); })
    .then(function(data) {
      if (data.length === 0) {
        suggestionsDiv.innerHTML = '<div class="suggestion-item">No results found</div>';
        return;
      }
      var html = '';
      for (var i = 0; i < data.length; i++) {
        var place = data[i];
        var escapedName = place.display_name.replace(/'/g, "\\'");
        html += '<div class="suggestion-item" onclick="selectDestination(' + place.lat + ', ' + place.lon + ', \'' + escapedName + '\')">' +
          '<strong>' + place.display_name.split(',')[0] + '</strong><br>' +
          '<small>' + place.display_name + '</small></div>';
      }
      suggestionsDiv.innerHTML = html;
    });
}

function selectDestination(lat, lon, name) {
  destinationLat = parseFloat(lat);
  destinationLon = parseFloat(lon);
  document.getElementById('destinationInput').value = name.split(',')[0];
  document.getElementById('suggestions').classList.add('hidden');
  document.getElementById('planRouteBtn').style.display = 'block';
  
  if (window.destMarker) routeMap.removeLayer(window.destMarker);
  window.destMarker = L.marker([destinationLat, destinationLon]).addTo(routeMap).bindPopup('<b>Destination</b><br>' + name);
}

function planRoutes() {
  if (!currentLat || !currentLon || !destinationLat || !destinationLon) {
    alert('Please wait for location and select a destination');
    return;
  }
  
  var baseTemp = cachedWeather ? cachedWeather.temperature[currentForecast] : 28;
  var routes = [
    { name: '🚶 Direct Route', distance: '1.2 km', time: '15 min', heatScore: baseTemp + 2 },
    { name: '🌳 Shaded Route', distance: '1.5 km', time: '19 min', heatScore: baseTemp - 2 },
    { name: '🏞️ Park Route', distance: '1.8 km', time: '22 min', heatScore: baseTemp - 4 }
  ];
  
  for (var i = 0; i < routes.length; i++) {
    var hs = routes[i].heatScore;
    routes[i].risk = hs >= 32 ? 'DANGER' : (hs >= 27 ? 'ALERT' : 'SAFE');
  }
  routes[2].isBest = true;
  
  var html = '';
  for (var i = 0; i < routes.length; i++) {
    var route = routes[i];
    var isBest = route.isBest || false;
    var bestBadge = isBest ? '🏆 BEST ROUTE - ' : '';
    var heatColor = route.risk === 'DANGER' ? '#ff4b4b' : (route.risk === 'ALERT' ? '#ffa500' : '#4caf50');
    html += '<div class="route-card ' + (isBest ? 'best' : '') + '" onclick="selectRouteOption(' + i + ')">' +
      '<div class="route-name">' + bestBadge + route.name + '</div>' +
      '<div class="route-stats"><span>📏 ' + route.distance + '</span><span>⏱️ ' + route.time + '</span>' +
      '<span class="route-heat" style="color:' + heatColor + '">🌡️ ' + route.heatScore + '°C avg</span></div>' +
      '<div class="route-stats"><span>⚠️ Risk: ' + route.risk + '</span></div></div>';
  }
  
  html += '<div class="route-card" style="background:#e8f4f8; margin-top:10px;">' +
    '<div class="route-name">💡 Heat Safety Tips</div>' +
    '<div class="route-stats">• Walk on shaded side of street</div>' +
    '<div class="route-stats">• Carry water and umbrella</div>' +
    '<div class="route-stats">• Take breaks in cool spots</div></div>';
  
  document.getElementById('routeResultsContent').innerHTML = html;
  
  if (currentLat && destinationLat) {
    var bounds = L.latLngBounds([[currentLat, currentLon], [destinationLat, destinationLon]]);
    routeMap.fitBounds(bounds, { padding: [50, 50] });
  }
}

function selectRouteOption(routeIndex) {
  var routeCards = document.querySelectorAll('.route-card');
  for (var i = 0; i < routeCards.length; i++) {
    if (i === routeIndex) routeCards[i].style.border = '3px solid #ff7e5f';
    else routeCards[i].style.border = '2px solid transparent';
  }
}

window.onload = function() {
  updateAgents(false);
  navigator.geolocation.getCurrentPosition(
    function(position) {
      currentLat = position.coords.latitude;
      currentLon = position.coords.longitude;
      initHeatMap(currentLat, currentLon);
      initRouteMap(currentLat, currentLon);
      refreshHeatMap();
    },
    function() {
      initHeatMap(40.7128, -74.0060);
      initRouteMap(40.7128, -74.0060);
      refreshHeatMap();
    }
  );
};
</script>
</body>
</html>
""";
}
