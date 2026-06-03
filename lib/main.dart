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

const String _html = r'''
<!DOCTYPE html>
<html>
<head>
  <title>AI Heat Risk Warning</title>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes">

  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">

  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: 'Inter', sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
    }

    /* Custom Scrollbar */
    ::-webkit-scrollbar {
      width: 6px;
    }

    ::-webkit-scrollbar-track {
      background: #f1f1f1;
      border-radius: 10px;
    }

    ::-webkit-scrollbar-thumb {
      background: #ff7e5f;
      border-radius: 10px;
    }

    /* Main Container */
    .app-container {
      max-width: 550px;
      margin: 0 auto;
      padding: 16px;
      padding-bottom: 30px;
    }

    /* Header Section */
    .header {
      background: rgba(255,255,255,0.95);
      border-radius: 28px;
      padding: 20px;
      margin-bottom: 16px;
      box-shadow: 0 20px 35px -10px rgba(0,0,0,0.2);
      backdrop-filter: blur(10px);
    }

    .header h1 {
      font-size: 28px;
      font-weight: 800;
      background: linear-gradient(135deg, #ff6b6b, #ff8e53);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
      margin-bottom: 4px;
    }

    .header p {
      color: #666;
      font-size: 13px;
      font-weight: 500;
    }

    /* Blinking Warning Card */
    .warning-card {
      background: linear-gradient(135deg, #1a1a2e, #16213e);
      border-radius: 20px;
      padding: 18px;
      margin-bottom: 16px;
      position: relative;
      overflow: hidden;
      cursor: pointer;
      transition: transform 0.3s ease;
    }

    .warning-card:hover {
      transform: translateY(-2px);
    }

    .warning-card.blinking {
      animation: pulseGlow 1.5s ease-in-out infinite;
    }

    @keyframes pulseGlow {
      0%, 100% {
        box-shadow: 0 0 0 0 rgba(255, 107, 107, 0.7);
        border-left: 4px solid #ff6b6b;
      }
      50% {
        box-shadow: 0 0 0 12px rgba(255, 107, 107, 0);
        border-left: 4px solid #ffd93d;
      }
    }

    .warning-card.safe {
      background: linear-gradient(135deg, #1b4332, #2d6a4f);
    }

    .warning-card.alert {
      background: linear-gradient(135deg, #e85d04, #f48c06);
    }

    .warning-card.danger {
      background: linear-gradient(135deg, #9d0208, #dc2f02);
      animation: pulseGlow 1s ease-in-out infinite;
    }

    .warning-header {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 12px;
    }

    .warning-icon {
      font-size: 32px;
    }

    .warning-title {
      font-size: 20px;
      font-weight: 800;
      color: white;
    }

    .warning-message {
      color: rgba(255,255,255,0.95);
      font-size: 14px;
      line-height: 1.5;
      margin-bottom: 10px;
    }

    .warning-location {
      color: rgba(255,255,255,0.8);
      font-size: 12px;
      display: flex;
      align-items: center;
      gap: 6px;
    }

    .risk-badge {
      display: inline-block;
      background: rgba(255,255,255,0.2);
      border-radius: 20px;
      padding: 4px 12px;
      font-size: 13px;
      font-weight: 600;
      color: white;
      margin-top: 8px;
    }

    /* Map Container */
    .map-section {
      background: rgba(255,255,255,0.95);
      border-radius: 24px;
      padding: 12px;
      margin-bottom: 16px;
      box-shadow: 0 10px 30px rgba(0,0,0,0.15);
    }

    .map-title {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;
      padding: 0 8px;
    }

    .map-title h3 {
      font-size: 16px;
      font-weight: 700;
      color: #333;
    }

    .map-buttons {
      display: flex;
      gap: 8px;
    }

    .mode-btn {
      padding: 6px 14px;
      border: none;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s ease;
      background: #f0f0f0;
      color: #666;
    }

    .mode-btn.active {
      background: #ff7e5f;
      color: white;
    }

    #map {
      height: 380px;
      border-radius: 20px;
      overflow: hidden;
      box-shadow: 0 4px 15px rgba(0,0,0,0.1);
    }

    /* Control Panel */
    .control-panel {
      background: rgba(255,255,255,0.95);
      border-radius: 24px;
      padding: 16px;
      margin-bottom: 16px;
      box-shadow: 0 10px 30px rgba(0,0,0,0.15);
    }

    .slider-container {
      margin-bottom: 16px;
    }

    .slider-label {
      display: flex;
      justify-content: space-between;
      margin-bottom: 8px;
      font-size: 13px;
      font-weight: 600;
      color: #555;
    }

    input[type="range"] {
      width: 100%;
      height: 6px;
      border-radius: 10px;
      background: linear-gradient(90deg, #4caf50, #ffa500, #ff4b4b);
      -webkit-appearance: none;
    }

    input[type="range"]:focus {
      outline: none;
    }

    input[type="range"]::-webkit-slider-thumb {
      -webkit-appearance: none;
      width: 20px;
      height: 20px;
      border-radius: 50%;
      background: #ff7e5f;
      cursor: pointer;
      box-shadow: 0 2px 8px rgba(0,0,0,0.2);
      border: 2px solid white;
    }

    #forecastValue {
      font-weight: 700;
      color: #ff7e5f;
    }

    /* Location Card */
    .location-card {
      background: #f8f9fa;
      border-radius: 16px;
      padding: 14px;
      margin-bottom: 16px;
    }

    .location-card h4 {
      font-size: 13px;
      color: #888;
      margin-bottom: 8px;
    }

    .location-name {
      font-size: 15px;
      font-weight: 600;
      color: #333;
      word-break: break-word;
    }

    /* Destination Search */
    .destination-card {
      background: white;
      border-radius: 16px;
      padding: 14px;
      margin-bottom: 16px;
      border: 1px solid #e0e0e0;
    }

    .search-box {
      display: flex;
      gap: 10px;
      margin-bottom: 12px;
    }

    .search-input {
      flex: 1;
      padding: 12px 16px;
      border: 1px solid #ddd;
      border-radius: 25px;
      font-size: 14px;
      outline: none;
      transition: all 0.2s;
    }

    .search-input:focus {
      border-color: #ff7e5f;
      box-shadow: 0 0 0 2px rgba(255,126,95,0.2);
    }

    .search-btn, .route-btn {
      padding: 10px 20px;
      background: #ff7e5f;
      color: white;
      border: none;
      border-radius: 25px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
    }

    .search-btn:hover, .route-btn:hover {
      background: #feb47b;
      transform: translateY(-1px);
    }

    .route-btn {
      width: 100%;
      margin-top: 10px;
      background: linear-gradient(135deg, #667eea, #764ba2);
    }

    .suggestions {
      max-height: 200px;
      overflow-y: auto;
      background: white;
      border-radius: 12px;
      margin-top: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    }

    .suggestion-item {
      padding: 12px 16px;
      border-bottom: 1px solid #eee;
      cursor: pointer;
      transition: background 0.2s;
    }

    .suggestion-item:hover {
      background: #f5f5f5;
    }

    /* Agents Grid */
    .agents-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 10px;
      margin-top: 12px;
    }

    .agent-card {
      background: linear-gradient(135deg, #f5f7fa, #c3cfe2);
      padding: 12px;
      border-radius: 14px;
      position: relative;
      transition: all 0.3s ease;
    }

    .agent-card.active {
      background: linear-gradient(135deg, #ff7e5f, #feb47b);
      color: white;
      transform: scale(1.02);
    }

    .agent-name {
      font-weight: 700;
      font-size: 12px;
      margin-bottom: 4px;
    }

    .agent-status {
      font-size: 10px;
      opacity: 0.8;
    }

    .agent-dot {
      position: absolute;
      top: 10px;
      right: 10px;
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #4caf50;
      animation: blink 1s infinite;
    }

    @keyframes blink {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.3; }
    }

    /* Results */
    .results-container {
      background: rgba(255,255,255,0.95);
      border-radius: 24px;
      padding: 16px;
      margin-top: 16px;
    }

    .results-container h3 {
      font-size: 16px;
      margin-bottom: 12px;
      color: #333;
    }

    .street-card {
      background: white;
      border-radius: 14px;
      padding: 14px;
      margin-bottom: 10px;
      border-left: 5px solid;
      box-shadow: 0 2px 8px rgba(0,0,0,0.05);
      transition: transform 0.2s;
    }

    .street-card:hover {
      transform: translateX(4px);
    }

    .street-card.DANGER { border-color: #ff4b4b; }
    .street-card.ALERT { border-color: #ffa500; }
    .street-card.SAFE { border-color: #4caf50; }

    .street-name {
      font-weight: 700;
      font-size: 15px;
      margin-bottom: 6px;
    }

    .street-details {
      font-size: 12px;
      color: #666;
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      margin-top: 6px;
    }

    .route-info {
      background: #e8f4f8;
      border-radius: 12px;
      padding: 12px;
      margin-top: 10px;
    }

    .best-route {
      background: linear-gradient(135deg, #2ecc71, #27ae60);
      color: white;
      padding: 12px;
      border-radius: 12px;
      margin-top: 10px;
      font-weight: 600;
    }

    .hidden {
      display: none;
    }

    .loading {
      text-align: center;
      padding: 20px;
      color: #888;
    }
  </style>

  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/leaflet-color-markers@1.2.0/js/leaflet-color-markers.min.js"></script>
</head>

<body>
<div class="app-container">
  <!-- Header -->
  <div class="header">
    <h1>🌡️ AI Heat Risk</h1>
    <p>Real-time thermal mapping & intelligent route planning</p>
  </div>

  <!-- Blinking Warning Card -->
  <div id="warningCard" class="warning-card blinking safe" onclick="refreshRisk()">
    <div class="warning-header">
      <span class="warning-icon" id="warningIcon">✅</span>
      <span class="warning-title" id="warningTitle">Safe Zone</span>
    </div>
    <div class="warning-message" id="warningMessage">
      Tap to check your current heat risk level
    </div>
    <div class="warning-location">
      <span>📍</span>
      <span id="warningLocation">--</span>
    </div>
    <div class="risk-badge" id="riskBadge">Risk Score: --</div>
  </div>

  <!-- Map Section -->
  <div class="map-section">
    <div class="map-title">
      <h3>🗺️ Heat Map</h3>
      <div class="map-buttons">
        <button class="mode-btn active" id="nearbyBtn" onclick="setMapMode('nearby')">Nearby</button>
        <button class="mode-btn" id="routesBtn" onclick="setMapMode('routes')">Routes</button>
      </div>
    </div>
    <div id="map"></div>
  </div>

  <!-- Control Panel -->
  <div class="control-panel">
    <div class="slider-container">
      <div class="slider-label">
        <span>⏰ Forecast Time</span>
        <span id="forecastValue">Now</span>
      </div>
      <input type="range" id="forecastSlider" min="0" max="12" value="0" oninput="updateForecast(this.value)">
    </div>

    <button class="search-btn" style="width:100%; margin-top:5px;" onclick="refreshRisk()">
      🔄 Refresh Data
    </button>
  </div>

  <!-- Location Info -->
  <div class="location-card">
    <h4>📍 CURRENT LOCATION</h4>
    <div class="location-name" id="locationName">Tap refresh to get location</div>
  </div>

  <!-- Destination Search (for route mode) -->
  <div class="destination-card" id="destinationCard">
    <h4 style="margin-bottom:10px;">🎯 Plan a Cool Route</h4>
    <div class="search-box">
      <input type="text" class="search-input" id="destinationInput" placeholder="Enter destination (e.g., Central Park, Times Square)">
      <button class="search-btn" onclick="searchLocation()">Search</button>
    </div>
    <div id="suggestions" class="suggestions hidden"></div>
    <button class="route-btn" id="findRouteBtn" onclick="findCoolRoutes()" style="display:none;">🌿 Find Coolest Routes</button>
  </div>

  <!-- AI Agents -->
  <div class="control-panel">
    <h4 style="margin-bottom:12px;">🤖 AI Agent Network</h4>
    <div class="agents-grid" id="agentsGrid"></div>
  </div>

  <!-- Results -->
  <div class="results-container" id="resultsContainer">
    <h3>📊 Street Heat Analysis</h3>
    <div id="resultsContent">Waiting for location data...</div>
  </div>
</div>

<script>
// Global variables
let map, userMarker, userCircle, heatLayer;
let currentMode = 'nearby';
let currentLat = null, currentLon = null;
let destinationLat = null, destinationLon = null;
let destinationName = '';
let cachedWeather = null;
let currentForecast = 0;
let forecastNames = [];
let streetMarkers = [];
let routeMarkers = [];
let currentRoutes = [];

// Initialize map
function initMap(lat, lon) {
  if (!map) {
    map = L.map("map").setView([lat, lon], 14);
    
    // Base tile layer with English labels
    L.tileLayer("https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png", {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; CartoDB',
      subdomains: 'abcd',
      maxZoom: 19,
      minZoom: 3
    }).addTo(map);
  } else {
    map.setView([lat, lon], 14);
  }
  
  // Update or create user marker with colored circle
  if (userMarker) {
    userMarker.setLatLng([lat, lon]);
  } else {
    userMarker = L.marker([lat, lon], {
      icon: L.divIcon({
        className: 'custom-div-icon',
        html: '<div style="background-color:#ff7e5f; width:20px; height:20px; border-radius:50%; border:3px solid white; box-shadow:0 0 10px rgba(0,0,0,0.3);"></div>',
        iconSize: [20, 20],
        popupAnchor: [0, -10]
      })
    }).addTo(map).bindPopup('<b>You are here</b><br>Tap refresh for heat data');
  }
  
  // Add colored circle around user based on risk
  updateUserCircle(lat, lon);
}

function updateUserCircle(lat, lon) {
  if (userCircle) map.removeLayer(userCircle);
  
  // Get current risk level for user
  let color = '#4caf50'; // default green
  let radius = 80;
  
  if (cachedWeather) {
    const temp = cachedWeather.temperature[currentForecast];
    const risk = calculateRiskScore(temp);
    if (risk >= 70) color = '#ff4b4b';
    else if (risk >= 40) color = '#ffa500';
    else color = '#4caf50';
    radius = 60 + (risk / 2);
  }
  
  userCircle = L.circle([lat, lon], {
    radius: radius,
    color: color,
    fillColor: color,
    fillOpacity: 0.3,
    weight: 2,
    opacity: 0.8
  }).addTo(map).bindPopup('Your heat zone');
}

// Calculate risk score from temperature
function calculateRiskScore(temp) {
  if (temp >= 35) return 90;
  if (temp >= 30) return 70;
  if (temp >= 25) return 45;
  if (temp >= 20) return 25;
  return 10;
}

// Get color for temperature
function getTempColor(temp) {
  if (temp >= 35) return '#d73027';
  if (temp >= 30) return '#fc8d59';
  if (temp >= 25) return '#fee08b';
  if (temp >= 20) return '#d9ef8b';
  return '#a6d96a';
}

// Update heat overlay on map
function updateHeatOverlay() {
  if (heatLayer) map.removeLayer(heatLayer);
  
  if (!currentLat || !currentLon || !cachedWeather) return;
  
  const temp = cachedWeather.temperature[currentForecast];
  const radius = 300;
  
  heatLayer = L.circle([currentLat, currentLon], {
    radius: radius,
    color: getTempColor(temp),
    fillColor: getTempColor(temp),
    fillOpacity: 0.4,
    weight: 1,
    opacity: 0.6
  }).addTo(map);
  
  // Add surrounding heat points
  const offsets = [[0.003, 0], [-0.003, 0], [0, 0.003], [0, -0.003], [0.002, 0.002], [-0.002, -0.002]];
  offsets.forEach(offset => {
    const heatCircle = L.circle([currentLat + offset[0], currentLon + offset[1]], {
      radius: radius * 0.7,
      color: getTempColor(temp - 2),
      fillColor: getTempColor(temp - 2),
      fillOpacity: 0.3,
      weight: 0
    }).addTo(map);
    // Store for cleanup
    if (!window.heatCircles) window.heatCircles = [];
    window.heatCircles.push(heatCircle);
  });
}

// Update warning card with blinking effect
function updateWarningCard(riskLevel, riskScore, location, message) {
  const card = document.getElementById('warningCard');
  const icon = document.getElementById('warningIcon');
  const title = document.getElementById('warningTitle');
  const warningMsg = document.getElementById('warningMessage');
  const locationSpan = document.getElementById('warningLocation');
  const riskBadge = document.getElementById('riskBadge');
  
  // Reset classes
  card.className = 'warning-card';
  
  if (riskLevel === 'DANGER') {
    card.classList.add('danger');
    icon.innerHTML = '🔥';
    title.innerHTML = 'DANGER - High Heat Risk';
    warningMsg.innerHTML = message || '⚠️ Avoid outdoor exposure! Stay hydrated, seek shade.';
  } else if (riskLevel === 'ALERT') {
    card.classList.add('alert');
    icon.innerHTML = '⚠️';
    title.innerHTML = 'ALERT - Moderate Heat Risk';
    warningMsg.innerHTML = message || 'Take precautions, use sunscreen, limit sun exposure.';
  } else {
    card.classList.add('safe');
    icon.innerHTML = '✅';
    title.innerHTML = 'SAFE - Low Heat Risk';
    warningMsg.innerHTML = message || 'Conditions are favorable. Stay hydrated.';
  }
  
  locationSpan.innerHTML = location || '--';
  riskBadge.innerHTML = `Risk Score: ${riskScore}/100`;
  
  // Add blinking effect for danger
  if (riskLevel === 'DANGER') {
    card.style.animation = 'pulseGlow 1s ease-in-out infinite';
  } else {
    card.style.animation = '';
  }
}

// Fetch weather data
async function fetchWeather(lat, lon) {
  const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&hourly=temperature_2m,relative_humidity_2m,apparent_temperature&forecast_days=1&timezone=auto`;
  const response = await fetch(url);
  const data = await response.json();
  
  const now = new Date();
  const resultTemp = [];
  const resultHumidity = [];
  const resultApparent = [];
  const resultTime = [];
  
  for (let step = 0; step <= 12; step++) {
    const targetTime = new Date(now.getTime() + step * 30 * 60 * 1000);
    let beforeIndex = 0;
    
    for (let i = 0; i < data.hourly.time.length - 1; i++) {
      const t1 = new Date(data.hourly.time[i]);
      const t2 = new Date(data.hourly.time[i + 1]);
      if (targetTime >= t1 && targetTime <= t2) {
        beforeIndex = i;
        break;
      }
    }
    
    const t1 = new Date(data.hourly.time[beforeIndex]);
    const t2 = new Date(data.hourly.time[beforeIndex + 1]);
    const ratio = (targetTime - t1) / (t2 - t1);
    
    resultTime.push(targetTime);
    resultTemp.push(Number((data.hourly.temperature_2m[beforeIndex] + 
      (data.hourly.temperature_2m[beforeIndex + 1] - data.hourly.temperature_2m[beforeIndex]) * ratio).toFixed(1)));
    resultHumidity.push(Math.round(data.hourly.relative_humidity_2m[beforeIndex] + 
      (data.hourly.relative_humidity_2m[beforeIndex + 1] - data.hourly.relative_humidity_2m[beforeIndex]) * ratio));
    resultApparent.push(Number((data.hourly.apparent_temperature[beforeIndex] + 
      (data.hourly.apparent_temperature[beforeIndex + 1] - data.hourly.apparent_temperature[beforeIndex]) * ratio).toFixed(1)));
  }
  
  cachedWeather = {
    temperature: resultTemp,
    humidity: resultHumidity,
    apparent_temperature: resultApparent,
    time: resultTime
  };
  
  forecastNames = resultTime.map(t => {
    return t.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  });
  
  document.getElementById('forecastSlider').max = forecastNames.length - 1;
  document.getElementById('forecastValue').innerText = forecastNames[0];
}

// Get location name from coordinates
async function getLocationName(lat, lon) {
  const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lon}&zoom=18&addressdetails=1&accept-language=en`;
  const response = await fetch(url, {
    headers: { "User-Agent": "AI-Heat-Risk-Demo/1.0" }
  });
  const data = await response.json();
  return data.display_name || `${lat.toFixed(4)}, ${lon.toFixed(4)}`;
}

// Search for location
async function searchLocation() {
  const query = document.getElementById('destinationInput').value.trim();
  if (!query) return;
  
  const suggestionsDiv = document.getElementById('suggestions');
  suggestionsDiv.classList.remove('hidden');
  suggestionsDiv.innerHTML = '<div class="loading">Searching...</div>';
  
  const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=5&accept-language=en`;
  const response = await fetch(url, {
    headers: { "User-Agent": "AI-Heat-Risk-Demo/1.0" }
  });
  const data = await response.json();
  
  if (data.length === 0) {
    suggestionsDiv.innerHTML = '<div class="suggestion-item">No results found</div>';
    return;
  }
  
  suggestionsDiv.innerHTML = data.map(place => `
    <div class="suggestion-item" onclick="selectDestination('${place.lat}', '${place.lon}', '${place.display_name.replace(/'/g, "\\'")}')">
      <strong>${place.display_name.split(',')[0]}</strong><br>
      <small>${place.display_name}</small>
    </div>
  `).join('');
}

function selectDestination(lat, lon, name) {
  destinationLat = parseFloat(lat);
  destinationLon = parseFloat(lon);
  destinationName = name;
  
  document.getElementById('destinationInput').value = name.split(',')[0];
  document.getElementById('suggestions').classList.add('hidden');
  document.getElementById('findRouteBtn').style.display = 'block';
  
  // Show destination marker
  if (window.destMarker) map.removeLayer(window.destMarker);
  window.destMarker = L.marker([destinationLat, destinationLon], {
    icon: L.divIcon({
      className: 'custom-div-icon',
      html: '<div style="background-color:#667eea; width:16px; height:16px; border-radius:50%; border:2px solid white;"></div>',
      iconSize: [16, 16]
    })
  }).addTo(map).bindPopup(`<b>Destination</b><br>${name}`);
}

// Find cool routes
async function findCoolRoutes() {
  if (!currentLat || !currentLon || !destinationLat || !destinationLon) {
    alert('Please set both current location and destination');
    return;
  }
  
  document.getElementById('resultsContent').innerHTML = '<div class="loading">🌿 Finding coolest routes...</div>';
  
  // Generate 3 different routes
  const routes = generateRoutes();
  currentRoutes = routes;
  
  // Display route options
  displayRouteOptions(routes);
}

function generateRoutes() {
  // Calculate direct route and two alternatives
  const midLat = (currentLat + destinationLat) / 2;
  const midLon = (currentLon + destinationLon) / 2;
  const dx = destinationLon - currentLon;
  const dy = destinationLat - currentLat;
  
  const routes = [];
  
  // Route 1: Direct
  routes.push({
    name: '🚶 Direct Route',
    points: [currentLat, currentLon, destinationLat, destinationLon],
    description: 'Shortest path but may have more sun exposure',
    type: 'direct'
  });
  
  // Route 2: Shaded (north)
  const offset = 0.008;
  const northPoint = [midLat + offset, midLon];
  routes.push({
    name: '🌳 Shaded Route',
    points: [currentLat, currentLon, northPoint[0], northPoint[1], destinationLat, destinationLon],
    description: 'Passes through potential shaded areas',
    type: 'shaded'
  });
  
  // Route 3: Park route
  const parkPoint = [midLat - offset * 0.5, midLon + offset * 0.7];
  routes.push({
    name: '🏞️ Park Route',
    points: [currentLat, currentLon, parkPoint[0], parkPoint[1], destinationLat, destinationLon],
    description: 'Goes through greener areas with trees',
    type: 'park'
  });
  
  // Calculate heat scores for each route
  routes.forEach(route => {
    let totalTemp = 0;
    const steps = Math.floor(route.points.length / 2);
    for (let i = 0; i < steps; i++) {
      const lat = route.points[i * 2];
      const lon = route.points[i * 2 + 1];
      // Estimate temperature based on position and current temp
      const baseTemp = cachedWeather ? cachedWeather.temperature[currentForecast] : 25;
      // Add random variation based on position (more shade = cooler)
      const variation = route.type === 'shaded' ? -3 : (route.type === 'park' ? -2 : 1);
      totalTemp += baseTemp + variation;
    }
    route.heatScore = Math.round(totalTemp / steps);
    route.riskLevel = route.heatScore >= 32 ? 'DANGER' : (route.heatScore >= 27 ? 'ALERT' : 'SAFE');
    route.riskColor = route.riskLevel === 'DANGER' ? '#ff4b4b' : (route.riskLevel === 'ALERT' ? '#ffa500' : '#4caf50');
  });
  
  // Find best route (lowest heat score)
  routes.sort((a, b) => a.heatScore - b.heatScore);
  routes[0].isBest = true;
  
  return routes;
}

function displayRouteOptions(routes) {
  let html = '<div class="route-info"><strong>🎯 Recommended Routes</strong><br><small>Based on current heat conditions</small></div>';
  
  routes.forEach((route, idx) => {
    const bestTag = route.isBest ? '🏆 BEST CHOICE - ' : '';
    html += `
      <div class="street-card ${route.riskLevel}" style="cursor:pointer;" onclick="showRouteOnMap(${idx})">
        <div class="street-name">${bestTag}${route.name}</div>
        <div class="street-details">
          <span>🌡️ Heat Score: ${route.heatScore}°C</span>
          <span>⚡ Risk: ${route.riskLevel}</span>
        </div>
        <div class="street-details">${route.description}</div>
        <div class="street-details" style="margin-top:6px; color:#ff7e5f;">
          🗺️ Click to view on map
        </div>
      </div>
    `;
  });
  
  // Add best route summary
  const bestRoute = routes[0];
  html += `
    <div class="best-route">
      🌟 ${bestRoute.name}<br>
      <small>Recommended: ${bestRoute.heatScore}°C average - ${bestRoute.riskLevel === 'SAFE' ? 'Safest option' : 'Proceed with caution'}</small>
    </div>
  `;
  
  document.getElementById('resultsContent').innerHTML = html;
}

function showRouteOnMap(routeIndex) {
  const route = currentRoutes[routeIndex];
  if (!route) return;
  
  // Clear previous route markers
  if (window.routeLines) {
    window.routeLines.forEach(line => map.removeLayer(line));
  }
  window.routeLines = [];
  
  // Draw the route
  const points = [];
  for (let i = 0; i < route.points.length; i += 2) {
    points.push([route.points[i], route.points[i + 1]]);
  }
  
  const line = L.polyline(points, {
    color: route.riskColor,
    weight: 5,
    opacity: 0.8,
    dashArray: '10, 10'
  }).addTo(map);
  
  if (!window.routeLines) window.routeLines = [];
  window.routeLines.push(line);
  
  // Fit bounds to show entire route
  const bounds = L.latLngBounds(points);
  map.fitBounds(bounds, { padding: [50, 50] });
  
  // Add animated marker
  if (window.animatedMarker) map.removeLayer(window.animatedMarker);
  window.animatedMarker = L.marker(points[0], {
    icon: L.divIcon({
      className: 'custom-div-icon',
      html: '<div style="background-color:#ff7e5f; width:14px; height:14px; border-radius:50%; border:2px solid white; animation:pulse 1s infinite;"></div>',
      iconSize: [14, 14]
    })
  }).addTo(map).bindPopup('Recommended start');
}

// Fetch nearby streets
async function fetchNearbyStreets(lat, lon) {
  const query = `[out:json][timeout:25];way["highway"](around:500,${lat},${lon});out center tags;`;
  const response = await fetch("https://overpass-api.de/api/interpreter", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", "User-Agent": "AI-Heat-Risk-Demo/1.0" },
    body: "data=" + encodeURIComponent(query)
  });
  const data = await response.json();
  
  const streets = [];
  const seen = new Set();
  
  for (const element of data.elements || []) {
    const tags = element.tags;
    const center = element.center;
    if (!tags || !center) continue;
    
    const name = tags["name:en"] || tags.name || `Unnamed ${tags.highway || 'road'}`;
    const key = `${name}-${center.lat.toFixed(4)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    
    streets.push({
      name: name,
      lat: center.lat,
      lon: center.lon,
      type: tags.highway || 'road',
      surface: getSurfaceType(tags.highway)
    });
    
    if (streets.length >= 15) break;
  }
  
  return streets;
}

function getSurfaceType(highway) {
  const concrete = ["motorway", "trunk", "primary", "secondary"];
  const mixed = ["residential", "tertiary", "living_street"];
  if (concrete.includes(highway)) return "Concrete/Road";
  if (mixed.includes(highway)) return "Mixed Surface";
  return "Natural/Greenery";
}

// Update UI for nearby mode
async function updateNearbyMode() {
  if (!currentLat || !currentLon || !cachedWeather) return;
  
  document.getElementById('resultsContent').innerHTML = '<div class="loading">🌡️ Analyzing nearby streets...</div>';
  updateAgents(true);
  
  const streets = await fetchNearbyStreets(currentLat, currentLon);
  const temp = cachedWeather.temperature[currentForecast];
  const humidity = cachedWeather.humidity[currentForecast];
  
  let html = '';
  
  streets.forEach(street => {
    const surfaceScore = street.surface === "Concrete/Road" ? 30 : (street.surface === "Mixed Surface" ? 18 : 6);
    let riskScore = calculateRiskScore(temp) + surfaceScore;
    riskScore = Math.min(100, riskScore);
    
    let level = riskScore >= 70 ? 'DANGER' : (riskScore >= 40 ? 'ALERT' : 'SAFE');
    let advice = level === 'DANGER' ? 'Avoid this street' : (level === 'ALERT' ? 'Take caution' : 'Safe to walk');
    
    html += `
      <div class="street-card ${level}">
        <div class="street-name">🛣️ ${street.name}</div>
        <div class="street-details">
          <span>🏗️ Type: ${street.type}</span>
          <span>🟤 Surface: ${street.surface}</span>
        </div>
        <div class="street-details">
          <span>🌡️ Temp: ${temp}°C</span>
          <span>💧 Humidity: ${humidity}%</span>
          <span>⚠️ Risk: ${riskScore}/100 (${level})</span>
        </div>
        <div class="street-details">${advice}</div>
      </div>
    `;
    
    // Add to map
    const color = level === 'DANGER' ? '#ff4b4b' : (level === 'ALERT' ? '#ffa500' : '#4caf50');
    const circle = L.circle([street.lat, street.lon], {
      radius: 25 + riskScore / 2,
      color: color,
      fillColor: color,
      fillOpacity: 0.5,
      weight: 2
    }).addTo(map).bindPopup(`<b>${street.name}</b><br>Risk: ${level}<br>Temp: ${temp}°C`);
    
    streetMarkers.push(circle);
  });
  
  if (html === '') html = '<div class="loading">No nearby streets found</div>';
  document.getElementById('resultsContent').innerHTML = html;
  updateAgents(false);
}

// Set map mode
function setMapMode(mode) {
  currentMode = mode;
  
  // Update button styles
  document.getElementById('nearbyBtn').classList.remove('active');
  document.getElementById('routesBtn').classList.remove('active');
  document.getElementById(`${mode}Btn`).classList.add('active');
  
  // Show/hide destination card
  const destCard = document.getElementById('destinationCard');
  if (mode === 'routes') {
    destCard.style.display = 'block';
  } else {
    destCard.style.display = 'none';
    document.getElementById('findRouteBtn').style.display = 'none';
    document.getElementById('suggestions').classList.add('hidden');
  }
  
  // Clear and reload based on mode
  clearMapOverlays();
  if (mode === 'nearby') {
    updateNearbyMode();
  }
}

function clearMapOverlays() {
  streetMarkers.forEach(m => map.removeLayer(m));
  streetMarkers = [];
  if (window.routeLines) {
    window.routeLines.forEach(l => map.removeLayer(l));
    window.routeLines = [];
  }
  if (window.heatCircles) {
    window.heatCircles.forEach(c => map.removeLayer(c));
    window.heatCircles = [];
  }
}

function updateForecast(value) {
  currentForecast = parseInt(value);
  document.getElementById('forecastValue').innerText = forecastNames[currentForecast];
  
  if (currentLat && cachedWeather) {
    updateUserCircle(currentLat, currentLon);
    updateHeatOverlay();
    if (currentMode === 'nearby') updateNearbyMode();
  }
}

// Update AI agents
function updateAgents(loading) {
  const agents = [
    { name: '🌡️ Heat Sensor', status: loading ? 'Scanning...' : 'Active' },
    { name: '🗺️ Surface Scanner', status: loading ? 'Analyzing...' : 'Ready' },
    { name: '👥 People Tracker', status: loading ? 'Tracking...' : 'Monitoring' },
    { name: '⚖️ Risk Calculator', status: loading ? 'Computing...' : 'Online' },
    { name: '🔔 Alert Agent', status: loading ? 'Preparing...' : 'Standby' },
    { name: '🧠 Learning AI', status: loading ? 'Updating...' : 'Optimized' }
  ];
  
  let html = '';
  agents.forEach(agent => {
    html += `
      <div class="agent-card ${loading ? 'active' : ''}">
        <div class="agent-name">${agent.name}</div>
        <div class="agent-status">${agent.status}</div>
        <div class="agent-dot"></div>
      </div>
    `;
  });
  document.getElementById('agentsGrid').innerHTML = html;
}

// Main refresh function
async function refreshRisk() {
  updateAgents(true);
  document.getElementById('resultsContent').innerHTML = '<div class="loading">🌍 Getting your location...</div>';
  document.getElementById('locationName').innerHTML = 'Getting location...';
  
  navigator.geolocation.getCurrentPosition(async function(position) {
    currentLat = position.coords.latitude;
    currentLon = position.coords.longitude;
    
    initMap(currentLat, currentLon);
    
    const locationName = await getLocationName(currentLat, currentLon);
    const shortName = locationName.split(',').slice(0, 2).join(',');
    document.getElementById('locationName').innerHTML = shortName;
    
    await fetchWeather(currentLat, currentLon);
    updateHeatOverlay();
    
    const temp = cachedWeather.temperature[0];
    const riskScore = calculateRiskScore(temp);
    let riskLevel = riskScore >= 70 ? 'DANGER' : (riskScore >= 40 ? 'ALERT' : 'SAFE');
    let message = riskLevel === 'DANGER' ? '🔥 Extreme heat! Stay indoors if possible.' : 
                  (riskLevel === 'ALERT' ? '⚠️ High heat - take frequent breaks.' : 
                   '✅ Safe conditions but stay hydrated.');
    
    updateWarningCard(riskLevel, riskScore, shortName, message);
    updateUserCircle(currentLat, currentLon);
    
    if (currentMode === 'nearby') {
      await updateNearbyMode();
    }
    
    updateAgents(false);
  }, function(error) {
    console.error(error);
    document.getElementById('resultsContent').innerHTML = '<div class="loading">❌ Location access denied. Please enable location services.</div>';
    document.getElementById('locationName').innerHTML = 'Location unavailable';
    updateAgents(false);
  }, { enableHighAccuracy: true, timeout: 10000 });
}

// Initialize on load
window.onload = () => {
  updateAgents(false);
  refreshRisk();
};
</script>
</body>
</html>
''';
