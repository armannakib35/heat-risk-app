import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('TtsChannel', onMessageReceived: (message) {
        _speak(message.message);
      })
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

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String message) async {
    await flutterTts.speak(message);
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
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'Inter', sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; }
    .app-container { max-width: 550px; margin: 0 auto; padding: 16px; padding-bottom: 30px; }
    .header { background: rgba(255,255,255,0.95); border-radius: 28px; padding: 20px; margin-bottom: 16px; text-align: center; }
    .header h1 { font-size: 28px; font-weight: 800; background: linear-gradient(135deg, #ff6b6b, #ff8e53); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 4px; }
    .header p { color: #666; font-size: 13px; }
    .tab-container { display: flex; gap: 12px; margin-bottom: 16px; }
    .tab-btn { flex: 1; padding: 14px; border: none; border-radius: 16px; font-size: 16px; font-weight: 700; cursor: pointer; background: rgba(255,255,255,0.9); color: #666; }
    .tab-btn.active { background: linear-gradient(135deg, #ff7e5f, #feb47b); color: white; }
    .warning-card { background: linear-gradient(135deg, #1a1a2e, #16213e); border-radius: 20px; padding: 20px; margin-bottom: 16px; cursor: pointer; }
    .warning-card.safe { background: linear-gradient(135deg, #1b4332, #2d6a4f); }
    .warning-card.alert { background: linear-gradient(135deg, #e85d04, #f48c06); }
    .warning-card.danger { background: linear-gradient(135deg, #9d0208, #dc2f02); animation: pulseGlow 1s ease-in-out infinite; }
    @keyframes pulseGlow { 0%,100% { box-shadow: 0 0 0 0 rgba(255,75,75,0.7); } 50% { box-shadow: 0 0 0 12px rgba(255,75,75,0); } }
    .warning-header { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }
    .warning-icon { font-size: 36px; }
    .warning-title { font-size: 22px; font-weight: 800; color: white; }
    .warning-message { color: rgba(255,255,255,0.95); font-size: 15px; line-height: 1.6; margin-bottom: 12px; }
    .warning-location { color: rgba(255,255,255,0.85); font-size: 13px; display: flex; align-items: center; gap: 6px; margin-bottom: 10px; }
    .risk-badge { display: inline-block; background: rgba(255,255,255,0.2); border-radius: 20px; padding: 6px 14px; font-size: 14px; font-weight: 600; color: white; }
    .map-section { background: rgba(255,255,255,0.95); border-radius: 24px; padding: 12px; margin-bottom: 16px; }
    .map-title { margin-bottom: 12px; padding: 0 8px; }
    .map-title h3 { font-size: 16px; font-weight: 700; color: #333; }
    #heatmap, #routemap { height: 400px; border-radius: 20px; background: #f0f0f0; width: 100%; }
    .control-panel { background: rgba(255,255,255,0.95); border-radius: 24px; padding: 16px; margin-bottom: 16px; }
    .slider-container { margin-bottom: 16px; }
    .slider-label { display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 13px; font-weight: 600; color: #555; }
    input[type="range"] { width: 100%; height: 6px; border-radius: 10px; background: linear-gradient(90deg, #4caf50, #ffa500, #ff4b4b); -webkit-appearance: none; }
    input[type="range"]::-webkit-slider-thumb { -webkit-appearance: none; width: 20px; height: 20px; border-radius: 50%; background: #ff7e5f; cursor: pointer; border: 2px solid white; }
    .location-card { background: #f8f9fa; border-radius: 16px; padding: 16px; margin-bottom: 16px; }
    .location-card h4 { font-size: 13px; color: #888; margin-bottom: 8px; }
    .location-name { font-size: 16px; font-weight: 700; color: #333; margin-bottom: 8px; }
    .location-coords { font-size: 12px; color: #666; font-family: monospace; }
    .location-details { margin-top: 8px; padding-top: 8px; border-top: 1px solid #e0e0e0; font-size: 12px; color: #555; display: flex; gap: 16px; flex-wrap: wrap; }
    .destination-card { background: white; border-radius: 16px; padding: 14px; margin-bottom: 16px; border: 1px solid #e0e0e0; }
    .search-box { display: flex; gap: 10px; margin-bottom: 12px; }
    .search-input { flex: 1; padding: 12px 16px; border: 1px solid #ddd; border-radius: 25px; font-size: 14px; outline: none; }
    .search-input:focus { border-color: #ff7e5f; }
    .search-btn, .route-btn { padding: 10px 20px; background: #ff7e5f; color: white; border: none; border-radius: 25px; font-weight: 600; cursor: pointer; }
    .route-btn { width: 100%; margin-top: 10px; background: linear-gradient(135deg, #667eea, #764ba2); }
    .suggestions { max-height: 200px; overflow-y: auto; background: white; border-radius: 12px; margin-top: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
    .suggestion-item { padding: 12px 16px; border-bottom: 1px solid #eee; cursor: pointer; }
    .suggestion-item:hover { background: #f5f5f5; }
    .agents-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin-top: 12px; }
    .agent-card { background: linear-gradient(135deg, #f5f7fa, #c3cfe2); padding: 12px; border-radius: 14px; position: relative; }
    .agent-card.active { background: linear-gradient(135deg, #ff7e5f, #feb47b); color: white; }
    .agent-name { font-weight: 700; font-size: 12px; margin-bottom: 4px; }
    .agent-status { font-size: 10px; opacity: 0.8; }
    .agent-dot { position: absolute; top: 10px; right: 10px; width: 8px; height: 8px; border-radius: 50%; background: #4caf50; animation: blink 1s infinite; }
    @keyframes blink { 0%,100% { opacity: 1; } 50% { opacity: 0.3; } }
    .results-container { background: rgba(255,255,255,0.95); border-radius: 24px; padding: 16px; margin-top: 16px; }
    .results-container h3 { font-size: 16px; margin-bottom: 12px; color: #333; }
    .street-card { background: white; border-radius: 14px; padding: 14px; margin-bottom: 10px; border-left: 5px solid; box-shadow: 0 2px 8px rgba(0,0,0,0.05); }
    .street-card.DANGER { border-color: #ff4b4b; }
    .street-card.ALERT { border-color: #ffa500; }
    .street-card.SAFE { border-color: #4caf50; }
    .street-name { font-weight: 700; font-size: 15px; margin-bottom: 6px; }
    .street-details { font-size: 12px; color: #666; display: flex; flex-wrap: wrap; gap: 12px; margin-top: 6px; }
    .route-option { background: white; border-radius: 14px; padding: 14px; margin-bottom: 10px; cursor: pointer; border: 2px solid transparent; }
    .route-option.selected { border-color: #ff7e5f; background: #fff5f0; }
    .route-name { font-weight: 700; font-size: 15px; margin-bottom: 6px; }
    .route-stats { font-size: 12px; color: #666; display: flex; gap: 12px; margin-top: 6px; flex-wrap: wrap; }
    .hidden { display: none; }
    .loading { text-align: center; padding: 20px; color: #888; }
    button { cursor: pointer; }
  </style>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
</head>
<body>
<div class="app-container">
  <div class="header">
    <h1>🌡️ AI Heat Risk Warning</h1>
    <p>Real-time thermal monitoring & intelligent route planning</p>
  </div>
  <div class="tab-container">
    <button class="tab-btn active" id="heatmapTab" onclick="switchTab('heatmap')">🔥 Heat Map</button>
    <button class="tab-btn" id="routeTab" onclick="switchTab('route')">🗺️ Route Planner</button>
  </div>
  <div id="heatmapPanel">
    <div id="warningCard" class="warning-card safe" onclick="refreshHeatmap()">
      <div class="warning-header"><span class="warning-icon" id="warningIcon">✅</span><span class="warning-title" id="warningTitle">Safe Zone</span></div>
      <div class="warning-message" id="warningMessage">Tap to check your current heat risk level.</div>
      <div class="warning-location"><span>📍</span><span id="warningLocation">--</span></div>
      <div class="risk-badge" id="riskBadge">Score: --</div>
    </div>
    <div class="map-section"><div class="map-title"><h3>🗺️ Heat Risk Map</h3></div><div id="heatmap"></div></div>
    <div class="control-panel">
      <div class="slider-container"><div class="slider-label"><span>⏰ Forecast Time</span><span id="forecastValueHeat">Now</span></div><input type="range" id="forecastSliderHeat" min="0" max="12" value="0" oninput="updateHeatForecast(this.value)"></div>
      <button class="search-btn" style="width:100%;" onclick="refreshHeatmap()">🔄 Refresh Data</button>
    </div>
    <div class="location-card">
      <h4>📍 CURRENT LOCATION</h4>
      <div class="location-name" id="locationName">Tap refresh to get location</div>
      <div class="location-coords" id="locationCoords">--</div>
      <div class="location-details" id="locationDetails"><span>🌡️ Waiting for data...</span></div>
    </div>
    <div class="control-panel"><h4 style="margin-bottom:12px;">🤖 AI Agent Network</h4><div class="agents-grid" id="agentsGridHeat"></div></div>
    <div class="results-container"><h3>📊 Street Heat Analysis</h3><div id="resultsHeat">Waiting for location data...</div></div>
  </div>
  <div id="routePanel" class="hidden">
    <div class="map-section"><div class="map-title"><h3>🗺️ Route Planning Map</h3></div><div id="routemap"></div></div>
    <div class="destination-card">
      <h4 style="margin-bottom:10px;">🎯 Plan Your Route</h4>
      <div class="search-box"><input type="text" class="search-input" id="destinationInput" placeholder="Enter destination"><button class="search-btn" onclick="searchLocation()">Search</button></div>
      <div id="suggestions" class="suggestions hidden"></div>
      <button class="route-btn" id="findRouteBtn" onclick="findRoutes()" style="display:none;">🌿 Find Coolest Routes</button>
    </div>
    <div class="results-container"><h3>🚶 Route Options (Click to View)</h3><div id="routeResults">Search a destination to see route options</div></div>
  </div>
</div>
<script>
let heatmapMap, routeMap, currentLat = null, currentLon = null, cachedWeather = null, currentForecast = 0, forecastNames = [], streetMarkers = [], currentRoutes = [], destinationLat = null, destinationLon = null, routeLines = [], cityName = '', countryName = '';
function speakMessage(message) { if (window.TtsChannel) { window.TtsChannel.postMessage(message); } else { window.speechSynthesis.cancel(); window.speechSynthesis.speak(new SpeechSynthesisUtterance(message)); } }
function switchTab(tab) {
  const heatmapPanel = document.getElementById('heatmapPanel'), routePanel = document.getElementById('routePanel'), heatmapTab = document.getElementById('heatmapTab'), routeTab = document.getElementById('routeTab');
  if (tab === 'heatmap') { heatmapPanel.classList.remove('hidden'); routePanel.classList.add('hidden'); heatmapTab.classList.add('active'); routeTab.classList.remove('active'); setTimeout(() => { if (heatmapMap) heatmapMap.invalidateSize(); }, 100); }
  else { heatmapPanel.classList.add('hidden'); routePanel.classList.remove('hidden'); heatmapTab.classList.remove('active'); routeTab.classList.add('active'); if (!routeMap && currentLat) { initRouteMap(currentLat, currentLon); } else if (routeMap && currentLat) { setTimeout(() => routeMap.invalidateSize(), 100); routeMap.setView([currentLat, currentLon], 14); } }
}
function initHeatmapMap(lat, lon) {
  if (!heatmapMap) { heatmapMap = L.map("heatmap").setView([lat, lon], 15); L.tileLayer("https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png", { attribution: '&copy; OpenStreetMap', subdomains: 'abcd', maxZoom: 19 }).addTo(heatmapMap); }
  else { heatmapMap.setView([lat, lon], 15); }
  if (window.userMarkerHeat) heatmapMap.removeLayer(window.userMarkerHeat);
  window.userMarkerHeat = L.marker([lat, lon], { icon: L.divIcon({ html: '<div style="background-color:#ff7e5f; width:20px; height:20px; border-radius:50%; border:3px solid white;"></div>', iconSize: [20,20] }) }).addTo(heatmapMap).bindPopup('<b>You are here</b>');
}
function updateHeatForecast(value) { currentForecast = parseInt(value); document.getElementById('forecastValueHeat').innerText = forecastNames[currentForecast]; if (currentLat && cachedWeather) { updateHeatmapStreets(); updateWarningCard(); } }
async function refreshHeatmap() {
  updateAgents('heat', true);
  document.getElementById('resultsHeat').innerHTML = '<div class="loading">🌍 Getting your location...</div>';
  navigator.geolocation.getCurrentPosition(async function(position) {
    currentLat = position.coords.latitude; currentLon = position.coords.longitude;
    initHeatmapMap(currentLat, currentLon);
    const locationData = await getDetailedLocation(currentLat, currentLon);
    cityName = locationData.city; countryName = locationData.country;
    document.getElementById('locationName').innerHTML = locationData.city + ', ' + locationData.country;
    document.getElementById('locationCoords').innerHTML = currentLat.toFixed(5) + '°N, ' + currentLon.toFixed(5) + '°E';
    await fetchWeather(currentLat, currentLon);
    await updateHeatmapStreets();
    updateWarningCard();
    updateLocationDetails();
    updateAgents('heat', false);
  }, function(error) { document.getElementById('resultsHeat').innerHTML = '<div class="loading">❌ Location access denied</div>'; updateAgents('heat', false); }, { enableHighAccuracy: true, timeout: 10000 });
}
async function getDetailedLocation(lat, lon) {
  const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lon}&zoom=18&addressdetails=1&accept-language=en`;
  try { const response = await fetch(url, { headers: { "User-Agent": "AI-Heat-Risk-Demo/1.0" } }); const data = await response.json();
    let city = data.address?.city || data.address?.town || data.address?.village || data.address?.suburb || 'Unknown City';
    let country = data.address?.country || 'Unknown Country';
    return { city: city, country: country }; } catch(e) { return { city: 'Unknown City', country: 'Unknown Country' }; }
}
function updateLocationDetails() { if (!cachedWeather) return; const temp = cachedWeather.temperature[currentForecast], humidity = cachedWeather.humidity[currentForecast], feelsLike = cachedWeather.apparent_temperature[currentForecast];
  document.getElementById('locationDetails').innerHTML = `<span>🌡️ Temperature: ${temp}°C</span><span>💧 Humidity: ${humidity}%</span><span>🌡️ Feels Like: ${feelsLike}°C</span>`; }
function updateWarningCard() {
  if (!cachedWeather || !currentLat) return;
  const temp = cachedWeather.temperature[currentForecast], humidity = cachedWeather.humidity[currentForecast], feelsLike = cachedWeather.apparent_temperature[currentForecast];
  let score = temp >= 35 ? 90 : (temp >= 32 ? 80 : (temp >= 30 ? 70 : (temp >= 28 ? 55 : (temp >= 25 ? 40 : (temp >= 22 ? 25 : 10)))));
  let riskLevel = score >= 70 ? 'DANGER' : (score >= 40 ? 'ALERT' : 'SAFE');
  let message = riskLevel === 'DANGER' ? 'DANGER: Extreme heat conditions! Avoid outdoor exposure if possible. Stay in air conditioning, drink water every 15 minutes, use sunscreen, wear light clothing, avoid peak sun hours 11am to 4pm.' : (riskLevel === 'ALERT' ? 'ALERT: High heat risk! Take precautions: stay hydrated, use sunscreen, take umbrella, wear hat, reduce outdoor exposure.' : 'SAFE: Low heat risk. Conditions are favorable for outdoor activities. Remember to drink water regularly.');
  const card = document.getElementById('warningCard'), icon = document.getElementById('warningIcon'), title = document.getElementById('warningTitle'), warningMsg = document.getElementById('warningMessage'), locationSpan = document.getElementById('warningLocation'), riskBadge = document.getElementById('riskBadge');
  card.className = 'warning-card';
  if (riskLevel === 'DANGER') { card.classList.add('danger'); icon.innerHTML = '🔥'; title.innerHTML = 'DANGER - High Heat Risk'; }
  else if (riskLevel === 'ALERT') { card.classList.add('alert'); icon.innerHTML = '⚠️'; title.innerHTML = 'ALERT - Moderate Heat Risk'; }
  else { card.classList.add('safe'); icon.innerHTML = '✅'; title.innerHTML = 'SAFE - Low Heat Risk'; }
  warningMsg.innerHTML = message; locationSpan.innerHTML = cityName + ', ' + countryName;
  riskBadge.innerHTML = `Score: ${score}/100 | ${temp}°C | Feels: ${feelsLike}°C | Humidity: ${humidity}%`;
  speakMessage(message);
}
async function fetchWeather(lat, lon) {
  const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&hourly=temperature_2m,relative_humidity_2m,apparent_temperature&forecast_days=1&timezone=auto`;
  const response = await fetch(url); const data = await response.json();
  const now = new Date(); const resultTemp = [], resultHumidity = [], resultApparent = [], resultTime = [];
  for (let step = 0; step <= 12; step++) {
    const targetTime = new Date(now.getTime() + step * 30 * 60 * 1000); let beforeIndex = 0;
    for (let i = 0; i < data.hourly.time.length - 1; i++) { const t1 = new Date(data.hourly.time[i]); const t2 = new Date(data.hourly.time[i+1]); if (targetTime >= t1 && targetTime <= t2) { beforeIndex = i; break; } }
    const t1 = new Date(data.hourly.time[beforeIndex]), t2 = new Date(data.hourly.time[beforeIndex+1]), ratio = (targetTime - t1) / (t2 - t1);
    resultTime.push(targetTime);
    resultTemp.push(Number((data.hourly.temperature_2m[beforeIndex] + (data.hourly.temperature_2m[beforeIndex+1] - data.hourly.temperature_2m[beforeIndex]) * ratio).toFixed(1)));
    resultHumidity.push(Math.round(data.hourly.relative_humidity_2m[beforeIndex] + (data.hourly.relative_humidity_2m[beforeIndex+1] - data.hourly.relative_humidity_2m[beforeIndex]) * ratio));
    resultApparent.push(Number((data.hourly.apparent_temperature[beforeIndex] + (data.hourly.apparent_temperature[beforeIndex+1] - data.hourly.apparent_temperature[beforeIndex]) * ratio).toFixed(1)));
  }
  cachedWeather = { temperature: resultTemp, humidity: resultHumidity, apparent_temperature: resultApparent, time: resultTime };
  forecastNames = resultTime.map(t => t.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }));
  const slider = document.getElementById('forecastSliderHeat'); if (slider) { slider.max = forecastNames.length - 1; document.getElementById('forecastValueHeat').innerText = forecastNames[0]; }
}
async function fetchNearbyStreets(lat, lon) {
  const query = `[out:json][timeout:25];way["highway"](around:400,${lat},${lon});out center tags;`;
  const response = await fetch("https://overpass-api.de/api/interpreter", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded", "User-Agent": "AI-Heat-Risk-Demo/1.0" }, body: "data=" + encodeURIComponent(query) });
  const data = await response.json(); const streets = [], seen = new Set();
  for (const element of data.elements || []) { const tags = element.tags, center = element.center; if (!tags || !center) continue;
    const name = tags["name:en"] || tags.name || `Unnamed ${tags.highway || 'road'}`; const key = `${name}-${center.lat.toFixed(4)}`;
    if (seen.has(key)) continue; seen.add(key); streets.push({ name: name, lat: center.lat, lon: center.lon, type: tags.highway || 'road' });
    if (streets.length >= 15) break; }
  return streets;
}
async function updateHeatmapStreets() {
  if (!currentLat || !currentLon || !cachedWeather) return;
  document.getElementById('resultsHeat').innerHTML = '<div class="loading">🌡️ Analyzing nearby streets...</div>';
  const streets = await fetchNearbyStreets(currentLat, currentLon);
  const temp = cachedWeather.temperature[currentForecast], humidity = cachedWeather.humidity[currentForecast], feelsLike = cachedWeather.apparent_temperature[currentForecast];
  streetMarkers.forEach(m => heatmapMap.removeLayer(m)); streetMarkers = [];
  let html = '';
  for (const street of streets) {
    let score = (temp >= 35 ? 90 : (temp >= 32 ? 80 : (temp >= 30 ? 70 : (temp >= 28 ? 55 : (temp >= 25 ? 40 : (temp >= 22 ? 25 : 10)))))) + (street.type.includes('primary') || street.type.includes('motorway') ? 20 : 10);
    score = Math.min(100, score); let level = score >= 70 ? 'DANGER' : (score >= 40 ? 'ALERT' : 'SAFE');
    let advice = level === 'DANGER' ? 'Avoid this street' : (level === 'ALERT' ? 'Take caution' : 'Safe street');
    html += `<div class="street-card ${level}"><div class="street-name">🛣️ ${street.name}</div><div class="street-details"><span>🏗️ Type: ${street.type}</span><span>🌡️ Temperature: ${temp}°C</span><span>💧 Humidity: ${humidity}%</span><span>🌡️ Feels Like: ${feelsLike}°C</span><span>⚠️ Level: ${level} (${score}/100)</span></div><div class="street-details">${advice}</div></div>`;
    const color = level === 'DANGER' ? '#ff4b4b' : (level === 'ALERT' ? '#ffa500' : '#4caf50');
    const circle = L.circle([street.lat, street.lon], { radius: 20 + score / 3, color: color, fillColor: color, fillOpacity: 0.5, weight: 2 }).addTo(heatmapMap).bindPopup(`<b>${street.name}</b><br>Level: ${level}<br>Temp: ${temp}°C<br>Humidity: ${humidity}%`);
    streetMarkers.push(circle);
  }
  if (html === '') html = '<div class="loading">No nearby streets found</div>';
  document.getElementById('resultsHeat').innerHTML = html;
}
function updateAgents(type, loading) {
  const agents = [{ name: '🌡️ Heat Sensor', status: loading ? 'Scanning...' : 'Active' }, { name: '🗺️ Surface Scanner', status: loading ? 'Analyzing...' : 'Ready' }, { name: '👥 People Tracker', status: loading ? 'Tracking...' : 'Monitoring' }, { name: '⚖️ Calculator', status: loading ? 'Computing...' : 'Online' }, { name: '🔔 Alert Agent', status: loading ? 'Preparing...' : 'Standby' }, { name: '🧠 Learning AI', status: loading ? 'Updating...' : 'Optimized' }];
  let html = ''; agents.forEach(agent => { html += `<div class="agent-card ${loading ? 'active' : ''}"><div class="agent-name">${agent.name}</div><div class="agent-status">${agent.status}</div><div class="agent-dot"></div></div>`; });
  document.getElementById(`agentsGrid${type === 'heat' ? 'Heat' : 'Route'}`).innerHTML = html;
}
function initRouteMap(lat, lon) {
  if (!routeMap) { routeMap = L.map("routemap").setView([lat, lon], 14); L.tileLayer("https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png", { attribution: '&copy; OpenStreetMap', subdomains: 'abcd', maxZoom: 19 }).addTo(routeMap); }
  else { routeMap.setView([lat, lon], 14); }
  if (window.userMarkerRoute) routeMap.removeLayer(window.userMarkerRoute);
  window.userMarkerRoute = L.marker([lat, lon], { icon: L.divIcon({ html: '<div style="background-color:#ff7e5f; width:20px; height:20px; border-radius:50%; border:3px solid white;"></div>', iconSize: [20,20] }) }).addTo(routeMap).bindPopup('<b>Start: Your Location</b>');
}
async function searchLocation() {
  const query = document.getElementById('destinationInput').value.trim(); if (!query) return;
  const suggestionsDiv = document.getElementById('suggestions'); suggestionsDiv.classList.remove('hidden'); suggestionsDiv.innerHTML = '<div class="loading">Searching...</div>';
  const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=5&accept-language=en`;
  const response = await fetch(url, { headers: { "User-Agent": "AI-Heat-Risk-Demo/1.0" } }); const data = await response.json();
  if (data.length === 0) { suggestionsDiv.innerHTML = '<div class="suggestion-item">No results found</div>'; return; }
  suggestionsDiv.innerHTML = data.map(place => `<div class="suggestion-item" onclick="selectDestination('${place.lat}', '${place.lon}', '${place.display_name.replace(/'/g, "\\'")}')"><strong>${place.display_name.split(',')[0]}</strong><br><small>${place.display_name}</small></div>`).join('');
}
function selectDestination(lat, lon, name) {
  destinationLat = parseFloat(lat); destinationLon = parseFloat(lon);
  document.getElementById('destinationInput').value = name.split(',')[0]; document.getElementById('suggestions').classList.add('hidden'); document.getElementById('findRouteBtn').style.display = 'block';
  if (window.destMarker) routeMap.removeLayer(window.destMarker);
  window.destMarker = L.marker([destinationLat, destinationLon], { icon: L.divIcon({ html: '<div style="background-color:#667eea; width:16px; height:16px; border-radius:50%; border:2px solid white;"></div>', iconSize: [16,16] }) }).addTo(routeMap).bindPopup(`<b>Destination</b><br>${name}`);
  routeMap.fitBounds([[currentLat, currentLon], [destinationLat, destinationLon]], { padding: [50, 50] });
}
async function findRoutes() {
  if (!currentLat || !currentLon || !destinationLat || !destinationLon) { alert('Please wait for location and select a destination'); return; }
  document.getElementById('routeResults').innerHTML = '<div class="loading">🌿 Finding coolest routes...</div>';
  routeLines.forEach(line => routeMap.removeLayer(line)); routeLines = [];
  const temp = cachedWeather ? cachedWeather.temperature[0] : 28;
  const routes = [];
  routes.push({ name: '🚶 Direct Road Route', points: [[currentLat, currentLon], [destinationLat, destinationLon]], description: 'Follows main roads directly', heatScore: Math.round(temp + 2), level: (temp + 2) >= 32 ? 'DANGER' : ((temp + 2) >= 27 ? 'ALERT' : 'SAFE') });
  const midLat = (currentLat + destinationLat) / 2, midLon = (currentLon + destinationLon) / 2;
  routes.push({ name: '🌳 Shaded Residential Route', points: [[currentLat, currentLon], [midLat + 0.007, midLon], [destinationLat, destinationLon]], description: 'Uses residential streets with tree coverage', heatScore: Math.round(temp - 2), level: (temp - 2) >= 32 ? 'DANGER' : ((temp - 2) >= 27 ? 'ALERT' : 'SAFE') });
  routes.push({ name: '🏞️ Park & Green Route', points: [[currentLat, currentLon], [midLat - 0.005, midLon - 0.005], [destinationLat, destinationLon]], description: 'Passes through parks and green areas', heatScore: Math.round(temp - 4), level: (temp - 4) >= 32 ? 'DANGER' : ((temp - 4) >= 27 ? 'ALERT' : 'SAFE') });
  currentRoutes = routes;
  let html = ''; routes.forEach((route, idx) => { const color = route.level === 'DANGER' ? '#ff4b4b' : (route.level === 'ALERT' ? '#ffa500' : '#4caf50'); const bestTag = idx === 0 ? '🏆 BEST ' : '';
    html += `<div class="route-option" onclick="showRouteOnMap(${idx})" style="border-left: 5px solid ${color}"><div class="route-name">${bestTag}${route.name}</div><div class="route-stats"><span>🌡️ Heat Score: ${route.heatScore}°C</span><span>⚠️ Level: ${route.level}</span></div><div class="route-stats">${route.description}</div><div class="route-stats" style="color:#ff7e5f;">🗺️ Click to view on map</div></div>`; });
  document.getElementById('routeResults').innerHTML = html;
}
function showRouteOnMap(routeIndex) {
  const route = currentRoutes[routeIndex]; if (!route || !route.points) return;
  routeLines.forEach(line => routeMap.removeLayer(line)); routeLines = [];
  const color = route.level === 'DANGER' ? '#ff4b4b' : (route.level === 'ALERT' ? '#ffa500' : '#4caf50');
  const line = L.polyline(route.points, { color: color, weight: 6, opacity: 0.9, lineJoin: 'round', lineCap: 'round' }).addTo(routeMap);
  routeLines.push(line);
  const bounds = L.latLngBounds(route.points); routeMap.fitBounds(bounds, { padding: [50, 50] });
  document.querySelectorAll('.route-option').forEach((el, idx) => { if (idx === routeIndex) el.classList.add('selected'); else el.classList.remove('selected'); });
}
window.onload = () => { refreshHeatmap(); const checkLocation = setInterval(() => { if (currentLat) { initRouteMap(currentLat, currentLon); clearInterval(checkLocation); } }, 1000); };
</script>
</body>
</html>
''';
