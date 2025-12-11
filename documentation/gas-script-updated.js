/**
 * Google Apps Script to automate schedule lifecycle and telemetry migration
 * between Firestore (schedules/deployments/bots) and Firebase RTDB (bots/deployments).
 *
 * Script Properties required:
 * - GAS_FIREBASE_PROJECT_ID
 * - GAS_FIREBASE_DATABASE_URL (e.g. https://your-project-id-default-rtdb.firebaseio.com)
 * - GAS_SA_CLIENT_EMAIL
 * - GAS_SA_PRIVATE_KEY (PEM; \n allowed)
 */

const CFG = (() => {
  const props = PropertiesService.getScriptProperties();
  return Object.freeze({
    PROJECT_ID: props.getProperty('GAS_FIREBASE_PROJECT_ID'),
    DATABASE_URL: (props.getProperty('GAS_FIREBASE_DATABASE_URL') || '').replace(/\/$/, ''),
    SA_CLIENT_EMAIL: props.getProperty('GAS_SA_CLIENT_EMAIL'),
    SA_PRIVATE_KEY_RAW: props.getProperty('GAS_SA_PRIVATE_KEY'),

    // Firestore collections
    FS: {
      SCHEDULES: 'schedules',
      DEPLOYMENTS: 'deployments',
      BOTS: 'bots'
    },

    // Firestore field names - snake_case schema
    FIELDS: {
      schedule: {
        status: 'status',
        startAt: 'scheduled_date',
        endAt: 'scheduled_end_date',
        botId: 'bot_id',
        deploymentId: 'deployment_id',
        startedAt: 'started_at',
        endedAt: 'completed_at'
      },
      deployment: {
        status: 'status',
        botId: 'bot_id',
        scheduleId: 'schedule_id',
        createdAt: 'created_at',
        startedAt: 'actual_start_time',
        endedAt: 'actual_end_time',
        metrics: 'metrics'
      },
      bot: {
        status: 'status',
        lastUpdated: 'last_updated'
      }
    },

    // RTDB paths and keys - snake_case schema
    RT: {
      BOTS_ROOT: 'bots',
      DEPLOYMENTS_ROOT: 'deployments',
      botStatusKey: 'status',
      botCurrentScheduleKey: 'current_schedule_id',
      botCurrentDeploymentKey: 'current_deployment_id'
    },

    // Telemetry field mapping
    TELEMETRY: {
      ph: 'ph_level',
      turbidity: 'turbidity',
      temperatureC: 'temp',
      temperatureAlt: 'temperature',
      trashKg: 'trash_collected',
      trashGrams: 'trash_grams',
      batteryPct: 'battery_pct',
      batteryAlt: 'battery'
    },

    // Unit behavior
    UNITS: {
      trashInput: 'kg'
    },

    SCOPES: [
      'https://www.googleapis.com/auth/datastore',
      'https://www.googleapis.com/auth/firebase.database'
    ],

    BATCH_LIMIT: 200
  });
})();

/**
 * Main scheduled task entrypoint (run every minute).
 */
function tick() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(30 * 1000)) {
    console.log('Another run is active; skipping.');
    return;
  }
  const t0 = Date.now();
  try {
    processScheduledToActive_();
    processActiveToCompleted_();
  } catch (e) {
    console.error('tick error:', e && e.stack || e);
  } finally {
    lock.releaseLock();
    console.log(`tick finished in ${Date.now() - t0} ms`);
  }
}

/**
 * Promote schedules from 'scheduled' to 'active' when startAt <= now.
 */
