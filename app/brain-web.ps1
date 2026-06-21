# Claude Brain — Local Web Dashboard (cross-platform, works on Mac/Linux/Windows)
# Starts a tiny HTTP server on localhost:7337, open in any browser

param([int]$Port = 7337)

$BRAIN_DIR = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$MACHINE_NAME = $env:COMPUTERNAME

function Sync-Brain {
    param([string]$Msg = "sync")
    $script = if ($IsWindows -or $env:OS -match "Windows") {
        "$BRAIN_DIR\sync.ps1"
    } else { "$BRAIN_DIR/sync.sh" }
    if (Test-Path $script) {
        if ($script.EndsWith(".ps1")) {
            & powershell -NonInteractive -File $script $Msg 2>&1 | Out-String
        } else {
            & bash $script $Msg 2>&1 | Out-String
        }
    }
}

function Get-HandoffHtml {
    $h = if (Test-Path "$BRAIN_DIR/handoff/current.md") {
        Get-Content "$BRAIN_DIR/handoff/current.md" -Raw
    } else { "No handoff." }
    return [System.Net.WebUtility]::HtmlEncode($h)
}

function Get-InboxHtml {
    $msgs = Get-ChildItem "$BRAIN_DIR/inbox" -Filter "*.md" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne "README.md" } | Sort-Object LastWriteTime -Descending
    if (-not $msgs) { return "<p class='muted'>No messages.</p>" }
    $html = ""
    foreach ($m in $msgs) {
        $content = [System.Net.WebUtility]::HtmlEncode((Get-Content $m.FullName -Raw))
        $html += "<div class='card msg-card'><div class='msg-name'>$($m.Name)</div><pre>$content</pre><button onclick=`"deleteMsg('$($m.Name)')`" class='btn btn-red'>Delete</button></div>"
    }
    return $html
}

function Get-MemoryHtml {
    $files = Get-ChildItem "$BRAIN_DIR/memory" -Filter "*.md" -ErrorAction SilentlyContinue | Sort-Object Name
    if (-not $files) { return "<p class='muted'>No memory files.</p>" }
    $html = "<div class='mem-list'>"
    foreach ($f in $files) {
        $content = [System.Net.WebUtility]::HtmlEncode((Get-Content $f.FullName -Raw))
        $name = [System.Net.WebUtility]::HtmlEncode($f.Name)
        $html += "<div class='card'><h3>$name</h3><textarea class='mem-edit' data-file='$name' rows='8'>$content</textarea><button onclick=`"saveMem('$name', this)`" class='btn'>Save + Sync</button></div>"
    }
    $html += "</div>"
    return $html
}

function Get-GitLog {
    try { & git -C $BRAIN_DIR log --oneline -10 2>&1 | Out-String } catch { "git unavailable" }
}

function Get-StatusJson {
    $gitStatus = try { $s = & git -C $BRAIN_DIR status --porcelain 2>&1; if ($s) {"unsynced"} else {"clean"} } catch {"unknown"}
    $lastCommit = try { & git -C $BRAIN_DIR log -1 --format="%ci" 2>&1 } catch { "unknown" }
    $inboxCount = (Get-ChildItem "$BRAIN_DIR/inbox" -Filter "*.md" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "README.md" }).Count
    return @{ status=$gitStatus; lastCommit=$lastCommit; machine=$MACHINE_NAME; inbox=$inboxCount } | ConvertTo-Json
}

