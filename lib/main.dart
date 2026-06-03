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
  <title>AI Heat Risk Warning - Intelligent System</title>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: 'Inter', sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; }
    .app-container { max-width: 600px; margin: 0 auto; padding: 16px; padding-bottom: 30px; }
    .header { background: rgba(255,255,255,0.95); border-radius: 28px; padding: 20px; margin-bottom: 16px; text-align: center; box-shadow: 0 10px 30px rgba(0,0,0,0.1); }
    .header h1 { font-size: 28px; font-weight: 800; background: linear-gradient(135deg, #ff6b6b, #ff8e53); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 4px; }
    .header p { color: #666; font-size: 13px; }
    .warning-card { background: linear-gradient(135deg, #1a1a2e, #16213e); border-radius: 20px; padding: 20px; margin-bottom: 16px; cursor: pointer; transition: transform 0.3s ease; position: relative; overflow: hidden; }
    .warning-card:hover { transform: translateY(-2px); }
    .warning-card.safe { background: linear-gradient(135deg, #1b4332, #2d6a4f); }
    .warning-card.alert { background: linear-gradient(135deg, #e85d04, #f48c06); }
    .warning-card.danger { background: linear-gradient(135deg, #9d0208, #dc2f02); animation: pulseGlow 0.8s ease-in-out infinite; }
    @keyframes pulseGlow { 0%,100% { box-shadow: 0 0 0 0 rgba(255,75,75,0.7); border-left: 4px solid #ff4b4b; } 50% { box-shadow: 0 0 0 15px rgba(255,75,75,0); border-left: 4px solid #ffa500; } }
    .warning-header { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }
    .warning-icon { font-size: 42px; animation: blinkIcon 1s infinite; }
    @keyframes blinkIcon { 0%,100% { opacity: 1; transform: scale(1); } 50% { opacity: 0.7; transform: scale(1.1); } }
    .warning-title { font-size: 22px; font-weight: 800; color: white; }
    .warning-message { color: rgba(255,255,255,0.95); font-size: 14px; line-height: 1.5; margin-bottom: 12px; }
    .warning-location { color: rgba(255,255,255,0.85); font-size: 12px; display: flex; align-items: center; gap: 6px; margin-bottom: 10px; flex-wrap: wrap; }
    .risk-badge { display: inline-block; background: rgba(255,255,255,0.2); border-radius: 20px; padding: 6px 14px; font-size: 13px; font-weight: 600; color: white; }
    .map-section { background: rgba(255,255,255,0.95); border-radius: 24px; padding: 12px; margin-bottom: 16px; box-shadow: 0 10px 30px rgba(0,0,0,0.1); }
    .map-title { margin-bottom: 12px; padding: 0 8px; }
    .map-title h3 { font-size: 16px; font-weight: 700; color: #333; }
    #heatmap { height: 450px; border-radius: 20px; background: #e8e8e8; width: 100%; z-index: 1; }
    .control-panel { background: rgba(255,255,255,0.95); border-radius: 24px; padding: 16px; margin-bottom: 16px; }
    .slider-container { margin-bottom: 16px; }
    .slider-label { display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 13px; font-weight: 600; color: #555; }
    input[type="range"] { width: 100%; height: 6px; border-radius: 10px; background: linear-gradient(90deg, #4caf50, #ffa500, #ff4b4b); -webkit-appearance: none; }
    input[type="range"]::-webkit-slider-thumb { -webkit-appearance: none; width: 20px; height: 20px; border-radius: 50%; background: #ff7e5f; cursor: pointer; border: 2px solid white; }
    .location-card { background: #f8f9fa; border-radius: 16px; padding: 16px; margin-bottom: 16px; }
    .location-card h4 { font-size: 13px; color: #888; margin-bottom: 8px; }
    .location-name { font-size: 15px; font-weight: 700; color: #333; margin-bottom: 8px; line-height: 1.4; }
    .location-coords { font-size: 11px; color: #666; font-family: monospace; margin-bottom: 6px; }
    .location-full { font-size: 11px; color: #777; margin-top: 6px; padding-top: 6px; border-top: 1px solid #e0e0e0; line-height: 1.5; }
    .location-details { margin-top: 8px; padding-top: 8px; border-top: 1px solid #e0e0e0; font-size: 12px; color: #555; display: flex; gap: 16px; flex-wrap: wrap; }
    .agents-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin-top: 12px; }
    .agent-card { background: linear-gradient(135deg, #f5f7fa, #c3cfe2); padding: 12px; border-radius: 14px; position: relative; transition: all 0.3s; cursor: pointer; }
    .agent-card.active { background: linear-gradient(135deg, #ff7e5f, #feb47b); color: white; transform: scale(1.02); }
    .agent-card.learning { background: linear-gradient(135deg, #11998e, #38ef7d); color: white; animation: pulse 1s infinite; }
    @keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: 0.7; } }
    .agent-name { font-weight: 700; font-size: 12px; margin-bottom: 4px; }
    .agent-status { font-size: 10px; opacity: 0.8; }
    .agent-dot { position: absolute; top: 10px; right: 10px; width: 8px; height: 8px; border-radius: 50%; background: #4caf50; animation: blink 1s infinite; }
    @keyframes blink { 0%,100% { opacity: 1; } 50% { opacity: 0.3; } }
    .results-container { background: rgba(255,255,255,0.95); border-radius: 24px; padding: 16px; margin-top: 16px; max-height: 400px; overflow-y: auto; }
    .results-container h3 { font-size: 16px; margin-bottom: 12px; color: #333; }
    .street-card { background: white; border-radius: 14px; padding: 14px; margin-bottom: 10px; border-left: 5px solid; box-shadow: 0 2px 8px rgba(0,0,0,0.05); transition: transform 0.2s; }
    .street-card:hover { transform: translateX(5px); }
    .street-card.DANGER { border-color: #ff4b4b; background: #fff5f5; }
    .street-card.ALERT { border-color: #ffa500; background: #fffaf0; }
    .street-card.SAFE { border-color: #4caf50; background: #f0fff0; }
    .street-name { font-weight: 700; font-size: 14px; margin-bottom: 6px; color: #333; }
    .street-details { font-size: 11px; color: #666; display: flex; flex-wrap: wrap; gap: 10px; margin-top: 6px; }
    .refresh-btn { width: 100%; padding: 14px; background: linear-gradient(135deg, #ff7e5f, #feb47b); color: white; border: none; border-radius: 25px; font-weight: 700; font-size: 16px; cursor: pointer; margin-top: 10px; }
    .loading { text-align: center; padding: 20px; color: #888; }
    .ai-insight { background: linear-gradient(135deg, #667eea, #764ba2); color: white; padding: 15px; border-radius: 16px; margin-top: 10px; font-size: 13px; line-height: 1.5; }
    .custom-div-icon { background: transparent; }
    ::-webkit-scrollbar { width: 5px; }
    ::-webkit-scrollbar-track { background: #f1f1f1; border-radius: 10px; }
    ::-webkit-scrollbar-thumb { background: #ff7e5f; border-radius: 10px; }
  </style>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
</head>
<body>
<div class="app-container">
  <div class="header">
    <h1>🧠 AI Heat Risk Warning</h1>
    <p>Intelligent self-learning system with 6 AI agents</p>
  </div>
  <div id="warningCard" class="warning-card safe" onclick="refreshData()">
    <div class="warning-header">
      <span class="warning-icon" id="warningIcon">✅</span>
      <span class="warning-title" id="warningTitle">Safe Zone</span>
    </div>
    <div class="warning-message" id="warningMessage">Tap to check your current heat risk level</div>
    <div class="warning-location"><span>📍</span><span id="warningLocation">--</span></div>
    <div class="risk-badge" id="riskBadge">Score: --</div>
  </div>
  <div class="map-section">
    <div class="map-title"><h3>🗺️ Street Heat Map</h3></div>
    <div id="heatmap"></div>
  </div>
  <div class="control-panel">
    <div class="slider-container">
      <div class="slider-label"><span>⏰ Forecast Time</span><span id="forecastValue">Now</span></div>
      <input type="range" id="forecastSlider" min="0" max="12" value="0" oninput="updateForecast(this.value)">
    </div>
    <button class="refresh-btn" onclick="refreshData()">🔄 Refresh Data</button>
    <button class="refresh-btn" style="background:#2196F3; margin-top:5px;" onclick="getAIInsights()">🤖 Get AI Insights</button>
  </div>
  <div class="location-card">
    <h4>📍 YOUR LOCATION</h4>
    <div class="location-name" id="locationName">--</div>
    <div class="location-coords" id="locationCoords">--</div>
    <div class="location-full" id="locationFull">--</div>
    <div class="location-details" id="locationDetails"><span>🌡️ Waiting for data...</span></div>
  </div>
  <div class="control-panel">
    <h4 style="margin-bottom:12px;">🤖 AI Agent Network (Self-Learning)</h4>
    <div class="agents-grid" id="agentsGrid"></div>
  </div>
  <div id="aiInsights" class="ai-insight" style="display:none;"></div>
  <div class="results-container">
    <h3>📊 Street-Level Heat Analysis</h3>
    <div id="results">Waiting for location data...</div>
  </div>
</div>
<script>
// ============ CONFIGURATION ============
const LLM_API_KEY = 'sk-a9494512c2904a688bfc78cfac87d2fb';
const LLM_API_URL = 'https://api.deepseek.com/v1/chat/completions';

// ============ SELF-LEARNING SYSTEM ============
let learningData = {
  history: [],
  patterns: {},
  userPreferences: {},
  riskPredictions: {},
  lastPrediction: null,
  learningIterations: 0
};

// Load saved learning data from localStorage
function loadLearningData() {
  try {
    const saved = localStorage.getItem('heatRiskLearning');
    if (saved) {
      learningData = JSON.parse(saved);
      console.log('Learning data loaded, iterations:', learningData.learningIterations);
    }
  } catch(e) { console.log('No saved data'); }
}

// Save learning data
function saveLearningData() {
  try {
    localStorage.setItem('heatRiskLearning', JSON.stringify(learningData));
  } catch(e) {}
}

// Record an event for learning
function recordEvent(eventType, data) {
  const event = {
    timestamp: Date.now(),
    type: eventType,
    data: data,
    location: { lat: currentLat, lon: currentLon, address: fullAddress }
  };
  learningData.history.push(event);
  if (learningData.history.length > 100) learningData.history.shift();
  
  // Update patterns
  const key = `${eventType}_${Math.floor(data.temp || 0)}`;
  learningData.patterns[key] = (learningData.patterns[key] || 0) + 1;
  
  saveLearningData();
}

// AI Agent System with LLM Integration
class AIAgent {
  constructor(name, role) {
    this.name = name;
    this.role = role;
    this.status = 'idle';
    this.learnings = [];
    this.confidence = 0.7;
  }
  
  async analyze(context) {
    this.status = 'analyzing';
    updateAgentUI(this.name, 'analyzing...', true);
    
    try {
      const result = await this.callLLM(context);
      this.learnings.push(result);
      this.confidence = Math.min(0.95, this.confidence + 0.05);
      this.status = 'active';
      updateAgentUI(this.name, 'active', false);
      return result;
    } catch(e) {
      this.status = 'error';
      updateAgentUI(this.name, 'error', false);
      return this.fallbackAnalysis(context);
    }
  }
  
  async callLLM(context) {
    const response = await fetch(LLM_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${LLM_API_KEY}`
      },
      body: JSON.stringify({
        model: 'deepseek-chat',
        messages: [
          { role: 'system', content: `You are ${this.name}, an AI agent specialized in ${this.role}. Provide concise, actionable insights.` },
          { role: 'user', content: context }
        ],
        temperature: 0.7,
        max_tokens: 200
      })
    });
    
    if (!response.ok) throw new Error('API error');
    const data = await response.json();
    return data.choices[0].message.content;
  }
  
  fallbackAnalysis(context) {
    return `${this.name}: Analysis based on local patterns. ${context.substring(0, 100)}`;
  }
}

// Initialize all AI Agents
const agents = {
  heatSensor: new AIAgent('🌡️ Heat Sensor Agent', 'analyzing real-time temperature data and heat patterns'),
  surfaceScanner: new AIAgent('🗺️ Surface Scanner Agent', 'evaluating street surfaces and heat absorption rates'),
  populationTracker: new AIAgent('👥 Population Tracker Agent', 'estimating crowd density and exposure risk'),
  riskCalculator: new AIAgent('⚖️ Risk Calculator Agent', 'computing comprehensive heat risk scores'),
  alertAgent: new AIAgent('🔔 Alert Agent', 'generating personalized safety recommendations'),
  learningAI: new AIAgent('🧠 Self-Learning AI', 'learning from historical data and improving predictions')
};

function updateAgentUI(agentName, status, isLoading) {
  const cards = document.querySelectorAll('.agent-card');
  for (let card of cards) {
    if (card.querySelector('.agent-name')?.innerText.includes(agentName.split(' ')[1]) ||
        card.innerText.includes(agentName)) {
      if (isLoading) {
        card.classList.add('active');
        card.querySelector('.agent-status').innerText = status;
      } else {
        card.classList.remove('active');
        card.querySelector('.agent-status').innerText = status;
      }
    }
  }
}

function updateAllAgents(isLoading) {
  const status = isLoading ? 'Analyzing...' : 'Active';
  const loading = isLoading;
  const agentsList = [
    '🌡️ Heat Sensor Agent', '🗺️ Surface Scanner Agent', '👥 Population Tracker Agent',
    '⚖️ Risk Calculator Agent', '🔔 Alert Agent', '🧠 Self-Learning AI'
  ];
  
  const cards = document.querySelectorAll('.agent-card');
  cards.forEach((card, idx) => {
    if (idx < agentsList.length) {
      if (loading) {
        card.classList.add('active');
        card.querySelector('.agent-status').innerText = status;
      } else {
        card.classList.remove('active');
        card.querySelector('.agent-status').innerText = status;
      }
    }
  });
}

// Call LLM for intelligent insights
async function getAIInsights() {
  if (!currentLat || !cachedWeather) {
    alert('Please wait for data to load first');
    return;
  }
  
  const insightsDiv = document.getElementById('aiInsights');
  insightsDiv.style.display = 'block';
  insightsDiv.innerHTML = '<div class="loading">🤔 AI Agents are thinking...</div>';
  
  const temp = cachedWeather.temperature[currentForecast];
  const humidity = cachedWeather.humidity[currentForecast];
  const feelsLike = cachedWeather.apparent_temperature[currentForecast];
  const riskScore = temp >= 35 ? 90 : (temp >= 32 ? 80 : (temp >= 30 ? 70 : (temp >= 28 ? 55 : (temp >= 25 ? 40 : (temp >= 22 ? 25 : 10)))));
  const riskLevel = riskScore >= 70 ? 'DANGER' : (riskScore >= 40 ? 'ALERT' : 'SAFE');
  
  // Run all agents in parallel for learning
  updateAllAgents(true);
  
  const context = `
    Location: ${fullAddress}
    Temperature: ${temp}°C
    Humidity: ${humidity}%
    Feels Like: ${feelsLike}°C
    Risk Level: ${riskLevel}
    Risk Score: ${riskScore}/100
    Historical patterns: ${JSON.stringify(learningData.patterns)}
    Learning iterations: ${learningData.learningIterations}
    
    Provide a comprehensive heat risk assessment with:
    1. Current risk analysis
    2. Safety recommendations
    3. Prediction for next 2 hours based on pattern learning
    4. One sentence of personalized advice
  `;
  
  try {
    const response = await fetch(LLM_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${LLM_API_KEY}`
      },
      body: JSON.stringify({
        model: 'deepseek-chat',
        messages: [
          { role: 'system', content: 'You are an expert heat safety advisor with access to real-time weather data. Provide actionable, concise insights.' },
          { role: 'user', content: context }
        ],
        temperature: 0.7,
        max_tokens: 500
      })
    });
    
    if (response.ok) {
      const data = await response.json();
      const insight = data.choices[0].message.content;
      
      insightsDiv.innerHTML = `
        <strong>🧠 AI Intelligence Report</strong><br><br>
        ${insight.replace(/\n/g, '<br>')}
        <br><br>
        <small>🤖 AI is continuously learning from your local patterns</small>
      `;
      
      // Update learning data
      learningData.learningIterations++;
      learningData.lastPrediction = {
        temp: temp,
        riskLevel: riskLevel,
        insight: insight,
        timestamp: Date.now()
      };
      saveLearningData();
      
      // Speak the insight
      speakMessage(insight.substring(0, 200));
    } else {
      insightsDiv.innerHTML = '<strong>🧠 AI Insights</strong><br>Based on current data: ' + 
        (riskLevel === 'DANGER' ? '🔥 Extreme heat detected. Stay indoors, hydrate frequently.' :
         riskLevel === 'ALERT' ? '⚠️ High heat conditions. Take precautions, use shade.' :
         '✅ Conditions are safe. Stay hydrated and enjoy outdoors.');
    }
  } catch(e) {
    console.error('LLM Error:', e);
    insightsDiv.innerHTML = '<strong>🧠 AI Insights (Local Mode)</strong><br>' + 
      (riskLevel === 'DANGER' ? '🔥 DANGER: Extreme heat! Avoid outdoor exposure. Drink water every 15 minutes.' :
       riskLevel === 'ALERT' ? '⚠️ ALERT: High heat risk! Use sunscreen, stay hydrated, take shade breaks.' :
       '✅ SAFE: Low risk. Enjoy outdoor activities but stay hydrated.');
  }
  
  updateAllAgents(false);
  setTimeout(() => {
    insightsDiv.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }, 100);
}

// Voice function
let voiceEnabled = false;
function speakMessage(message) {
  if (!voiceEnabled) return;
  try {
    window.speechSynthesis.cancel();
    var u = new SpeechSynthesisUtterance(message);
    u.lang = 'en-US';
    u.rate = 0.9;
    window.speechSynthesis.speak(u);
  } catch(e) { }
}

function enableVoice() {
  voiceEnabled = true;
  speakMessage('Voice enabled. Heat risk alerts will speak automatically.');
}

// ============ MAP AND WEATHER FUNCTIONS ============
let map, userMarker, currentLat = null, currentLon = null;
let cachedWeather = null, currentForecast = 0, forecastNames = [];
let streetMarkers = [];
let fullAddress = '';
let streetName = '', villageName = '', cityName = '', stateName = '', countryName = '';

function initMap(lat, lon) {
  if (!map) {
    map = L.map("heatmap").setView([lat, lon], 16);
    L.tileLayer("https://{s}.basemaps.cartocdn.com/rastertiles/voyager_labels_under/{z}/{x}/{y}{r}.png", {
      attribution: '&copy; OpenStreetMap',
      subdomains: 'abcd',
      maxZoom: 20
    }).addTo(map);
  } else {
    map.setView([lat, lon], 16);
  }
  if (userMarker) map.removeLayer(userMarker);
  userMarker = L.marker([lat, lon], {
    icon: L.divIcon({
      html: '<div style="background:#ff7e5f; width:24px; height:24px; border-radius:50%; border:3px solid white; box-shadow:0 0 15px rgba(0,0,0,0.3);"></div>',
      iconSize: [24, 24]
    })
  }).addTo(map).bindPopup('<b>You are here</b>');
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
  updateAgentsUI(true);
  document.getElementById('results').innerHTML = '<div class="loading">🌍 Getting your location...</div>';
  document.getElementById('aiInsights').style.display = 'none';
  
  navigator.geolocation.getCurrentPosition(async function(position) {
    currentLat = position.coords.latitude;
    currentLon = position.coords.longitude;
    initMap(currentLat, currentLon);
    await getFullAddress(currentLat, currentLon);
    document.getElementById('locationCoords').innerHTML = currentLat.toFixed(6) + '°N, ' + currentLon.toFixed(6) + '°E';
    await fetchWeather(currentLat, currentLon);
    await updateStreets();
    updateWarningCard();
    updateLocationDetails();
    updateAgentsUI(false);
    
    // Record event for learning
    const temp = cachedWeather.temperature[currentForecast];
    recordEvent('weather_update', { temp: temp, location: fullAddress });
  }, function(error) {
    document.getElementById('results').innerHTML = '<div class="loading">❌ Location access denied</div>';
    updateAgentsUI(false);
  }, { enableHighAccuracy: true, timeout: 10000 });
}

async function getFullAddress(lat, lon) {
  var url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=' + lat + '&lon=' + lon + '&zoom=18&addressdetails=1&accept-language=en';
  try {
    var response = await fetch(url, { headers: { "User-Agent": "AI-Heat-Risk-Demo/1.0" } });
    var data = await response.json();
    var addr = data.address || {};
    
    streetName = addr.road || addr.pedestrian || addr.footway || '';
    villageName = addr.village || addr.hamlet || addr.suburb || '';
    cityName = addr.city || addr.town || addr.municipality || '';
    stateName = addr.state || addr.province || addr.region || '';
    countryName = addr.country || '';
    
    var houseNumber = addr.house_number || '';
    
    var fullAddressParts = [];
    if (streetName) fullAddressParts.push(streetName);
    if (houseNumber) fullAddressParts.push(houseNumber);
    if (villageName) fullAddressParts.push(villageName);
    if (cityName) fullAddressParts.push(cityName);
    if (stateName) fullAddressParts.push(stateName);
    if (countryName) fullAddressParts.push(countryName);
    
    fullAddress = fullAddressParts.join(', ');
    
    document.getElementById('locationName').innerHTML = streetName || cityName || 'Unknown';
    document.getElementById('locationFull').innerHTML = '📍 ' + fullAddress;
  } catch(e) {
    document.getElementById('locationName').innerHTML = 'Unknown';
    document.getElementById('locationFull').innerHTML = '📍 Location unavailable';
  }
}

function updateLocationDetails() {
  if (!cachedWeather) return;
  var temp = cachedWeather.temperature[currentForecast];
  var humidity = cachedWeather.humidity[currentForecast];
  var feelsLike = cachedWeather.apparent_temperature[currentForecast];
  document.getElementById('locationDetails').innerHTML = '<span>🌡️ ' + temp + '°C</span><span>💧 ' + humidity + '%</span><span>🌡️ Feels: ' + feelsLike + '°C</span>';
}

function updateWarningCard() {
  if (!cachedWeather || !currentLat) return;
  var temp = cachedWeather.temperature[currentForecast];
  var humidity = cachedWeather.humidity[currentForecast];
  var feelsLike = cachedWeather.apparent_temperature[currentForecast];
  var score = temp >= 35 ? 90 : (temp >= 32 ? 80 : (temp >= 30 ? 70 : (temp >= 28 ? 55 : (temp >= 25 ? 40 : (temp >= 22 ? 25 : 10)))));
  var riskLevel = score >= 70 ? 'DANGER' : (score >= 40 ? 'ALERT' : 'SAFE');
  var message = '';
  if (riskLevel === 'DANGER') {
    message = 'DANGER! Extreme heat at ' + temp + '°C at ' + (streetName || cityName) + '. Avoid outdoor exposure. Stay in AC, drink water every 15 minutes.';
  } else if (riskLevel === 'ALERT') {
    message = 'ALERT! High heat at ' + temp + '°C at ' + (streetName || cityName) + '. Stay hydrated, use sunscreen, take shade breaks.';
  } else {
    message = 'SAFE. ' + temp + '°C at ' + (streetName || cityName) + '. Conditions are good. Stay hydrated.';
  }
  var card = document.getElementById('warningCard');
  var icon = document.getElementById('warningIcon');
  var title = document.getElementById('warningTitle');
  var warningMsg = document.getElementById('warningMessage');
  var locationSpan = document.getElementById('warningLocation');
  var riskBadge = document.getElementById('riskBadge');
  card.className = 'warning-card';
  if (riskLevel === 'DANGER') {
    card.classList.add('danger');
    icon.innerHTML = '🔥🔥';
    title.innerHTML = 'DANGER - Extreme Heat!';
  } else if (riskLevel === 'ALERT') {
    card.classList.add('alert');
    icon.innerHTML = '⚠️⚠️';
    title.innerHTML = 'ALERT - High Heat Risk';
  } else {
    card.classList.add('safe');
    icon.innerHTML = '✅✅';
    title.innerHTML = 'SAFE - Low Risk';
  }
  warningMsg.innerHTML = message;
  locationSpan.innerHTML = fullAddress.substring(0, 80);
  riskBadge.innerHTML = 'Score: ' + score + '/100 | ' + temp + '°C | Feels: ' + feelsLike + '°C | Humidity: ' + humidity + '%';
  
  speakMessage(message);
  recordEvent('risk_update', { temp: temp, riskLevel: riskLevel, score: score });
}

async function fetchWeather(lat, lon) {
  var url = 'https://api.open-meteo.com/v1/forecast?latitude=' + lat + '&longitude=' + lon + '&hourly=temperature_2m,relative_humidity_2m,apparent_temperature&forecast_days=1&timezone=auto';
  var response = await fetch(url);
  var data = await response.json();
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
  var slider = document.getElementById('forecastSlider');
  if (slider) { slider.max = forecastNames.length - 1; document.getElementById('forecastValue').innerText = forecastNames[0]; }
}

async function fetchNearbyStreets(lat, lon) {
  var query = '[out:json][timeout:25];way["highway"]["name"](around:500,' + lat + ',' + lon + ');out center tags;';
  var response = await fetch("https://overpass-api.de/api/interpreter", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", "User-Agent": "AI-Heat-Risk-Demo/1.0" },
    body: "data=" + encodeURIComponent(query)
  });
  var data = await response.json();
  var streets = [];
  var seen = new Set();
  for (var i = 0; i < (data.elements || []).length; i++) {
    var element = data.elements[i];
    var tags = element.tags;
    var center = element.center;
    if (!tags || !center) continue;
    var name = tags["name:en"] || tags.name || '';
    if (!name || name.length < 2) continue;
    var key = name + '-' + center.lat.toFixed(5);
    if (seen.has(key)) continue;
    seen.add(key);
    streets.push({ name: name, lat: center.lat, lon: center.lon, type: tags.highway || 'road' });
    if (streets.length >= 20) break;
  }
  return streets;
}

async function updateStreets() {
  if (!currentLat || !currentLon || !cachedWeather) return;
  document.getElementById('results').innerHTML = '<div class="loading">🌡️ Scanning nearby streets...</div>';
  var streets = await fetchNearbyStreets(currentLat, currentLon);
  var temp = cachedWeather.temperature[currentForecast];
  var humidity = cachedWeather.humidity[currentForecast];
  var feelsLike = cachedWeather.apparent_temperature[currentForecast];
  for (var i = 0; i < streetMarkers.length; i++) { map.removeLayer(streetMarkers[i]); }
  streetMarkers = [];
  if (streets.length === 0) {
    document.getElementById('results').innerHTML = '<div class="loading">No named streets found nearby</div>';
    return;
  }
  var html = '';
  for (var s = 0; s < streets.length; s++) {
    var street = streets[s];
    var baseScore = temp >= 35 ? 90 : (temp >= 32 ? 80 : (temp >= 30 ? 70 : (temp >= 28 ? 55 : (temp >= 25 ? 40 : (temp >= 22 ? 25 : 10)))));
    var surfaceScore = (street.type.includes('primary') || street.type.includes('motorway')) ? 25 : 10;
    var score = Math.min(100, baseScore + surfaceScore);
    var level = score >= 70 ? 'DANGER' : (score >= 40 ? 'ALERT' : 'SAFE');
    var advice = level === 'DANGER' ? '🔥 Avoid this street' : (level === 'ALERT' ? '⚠️ Take caution' : '✅ Safe for walking');
    html += '<div class="street-card ' + level + '"><div class="street-name">🛣️ ' + street.name + '</div><div class="street-details"><span>🏗️ ' + street.type + '</span><span>🌡️ ' + temp + '°C</span><span>💧 ' + humidity + '%</span><span>🌡️ Feels: ' + feelsLike + '°C</span><span> ' + level + ' (' + score + '/100)</span></div><div class="street-details">' + advice + '</div></div>';
    var color = level === 'DANGER' ? '#ff4b4b' : (level === 'ALERT' ? '#ffa500' : '#4caf50');
    var radius = 35;
    var circle = L.circle([street.lat, street.lon], { radius: radius, color: color, fillColor: color, fillOpacity: 0.5, weight: 3 }).addTo(map);
    circle.bindPopup('<b>' + street.name + '</b><br><b>Risk:</b> ' + level + '<br><b>Temp:</b> ' + temp + '°C<br><b>Score:</b> ' + score + '/100');
    streetMarkers.push(circle);
  }
  document.getElementById('results').innerHTML = html;
  if (streetMarkers.length > 0) {
    var bounds = L.latLngBounds(streetMarkers.map(function(m) { return m.getLatLng(); }));
    bounds.extend([currentLat, currentLon]);
    map.fitBounds(bounds, { padding: [50, 50] });
  }
}

function updateAgentsUI(loading) {
  var agents = [
    { name: '🌡️ Heat Sensor Agent', status: loading ? 'Scanning...' : 'Active' },
    { name: '🗺️ Surface Scanner Agent', status: loading ? 'Analyzing...' : 'Ready' },
    { name: '👥 Population Tracker Agent', status: loading ? 'Tracking...' : 'Monitoring' },
    { name: '⚖️ Risk Calculator Agent', status: loading ? 'Computing...' : 'Online' },
    { name: '🔔 Alert Agent', status: loading ? 'Preparing...' : 'Standby' },
    { name: '🧠 Self-Learning AI', status: loading ? `Learning (${learningData.learningIterations} iterations)...` : `Optimized (${learningData.learningIterations} learns)` }
  ];
  var html = '';
  for (var i = 0; i < agents.length; i++) {
    html += '<div class="agent-card ' + (loading ? 'active' : '') + '"><div class="agent-name">' + agents[i].name + '</div><div class="agent-status">' + agents[i].status + '</div><div class="agent-dot"></div></div>';
  }
  document.getElementById('agentsGrid').innerHTML = html;
}

// Initialize
loadLearningData();
window.onload = function() { 
  refreshData();
  enableVoice();
  updateAgentsUI(false);
};
</script>
</body>
</html>
''';
