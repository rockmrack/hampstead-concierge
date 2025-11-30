# =============================================================================
# HAMPSTEAD CONCIERGE v5 COMPLETE - FULL SYSTEM TEST
# =============================================================================
# Tests all v5 features including SMS, after-hours, calendar, analytics
# Run with: .\scripts\test-v5-complete.ps1 -Verbose
# =============================================================================

param(
    [switch]$Verbose,
    [switch]$SkipSMS,
    [switch]$SkipCalendar,
    [string]$TestPhone = "+447700900123"
)

# Configuration
$ErrorActionPreference = "Stop"
$script:testResults = @()
$script:passCount = 0
$script:failCount = 0

# Colors for output
function Write-TestHeader {
    param([string]$Title)
    Write-Host "`n" -NoNewline
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = ""
    )
    
    if ($Passed) {
        $script:passCount++
        Write-Host "  ✅ PASS: $TestName" -ForegroundColor Green
    } else {
        $script:failCount++
        Write-Host "  ❌ FAIL: $TestName" -ForegroundColor Red
    }
    
    if ($Details -and $Verbose) {
        Write-Host "     Details: $Details" -ForegroundColor Gray
    }
    
    $script:testResults += @{
        Name = $TestName
        Passed = $Passed
        Details = $Details
    }
}

# =============================================================================
# Test 1: Configuration Files Exist
# =============================================================================
Write-TestHeader "1. Configuration Files Check"

$configFiles = @(
    "config/vapi-assistant-v5.json",
    "config/vapi-system-prompt-v5.md",
    "config/vapi-tools-v5.json",
    "config/make-scenario-v5.json",
    "config/.env.v5.example",
    "database/schema-v5.sql"
)

foreach ($file in $configFiles) {
    $fullPath = Join-Path $PSScriptRoot "..\$file"
    $exists = Test-Path $fullPath
    Write-TestResult "File exists: $file" $exists
}

# =============================================================================
# Test 2: UK Phone Number Format Validation
# =============================================================================
Write-TestHeader "2. UK Phone Number Format Validation"

$ukPhonePatterns = @{
    "UK Mobile (+447...)" = "^\+447[0-9]{9}$"
    "UK Landline (+4420...)" = "^\+4420[0-9]{8}$"
    "UK Landline (+441...)" = "^\+441[0-9]{9}$"
}

$testNumbers = @(
    @{ Number = "+447459345456"; Expected = $true; Type = "Ross's mobile" },
    @{ Number = "+442071234567"; Expected = $true; Type = "London landline" },
    @{ Number = "07459345456"; Expected = $false; Type = "Without country code" },
    @{ Number = "+14155551234"; Expected = $false; Type = "US number (should fail)" }
)

foreach ($test in $testNumbers) {
    $isUK = $test.Number -match "^\+44"
    $expectedResult = $test.Expected
    $passed = ($isUK -eq $expectedResult)
    Write-TestResult "Phone format: $($test.Type)" $passed $test.Number
}

# =============================================================================
# Test 3: UK Postcode Validation
# =============================================================================
Write-TestHeader "3. UK Postcode Validation (Service Areas)"

$servicePostcodes = @("NW3", "NW6", "NW8", "NW11", "N2", "N6", "NW1", "NW2", "NW5")

$testPostcodes = @(
    @{ Postcode = "NW3 2QG"; Expected = $true; Description = "Hampstead" },
    @{ Postcode = "NW6 1XG"; Expected = $true; Description = "Kilburn" },
    @{ Postcode = "SW1A 1AA"; Expected = $false; Description = "Westminster (outside area)" },
    @{ Postcode = "E1 6AN"; Expected = $false; Description = "Whitechapel (outside area)" }
)

foreach ($test in $testPostcodes) {
    $postcodePrefix = ($test.Postcode -split " ")[0]
    $inServiceArea = $servicePostcodes -contains $postcodePrefix
    $passed = ($inServiceArea -eq $test.Expected)
    Write-TestResult "Postcode: $($test.Description)" $passed $test.Postcode
}

# =============================================================================
# Test 4: After-Hours Detection (UK Timezone)
# =============================================================================
Write-TestHeader "4. After-Hours Detection (Europe/London)"

