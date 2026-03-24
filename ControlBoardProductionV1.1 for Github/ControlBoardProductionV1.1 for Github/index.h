const char index_html[] PROGMEM = R"=====(
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>LIMI WiFi Setup</title>
  <style>
    body { font-family: Arial; text-align: center; margin: 20px; }
    input { padding: 8px; margin: 5px; width: 80%; }
    button { padding: 10px 20px; }
    #status { margin-top: 20px; font-weight: bold; }
  </style>
</head>
<body>
  <h2>WiFi Setup</h2>
  <form id="wifiForm">
    <input type="text" name="ssid" placeholder="WiFi SSID" required><br>
    <input type="password" name="password" placeholder="WiFi Password" required><br>
    <button type="submit">Connect</button>
  </form>
  <div id="status"></div>

  <script>
    const form = document.getElementById('wifiForm');
    const statusDiv = document.getElementById('status');

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      statusDiv.textContent = 'Connecting...';

      const formData = new FormData(form);
      const ssid = formData.get('ssid');
      const password = formData.get('password');

      try {
        const resp = await fetch('/wifi', {
          method: 'POST',
          body: new URLSearchParams({ ssid, password })
        });

        if (resp.ok) {
          const data = await resp.json();
          if (data.status === 'saved') {
            statusDiv.textContent = 'Saved! Rebooting...';
          } else {
            statusDiv.textContent = 'Error saving credentials';
          }
        } else {
          statusDiv.textContent = 'Error connecting';
        }
      } catch (err) {
        statusDiv.textContent = 'Request failed';
      }
    });
  </script>
</body>
</html>
)=====";


const char MAIN_pageA[] PROGMEM = R"=====(
<!DOCTYPE html>
<html>
<head>
    <title>LIMI Test</title>
    <meta name='viewport' content='width=device-width, initial-scale=1'>
<script>
var gateway = `ws://${window.location.hostname}/ws`;
var websocket;
window.addEventListener('load', onload);

let lightingConfig = {
  sets: []
};

function onload(event) {
    initWebSocket();
}

function initWebSocket() {
    websocket = new WebSocket(gateway);
    websocket.onopen = onOpen;
    websocket.onclose = onClose;
    websocket.onmessage = onMessage;
}

function onOpen(event) {
    websocket.send('getConfig');
    startSensorUpdates();
    startNodeUpdates();
}

function onClose(event) {
    setTimeout(initWebSocket, 2000);
}

function onMessage(event) {
    var myObj = JSON.parse(event.data);

    if (myObj.sets) {
      lightingConfig.sets = myObj.sets;
      renderLightingSets(lightingConfig);
      return;
    }
    
    if (myObj.nodes) {
      updateNodeStatus(myObj.nodes);
      return;
    }

    ['bus','shu','cur','pow'].forEach(id => {
        if (myObj[id] !== undefined) {
            let el = document.getElementById(id);
            if (el) el.innerHTML = myObj[id];
        }
    });
}

var sensorTimer;
function startSensorUpdates() {
    sensorTimer = setInterval(() => {
        websocket.send('getSensors');
    }, 3000); 
}

var nodeTimer;
function startNodeUpdates() {
  nodeTimer = setInterval(() => {
    websocket.send('getNodes');
  }, 1000); 
}