function processScheduledToActive_() {
  const token = getAccessToken_(CFG.SCOPES);
  const now = new Date();

  const scheduled = runQueryByStatus_(CFG.FS.SCHEDULES, CFG.FIELDS.schedule.status, 'scheduled', token);
  console.log(`Found ${scheduled.length} scheduled items`);

  scheduled.forEach(row => {
    try {
      const doc = row.document;
      if (!doc) return;
      const fields = doc.fields || {};
      const scheduleId = doc.name.split('/').pop();

      const startAt = getFsTimestamp_(fields, CFG.FIELDS.schedule.startAt);
      if (!startAt || startAt > now) return;

      // Optional endAt read (to optionally fast-complete if already past end)
      const endAt = getFsTimestamp_(fields, CFG.FIELDS.schedule.endAt);

      const botId = getFsString_(fields, CFG.FIELDS.schedule.botId);
      const firestoreDeploymentId = getFsString_(fields, CFG.FIELDS.schedule.deploymentId) || scheduleId;

      // Ensure Firestore deployment doc exists
      ensureDeployment_(firestoreDeploymentId, {
        [CFG.FIELDS.deployment.scheduleId]: scheduleId,
        [CFG.FIELDS.deployment.botId]: botId || '',
        [CFG.FIELDS.deployment.status]: 'active',
        [CFG.FIELDS.deployment.createdAt]: new Date().toISOString(),
        [CFG.FIELDS.deployment.startedAt]: now.toISOString()
      }, token);

      // Update schedule to active
      patchDoc_(doc.name, {
        [CFG.FIELDS.schedule.status]: { stringValue: 'active' },
        [CFG.FIELDS.schedule.startedAt]: { timestampValue: now.toISOString() },
        [CFG.FIELDS.schedule.deploymentId]: { stringValue: firestoreDeploymentId }
      }, [CFG.FIELDS.schedule.status, CFG.FIELDS.schedule.startedAt, CFG.FIELDS.schedule.deploymentId], token);

      // Update bot status in BOTH Firestore and RTDB
      // IMPORTANT: For RTDB, use botId as current_deployment_id (the RTDB deployment node id)
      if (botId) {
        updateBotStatusBoth_(botId, 'active', scheduleId, botId, token);

        // Also maintain RTDB deployments/{botId} status and metadata
        const rtPayload = {
          status: 'active',
          schedule_id: scheduleId,
          deployment_id: firestoreDeploymentId, // reference to Firestore doc for history
          bot_id: botId,
          actual_start_time: now.toISOString(),
          updated_at: now.toISOString()
        };
        rtdbPatch_(`/${CFG.RT.DEPLOYMENTS_ROOT}/${botId}`, rtPayload, token);
      }

      console.log(`Activated schedule ${scheduleId} (Firestore deployment ${firestoreDeploymentId}, RTDB deployment node ${botId})`);

      // Optional immediate completion if already past endAt (edge case)
      if (endAt && endAt <= now) {
        completeDeploymentNow_(doc.name, scheduleId, botId, firestoreDeploymentId, token);
      }
    } catch (e) {
      console.error('processScheduledToActive item error:', e && e.stack || e);
    }
  });
}

/**
 * Complete schedules from 'active' to 'completed' when endAt <= now.
 */
function processActiveToCompleted_() {
  const token = getAccessToken_(CFG.SCOPES);
  const now = new Date();

  const active = runQueryByStatus_(CFG.FS.SCHEDULES, CFG.FIELDS.schedule.status, 'active', token);
  console.log(`Found ${active.length} active items`);

  active.forEach(row => {
    try {
      const doc = row.document;
      if (!doc) return;
      const fields = doc.fields || {};
      const scheduleId = doc.name.split('/').pop();

      const endAt = getFsTimestamp_(fields, CFG.FIELDS.schedule.endAt);
      if (!endAt || endAt > now) return;

      const botId = getFsString_(fields, CFG.FIELDS.schedule.botId);
      const firestoreDeploymentId = getFsString_(fields, CFG.FIELDS.schedule.deploymentId) || scheduleId;

      // Aggregate telemetry and mark completed
      completeDeploymentNow_(doc.name, scheduleId, botId, firestoreDeploymentId, token);
    } catch (e) {
      console.error('processActiveToCompleted item error:', e && e.stack || e);
    }
  });
}

/**
 * Completes a deployment + schedule, aggregates telemetry, and resets bot to idle.
 * @param {string} scheduleFullName - Full Firestore path to the schedule document
 * @param {string} scheduleId - Schedule document ID
 * @param {string} botId - Bot ID (also used as RTDB deployment node id)
 * @param {string} firestoreDeploymentId - Firestore deployment document ID
 * @param {string} token - OAuth access token
 */
function completeDeploymentNow_(scheduleFullName, scheduleId, botId, firestoreDeploymentId, token) {
  const nowIso = new Date().toISOString();

  // Aggregate telemetry (checks deployments/{botId}/readings first, then deployments/{firestoreDeploymentId}/readings, then bots/{botId})
  const metrics = summarizeTelemetry_(botId, firestoreDeploymentId, token);

  // Update Firestore deployment
  const depFullName = `projects/${CFG.PROJECT_ID}/databases/(default)/documents/${CFG.FS.DEPLOYMENTS}/${firestoreDeploymentId}`;
  patchDoc_(depFullName, {
    [CFG.FIELDS.deployment.status]: { stringValue: 'completed' },
    [CFG.FIELDS.deployment.endedAt]: { timestampValue: nowIso },
    [CFG.FIELDS.deployment.metrics]: toFsMap_(metrics)
  }, [CFG.FIELDS.deployment.status, CFG.FIELDS.deployment.endedAt, CFG.FIELDS.deployment.metrics], token);

  // Update schedule
  patchDoc_(scheduleFullName, {
    [CFG.FIELDS.schedule.status]: { stringValue: 'completed' },
    [CFG.FIELDS.schedule.endedAt]: { timestampValue: nowIso }
  }, [CFG.FIELDS.schedule.status, CFG.FIELDS.schedule.endedAt], token);

  // Update RTDB: mark deployments/{botId} completed
  if (botId) {
    rtdbPatch_(`/${CFG.RT.DEPLOYMENTS_ROOT}/${botId}`, {
      status: 'completed',
      actual_end_time: nowIso,
      updated_at: nowIso
    }, token);

    // Reset bot status to idle in BOTH Firestore and RTDB
    updateBotStatusBoth_(botId, 'idle', null, null, token);
  }

  console.log(`Completed schedule ${scheduleId} / Firestore deployment ${firestoreDeploymentId}`);
}