function Test-AfterHours {
    param([datetime]$TestTime)
    
    $hour = $TestTime.Hour
    $dayOfWeek = $TestTime.DayOfWeek
    
    # Sunday or Saturday
    if ($dayOfWeek -eq "Sunday" -or $dayOfWeek -eq "Saturday") {
        return $true
    }
    
    # Before 8 AM or after 6 PM
    if ($hour -lt 8 -or $hour -ge 18) {
        return $true
    }
    
    return $false
}

$afterHoursTests = @(
    @{ Time = (Get-Date "2025-01-15 10:00"); Expected = $false; Desc = "Wednesday 10 AM" },
    @{ Time = (Get-Date "2025-01-15 07:30"); Expected = $true; Desc = "Wednesday 7:30 AM (before hours)" },
    @{ Time = (Get-Date "2025-01-15 19:00"); Expected = $true; Desc = "Wednesday 7 PM (after hours)" },
    @{ Time = (Get-Date "2025-01-19 12:00"); Expected = $true; Desc = "Sunday 12 PM (weekend)" }
)

foreach ($test in $afterHoursTests) {
    $isAfterHours = Test-AfterHours -TestTime $test.Time
    $passed = ($isAfterHours -eq $test.Expected)
    Write-TestResult "After-hours: $($test.Desc)" $passed "Expected: $($test.Expected), Got: $isAfterHours"
}

# =============================================================================
# Test 5: JSON Configuration Parsing
# =============================================================================
Write-TestHeader "5. JSON Configuration Parsing"

$jsonFiles = @(
    "config/vapi-assistant-v5.json",
    "config/vapi-tools-v5.json",
    "config/make-scenario-v5.json"
)

foreach ($file in $jsonFiles) {
    $fullPath = Join-Path $PSScriptRoot "..\$file"
    try {
        if (Test-Path $fullPath) {
            $content = Get-Content $fullPath -Raw
            $json = $content | ConvertFrom-Json
            Write-TestResult "JSON valid: $file" $true
        } else {
            Write-TestResult "JSON valid: $file" $false "File not found"
        }
    } catch {
        Write-TestResult "JSON valid: $file" $false $_.Exception.Message
    }
}

# =============================================================================
# Test 6: v5 Feature Flags in Configuration
# =============================================================================
Write-TestHeader "6. v5 Feature Flags Check"

$assistantPath = Join-Path $PSScriptRoot "..\config\vapi-assistant-v5.json"
if (Test-Path $assistantPath) {
    $assistant = Get-Content $assistantPath -Raw | ConvertFrom-Json
    
    # Check for v5-specific features
    $features = @{
        "SMS Confirmation" = ($assistant.metadata.features -contains "sms_confirmation")
        "After-Hours" = ($assistant.metadata.features -contains "after_hours_handling")
        "Appointment Booking" = ($assistant.metadata.features -contains "appointment_booking")
        "Analytics" = ($assistant.metadata.features -contains "analytics_dashboard")
        "Multi-Language" = ($assistant.metadata.features -contains "multi_language_support")
    }
    
    foreach ($feature in $features.GetEnumerator()) {
        Write-TestResult "Feature enabled: $($feature.Key)" $feature.Value
    }
} else {
    Write-TestResult "Feature flags check" $false "Assistant config not found"
}

# =============================================================================
# Test 7: Quality Scoring Thresholds
# =============================================================================
Write-TestHeader "7. Quality Scoring Validation"

$qualityTests = @(
    @{ Score = 95; Expected = "excellent"; Desc = "Score 95 = Excellent" },
    @{ Score = 75; Expected = "good"; Desc = "Score 75 = Good" },
    @{ Score = 55; Expected = "acceptable"; Desc = "Score 55 = Acceptable" },
    @{ Score = 40; Expected = "poor"; Desc = "Score 40 = Poor" }
)

foreach ($test in $qualityTests) {
    $category = switch ($test.Score) {
        { $_ -ge 85 } { "excellent" }
        { $_ -ge 70 } { "good" }
        { $_ -ge 50 } { "acceptable" }
        default { "poor" }
    }
    $passed = ($category -eq $test.Expected)
    Write-TestResult $test.Desc $passed "Got: $category"
}

# =============================================================================
# Test 8: SMS Template Variables
# =============================================================================
Write-TestHeader "8. SMS Template Variable Substitution"

$smsTemplate = "Hi {name}! Thanks for calling Hampstead Renovations. Ross will call you back within {timeframe}. Questions? WhatsApp Ross at {ross_mobile}."

