from __future__ import annotations


def render_admin_page() -> str:
    return """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Cohere Transcribe Admin</title>
  <style>
    :root {
      --bg: #f5f1e8;
      --panel: rgba(255, 252, 246, 0.92);
      --ink: #1b1a17;
      --muted: #6b645a;
      --line: #d7cfc1;
      --accent: #c05a2b;
      --accent-2: #1f4f46;
      --ok: #256b45;
      --warn: #8d5b12;
      --shadow: 0 18px 50px rgba(49, 39, 24, 0.10);
    }

    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: Georgia, "Times New Roman", serif;
      color: var(--ink);
      background:
        radial-gradient(circle at top left, rgba(192, 90, 43, 0.18), transparent 32%),
        radial-gradient(circle at bottom right, rgba(31, 79, 70, 0.18), transparent 28%),
        var(--bg);
    }

    .shell {
      max-width: 1180px;
      margin: 0 auto;
      padding: 32px 20px 48px;
    }

    .hero {
      display: grid;
      gap: 12px;
      margin-bottom: 26px;
    }

    .eyebrow {
      text-transform: uppercase;
      letter-spacing: 0.18em;
      color: var(--accent);
      font-size: 12px;
      font-weight: 700;
    }

    h1 {
      margin: 0;
      font-size: clamp(34px, 5vw, 58px);
      line-height: 0.96;
      font-weight: 700;
    }

    .sub {
      max-width: 760px;
      color: var(--muted);
      font-size: 16px;
      line-height: 1.6;
    }

    .grid {
      display: grid;
      grid-template-columns: 1.15fr 0.85fr;
      gap: 18px;
    }

    .stack {
      display: grid;
      gap: 18px;
    }

    .panel {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 22px;
      box-shadow: var(--shadow);
      padding: 22px;
      backdrop-filter: blur(10px);
    }

    .panel h2 {
      margin: 0 0 14px;
      font-size: 24px;
    }

    .meta {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
    }

    .stat {
      padding: 14px;
      border: 1px solid var(--line);
      border-radius: 16px;
      background: rgba(255,255,255,0.45);
    }

    .label {
      color: var(--muted);
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.12em;
    }

    .value {
      margin-top: 6px;
      font-size: 18px;
      font-weight: 700;
      word-break: break-word;
    }

    form {
      display: grid;
      gap: 12px;
    }

    input, select, button, textarea {
      width: 100%;
      font: inherit;
      border-radius: 14px;
      border: 1px solid var(--line);
      padding: 12px 14px;
      background: rgba(255,255,255,0.88);
      color: var(--ink);
    }

    textarea { min-height: 84px; resize: vertical; }

    .row {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
    }

    .actions {
      display: flex;
      gap: 10px;
      align-items: center;
      flex-wrap: wrap;
    }

    button {
      cursor: pointer;
      font-weight: 700;
      border: 0;
      color: #fff7ef;
      background: linear-gradient(135deg, var(--accent), #d77d3d);
      transition: transform 0.15s ease, opacity 0.15s ease;
    }

    button.secondary {
      background: linear-gradient(135deg, var(--accent-2), #2f6c61);
    }

    button:hover { transform: translateY(-1px); }
    button:disabled { opacity: 0.65; cursor: wait; transform: none; }

    .status {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 8px 12px;
      border-radius: 999px;
      border: 1px solid var(--line);
      background: rgba(255,255,255,0.6);
      color: var(--muted);
      font-size: 14px;
    }

    .dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: var(--warn);
      box-shadow: 0 0 0 4px rgba(141, 91, 18, 0.13);
    }

    .dot.ok {
      background: var(--ok);
      box-shadow: 0 0 0 4px rgba(37, 107, 69, 0.13);
    }

    .result, .recent-item {
      border: 1px solid var(--line);
      border-radius: 16px;
      padding: 14px;
      background: rgba(255,255,255,0.52);
    }

    .result pre {
      margin: 0;
      white-space: pre-wrap;
      word-break: break-word;
      font-family: Consolas, "Courier New", monospace;
      font-size: 13px;
      line-height: 1.55;
    }

    .recent-list {
      display: grid;
      gap: 10px;
      max-height: 520px;
      overflow: auto;
    }

    .small {
      color: var(--muted);
      font-size: 13px;
    }

    @media (max-width: 920px) {
      .grid, .row, .meta {
        grid-template-columns: 1fr;
      }
    }
  </style>
</head>
<body>
  <main class="shell">
    <section class="hero">
      <div class="eyebrow">Cohere Transcribe</div>
      <h1>Admin Console</h1>
      <div class="sub">
        Inspect runtime settings, verify OpenAI-style transcription requests, and run ad hoc uploads
        without leaving the browser.
      </div>
      <div id="health-pill" class="status"><span class="dot"></span><span>Checking service status...</span></div>
    </section>

    <section class="grid">
      <div class="stack">
        <article class="panel">
          <h2>Service Snapshot</h2>
          <div class="meta" id="stats"></div>
        </article>

        <article class="panel">
          <h2>Test Transcription</h2>
          <form id="transcribe-form">
            <div class="row">
              <label>
                <div class="small">Audio file</div>
                <input type="file" name="file" accept="audio/*" required>
              </label>
              <label>
                <div class="small">Language</div>
                <input type="text" name="language" value="en" placeholder="en">
              </label>
            </div>

            <div class="row">
              <label>
                <div class="small">Response format</div>
                <select name="response_format">
                  <option value="json">json</option>
                  <option value="text">text</option>
                  <option value="verbose_json">verbose_json</option>
                </select>
              </label>
              <label>
                <div class="small">Punctuation</div>
                <select name="punctuation">
                  <option value="true">true</option>
                  <option value="false">false</option>
                </select>
              </label>
            </div>

            <label>
              <div class="small">Prompt</div>
              <textarea name="prompt" placeholder="Optional OpenAI-style prompt. This server accepts it but does not currently use it for decoding."></textarea>
            </label>

            <div class="actions">
              <button id="submit-btn" type="submit">Run Transcription</button>
              <button class="secondary" id="refresh-btn" type="button">Refresh Status</button>
              <span id="form-status" class="small"></span>
            </div>
          </form>
        </article>

        <article class="panel">
          <h2>Latest Result</h2>
          <div class="result"><pre id="result-output">No request submitted yet.</pre></div>
        </article>
      </div>

      <div class="stack">
        <article class="panel">
          <h2>Recent Requests</h2>
          <div id="recent-list" class="recent-list">
            <div class="recent-item small">No recent requests yet.</div>
          </div>
        </article>
      </div>
    </section>
  </main>

  <script>
    const healthPill = document.getElementById('health-pill');
    const stats = document.getElementById('stats');
    const resultOutput = document.getElementById('result-output');
    const recentList = document.getElementById('recent-list');
    const form = document.getElementById('transcribe-form');
    const formStatus = document.getElementById('form-status');
    const submitBtn = document.getElementById('submit-btn');
    const refreshBtn = document.getElementById('refresh-btn');

    function statCard(label, value) {
      return `<div class="stat"><div class="label">${label}</div><div class="value">${value ?? '-'}</div></div>`;
    }

    function setHealth(ok, text) {
      healthPill.innerHTML = `<span class="dot ${ok ? 'ok' : ''}"></span><span>${text}</span>`;
    }

    async function loadStatus() {
      const [statusRes, recentRes] = await Promise.all([
        fetch('/admin/api/status'),
        fetch('/admin/api/recent'),
      ]);

      const status = await statusRes.json();
      const recent = await recentRes.json();

      setHealth(status.status === 'ok', status.status === 'ok'
        ? `Service ready on ${status.device} with ${status.model_id}`
        : `Service status: ${status.status}`);

      stats.innerHTML = [
        statCard('Model', status.model_id),
        statCard('Device', status.device),
        statCard('Default Language', status.default_language),
        statCard('Batch Size', status.batch_size),
        statCard('Compile Encoder', String(status.compile_encoder)),
        statCard('Pipeline Detokenization', String(status.pipeline_detokenization)),
        statCard('Runtime Loaded', String(status.runtime_loaded)),
      ].join('');

      if (!recent.items.length) {
        recentList.innerHTML = '<div class="recent-item small">No recent requests yet.</div>';
      } else {
        recentList.innerHTML = recent.items.map((item) => `
          <div class="recent-item">
            <div><strong>${item.filename}</strong></div>
            <div class="small">${item.created_at}</div>
            <div class="small">language=${item.language} response_format=${item.response_format}</div>
            <div style="margin-top:8px">${item.preview}</div>
          </div>
        `).join('');
      }
    }

    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      formStatus.textContent = 'Uploading and transcribing...';
      submitBtn.disabled = true;
      resultOutput.textContent = 'Waiting for response...';

      try {
        const data = new FormData(form);
        const punctuation = data.get('punctuation') === 'true' ? 'true' : 'false';
        data.set('punctuation', punctuation);
        data.set('model', '');
        data.set('temperature', '0');

        const response = await fetch('/v1/audio/transcriptions', {
          method: 'POST',
          body: data,
        });

        const contentType = response.headers.get('content-type') || '';
        let body;
        if (contentType.includes('application/json')) {
          body = await response.json();
          resultOutput.textContent = JSON.stringify(body, null, 2);
        } else {
          body = await response.text();
          resultOutput.textContent = body;
        }

        if (!response.ok) {
          formStatus.textContent = 'Request failed.';
        } else {
          formStatus.textContent = 'Request completed.';
        }

        await loadStatus();
      } catch (error) {
        formStatus.textContent = 'Request failed.';
        resultOutput.textContent = String(error);
      } finally {
        submitBtn.disabled = false;
      }
    });

    refreshBtn.addEventListener('click', async () => {
      formStatus.textContent = 'Refreshing status...';
      try {
        await loadStatus();
        formStatus.textContent = 'Status refreshed.';
      } catch (error) {
        formStatus.textContent = 'Status refresh failed.';
      }
    });

    loadStatus().catch((error) => {
      setHealth(false, 'Unable to load admin status');
      resultOutput.textContent = String(error);
    });
  </script>
</body>
</html>"""