function renderLightingSets(config) {
  const container = document.getElementById('lightingSets');
  container.innerHTML = '';

  config.sets.forEach(set => {
    const card = document.createElement('div');
    card.className = 'card';

    // Ensure we are comparing uppercase strings to avoid "pwm" vs "PWM" issues
    const isPWM = set.mode === 'PWM';
    const isRGB = set.mode === 'RGB';
    const isPattern = set.mode === 'PATTERN';

    card.innerHTML = `
      <p class='card-title'>Lighting Set ${set.id + 1}</p>

      <p>
        Mode:
        <select onchange='changeMode(${set.id}, this.value)' class='dropdown'>
          <option value='PWM' ${isPWM ? 'selected' : ''}>CCT White</option>
          <option value='RGB' ${isRGB ? 'selected' : ''}>RGB Solid</option>
          <option value='PATTERN' ${isPattern ? 'selected' : ''}>RGB Pattern</option>
        </select>
      </p>

      <div id='controls-${set.id}'></div>
      <hr>

      <details style="text-align: left; padding: 10px; background: #f0f0f0; border-radius: 5px; margin: 10px;">
        <summary style="font-weight: bold; cursor: pointer;">Advanced Settings</summary>
        <div style="margin-top:10px;">
          <label>LED Count (1-300):</label>
          <input type="number" min="1" max="300" value="${set.ledCount || 300}" onchange="sendAdv(${set.id}, 'LEDS', this.value)" style="width: 60px;"><br><br>
          
          <label>Instant-On Memory:</label>
          <select onchange="sendAdv(${set.id}, 'INST', this.value)">
            <option value="1" ${set.instantOn == 1 ? 'selected' : ''}>Enabled</option>
            <option value="0" ${set.instantOn == 0 ? 'selected' : ''}>Start OFF</option>
          </select><br><br>

          <label>Strip Color Order:</label>
          <select onchange="sendAdv(${set.id}, 'ORD', this.value)">
            <option value="0" ${set.colorOrder == 0 ? 'selected' : ''}>GRB (Standard)</option>
            <option value="1" ${set.colorOrder == 1 ? 'selected' : ''}>RGB</option>
            <option value="2" ${set.colorOrder == 2 ? 'selected' : ''}>RBG</option>
          </select><br><br>

          <label>Color Balance (0-255):</label><br>
          R: <input type="number" max="255" value="${set.balR || 255}" onchange="sendAdv(${set.id}, 'BR', this.value)" style="width: 50px;">
          G: <input type="number" max="255" value="${set.balG || 255}" onchange="sendAdv(${set.id}, 'BG', this.value)" style="width: 50px;">
          B: <input type="number" max="255" value="${set.balB || 255}" onchange="sendAdv(${set.id}, 'BB', this.value)" style="width: 50px;"><br><br>

          <button onclick="sendTrigger(${set.id}, 'DIAG')" style="background: #034078; color: white; border: none; padding: 8px; border-radius: 4px; cursor: pointer; width: 100%;">Run Hardware Diagnostic</button>
        </div>
      </details>

      <div class='state' id='status-${set.id}'> Synchronized </div>
    `;

    container.appendChild(card);
    renderControls(set);
  });
}