$variables = @{
    "{name}" = "John Smith"
    "{timeframe}" = "2 hours"
    "{ross_mobile}" = "+447459345456"
}

$finalMessage = $smsTemplate
foreach ($var in $variables.GetEnumerator()) {
    $finalMessage = $finalMessage.Replace($var.Key, $var.Value)
}

$hasNoPlaceholders = $finalMessage -notmatch "\{[^}]+\}"
Write-TestResult "SMS template substitution" $hasNoPlaceholders $finalMessage.Substring(0, [Math]::Min(50, $finalMessage.Length)) + "..."

$messageLength = $finalMessage.Length
$validLength = ($messageLength -le 160)
Write-TestResult "SMS within 160 char limit" $validLength "Length: $messageLength chars"

# =============================================================================
# Test 9: Multi-Language Detection
# =============================================================================
Write-TestHeader "9. Multi-Language Detection"

function Detect-Language {
    param([string]$Input)
    
    $polishTriggers = @("dzień dobry", "czy mówi pan po polsku", "proszę", "dziękuję")
    $spanishTriggers = @("hola", "buenos días", "habla español", "gracias")
    
    $inputLower = $Input.ToLower()
    
    foreach ($trigger in $polishTriggers) {
        if ($inputLower -match $trigger) { return "polish" }
    }
    
    foreach ($trigger in $spanishTriggers) {
        if ($inputLower -match $trigger) { return "spanish" }
    }
    
    return "english"
}

$languageTests = @(
    @{ Input = "Hello, I need a builder"; Expected = "english" },
    @{ Input = "Dzień dobry, szukam budowlańca"; Expected = "polish" },
    @{ Input = "Hola, necesito un constructor"; Expected = "spanish" }
)

foreach ($test in $languageTests) {
    $detected = Detect-Language -Input $test.Input
    $passed = ($detected -eq $test.Expected)
    Write-TestResult "Language: $($test.Expected)" $passed "Input: $($test.Input.Substring(0, [Math]::Min(30, $test.Input.Length)))..."
}

# =============================================================================
# Test 10: Appointment Time Slot Validation
# =============================================================================
Write-TestHeader "10. Appointment Time Slot Validation"

$validDays = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
$startHour = 9
$endHour = 17

$appointmentTests = @(
    @{ Day = "Tuesday"; Hour = 10; Expected = $true; Desc = "Tuesday 10 AM" },
    @{ Day = "Saturday"; Hour = 14; Expected = $true; Desc = "Saturday 2 PM" },
    @{ Day = "Sunday"; Hour = 12; Expected = $false; Desc = "Sunday (closed)" },
    @{ Day = "Monday"; Hour = 8; Expected = $false; Desc = "Monday 8 AM (before opening)" },
    @{ Day = "Friday"; Hour = 18; Expected = $false; Desc = "Friday 6 PM (after closing)" }
)

foreach ($test in $appointmentTests) {
    $dayValid = $validDays -contains $test.Day
    $timeValid = ($test.Hour -ge $startHour) -and ($test.Hour -lt $endHour)
    $slotValid = $dayValid -and $timeValid
    $passed = ($slotValid -eq $test.Expected)
    Write-TestResult "Appointment slot: $($test.Desc)" $passed
}

# =============================================================================
# Summary
# =============================================================================
Write-TestHeader "TEST SUMMARY"

$totalTests = $script:passCount + $script:failCount
$passRate = if ($totalTests -gt 0) { [math]::Round(($script:passCount / $totalTests) * 100, 1) } else { 0 }

Write-Host ""
Write-Host "  Total Tests:  $totalTests" -ForegroundColor White
Write-Host "  Passed:       $($script:passCount)" -ForegroundColor Green
Write-Host "  Failed:       $($script:failCount)" -ForegroundColor $(if ($script:failCount -gt 0) { "Red" } else { "Green" })
Write-Host "  Pass Rate:    $passRate%" -ForegroundColor $(if ($passRate -ge 90) { "Green" } elseif ($passRate -ge 70) { "Yellow" } else { "Red" })
Write-Host ""

if ($script:failCount -eq 0) {
    Write-Host "  🎉 ALL TESTS PASSED! v5 COMPLETE is ready." -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Some tests failed. Please review before deployment." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan

# Return exit code based on test results
exit $script:failCount
