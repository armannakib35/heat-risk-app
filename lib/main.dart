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
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <link rel="stylesheet" href="https://unpkg.com/leaflet/dist/leaflet.css" />

  <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;700&display=swap" rel="stylesheet">

  <style>
    body {
      font-family: 'Roboto', sans-serif;
      background: #f0f3f8;
      margin: 0;
      padding: 0;
    }

    .app {
      max-width: 550px;
      margin: 20px auto;
      background: #ffffff;
      border-radius: 20px;
      padding: 20px;
      box-shadow: 0 12px 30px rgba(0,0,0,0.15);
    }

    h2 {
      background: linear-gradient(90deg, #ff7e5f, #feb47b);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      font-size: 26px;
      margin-bottom: 5px;
    }

    p.description {
      font-size: 14px;
      color: #555;
      margin-top: 0;
    }

    button {
      width: 100%;
      padding: 14px;
      background: #ff7e5f;
      color: white;
      border: none;
      border-radius: 12px;
      font-size: 16px;
      margin-top: 15px;
      cursor: pointer;
      transition: all 0.3s ease;
    }

    button:hover {
      background: #feb47b;
      transform: translateY(-2px);
    }

    #map {
      height: 400px;
      border-radius: 15px;
      margin-top: 20px;
      box-shadow: 0 6px 20px rgba(0,0,0,0.1);
      border: 2px solid #ff7e5f33;
    }

    .slider-box {
      margin-top: 15px;
      padding: 12px;
      background: #f7f7f7;
      border-radius: 12px;
    }

    input[type="range"] {
      width: 100%;
    }

    .agents {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-top: 20px;
    }

    .agent {
      background: #eef2ff;
      padding: 12px;
      border-radius: 14px;
      font-size: 13px;
      position: relative;
      box-shadow: 0 4px 12px rgba(0,0,0,0.08);
    }

    .agent::after {
      content: "";
      position: absolute;
      top: 12px;
      right: 12px;
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: #4caf50;
      animation: blink 1.2s infinite;
    }

    @keyframes blink {
      0%, 50%, 100% { opacity: 1; }
      25%, 75% { opacity: 0; }
    }

    #placeBox {
      background: #f9f9f9;
      padding: 14px;
      border-radius: 14px;
      margin-top: 15px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.08);
      font-size: 14px;
    }

    .card {
      padding: 14px;
      border-radius: 14px;
      background: #fdfdfd;
      margin-top: 12px;
      box-shadow: 0 6px 16px rgba(0,0,0,0.05);
      border-left: 6px solid;
    }

    .DANGER { border-color: #ff4b4b; }
    .ALERT { border-color: #ffa500; }
    .SAFE { border-color: #4caf50; }

    .small { font-size: 12px; color: #555; }
  </style>
</head>

<body>
<div class="app">
  <center><h2>AI Heat Risk Warning</h2></center>
  <center><p class="description">Real weather + GPS location + real place names + live nearby streets</p></center>

  <button onclick="getRisk()">Check My Heat Risk</button>

  <div class="slider-box">
    <b>Forecast Time:</b>
    <p id="forecastLabel">Now</p>
    <input type="range" min="0" max="2" value="0" id="forecastSlider" onchange="changeForecast(this.value)">
  </div>

  <div id="placeBox">Location not checked yet.</div>
  <div id="map"></div>

  <center><h3>AI Agent System</h3></center>
  <div class="agents" id="agents"></div>

  <center><h3>Street Risk Results</h3></center>
  <div id="result"></div>
</div>

<script src="https://unpkg.com/leaflet/dist/leaflet.js"></script>

<script>
let map, userMarker, streetMarkers=[], currentForecast=0, lastLat=null, lastLon=null;
let forecastNames=["Now","+2 Hours","+6 Hours"];
let cachedWeather=null;

function initMap(lat, lon){
    if(!map){
        map=L.map("map").setView([lat, lon],15);
        L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}",{
            attribution:"Tiles &copy; Esri", maxZoom:16
        }).addTo(map);
        userMarker=L.marker([lat,lon]).addTo(map).bindPopup("Loading location...").openPopup();
    } else { 
        map.setView([lat,lon],15); 
        userMarker.setLatLng([lat,lon]); 
    }
}

function updateAgentPanel(){
    const agents=[
        ["Heat Sensor Agent","Fetching real Open-Meteo weather"],
        ["Surface Scanner Agent","Reading real OSM streets"],
        ["People Tracker Agent","Estimating street exposure"],
        ["Risk Calculator Agent","Calculating heat danger score"],
        ["Alert Agent","Preparing safety warning"],
        ["Self Learning Agent","Ready for future data"]
    ];
    let html="";
    agents.forEach(a=>html+=`<div class="agent"><b>${a[0]}</b><br>${a[1]}</div>`);
    document.getElementById("agents").innerHTML=html;
}

function getColor(level){ 
    return level==="DANGER"?"#ff4b4b":level==="ALERT"?"#ffa500":"#4caf50"; 
}

function highwayToSurface(highway){
    const concrete=["motorway","trunk","primary","secondary","tertiary","unclassified"];
    const mixed=["residential","service","living_street","pedestrian","footway","cycleway"];
    if(concrete.includes(highway)) return "Road / Concrete";
    if(mixed.includes(highway)) return "Mixed Area";
    return "Park / Trees";
}

function getSurfaceScore(surface){
    if(surface==="Road / Concrete") return 30;
    if(surface==="Mixed Area") return 18;
    if(surface==="Park / Trees") return 6;
    return 15;
}

function calculateRisk(temp, humidity, apparentTemp, surfaceScore){
    const tempScore=Math.max(0,(temp-24)*3);
    const humidityScore=Math.max(0,(humidity-55)*0.35);
    const feelsLikeScore=Math.max(0,(apparentTemp-27)*2);
    let riskScore=Math.round(tempScore+humidityScore+feelsLikeScore+surfaceScore);
    riskScore=Math.max(0,Math.min(100,riskScore));

    if(riskScore>=70){
        return {
            risk_score:riskScore,
            level:"DANGER",
            advice:"Avoid outdoor exposure and use shaded routes."
        };
    }
    if(riskScore>=40){
        return {
            risk_score:riskScore,
            level:"ALERT",
            advice:"Take precautions, stay hydrated, and avoid long exposure."
        };
    }
    return {
        risk_score:riskScore,
        level:"SAFE",
        advice:"Area is safe for outdoor activity."
    };
}

async function loadPlaceName(lat, lon){
    const url=`https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lon}&zoom=18&addressdetails=1&accept-language=en`;
    const response=await fetch(url,{headers:{"User-Agent":"AI-Heat-Risk-Demo/1.0"}});
    const data=await response.json();
    const shortLocation = data.display_name ? data.display_name.split(",").slice(0,3).join(",") : "Current location";
    if(userMarker){
      userMarker.bindPopup(shortLocation).openPopup();
    }

    document.getElementById("placeBox").innerHTML=
        `<b>Current Location:</b><br>${data.display_name || "Unknown location"}<br>
        <span class="small">Lat: ${lat.toFixed(5)}<br>Lon: ${lon.toFixed(5)}</span>`;
}

async function fetchWeather(lat, lon){
    const url=`https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&hourly=temperature_2m,relative_humidity_2m,apparent_temperature&forecast_days=1&timezone=auto`;
    const response=await fetch(url);
    const data=await response.json();

    const now = new Date();
    const currentHour = now.getHours();

    let startIndex = 0;
    for(let i=0; i<data.hourly.time.length; i++){
        const forecastTime = new Date(data.hourly.time[i]);
        if(forecastTime.getHours() >= currentHour){
            startIndex = i;
            break;
        }
    }

    cachedWeather={
        time:[
            data.hourly.time[startIndex],
            data.hourly.time[startIndex+2],
            data.hourly.time[startIndex+4],
            data.hourly.time[startIndex+6]
        ],
        temperature:[
            data.hourly.temperature_2m[startIndex],
            data.hourly.temperature_2m[startIndex+2],
            data.hourly.temperature_2m[startIndex+4],
            data.hourly.temperature_2m[startIndex+6]
        ],
        humidity:[
            data.hourly.relative_humidity_2m[startIndex],
            data.hourly.relative_humidity_2m[startIndex+2],
            data.hourly.relative_humidity_2m[startIndex+4],
            data.hourly.relative_humidity_2m[startIndex+6]
        ],
        apparent_temperature:[
            data.hourly.apparent_temperature[startIndex],
            data.hourly.apparent_temperature[startIndex+2],
            data.hourly.apparent_temperature[startIndex+4],
            data.hourly.apparent_temperature[startIndex+6]
        ]
    };

    forecastNames = cachedWeather.time.map(t => {
        const d = new Date(t);
        return d.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
    });

    document.getElementById("forecastSlider").max = forecastNames.length - 1;
    document.getElementById("forecastSlider").value = 0;
    document.getElementById("forecastLabel").innerText = forecastNames[0];
}

async function fetchStreets(lat, lon){
    const query=`[out:json][timeout:25];way["highway"](around:900,${lat},${lon});out center tags;`;
    const response=await fetch("https://overpass-api.de/api/interpreter",{
        method:"POST",
        headers:{"Content-Type":"application/x-www-form-urlencoded","User-Agent":"AI-Heat-Risk-Demo/1.0"},
        body:"data="+encodeURIComponent(query)
    });
    const data=await response.json();

    const seen=new Set();
    const streets=[];

    for(const element of data.elements || []){
        const tags=element.tags;
        const center=element.center;
        if(!tags || !center) continue;

        const highway=tags.highway || "road";
        const name=tags["name:en"] || tags.name || `Unnamed ${highway} road`;
        const key=`${name}-${center.lat.toFixed(5)}-${center.lon.toFixed(5)}`;
        if(seen.has(key)) continue;
        seen.add(key);

        streets.push({
            name:name,
            lat:center.lat,
            lon:center.lon,
            surface:highwayToSurface(highway),
            highway_type:highway
        });

        if(streets.length>=20) break;
    }

    return {
        source:"OpenStreetMap Overpass API",
        count:streets.length,
        streets:streets
    };
}

async function loadStreets(lat, lon){
    document.getElementById("result").innerHTML="Loading streets & heat risk...";
    streetMarkers.forEach(m=>map.removeLayer(m));
    streetMarkers=[];

    if(!cachedWeather){
        await fetchWeather(lat, lon);
    }

    const data=await fetchStreets(lat, lon);

    if(!data.streets || data.streets.length===0){
        document.getElementById("result").innerHTML=`<div class="card">No nearby streets found.</div>`;
        return;
    }

    let resultHtml=`<div class="card"><b>Source:</b> ${data.source}<br><b>Count:</b> ${data.count}</div>`;
    let bounds=[[lat,lon]];

    for(const street of data.streets){
        const index=currentForecast;

        const temp=cachedWeather.temperature[index];
        const humidity=cachedWeather.humidity[index];
        const apparentTemp=cachedWeather.apparent_temperature[index];
        const time=cachedWeather.time[index];

        const surfaceScore=getSurfaceScore(street.surface);
        const riskData=calculateRisk(temp,humidity,apparentTemp,surfaceScore);

        const item={
            forecast:forecastNames[currentForecast],
            time:time,
            temperature:temp,
            humidity:humidity,
            apparent_temperature:apparentTemp,
            risk_score:riskData.risk_score,
            level:riskData.level,
            advice:riskData.advice
        };

        const color=getColor(item.level);
        bounds.push([street.lat,street.lon]);

        const circle=L.circle([street.lat,street.lon],{
            radius:20+item.risk_score,
            color:color,
            fillColor:color,
            fillOpacity:0.4,
            weight:3
        })
        .addTo(map)
        .bindPopup(`<b>${street.name}</b><br>Road: ${street.highway_type}<br>Surface: ${street.surface}<br>${item.forecast}: ${item.level}<br>Risk: ${item.risk_score}/100<br>Temp: ${item.temperature}°C`);
        streetMarkers.push(circle);

        resultHtml+=`<div class="card ${item.level}"><h3>${street.name}: ${item.level}</h3>
        <p><b>Road Type:</b> ${street.highway_type}</p><p><b>Surface:</b> ${street.surface}</p>
        <p><b>Forecast:</b> ${item.forecast}</p><p><b>Time:</b> ${item.time}</p>
        <p><b>Temp:</b> ${item.temperature}°C | <b>Humidity:</b> ${item.humidity}% | <b>Feels Like:</b> ${item.apparent_temperature}°C</p>
        <p><b>Risk Score:</b> ${item.risk_score}/100</p><p>${item.advice}</p></div>`;
    }

    map.fitBounds(bounds,{padding:[35,35]});
    document.getElementById("result").innerHTML=resultHtml;
}

function changeForecast(value){ 
    currentForecast=Number(value); 
    document.getElementById("forecastLabel").innerText=forecastNames[currentForecast]; 
    if(lastLat!==null && lastLon!==null){ 
        loadStreets(lastLat,lastLon); 
    } 
}

async function getRisk(){
    document.getElementById("result").innerHTML="Getting location...";
    document.getElementById("placeBox").innerHTML="Getting real place name...";
    updateAgentPanel();

    navigator.geolocation.getCurrentPosition(async function(position){
        lastLat=position.coords.latitude; 
        lastLon=position.coords.longitude;
        cachedWeather=null;
        initMap(lastLat,lastLon);
        await loadPlaceName(lastLat,lastLon);
        await fetchWeather(lastLat,lastLon);
        await loadStreets(lastLat,lastLon);
    },function(){
        document.getElementById("result").innerHTML="Location permission denied."; 
        document.getElementById("placeBox").innerHTML="Location permission denied."; 
    }, {enableHighAccuracy:true,timeout:15000,maximumAge:0});
}
</script>
</body>
</html>
''';