function renderControls(set) {
  const el = document.getElementById(`controls-${set.id}`);
  el.innerHTML = '';

  if (set.mode === 'PWM') {
    el.innerHTML = `
      <p class='state'>WW</p>
      <input type='range' min='0' max='255' value='${set.ww !== undefined ? set.ww : 0}'
        onchange='sendPWM(${set.id}, "WW", this.value)' class='slider'>

      <p class='state'>CW</p>
      <input type='range' min='0' max='255' value='${set.cw !== undefined ? set.cw : 0}'
        onchange='sendPWM(${set.id}, "CW", this.value)' class='slider'>
    `;
  }

  if (set.mode === 'RGB') {
    el.innerHTML = `
      <p class='state'>Red</p>
      <input type='range' min='0' max='255' value='${set.r !== undefined ? set.r : 0}'
        onchange='sendRGB(${set.id}, "R", this.value)' class='slider'>

      <p class='state'>Green</p>
      <input type='range' min='0' max='255' value='${set.g !== undefined ? set.g : 0}'
        onchange='sendRGB(${set.id}, "G", this.value)' class='slider'>

      <p class='state'>Blue</p>
      <input type='range' min='0' max='255' value='${set.b !== undefined ? set.b : 0}'
        onchange='sendRGB(${set.id}, "B", this.value)' class='slider'>
    `;
  }

  if (set.mode === 'PATTERN') {
    el.innerHTML = `
      <p class='state'>Pattern Type</p>
      <select onchange='sendPattern(${set.id}, "PAT", this.value)' class='dropdown'>
        <option value='0' ${set.pattern===0?'selected':''}>Off</option>
        <option value='1' ${set.pattern===1?'selected':''}>Solid</option>
        <option value='2' ${set.pattern===2?'selected':''}>Pulse</option>
        <option value='3' ${set.pattern===3?'selected':''}>Rainbow</option>
        <option value='4' ${set.pattern===4?'selected':''}>Rainbow Cycle</option>
        <option value='5' ${set.pattern===5?'selected':''}>Fade</option>
        <option value='6' ${set.pattern===6?'selected':''}>Breathe</option>
        <option value='7' ${set.pattern===7?'selected':''}>Chase</option>
        <option value='8' ${set.pattern===8?'selected':''}>Sparkle</option>
        <option value='9' ${set.pattern===9?'selected':''}>Meteor</option>
        <option value='10' ${set.pattern===10?'selected':''}>Fire</option>
        <option value='11' ${set.pattern===11?'selected':''}>Cylon</option>
        <option value='12' ${set.pattern===12?'selected':''}>Rainbow Strobe</option>
        <option value='13' ${set.pattern===13?'selected':''}>Chase Rainbow</option>
        <option value='14' ${set.pattern===14?'selected':''}>Double Chase</option>
        <option value='15' ${set.pattern===15?'selected':''}>Wave</option>
        <option value='16' ${set.pattern===16?'selected':''}>Running Lights</option>
        <option value='17' ${set.pattern===17?'selected':''}>Rainbow Pulse</option>
        <option value='18' ${set.pattern===18?'selected':''}>Gradient</option>
        <option value='19' ${set.pattern===19?'selected':''}>Dots</option>
        <option value='20' ${set.pattern===20?'selected':''}>Fading Blocks</option>
        <option value='21' ${set.pattern===21?'selected':''}>Bouncing Ball</option>
        <option value='22' ${set.pattern===22?'selected':''}>Flashing</option>
        <option value='23' ${set.pattern===23?'selected':''}>Strobe</option>
        <option value='24' ${set.pattern===24?'selected':''}>Color Wipe</option>
        <option value='25' ${set.pattern===25?'selected':''}>Theater Chase</option>
        <option value='26' ${set.pattern===26?'selected':''}>Twinkle</option>
        <option value='27' ${set.pattern===27?'selected':''}>Rainbow Multi</option>
        <option value='28' ${set.pattern===28?'selected':''}>Alternating</option>
        <option value='29' ${set.pattern===29?'selected':''}>Random Flash</option>
        <option value='30' ${set.pattern===30?'selected':''}>Breathing Rainbow</option>
        <option value='31' ${set.pattern===31?'selected':''}>Segment Rainbow</option>
      </select>

      <p class='state'>Animation Speed</p>
      <input type='range' min='1' max='100' value='${set.speed !== undefined ? set.speed : 50}'
        onchange='sendPattern(${set.id}, "SPD", this.value)' class='slider'>

      <p class='state'>Base Red</p>
      <input type='range' min='0' max='255' value='${set.r !== undefined ? set.r : 255}'
        onchange='sendPattern(${set.id}, "R", this.value)' class='slider'>

      <p class='state'>Base Green</p>
      <input type='range' min='0' max='255' value='${set.g !== undefined ? set.g : 0}'
        onchange='sendPattern(${set.id}, "G", this.value)' class='slider'>

      <p class='state'>Base Blue</p>
      <input type='range' min='0' max='255' value='${set.b !== undefined ? set.b : 0}'
        onchange='sendPattern(${set.id}, "B", this.value)' class='slider'>
    `;
  }
}



function changeMode(setId, mode) {
  websocket.send(JSON.stringify({ type: 'setMode', set: setId, mode: mode }));
  lightingConfig.sets.find(s => s.id === setId).mode = mode;
  renderControls(lightingConfig.sets.find(s => s.id === setId));
}

function sendPWM(setId, channel, value) {
  websocket.send(JSON.stringify({ type: 'pwm', set: setId, channel: channel, value: Number(value) }));
  let s = lightingConfig.sets.find(s => s.id === setId);
  if (channel === 'WW') s.ww = Number(value);
  if (channel === 'CW') s.cw = Number(value);
}

function sendRGB(setId, channel, value) {
  websocket.send(JSON.stringify({ type: 'rgb', set: setId, channel: channel, value: Number(value) }));
  let s = lightingConfig.sets.find(s => s.id === setId);
  if (channel === 'R') s.r = Number(value);
  if (channel === 'G') s.g = Number(value);
  if (channel === 'B') s.b = Number(value);
}

function sendPattern(setId, channel, value) {
  websocket.send(JSON.stringify({ type: 'pattern', set: setId, channel: channel, value: Number(value) }));
  let s = lightingConfig.sets.find(s => s.id === setId);
  if (channel === 'PAT') s.pattern = Number(value);
  if (channel === 'SPD') s.speed = Number(value);
  if (channel === 'R') s.r = Number(value);
  if (channel === 'G') s.g = Number(value);
  if (channel === 'B') s.b = Number(value);
}