$html = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Claude Brain</title>
<style>
  :root{--bg:#12121a;--panel:#1c1c26;--card:#262634;--accent:#6366f1;--accent2:#8b5cf6;--green:#34d399;--yellow:#fbbf24;--red:#f87171;--text:#e5e5e5;--muted:#78788a;--border:#37374b}
  *{box-sizing:border-box;margin:0;padding:0}
  body{background:var(--bg);color:var(--text);font-family:'Segoe UI',system-ui,sans-serif;font-size:14px}
  header{background:var(--panel);padding:14px 24px;display:flex;align-items:center;gap:16px;border-bottom:1px solid var(--border);position:sticky;top:0;z-index:10}
  header h1{font-size:18px;font-weight:700}
  .badge{background:var(--card);border:1px solid var(--border);border-radius:6px;padding:4px 10px;font-size:12px}
  .badge.green{border-color:var(--green);color:var(--green)}
  .badge.yellow{border-color:var(--yellow);color:var(--yellow)}
  .btn{background:var(--accent);color:#fff;border:none;border-radius:6px;padding:7px 14px;cursor:pointer;font-size:13px;font-weight:600}
  .btn:hover{filter:brightness(1.1)}
  .btn-red{background:var(--red)}
  .btn-muted{background:var(--card);border:1px solid var(--border)}
  .ml-auto{margin-left:auto}
  nav{display:flex;gap:2px;background:var(--panel);padding:0 24px;border-bottom:1px solid var(--border)}
  nav button{background:none;border:none;color:var(--muted);padding:10px 16px;cursor:pointer;font-size:13px;border-bottom:2px solid transparent}
  nav button.active{color:var(--text);border-bottom-color:var(--accent)}
  .tab{display:none;padding:24px}
  .tab.active{display:block}
  .cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px;margin-bottom:24px}
  .card{background:var(--card);border-radius:10px;padding:16px}
  .card-label{font-size:11px;font-weight:700;color:var(--muted);letter-spacing:.08em;margin-bottom:8px}
  .card-value{font-size:18px;font-weight:700;color:var(--accent)}
  .card-sub{font-size:12px;color:var(--muted);margin-top:4px}
  label{display:block;font-size:12px;color:var(--muted);margin-bottom:4px;margin-top:14px;font-weight:600;letter-spacing:.06em}
  input,textarea{width:100%;background:var(--card);border:1px solid var(--border);border-radius:6px;padding:8px 10px;color:var(--text);font-size:13px;font-family:inherit}
  textarea{resize:vertical;min-height:80px}
  .mem-edit{font-family:'Cascadia Code','Consolas',monospace;font-size:12px}
  pre{background:var(--panel);border-radius:8px;padding:14px;font-family:'Cascadia Code','Consolas',monospace;font-size:12px;white-space:pre-wrap;word-break:break-word;color:var(--text);border:1px solid var(--border)}
  .msg-card{margin-bottom:12px}
  .msg-name{font-size:11px;color:var(--muted);margin-bottom:8px;font-family:monospace}
  .muted{color:var(--muted)}
  #log{background:var(--panel);border-radius:8px;padding:12px;font-family:monospace;font-size:12px;color:var(--muted);height:160px;overflow-y:auto;border:1px solid var(--border)}
  .row{display:flex;gap:12px;align-items:flex-end}
  .row .btn{flex-shrink:0;height:36px}
  .section-title{font-size:11px;font-weight:700;color:var(--muted);letter-spacing:.08em;margin-bottom:12px;text-transform:uppercase}
  .spinner{display:none;width:14px;height:14px;border:2px solid var(--muted);border-top-color:var(--accent);border-radius:50%;animation:spin .6s linear infinite;margin-left:8px;vertical-align:middle}
  @keyframes spin{to{transform:rotate(360deg)}}
  .flex{display:flex;gap:12px;align-items:center}
</style>
</head>
<body>

<header>
  <h1>🧠 Claude Brain</h1>
  <span class="badge" id="machineTag">Loading…</span>
  <span class="badge" id="syncBadge">Checking…</span>
  <span class="badge" id="inboxBadge">Inbox: –</span>
  <button class="btn ml-auto" onclick="syncNow()">⟳ Sync Now<span class="spinner" id="syncSpinner"></span></button>
</header>

<nav>
  <button class="active" onclick="showTab('dashboard',this)">Dashboard</button>
  <button onclick="showTab('handoff',this)">Handoff</button>
  <button onclick="showTab('inbox',this)">Inbox</button>
  <button onclick="showTab('memory',this)">Memory</button>
  <button onclick="showTab('collab',this)">Collaborate</button>
  <button onclick="showTab('git',this)">Git Log</button>
</nav>

<!-- DASHBOARD -->
<div class="tab active" id="tab-dashboard">
  <div class="cards" id="statusCards">
    <div class="card"><div class="card-label">THIS MACHINE</div><div class="card-value" id="myMachine">–</div><div class="card-sub" id="myStatus">–</div></div>
    <div class="card"><div class="card-label">SYNC STATUS</div><div class="card-value" id="syncStatus">–</div><div class="card-sub" id="lastCommit">–</div></div>
    <div class="card"><div class="card-label">INBOX</div><div class="card-value" id="inboxCount">–</div><div class="card-sub">messages waiting</div></div>
  </div>
  <div class="section-title">Current Handoff</div>
  <pre id="handoffPreview">Loading…</pre>
  <div class="section-title" style="margin-top:20px">Activity</div>
  <div id="log"></div>
</div>

<!-- HANDOFF -->
<div class="tab" id="tab-handoff">
  <div class="section-title">Send Handoff to Other Machine</div>
  <label>To (machine name)</label>
  <input id="hTo" placeholder="e.g. LAPTOP or DESKTOP-JG30HPB">
  <label>Task</label>
  <input id="hTask" placeholder="What we're working on">
  <label>Context / What you did</label>
  <textarea id="hContext" rows="4" placeholder="Key details the other instance needs to know"></textarea>
  <label>Files touched</label>
  <textarea id="hFiles" rows="3" placeholder="One file path per line"></textarea>
  <label>Next steps</label>
  <textarea id="hNext" rows="4" placeholder="- [ ] Step 1&#10;- [ ] Step 2"></textarea>
  <br><br>
  <div class="flex">
    <button class="btn" onclick="sendHandoff()">Send Handoff + Sync →</button>
    <button class="btn btn-muted" onclick="clearHandoff()">Clear</button>
    <span id="handoffMsg" class="muted"></span>
  </div>
</div>

<!-- INBOX -->
<div class="tab" id="tab-inbox">
  <div class="section-title">Messages</div>
  <div id="inboxList">Loading…</div>
  <br>
  <div class="section-title">Send Message</div>
  <textarea id="newMsg" rows="3" placeholder="Type a message for the other instance…"></textarea>
  <br><br>
  <button class="btn" onclick="sendMsg()">Send + Sync</button>
  <span id="msgResult" class="muted"></span>
</div>

<!-- MEMORY -->
<div class="tab" id="tab-memory">
  <div class="section-title">Shared Memory Files</div>
  <div id="memoryList">Loading…</div>
</div>

<!-- COLLABORATE -->
<div class="tab" id="tab-collab">
  <div class="cards">
    <div class="card"><div class="card-label">OTHER MACHINE</div><div class="card-value" id="collabOtherName">—</div><div class="card-sub" id="collabOtherStatus">checking...</div></div>
    <div class="card"><div class="card-label">ACTIVE TASKS</div><div class="card-value" id="collabTaskCount">—</div><div class="card-sub">in task queue</div></div>
  </div>
  <div class="section-title">Dispatch a Collaborative Task</div>
  <p class="muted" style="margin-bottom:12px">Describe what you want built. If the other machine is online, it will automatically pick up half the work.</p>
  <label>Task description</label>
  <textarea id="collabTask" rows="3" placeholder="e.g. Build a user authentication system with JWT tokens"></textarea>
  <label>Relevant files / context (optional)</label>
  <input id="collabContext" placeholder="e.g. src/app.ts, package.json">
  <br><br>
  <div class="flex">
    <button class="btn" onclick="dispatchTask()">Dispatch Task</button>
    <button class="btn btn-muted" onclick="loadCollabStatus()">↻ Refresh</button>
    <span id="collabMsg" class="muted" style="margin-left:12px"></span>
  </div>
  <br>
  <div class="section-title">Task Queue</div>
  <div id="collabTaskList">Loading…</div>
</div>

<!-- GIT LOG -->
<div class="tab" id="tab-git">
  <div class="section-title">Recent Commits</div>
  <pre id="gitLog">Loading…</pre>
  <br>
  <button class="btn btn-muted" onclick="loadGit()">↻ Refresh</button>
</div>

<script>
function showTab(id,btn){
  document.querySelectorAll('.tab').forEach(t=>t.classList.remove('active'));
  document.querySelectorAll('nav button').forEach(b=>b.classList.remove('active'));
  document.getElementById('tab-'+id).classList.add('active');
  btn.classList.add('active');
  if(id==='inbox') loadInbox();
  if(id==='memory') loadMemory();
  if(id==='git') loadGit();
}

function log(msg){
  const el=document.getElementById('log');
  const ts=new Date().toLocaleTimeString();
  el.innerHTML=`<div>[${ts}] ${msg}</div>`+el.innerHTML;
}

async function api(path,opts){
  const r=await fetch(path,opts);
  return r.json();
}

async function loadStatus(){
  try {
    const s=await api('/status');
    document.getElementById('myMachine').textContent=s.machine;
    document.getElementById('machineTag').textContent=s.machine;
    document.getElementById('syncStatus').textContent=s.status==='clean'?'● Up to date':'● Unsynced';
    document.getElementById('syncStatus').style.color=s.status==='clean'?'var(--green)':'var(--yellow)';
    document.getElementById('lastCommit').textContent=s.lastCommit;
    document.getElementById('inboxCount').textContent=s.inbox;
    document.getElementById('syncBadge').textContent=s.status==='clean'?'✓ Synced':'Unsynced';
    document.getElementById('syncBadge').className='badge '+(s.status==='clean'?'green':'yellow');
    document.getElementById('inboxBadge').textContent=`Inbox: ${s.inbox}`;
  } catch(e){log('Status check failed: '+e)}
}

async function loadHandoff(){
  const r=await fetch('/handoff');
  const t=await r.text();
  document.getElementById('handoffPreview').textContent=t;
}

async function syncNow(){
  document.getElementById('syncSpinner').style.display='inline-block';
  try {
    const r=await api('/sync',{method:'POST'});
    log('Sync: '+r.result);
    await loadStatus(); await loadHandoff();
  } catch(e){log('Sync error: '+e)}
  document.getElementById('syncSpinner').style.display='none';
}

async function sendHandoff(){
  const body={to:document.getElementById('hTo').value,task:document.getElementById('hTask').value,context:document.getElementById('hContext').value,files:document.getElementById('hFiles').value,next:document.getElementById('hNext').value};
  const r=await api('/handoff',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
  document.getElementById('handoffMsg').textContent='✓ Sent at '+new Date().toLocaleTimeString();
  log('Handoff sent to: '+body.to);
  loadHandoff();
}

function clearHandoff(){
  ['hTo','hTask','hContext','hFiles','hNext'].forEach(id=>document.getElementById(id).value='');
  document.getElementById('handoffMsg').textContent='';
}

async function loadInbox(){
  const r=await fetch('/inbox');
  document.getElementById('inboxList').innerHTML=await r.text();
}

async function deleteMsg(name){
  await api('/inbox/delete',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name})});
  loadInbox(); loadStatus(); log('Deleted: '+name);
}

