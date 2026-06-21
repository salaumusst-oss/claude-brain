# Merge Results — waits for remote task to finish, then combines both outputs
# Claude calls this after finishing its local half

param(
    [Parameter(Mandatory)][string]$TaskId,
    [Parameter(Mandatory)][string]$LocalResult,
    [string]$BrainDir = "C:\Users\musst\claude-brain",
    [int]$TimeoutSeconds = 300  # wait up to 5 min for remote
)

$MY_MACHINE = $env:COMPUTERNAME

function Log { param([string]$Msg) Write-Host "[$( Get-Date -Format 'HH:mm:ss')] $Msg" }

Log "Waiting for remote result (task $TaskId)..."

$donePattern = "$BrainDir\tasks\$TaskId-*-done.md"
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$remoteResult = $null

while ((Get-Date) -lt $deadline) {
    & git -C $BrainDir pull 2>&1 | Out-Null

    $doneFiles = Get-ChildItem "$BrainDir\tasks" -Filter "$TaskId-*-done.md" -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -notmatch $MY_MACHINE }

    if ($doneFiles) {
        $remoteResult = Get-Content $doneFiles[0].FullName -Raw
        Log "Remote result received from: $($doneFiles[0].Name)"
        break
    }

    Log "Remote not done yet. Checking again in 15s..."
    Start-Sleep -Seconds 15
}

# Build merged output
if ($remoteResult) {
    $remoteResultSection = if ($remoteResult -match "## RESULT\s*\n([\s\S]+)") { $matches[1].Trim() } else { $remoteResult }

    $merged = @"
# Combined Result — Task $TaskId

## Local Result ($MY_MACHINE)
$LocalResult

## Remote Result
$remoteResultSection

---
*Both instances finished. Review and combine above into your final answer.*
"@
} else {
    Log "Remote timed out after ${TimeoutSeconds}s. Using local result only."
    $merged = @"
# Result — Task $TaskId (Local Only — Remote Timed Out)

$LocalResult

---
*Remote instance did not respond in time. This is the local result only.*
"@
}

# Save merged result
$mergedFile = "$BrainDir\tasks\$TaskId-MERGED.md"
$merged | Set-Content $mergedFile -Encoding UTF8

& git -C $BrainDir add -A 2>&1 | Out-Null
& git -C $BrainDir commit -m "task: merged result $TaskId" 2>&1 | Out-Null
& git -C $BrainDir push origin main 2>&1 | Out-Null

Write-Output $merged