// NEW: Advanced Config UI Hook
function sendAdv(setId, channel, value) {
  websocket.send(JSON.stringify({ type: 'adv', set: setId, channel: channel, value: Number(value) }));
  let s = lightingConfig.sets.find(s => s.id === setId);
  if (channel === 'LEDS') s.ledCount = Number(value);
  if (channel === 'INST') s.instantOn = Number(value);
  if (channel === 'ORD') s.colorOrder = Number(value);
  if (channel === 'BR') s.balR = Number(value);
  if (channel === 'BG') s.balG = Number(value);
  if (channel === 'BB') s.balB = Number(value);
}

// NEW: Diagnostics UI Hook
function sendTrigger(setId, cmdString) {
  websocket.send(JSON.stringify({ type: 'trigger', set: setId, cmd: cmdString }));
}

function updateNodeStatus(nodes) {
  nodes.forEach(node => {
    const el = document.getElementById(`status-${node.id}`);
    if (!el) return;

    if (!node.online) {
      el.innerHTML = `<span style="color:red; font-weight:bold;">OFFLINE</span>`;
      return;
    }

    // Decode Error Bits for UI
    let errStr = "None";
    if (node.errors > 0) {
      errStr = "";
      if (node.errors & 0x01) errStr += "OverTemp ";
      if (node.errors & 0x02) errStr += "VoltSpike ";
      if (node.errors & 0x04) errStr += "I2C_Coll ";
      if (node.errors & 0x08) errStr += "WearLvl ";
      if (node.errors & 0x10) errStr += "HardFault ";
      if (node.errors & 0x20) errStr += "SensorErr ";
      if (node.errors & 0x40) errStr += "BadCmd ";
    }

    el.innerHTML = `
      <div style="font-size: 0.9em; text-align: left; padding-left: 10px;">
        <b>I2C:</b> 0x${node.addr.toString(16).toUpperCase()} | <b>Mode:</b> ${node.mode}<br>
        <b>ADC:</b> ${node.adc.toFixed(1)} V | <b>Temp:</b> ${node.temp} &deg;C<br>
        <b>FW:</b> v${node.fw} <br>
        <b>Errors:</b> <span style="color:${node.errors > 0 ? 'red' : 'green'};">${errStr}</span>
      </div>
    `;
  });
}
</script>
</head>
<style>
/* ... (Keep all your existing CSS styles exactly the same here) ... */
html { font-family: Arial, Helvetica, sans-serif; display: inline-block; text-align: center; }
h1 { font-size: 1.8rem; color: white; }
p { font-size: 1.4rem; }
.topnav { overflow: hidden; background-color: #0A1128; }
body { margin: 0; }
.content { padding: 30px; }
.card-grid { max-width: 700px; margin: 0 auto; display: grid; grid-gap: 2rem; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); }
.card { background-color: white; box-shadow: 2px 2px 12px 1px rgba(140,140,140,.5); padding-bottom: 15px; }
.card-title { font-size: 1.2rem; font-weight: bold; color: #034078 }
.state { font-size: 1.2rem; color:#1282A2; }
.slider { -webkit-appearance: none; margin: 0 auto; width: 90%; height: 15px; border-radius: 10px; background: #FFD65C; outline: none; }
.slider::-webkit-slider-thumb { -webkit-appearance: none; appearance: none; width: 30px; height: 30px; border-radius: 50%; background: #034078; cursor: pointer; }
.dropdown { width: 90%; padding: 10px; font-size: 1rem; border-radius: 5px; background-color: #FFD65C; color: #034078; border: none; font-weight: bold; }
</style>
<body>
    <div class='topnav'>
        <h1>Lighting Control</h1>
    </div>
    
    <div class='content'>
        <div id='lightingSets' class='card-grid'></div>
    </div>
    
    <div class='card-grid'>
        <div class='card'>
            <p class='card-title'>Power Sensor Readings</p>
            <p class='state'>Bus Voltage: <span id='bus'>--</span> V</p>
            <p class='state'>Shunt Voltage: <span id='shu'>--</span> mV</p>
            <p class='state'>Current: <span id='cur'>--</span> mA</p>
            <p class='state'>Power: <span id='pow'>--</span> mW</p>
        </div>
    </div>
</body>
</html>
)=====";
