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
    .warning-card { background: linear-gradient(135deg, #1a1a2e, #16213e); border-radius: 20px; padding: 20px; margin-bottom: 16px; cursor: pointer; transition: transform 0.3s ease; }
    .warning-card:hover { transform: translateY(-2px); }
    .warning-card.safe { background: linear-gradient(135deg, #1b4332, #2d6a4f); }
    .warning-card.alert { background: linear-gradient(135deg, #e85d04, #f48c06); }
    .warning-card.danger { background: linear-gradient(135deg, #9d0208, #dc2f02); }
    .blinking { animation: pulseGlow 1s ease-in-out infinite; }
    @keyframes pulseGlow { 0%,100% { box-shadow: 0 0 0 0 rgba(255,75,75,0.7); } 50% { box-shadow: 0 0 0 12px rgba(255,75,75,0); } }
    .warning-header { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }
    .warning-icon { font-size: 36px; animation: bounce 1s ease-in-out infinite; }
    @keyframes bounce { 0%,100% { transform: scale(1); } 50% { transform: scale(1.1); } }
    .warning-title { font-size: 22px; font-weight: 800; color: white; }
    .warning-message { color: rgba(255,255,255,0.95); font-size: 15px; line-height: 1.6; margin-bottom: 12px; }
    .warning-location { color: rgba(255,255,255,0.85); font-size: 13px; display: flex; align-items: center; gap: 6px; margin-bottom: 10px; flex-wrap: wrap; }
    .risk-badge { display: inline-block; background: rgba(255,255,255,0.2); border-radius: 20px; padding: 6px 14px; font-size: 14px; font-weight: 600; color: white; }
    .map-section { background: rgba(255,255,255,0.95); border-radius: 24px; padding: 12px; margin-bottom: 16px; }
    .map-title { margin-bottom: 12px; padding: 0 8px; }
    .map-title h3 { font-size: 16px; font-weight: 700; color: #333; }
    #heatmap { height: 420px; border-radius: 20px; background: #f0f0f0; width: 100%; z-index: 1; }
    .control-panel { background: rgba(255,255,255,0.95); border-radius: 24px; padding: 16px; margin-bottom: 16px; }
    .slider-container { margin-bottom: 16px; }
    .slider-label { display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 13px; font-weight: 600; color: #555; }
    input[type="range"] { width: 100%; height: 6px; border-radius: 10px; background: linear-gradient(90deg, #4caf50, #ffa500, #ff4b4b); -webkit-appearance: none; }
    input[type="range"]::-webkit-slider-thumb { -webkit-appearance: none; width: 20px; height: 20px; border-radius: 50%; background: #ff7e5f; cursor: pointer; border: 2px solid white; }
    .location-card { background: #f8f9fa; border-radius: 16px; padding: 16px; margin-bottom: 16px; }
    .location-card h4 { font-size: 13px; color: #888; margin-bottom: 8px; }
    .location-name { font-size: 15px; font-weight: 700; color: #333; margin-bottom: 6px; line-height: 1.4; }
    .location-coords { font-size: 12px; color: #666; font-family: monospace; margin-bottom: 6px; }
    .location-details { margin-top: 8px; padding-top: 8px; border-top: 1px solid #e0e0e0; font-size: 12px; color: #555; display: flex; gap: 16px; flex-wrap: wrap; }
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
    .street-name { font-weight: 700; font-size: 14px; margin-bottom: 6px; }
    .street-details { font-size: 11px; color: #666; display: flex; flex-wrap: wrap; gap: 10px; margin-top: 6px; }
    .hidden { display: none; }
    .loading { text-align: center; padding: 20px; color: #888; }
    button { cursor: pointer; }
    .refresh-btn { width: 100%; padding: 12px; background: #ff7e5f; color: white; border: none; border-radius: 25px; font-weight: 600; font-size: 14px; margin-top: 10px; }
    .voice-indicator { position: fixed; bottom: 20px; right: 20px; background: #ff7e5f; width: 50px; height: 50px; border-radius: 50%; display: flex; align-items: center; justify-content: center; box-shadow: 0 4px 15px rgba(0,0,0,0.2); animation: pulse 1.5s ease-in-out infinite; }
    @keyframes pulse { 0%,100% { transform: scale(1); } 50% { transform: scale(1.1); } }
    .voice-indicator span { font-size: 24px; }
  </style>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
</head>
<body>
<div class="app-container">
  <div class="header">
    <h1>🌡️ AI Heat Risk Warning</h1>
    <p>Real-time thermal monitoring & street analysis</p>
  </div>

  <div id="warningCard" class="warning-card safe" onclick="refreshData()">
    <div class="warning-header">
      <span class="warning-icon" id="warningIcon">✅</span>
      <span class="warning-title" id="warningTitle">Safe Zone</span>
    </div>
    <div class="warning-message" id="warningMessage">
      Tap to check your current heat risk level.
    </div>
    <div class="warning-location">
      <span>📍</span>
      <span id="warningLocation">--</span>
    </div>
    <div class="risk-badge" id="riskBadge">Score: --</div>
  </div>

  <div class="map-section">
    <div class="map-title"><h3>🗺️ Heat Risk Map</h3></div>
    <div id="heatmap"></div>
  </div>

  <div class="control-panel">
    <div class="slider-container">
      <div class="slider-label">
        <span>⏰ Forecast Time</span>
        <span id="forecastValue">Now</span>
      </div>
      <input type="range" id="forecastSlider" min="0" max="12" value="0" oninput="updateForecast(this.value)">
    </div>
    <button class="refresh-btn" onclick="refreshData()">🔄 Refresh Data</button>
  </div>

  <div class="location-card">
    <h4>📍 CURRENT LOCATION</h4>
    <div class="location-name" id="locationName">Tap refresh to get location</div>
    <div class="location-coords" id="locationCoords">--</div>
    <div class="location-details" id="locationDetails"><span>🌡️ Waiting for data...</span></div>
  </div>

  <div class="control-panel">
    <h4 style="margin-bottom:12px;">🤖 AI Agent Network</h4>
    <div class="agents-grid" id="agentsGrid"></div>
  </div>

  <div class="results-container">
    <h3>📊 Street Heat Analysis</h3>
    <div id="results">Waiting for location data...</div>
  </div>
</div>

<div class="voice-indicator" id="voiceIndicator">
  <span>🔊</span>
</div>

<script>
let map, currentLat = null, currentLon = null;
let cachedWeather = null, currentForecast = 0, forecastNames = [];
let streetMarkers = [], cityName = '', countryName = '', fullAddress = '';

function speakMessage(message) {
  if (window.TtsChannel) {
    window.TtsChannel.postMessage(message);
  } else {
    window.speechSynthesis.cancel();
    window.speechSynthesis.speak(new SpeechSynthesisUtterance(message));
  }
  const voiceIndicator = document.getElementById('voiceIndicator');
  voiceIndicator.style.animation = 'pulse 0.5s ease-in-out 3';
  setTimeout(() => { voiceIndicator.style.animation = 'pulse 1.5s ease-in-out infinite'; }, 1500);
}

function initMap(lat, lon) {
  if (!map) {
    map = L.map("heatmap").setView([lat, lon], 16);
    L.tileLayer("https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png", {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      subdomains: 'abcd',
      maxZoom: 19,
      minZoom: 3
    }).addTo(map);
  } else {
    map.setView([lat, lon], 16);
  }
  
  if (window.userMarker) map.removeLayer(window.userMarker);
  window.userMarker = L.marker([lat, lon], {
    icon: L.divIcon({
      html: '<div style="background-color:#ff7e5f; width:20px; height:20px; border-radius:50%; border:3px solid white; box-shadow:0 0 10px rgba(0,0,0,0.3);"></div>',
      iconSize: [20, 20]
    })
  }).addTo(map).bindPopup('<b>📍 You are here</b>').openPopup();
}

function updateForecast(value) {
  currentForecast = parseInt(value);
  document.getElementById('forecastValue').innerText = forecastNames[currentForecast];
  if (currentLat && cachedWeather) {
    updateStreets();
    updateWarningCard();
  }
}

async function refreshData() {
  updateAgents(true);
  document.getElementById('results').innerHTML = '<div class="loading">🌍 Getting your location...</div>';
  
  navigator.geolocation.getCurrentPosition(async function(position) {
    currentLat = position.coords.latitude;
    currentLon = position.coords.longitude;
    
    initMap(currentLat, currentLon);
    
    const locationData = await getFullAddress(currentLat, currentLon);
    cityName = locationData.city;
    countryName = locationData.country;
    fullAddress = locationData.fullAddress;
    
    document.getElementById('locationName').innerHTML = fullAddress;
    document.getElementById('locationCoords').innerHTML = `${currentLat.toFixed(6)}°N, ${currentLon.toFixed(6)}°E`;
    
    await fetchWeather(currentLat, currentLon);
    await updateStreets();
    updateWarningCard();
    updateLocationDetails();
    updateAgents(false);
    
    speakMessage(`Location updated: ${fullAddress}`);
  }, function(error) {
    document.getElementById('results').innerHTML = '<div class="loading">❌ Location access denied. Please enable location services.</div>';
    updateAgents(false);
  }, { enableHighAccuracy: true, timeout: 10000 });
}

async function getFullAddress(lat, lon) {
  const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lon}&zoom=18&addressdetails=1&accept-language=en`;
  try {
    const response = await fetch(url, { headers: { "User-Agent": "AI-Heat-Risk-Demo/1.0" } });
    const data = await response.json();
    
    let road = data.address?.road || data.address?.pedestrian || '';
    let suburb = data.address?.suburb || data.address?.neighbourhood || '';
    let city = data.address?.city || data.address?.town || data.address?.village || '';
    let state = data.address?.state || '';
    let country = data.address?.country || '';
    
    let fullAddress = '';
    if (road) fullAddress += road;
    if (suburb) fullAddress += (fullAddress ? ', ' : '') + suburb;
    if (city) fullAddress += (fullAddress ? ', ' : '') + city;
    if (state) fullAddress += (fullAddress ? ', ' : '') + state;
    if (country) fullAddress += (fullAddress ? ', ' : '') + country;
    if (!fullAddress) fullAddress = data.display_name || `${lat.toFixed(4)}, ${lon.toFixed(4)}`;
    
    return { city: city || 'Unknown City', country: country || 'Unknown Country', fullAddress: fullAddress };
  } catch(e) {
    return { city: 'Unknown', country: 'Unknown', fullAddress: 'Location unavailable' };
  }
}

function updateLocationDetails() {
  if (!cachedWeather) return;
  const temp = cachedWeather.temperature[currentForecast];
  const humidity = cachedWeather.humidity[currentForecast];
  const feelsLike = cachedWeather.apparent_temperature[currentForecast];
  
  document.getElementById('locationDetails').innerHTML = `
    <span>🌡️ Temperature: ${temp}°C</span>
    <span>💧 Humidity: ${humidity}%</span>
    <span>🌡️ Feels Like: ${feelsLike}°C</span>
  `;
}

function updateWarningCard() {
  if (!cachedWeather || !currentLat) return;
  
  const temp = cachedWeather.temperature[currentForecast];
  const humidity = cachedWeather.humidity[currentForecast];
  const feelsLike = cachedWeather.apparent_temperature[currentForecast];
  let score = calculateRiskScore(temp);
  let riskLevel = score >= 70 ? 'DANGER' : (score >= 40 ? 'ALERT' : 'SAFE');
  
  let message = '';
  let shortMessage = '';
  if (riskLevel === 'DANGER') {
    message = '🚨 DANGER: Extreme heat conditions! Avoid outdoor exposure if possible. Stay in air conditioning, drink water every 15 minutes, use sunscreen SPF 50, wear light colored clothing, avoid peak sun hours 11am to 4pm. Seek immediate shade if outdoors.';
    shortMessage = 'DANGER: Extreme heat! Stay indoors.';
  } else if (riskLevel === 'ALERT') {
    message = '⚠️ ALERT: High heat risk! Take precautions: stay hydrated, drink 2-3 liters of water daily, use sunscreen SPF 30+, wear a hat and umbrella, reduce outdoor exposure between 12pm-3pm, take breaks in shade every 20 minutes.';
    shortMessage = 'ALERT: High heat risk! Take precautions.';
  } else {
    message = '✅ SAFE: Low heat risk. Conditions are favorable for outdoor activities. Still remember to drink water regularly (2 liters per day), use SPF 15+ sunscreen, and wear a cap if staying out for more than 2 hours.';
    shortMessage = 'SAFE: Low heat risk. Enjoy outdoor activities.';
  }
  
  const card = document.getElementById('warningCard');
  const icon = document.getElementById('warningIcon');
  const title = document.getElementById('warningTitle');
  const warningMsg = document.getElementById('warningMessage');
  const locationSpan = document.getElementById('warningLocation');
  const riskBadge = document.getElementById('riskBadge');
  
  card.className = 'warning-card';
  if (riskLevel === 'DANGER') {
    card.classList.add('danger');
    card.classList.add('blinking');
    icon.innerHTML = '🔥';
    title.innerHTML = 'DANGER - High Heat Risk';
  } else if (riskLevel === 'ALERT') {
    card.classList.add('alert');
    card.classList.remove('blinking');
    icon.innerHTML = '⚠️';
    title.innerHTML = 'ALERT - Moderate Heat Risk';
  } else {
    card.classList.add('safe');
    card.classList.remove('blinking');
    icon.innerHTML = '✅';
    title.innerHTML = 'SAFE - Low Heat Risk';
  }
  
  warningMsg.innerHTML = message;
  locationSpan.innerHTML = fullAddress || `${cityName}, ${countryName}`;
  riskBadge.innerHTML = `Score: ${score}/100 | ${temp}°C | Feels: ${feelsLike}°C | Humidity: ${humidity}%`;
  
  speakMessage(shortMessage);
}

function calculateRiskScore(temp) {
  if (temp >= 38) return 95;
  if (temp >= 35) return 90;
  if (temp >= 32) return 80;
  if (temp >= 30) return 70;
  if (temp >= 28) return 55;
  if (temp >= 25) return 40;
  if (temp >= 22) return 25;
  if (temp >= 18) return 15;
  return 5;
}

async function fetchWeather(lat, lon) {
  const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&hourly=temperature_2m,relative_humidity_2m,apparent_temperature&forecast_days=1&timezone=auto`;
  const response = await fetch(url);
  const data = await response.json();
  
  const now = new Date();
  const resultTemp = [], resultHumidity = [], resultApparent = [], resultTime = [];
  
  for (let step = 0; step <= 12; step++) {
    const targetTime = new Date(now.getTime() + step * 30 * 60 * 1000);
    let beforeIndex = 0;
    for (let i = 0; i < data.hourly.time.length - 1; i++) {
      const t1 = new Date(data.hourly.time[i]);
      const t2 = new Date(data.hourly.time[i + 1]);
      if (targetTime >= t1 && targetTime <= t2) { beforeIndex = i; break; }
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
  
  cachedWeather = { temperature: resultTemp, humidity: resultHumidity, apparent_temperature: resultApparent, time: resultTime };
  forecastNames = resultTime.map(t => t.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }));
  
  const slider = document.getElementById('forecastSlider');
  if (slider) {
    slider.max = forecastNames.length - 1;
    document.getElementById('forecastValue').innerText = forecastNames[0];
  }
}

async function fetchNearbyStreets(lat, lon) {
  const query = `[out:json][timeout:25];(way["highway"](around:400,${lat},${lon});node["highway"](around:400,${lat},${lon}););out center;`;
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
    const lat = element.lat || element.center?.lat;
    const lon = element.lon || element.center?.lon;
    if (!tags || !lat || !lon) continue;
    const name = tags.name || tags["name:en"] || (tags.highway ? tags.highway.replace('_', ' ') : 'Road');
    const key = `${name}-${lat.toFixed(4)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    streets.push({ name: name, lat: lat, lon: lon, type: tags.highway || 'road' });
    if (streets.length >= 20) break;
  }
  return streets;
}

async function updateStreets() {
  if (!currentLat || !currentLon || !cachedWeather) return;
  
  document.getElementById('results').innerHTML = '<div class="loading">🌡️ Analyzing nearby streets...</div>';
  
  const streets = await fetchNearbyStreets(currentLat, currentLon);
  const temp = cachedWeather.temperature[currentForecast];
  const humidity = cachedWeather.humidity[currentForecast];
  const feelsLike = cachedWeather.apparent_temperature[currentForecast];
  
  streetMarkers.forEach(m => map.removeLayer(m));
  streetMarkers = [];
  
  let html = '';
  for (const street of streets) {
    let score = calculateRiskScore(temp);
    if (street.type === 'motorway' || street.type === 'trunk' || street.type === 'primary') score += 25;
    else if (street.type === 'secondary' || street.type === 'tertiary') score += 15;
    else if (street.type === 'residential' || street.type === 'living_street') score += 5;
    else score -= 5;
    score = Math.min(100, Math.max(0, score));
    
    let level = score >= 70 ? 'DANGER' : (score >= 40 ? 'ALERT' : 'SAFE');
    let advice = level === 'DANGER' ? '❌ Avoid this street - high heat absorption from concrete/pavement' : 
                  (level === 'ALERT' ? '⚠️ Use caution - moderate heat, take umbrella' : '✅ Safe street - good for walking');
    
    html += `
      <div class="street-card ${level}">
        <div class="street-name">🛣️ ${street.name}</div>
        <div class="street-details">
          <span>🏗️ Type: ${street.type}</span>
          <span>🌡️ Temp: ${temp}°C</span>
          <span>💧 Humidity: ${humidity}%</span>
          <span>🌡️ Feels: ${feelsLike}°C</span>
          <span>⚠️ Level: ${level} (${score}/100)</span>
        </div>
        <div class="street-details">💡 ${advice}</div>
      </div>
    `;
    
    const color = level === 'DANGER' ? '#ff4b4b' : (level === 'ALERT' ? '#ffa500' : '#4caf50');
    const radius = 15 + (score / 4);
    const circle = L.circle([street.lat, street.lon], {
      radius: radius,
      color: color,
      fillColor: color,
      fillOpacity: 0.5,
      weight: 2
    }).addTo(map).bindPopup(`
      <b>📍 ${street.name}</b><br>
      🏗️ Type: ${street.type}<br>
      🌡️ Temperature: ${temp}°C<br>
      💧 Humidity: ${humidity}%<br>
      🌡️ Feels Like: ${feelsLike}°C<br>
      ⚠️ Risk Level: ${level} (${score}/100)<br>
      💡 ${advice}
    `);
    streetMarkers.push(circle);
  }
  
  if (html === '') html = '<div class="loading">No nearby streets found. Try zooming out or moving to an area with more roads.</div>';
  document.getElementById('results').innerHTML = html;
}

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
    html += `<div class="agent-card ${loading ? 'active' : ''}">
      <div class="agent-name">${agent.name}</div>
      <div class="agent-status">${agent.status}</div>
      <div class="agent-dot"></div>
    </div>`;
  });
  document.getElementById('agentsGrid').innerHTML = html;
}

window.onload = () => {
  refreshData();
};
</script>
</body>
</html>
''';
}