async function sendMsg(){
  const msg=document.getElementById('newMsg').value.trim();
  if(!msg) return;
  await api('/inbox/send',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({message:msg})});
  document.getElementById('newMsg').value='';
  document.getElementById('msgResult').textContent='✓ Sent';
  loadInbox(); log('Message sent');
}

async function loadMemory(){
  const r=await fetch('/memory');
  document.getElementById('memoryList').innerHTML=await r.text();
}

async function saveMem(filename,btn){
  const ta=btn.previousElementSibling;
  await api('/memory/save',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({filename,content:ta.value})});
  log('Memory saved: '+filename);
}

async function loadGit(){
  const r=await fetch('/git-log');
  document.getElementById('gitLog').textContent=await r.text();
}

async function loadCollabStatus(){
  const s=await api('/status');
  document.getElementById('collabOtherName').textContent=s.otherMachine||'—';
  document.getElementById('collabOtherStatus').textContent=s.otherOnline==='online'?'ONLINE - will receive tasks':'OFFLINE - solo mode';
  document.getElementById('collabOtherName').style.color=s.otherOnline==='online'?'var(--green)':'var(--red)';
  document.getElementById('collabTaskCount').textContent=s.activeTasks||0;
  const r=await fetch('/collab-status');
  document.getElementById('collabTaskList').innerHTML=await r.text();
}