/**
 * Updates bot status in BOTH Firestore and RTDB for real-time sync.
 * @param {string} botId - The bot ID
 * @param {string} status - New status ('idle', 'active', 'scheduled', etc.)
 * @param {string|null} scheduleId - Current schedule ID or null
 * @param {string|null} deploymentId - RTDB deployment node id (use botId for active/scheduled, null for idle)
 * @param {string} token - OAuth access token
 */
function updateBotStatusBoth_(botId, status, scheduleId, deploymentId, token) {
  const nowIso = new Date().toISOString();

  // Update Firestore bots collection
  const botFullName = `projects/${CFG.PROJECT_ID}/databases/(default)/documents/${CFG.FS.BOTS}/${botId}`;
  const fsUpdate = {
    [CFG.FIELDS.bot.status]: { stringValue: status },
    [CFG.FIELDS.bot.lastUpdated]: { timestampValue: nowIso }
  };
  const fsUpdateMask = [CFG.FIELDS.bot.status, CFG.FIELDS.bot.lastUpdated];

  patchDoc_(botFullName, fsUpdate, fsUpdateMask, token);
  console.log(`Updated Firestore bot ${botId} status to ${status}`);

  // Update RTDB bots (deploymentId is the RTDB node id, which is botId for active deployments)
  const rtdbUpdate = {
    [CFG.RT.botStatusKey]: status,
    [CFG.RT.botCurrentScheduleKey]: scheduleId,
    [CFG.RT.botCurrentDeploymentKey]: deploymentId, // points to /deployments/{botId} or null
    last_updated: nowIso
  };

  rtdbPatch_(`/${CFG.RT.BOTS_ROOT}/${botId}`, rtdbUpdate, token);
  console.log(`Updated RTDB bot ${botId} status to ${status}, current_deployment_id to ${deploymentId}`);
}

/* =================== Firestore helpers =================== */

function runQueryByStatus_(collectionId, statusField, statusValue, token) {
  const url = `https://firestore.googleapis.com/v1/projects/${CFG.PROJECT_ID}/databases/(default)/documents:runQuery`;
  const body = {
    structuredQuery: {
      from: [{ collectionId }],
      where: {
        fieldFilter: {
          field: { fieldPath: statusField },
          op: 'EQUAL',
          value: { stringValue: statusValue }
        }
      },
      limit: CFG.BATCH_LIMIT
    }
  };
  const res = http_(url, 'post', body, token);
  return (res || []).filter(r => r.document);
}

function ensureDeployment_(deploymentId, initFields, token) {
  const base = `https://firestore.googleapis.com/v1/projects/${CFG.PROJECT_ID}/databases/(default)/documents`;
  const getUrl = `${base}/${CFG.FS.DEPLOYMENTS}/${encodeURIComponent(deploymentId)}`;
  const got = http_(getUrl, 'get', null, token, true);
  if (got && got.name) return;

  const createUrl = `${base}/${CFG.FS.DEPLOYMENTS}?documentId=${encodeURIComponent(deploymentId)}`;
  const body = { fields: toFsFields_(initFields) };
  http_(createUrl, 'post', body, token);
}

function patchDoc_(fullName, fieldsObject, updateMaskPaths, token) {
  const url = `https://firestore.googleapis.com/v1/${fullName}?` +
    updateMaskPaths.map(p => `updateMask.fieldPaths=${encodeURIComponent(p)}`).join('&');
  const body = { fields: fieldsObject };
  return http_(url, 'patch', body, token);
}

function toFsFields_(obj) {
  const out = {};
  Object.keys(obj || {}).forEach(k => {
    out[k] = toFsValue_(obj[k]);
  });
  return out;
}

