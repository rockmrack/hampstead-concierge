<#
.SYNOPSIS
    Hampstead Concierge - System Health Check
.DESCRIPTION
    Monitors the health of all system components
.EXAMPLE
    .\health-check.ps1
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  HAMPSTEAD CONCIERGE HEALTH CHECK" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$healthStatus = @()

# Check 1: Vapi Status
Write-Host "[1] Vapi.ai Status" -ForegroundColor Yellow
try {
    $vapiStatus = Invoke-RestMethod -Uri "https://status.vapi.ai/api/v2/status.json" -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($vapiStatus.status.indicator -eq "none") {
        Write-Host "    ✓ Vapi.ai - Operational" -ForegroundColor Green
        $healthStatus += @{Service = "Vapi.ai"; Status = "OK"}
    } else {
        Write-Host "    ⚠ Vapi.ai - $($vapiStatus.status.description)" -ForegroundColor Yellow
        $healthStatus += @{Service = "Vapi.ai"; Status = "Warning"}
    }
}
catch {
    Write-Host "    ⚠ Vapi.ai - Could not check status" -ForegroundColor Yellow
    $healthStatus += @{Service = "Vapi.ai"; Status = "Unknown"}
}

# Check 2: Twilio Status
Write-Host "[2] Twilio Status" -ForegroundColor Yellow
try {
    $twilioStatus = Invoke-RestMethod -Uri "https://status.twilio.com/api/v2/status.json" -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($twilioStatus.status.indicator -eq "none") {
        Write-Host "    ✓ Twilio - Operational" -ForegroundColor Green
        $healthStatus += @{Service = "Twilio"; Status = "OK"}
    } else {
        Write-Host "    ⚠ Twilio - $($twilioStatus.status.description)" -ForegroundColor Yellow
        $healthStatus += @{Service = "Twilio"; Status = "Warning"}
    }
}
catch {
    Write-Host "    ⚠ Twilio - Could not check status" -ForegroundColor Yellow
    $healthStatus += @{Service = "Twilio"; Status = "Unknown"}
}

# Check 3: OpenAI Status
Write-Host "[3] OpenAI Status" -ForegroundColor Yellow
try {
    $openaiStatus = Invoke-RestMethod -Uri "https://status.openai.com/api/v2/status.json" -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($openaiStatus.status.indicator -eq "none") {
        Write-Host "    ✓ OpenAI - Operational" -ForegroundColor Green
        $healthStatus += @{Service = "OpenAI"; Status = "OK"}
    } else {
        Write-Host "    ⚠ OpenAI - $($openaiStatus.status.description)" -ForegroundColor Yellow
        $healthStatus += @{Service = "OpenAI"; Status = "Warning"}
    }
}
catch {
    Write-Host "    ⚠ OpenAI - Could not check status" -ForegroundColor Yellow
    $healthStatus += @{Service = "OpenAI"; Status = "Unknown"}
}

# Check 4: ElevenLabs Status
Write-Host "[4] ElevenLabs Status" -ForegroundColor Yellow
try {
    # ElevenLabs doesn't have a public status API, so we check their main endpoint
    $response = Invoke-WebRequest -Uri "https://api.elevenlabs.io/v1/voices" -Method Head -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 401) {
        Write-Host "    ✓ ElevenLabs - API Responsive" -ForegroundColor Green
        $healthStatus += @{Service = "ElevenLabs"; Status = "OK"}
    }
}
catch {
    Write-Host "    ⚠ ElevenLabs - Could not check status" -ForegroundColor Yellow
    $healthStatus += @{Service = "ElevenLabs"; Status = "Unknown"}
}

# Check 5: Make.com Status
Write-Host "[5] Make.com Status" -ForegroundColor Yellow
try {
    $makeStatus = Invoke-RestMethod -Uri "https://status.make.com/api/v2/status.json" -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($makeStatus.status.indicator -eq "none") {
        Write-Host "    ✓ Make.com - Operational" -ForegroundColor Green
        $healthStatus += @{Service = "Make.com"; Status = "OK"}
    } else {
        Write-Host "    ⚠ Make.com - $($makeStatus.status.description)" -ForegroundColor Yellow
        $healthStatus += @{Service = "Make.com"; Status = "Warning"}
    }
}
catch {
    Write-Host "    ⚠ Make.com - Could not check status" -ForegroundColor Yellow
    $healthStatus += @{Service = "Make.com"; Status = "Unknown"}
}

# Check 6: Deepgram Status
Write-Host "[6] Deepgram Status" -ForegroundColor Yellow
try {
    $deepgramStatus = Invoke-RestMethod -Uri "https://status.deepgram.com/api/v2/status.json" -TimeoutSec 5 -ErrorAction SilentlyContinue
    if ($deepgramStatus.status.indicator -eq "none") {
        Write-Host "    ✓ Deepgram - Operational" -ForegroundColor Green
        $healthStatus += @{Service = "Deepgram"; Status = "OK"}
    } else {
        Write-Host "    ⚠ Deepgram - $($deepgramStatus.status.description)" -ForegroundColor Yellow
        $healthStatus += @{Service = "Deepgram"; Status = "Warning"}
    }
}
catch {
    Write-Host "    ⚠ Deepgram - Could not check status" -ForegroundColor Yellow
    $healthStatus += @{Service = "Deepgram"; Status = "Unknown"}
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  HEALTH SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$okCount = ($healthStatus | Where-Object { $_.Status -eq "OK" }).Count
$totalCount = $healthStatus.Count

if ($okCount -eq $totalCount) {
    Write-Host "  ✓ All systems operational ($okCount/$totalCount)" -ForegroundColor Green
} elseif ($okCount -gt 0) {
    Write-Host "  ⚠ Some systems may have issues ($okCount/$totalCount OK)" -ForegroundColor Yellow
} else {
    Write-Host "  ✗ Multiple systems may be down" -ForegroundColor Red
}

Write-Host ""
Write-Host "  Services:" -ForegroundColor Gray
foreach ($service in $healthStatus) {
    $icon = switch ($service.Status) {
        "OK" { "✓" }
        "Warning" { "⚠" }
        "Unknown" { "?" }
        default { "✗" }
    }
    $color = switch ($service.Status) {
        "OK" { "Green" }
        "Warning" { "Yellow" }
        default { "Gray" }
    }
    Write-Host "    $icon $($service.Service)" -ForegroundColor $color
}

Write-Host ""
Write-Host "  Last checked: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Return appropriate exit code
if ($okCount -eq $totalCount) { exit 0 }
elseif ($okCount -gt 0) { exit 1 }
else { exit 2 }