async function dispatchTask(){
  const task=document.getElementById('collabTask').value.trim();
  const ctx=document.getElementById('collabContext').value.trim();
  if(!task){document.getElementById('collabMsg').textContent='Enter a task first.';return;}
  document.getElementById('collabMsg').textContent='Dispatching...';
  try{
    const r=await api('/dispatch',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({task,context:ctx})});
    document.getElementById('collabMsg').textContent=r.mode==='split'?'Split task dispatched to both machines!':'Solo task dispatched (other machine offline).';
    document.getElementById('collabTask').value='';
    loadCollabStatus();
    log('Task dispatched: '+task);
  }catch(e){document.getElementById('collabMsg').textContent='Error: '+e;}
}

// Init
loadStatus(); loadHandoff();
setInterval(()=>{loadStatus(); loadHandoff();}, 15000);
</script>
</body>
</html>
'@

# HTTP server
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "Claude Brain running at http://localhost:$Port" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray

# Open browser
Start-Process "http://localhost:$Port"

function Send-Response {
    param($ctx, [string]$body, [string]$contentType = "text/html; charset=utf-8")
    $buf = [System.Text.Encoding]::UTF8.GetBytes($body)
    $ctx.Response.ContentType = $contentType
    $ctx.Response.ContentLength64 = $buf.Length
    $ctx.Response.OutputStream.Write($buf, 0, $buf.Length)
    $ctx.Response.OutputStream.Close()
}