function toFsMap_(obj) {
  const fields = toFsFields_(obj);
  return { mapValue: { fields } };
}

function toFsValue_(v) {
  if (v === null) return { nullValue: null };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') {
    return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  }
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toFsValue_) } };
  if (typeof v === 'object') return toFsMap_(v);
  return { stringValue: String(v) };
}

function getFsString_(fields, key) {
  const node = fields[key];
  if (!node) return null;
  return node.stringValue ?? null;
}

function getFsTimestamp_(fields, key) {
  const node = fields[key];
  const iso = node && node.timestampValue;
  return iso ? new Date(iso) : null;
}

/* =================== RTDB helpers =================== */

function rtdbGet_(path, token) {
  const url = `${CFG.DATABASE_URL}${path}.json`;
  return http_(url, 'get', null, token, true);
}

function rtdbPatch_(path, body, token) {
  const url = `${CFG.DATABASE_URL}${path}.json`;
  return http_(url, 'patch', body, token);
}

/* =================== Telemetry aggregation =================== */

/**
 * Aggregates telemetry from RTDB with fallback priority:
 * 1. deployments/{botId}/readings (single node per bot, recommended)
 * 2. deployments/{firestoreDeploymentId}/readings (per-deployment history)
 * 3. bots/{botId} snapshot (last known values)
 */
function summarizeTelemetry_(botId, firestoreDeploymentId, token) {
  const out = {
    totalTrashKg: 0,
    avgPH: null,
    avgTurbidity: null,
    avgTemperatureC: null,
    lastBatteryPct: null,
    sampleCount: 0,
    source: null
  };

  // 1) Prefer single-node-per-bot readings: deployments/{botId}/readings
  if (botId) {
    const depReadingsByBotPath = `/${CFG.RT.DEPLOYMENTS_ROOT}/${botId}/readings`;
    const readingsByBot = rtdbGet_(depReadingsByBotPath, token);
    if (readingsByBot && typeof readingsByBot === 'object' && Object.keys(readingsByBot).length > 0) {
      out.source = depReadingsByBotPath;
      accumulateFromReadings_(readingsByBot, out);
      return out;
    }
  }

  // 2) Fallback to per-deployment readings: deployments/{firestoreDeploymentId}/readings
  if (firestoreDeploymentId) {
    const depReadingsByIdPath = `/${CFG.RT.DEPLOYMENTS_ROOT}/${firestoreDeploymentId}/readings`;
    const readingsById = rtdbGet_(depReadingsByIdPath, token);
    if (readingsById && typeof readingsById === 'object' && Object.keys(readingsById).length > 0) {
      out.source = depReadingsByIdPath;
      accumulateFromReadings_(readingsById, out);
      return out;
    }
  }

  // 3) Last resort: bot snapshot: bots/{botId}
  if (botId) {
    const snap = rtdbGet_(`/${CFG.RT.BOTS_ROOT}/${botId}`, token);
    if (snap) {
      out.source = `/${CFG.RT.BOTS_ROOT}/${botId}`;
      accumulateFromSnapshot_(snap, out);
      return out;
    }
  }

  out.source = 'none';
  return out;
}

function accumulateFromReadings_(node, out) {
  const keys = Object.keys(node).sort();
  let phSum = 0, turbSum = 0, tempSum = 0, trashSumKg = 0, count = 0, lastBattery = null;

  keys.forEach(k => {
    const r = node[k] || {};
    const ph = toNum_(r[CFG.TELEMETRY.ph]);
    const turbidity = toNum_(r[CFG.TELEMETRY.turbidity]);
    const temp = toNum_(r[CFG.TELEMETRY.temperatureC] ?? r[CFG.TELEMETRY.temperatureAlt]);
    const trashKgVal =
      (CFG.UNITS.trashInput === 'kg')
        ? toNum_(r[CFG.TELEMETRY.trashKg])
        : (toNum_(r[CFG.TELEMETRY.trashGrams]) / 1000);
    const battery = r[CFG.TELEMETRY.batteryPct] ?? r[CFG.TELEMETRY.batteryAlt];

    if (isFinite(ph)) phSum += ph;
    if (isFinite(turbidity)) turbSum += turbidity;
    if (isFinite(temp)) tempSum += temp;
    if (isFinite(trashKgVal)) trashSumKg += trashKgVal;
    if (battery != null) lastBattery = battery;

    count++;
  });

  out.sampleCount = count;
  if (count > 0) {
    out.avgPH = round_(phSum / count, 3);
    out.avgTurbidity = round_(turbSum / count, 3);
    out.avgTemperatureC = round_(tempSum / count, 3);
    out.totalTrashKg = round_(trashSumKg, 3);
    out.lastBatteryPct = lastBattery;
  }
}

function accumulateFromSnapshot_(snap, out) {
  const ph = toNum_(snap[CFG.TELEMETRY.ph]);
  const turbidity = toNum_(snap[CFG.TELEMETRY.turbidity]);
  const temp = toNum_(snap[CFG.TELEMETRY.temperatureC] ?? snap[CFG.TELEMETRY.temperatureAlt]);
  const trashKgVal =
    (CFG.UNITS.trashInput === 'kg')
      ? toNum_(snap[CFG.TELEMETRY.trashKg])
      : (toNum_(snap[CFG.TELEMETRY.trashGrams]) / 1000);
  const battery = snap[CFG.TELEMETRY.batteryPct] ?? snap[CFG.TELEMETRY.batteryAlt];

  out.sampleCount = 1;
  out.avgPH = isFinite(ph) ? ph : null;
  out.avgTurbidity = isFinite(turbidity) ? turbidity : null;
  out.avgTemperatureC = isFinite(temp) ? temp : null;
  out.totalTrashKg = isFinite(trashKgVal) ? trashKgVal : 0;
  out.lastBatteryPct = battery ?? null;
}

function toNum_(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : NaN;
}

function round_(n, d) {
  const f = Math.pow(10, d || 0);
  return Math.round(n * f) / f;
}

/* =================== Auth + HTTP =================== */

function getAccessToken_(scopes) {
  const cache = CacheService.getScriptCache();
  const cached = cache.get('svc_token');
  if (cached) return cached;

  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + 3600;

  const header = base64url_(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64url_(JSON.stringify({
    iss: CFG.SA_CLIENT_EMAIL,
    scope: scopes.join(' '),
    aud: 'https://oauth2.googleapis.com/token',
    exp, iat
  }));

  const unsigned = `${header}.${claims}`;
  const privateKeyPem = normalizePrivateKey_(CFG.SA_PRIVATE_KEY_RAW);
  const signatureBytes = Utilities.computeRsaSha256Signature(unsigned, privateKeyPem);
  const signature = base64url_(signatureBytes);

  const assertion = `${unsigned}.${signature}`;
  const resp = UrlFetchApp.fetch('https://oauth2.googleapis.com/token', {
    method: 'post',
    contentType: 'application/x-www-form-urlencoded',
    payload: {
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion
    },
    muteHttpExceptions: true
  });
  if (resp.getResponseCode() !== 200) {
    throw new Error(`Token exchange failed: ${resp.getResponseCode()} ${resp.getContentText()}`);
  }
  const token = JSON.parse(resp.getContentText()).access_token;
  cache.put('svc_token', token, 55 * 60);
  return token;
}

function http_(url, method, body, token, mute) {
  const opt = {
    method: method.toUpperCase(),
    contentType: 'application/json',
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    payload: body ? JSON.stringify(body) : undefined,
    muteHttpExceptions: true
  };
  const res = UrlFetchApp.fetch(url, opt);
  const code = res.getResponseCode();
  const text = res.getContentText();
  if (code >= 200 && code < 300) {
    try { return text ? JSON.parse(text) : null; } catch { return text; }
  }
  if (!mute) console.error(`${method.toUpperCase()} ${url} -> ${code} ${text}`);
  return null;
}

function base64url_(input) {
  // Accept string (JSON) or byte[]
  let bytes;
  if (typeof input === 'string') {
    bytes = Utilities.newBlob(input).getBytes(); // UTF‑8
  } else if (Object.prototype.toString.call(input) === '[object Array]' || input instanceof Uint8Array) {
    bytes = input; // already bytes
  } else {
    bytes = Utilities.newBlob(String(input)).getBytes();
  }
  // One-arg variant; strip '=' padding for JWT
  const b64 = Utilities.base64EncodeWebSafe(bytes);
  return b64.replace(/=+$/g, '');
}

function normalizePrivateKey_(raw) {
  const fixed = (raw || '').replace(/\\n/g, '\n');
  if (!fixed.includes('BEGIN PRIVATE KEY')) {
    throw new Error('GAS_SA_PRIVATE_KEY is not a valid PEM');
  }
  return fixed;
}

/* =================== Trigger setup =================== */

function installTriggers() {
  ScriptApp.getProjectTriggers()
    .filter(t => t.getHandlerFunction() === 'tick')
    .forEach(t => ScriptApp.deleteTrigger(t));
  ScriptApp.newTrigger('tick').timeBased().everyMinutes(1).create();
  console.log('Installed tick() every 1 minute');
}