function Read-Body {
    param($ctx)
    $reader = New-Object System.IO.StreamReader($ctx.Request.InputStream)
    return $reader.ReadToEnd()
}

while ($listener.IsListening) {
    try {
        $ctx = $listener.GetContext()
        $url = $ctx.Request.Url.AbsolutePath
        $method = $ctx.Request.HttpMethod

        switch ("$method $url") {
            "GET /" {
                Send-Response $ctx $html
            }
            "GET /status" {
                $gitSt = try { $s = & git -C $BRAIN_DIR status --porcelain 2>&1; if ($s) {"unsynced"} else {"clean"} } catch {"unknown"}
                $last = try { & git -C $BRAIN_DIR log -1 --format="%ci" 2>&1 } catch { "unknown" }
                $inbox = (Get-ChildItem "$BRAIN_DIR/inbox" -Filter "*.md" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "README.md" }).Count
                # Check other machine online status
                $otherOnline = "offline"; $otherMachine = ""
                $beats = Get-ChildItem "$BRAIN_DIR/heartbeat" -Filter "*.json" -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -ne $MACHINE_NAME }
                $now = [int][double]::Parse((Get-Date -UFormat %s))
                foreach ($b in $beats) {
                    try {
                        $d = Get-Content $b.FullName | ConvertFrom-Json
                        if (($now - $d.epoch) -lt 120) { $otherOnline = "online"; $otherMachine = $d.machine; break }
                    } catch {}
                }
                # Active tasks
                $activeTasks = (Get-ChildItem "$BRAIN_DIR/tasks" -Filter "*.md" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch "README|MERGED" }).Count
                $json = @{ status=$gitSt; lastCommit=$last; machine=$MACHINE_NAME; inbox=$inbox; otherOnline=$otherOnline; otherMachine=$otherMachine; activeTasks=$activeTasks } | ConvertTo-Json
                Send-Response $ctx $json "application/json"
            }
            "GET /collab-status" {
                $tasks = Get-ChildItem "$BRAIN_DIR/tasks" -Filter "*.md" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch "README" } | Sort-Object LastWriteTime -Descending
                $html = if ($tasks) {
                    ($tasks | ForEach-Object {
                        $state = if ($_.Name -match "pending") {"pending"} elseif ($_.Name -match "active") {"active"} elseif ($_.Name -match "done") {"done"} elseif ($_.Name -match "MERGED") {"merged"} else {"unknown"}
                        $color = @{pending="var(--yellow)";active="var(--accent)";done="var(--green)";merged="var(--green)";unknown="var(--muted)"}[$state]
                        "<div class='card' style='margin-bottom:8px'><span style='color:$color;font-weight:700'>[$state]</span> $($_.Name)<div class='card-sub'>$($_.LastWriteTime)</div></div>"
                    }) -join ""
                } else { "<p class='muted'>No active tasks.</p>" }
                Send-Response $ctx $html
            }
            "GET /handoff" {
                $h = if (Test-Path "$BRAIN_DIR/handoff/current.md") { Get-Content "$BRAIN_DIR/handoff/current.md" -Raw } else { "No handoff." }
                Send-Response $ctx $h "text/plain; charset=utf-8"
            }
            "POST /handoff" {
                $body = Read-Body $ctx | ConvertFrom-Json
                $ts = Get-Date -Format "yyyy-MM-dd HH:mm"
                $content = @"
---
from: $MACHINE_NAME
to: $($body.to)
timestamp: $ts
status: active
---

# Current Handoff

## Task
$($body.task)

## Context
$($body.context)

## Files touched
$($body.files)

## Next steps
$($body.next)
"@
                $content | Set-Content "$BRAIN_DIR/handoff/current.md" -Encoding UTF8
                Sync-Brain "handoff from $MACHINE_NAME" | Out-Null
                Send-Response $ctx '{"ok":true}' "application/json"
            }
            "POST /sync" {
                $result = Sync-Brain "manual"
                $json = @{ result = $result } | ConvertTo-Json
                Send-Response $ctx $json "application/json"
            }
            "GET /inbox" {
                Send-Response $ctx (Get-InboxHtml)
            }
            "POST /inbox/delete" {
                $body = Read-Body $ctx | ConvertFrom-Json
                $path = "$BRAIN_DIR/inbox/$($body.name)"
                if (Test-Path $path) { Remove-Item $path -Force }
                Sync-Brain "inbox: deleted $($body.name)" | Out-Null
                Send-Response $ctx '{"ok":true}' "application/json"
            }
            "POST /inbox/send" {
                $body = Read-Body $ctx | ConvertFrom-Json
                $ts = Get-Date -Format "yyyyMMdd-HHmmss"
                $file = "$BRAIN_DIR/inbox/$ts-$MACHINE_NAME.md"
                @"
---
from: $MACHINE_NAME
timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
---

$($body.message)
"@ | Set-Content $file -Encoding UTF8
                Sync-Brain "inbox: new message" | Out-Null
                Send-Response $ctx '{"ok":true}' "application/json"
            }
            "GET /memory" {
                Send-Response $ctx (Get-MemoryHtml)
            }
            "POST /memory/save" {
                $body = Read-Body $ctx | ConvertFrom-Json
                $path = "$BRAIN_DIR/memory/$($body.filename)"
                $body.content | Set-Content $path -Encoding UTF8
                Sync-Brain "memory: $($body.filename)" | Out-Null
                Send-Response $ctx '{"ok":true}' "application/json"
            }
            "GET /git-log" {
                $log = try { & git -C $BRAIN_DIR log --oneline -20 2>&1 | Out-String } catch { "git unavailable" }
                Send-Response $ctx $log "text/plain"
            }
            "POST /dispatch" {
                $body = Read-Body $ctx | ConvertFrom-Json
                $task = $body.task
                $context = $body.context

                # Check if other machine online
                $beats = Get-ChildItem "$BRAIN_DIR/heartbeat" -Filter "*.json" -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -ne $MACHINE_NAME }
                $now = [int][double]::Parse((Get-Date -UFormat %s))
                $otherMachine = $null
                foreach ($b in $beats) {
                    try {
                        $d = Get-Content $b.FullName | ConvertFrom-Json
                        if (($now - $d.epoch) -lt 120) { $otherMachine = $d.machine; break }
                    } catch {}
                }

                $ts = Get-Date -Format "yyyyMMdd-HHmmss"

                if ($otherMachine) {
                    # Split mode — write remote task
                    $remoteFile = "$BRAIN_DIR/tasks/$ts-$otherMachine-pending.md"
                    @"
---
id: $ts
from: $MACHINE_NAME
to: $otherMachine
mode: split-remote
status: pending
task: $task
context_files: $context
created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
---

# Remote Task

You are the REMOTE Claude instance. LOCAL instance ($MACHINE_NAME) is handling the other half.

## Your job
$task

### Split responsibility
- You handle: research, planning, backend/data/API work
- Local handles: implementation, UI, and assembly

Context files: $context

Write your complete findings after a line that says: ## RESULT
"@ | Set-Content $remoteFile -Encoding UTF8
                    & git -C $BRAIN_DIR add -A 2>&1 | Out-Null
                    & git -C $BRAIN_DIR commit -m "task: dispatched $ts to $otherMachine" 2>&1 | Out-Null
                    & git -C $BRAIN_DIR push origin main 2>&1 | Out-Null
                    Send-Response $ctx (@{ mode="split"; taskId=$ts; remote=$otherMachine } | ConvertTo-Json) "application/json"
                } else {
                    # Solo mode
                    $soloFile = "$BRAIN_DIR/tasks/$ts-$MACHINE_NAME-solo.md"
                    @"
---
id: $ts
machine: $MACHINE_NAME
mode: solo
status: pending
task: $task
context_files: $context
created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
---

# Solo Task (other machine offline)

$task

Context: $context
"@ | Set-Content $soloFile -Encoding UTF8
                    & git -C $BRAIN_DIR add -A 2>&1 | Out-Null
                    & git -C $BRAIN_DIR commit -m "task: solo $ts" 2>&1 | Out-Null
                    & git -C $BRAIN_DIR push origin main 2>&1 | Out-Null
                    Send-Response $ctx (@{ mode="solo"; taskId=$ts } | ConvertTo-Json) "application/json"
                }
            }
            default {
                $ctx.Response.StatusCode = 404
                Send-Response $ctx "Not found"
            }
        }
    } catch {
        if ($_.Exception.Message -notmatch "listener") {
            Write-Host "Error: $_" -ForegroundColor Red
        }
    }
}
