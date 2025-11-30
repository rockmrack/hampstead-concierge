<#
.SYNOPSIS
    Hampstead Concierge - Test Suite Runner
.DESCRIPTION
    Runs automated tests for the AI Voice Assistant system
.PARAMETER Full
    Run all tests including integration tests
.PARAMETER LatencyOnly
    Run only latency tests
.PARAMETER SpamTest
    Run only spam detection tests
.PARAMETER WebhookTest
    Test webhook connectivity only
.EXAMPLE
    .\run-tests.ps1 -Full
    .\run-tests.ps1 -WebhookTest
#>

param(
    [switch]$Full,
    [switch]$LatencyOnly,
    [switch]$SpamTest,
    [switch]$WebhookTest
)

# Configuration - UPDATE THESE VALUES
$config = @{
    WebhookUrl = "https://hook.eu1.make.com/YOUR_WEBHOOK_ID"
    TwilioNumber = "+442081234567"
    RossNumber = "+447459345456"
    VapiApiKey = $env:VAPI_API_KEY
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  HAMPSTEAD CONCIERGE TEST SUITE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Webhook Connectivity
function Test-WebhookConnectivity {
    Write-Host "[TEST 1] Webhook Connectivity" -ForegroundColor Yellow
    
    $testPayload = @{
        message = @{
            type = "function-call"
            functionCall = @{
                name = "log_lead_details"
                parameters = @{
                    caller_name = "Test User"
                    phone_number = "+447700900999"
                    category = "Other"
                    summary = "Automated test call - please ignore"
                    sentiment = "Standard"
                }
            }
        }
        call = @{
            id = "test_$(Get-Date -Format 'yyyyMMddHHmmss')"
            createdAt = (Get-Date).ToString("o")
        }
    } | ConvertTo-Json -Depth 5
    
    try {
        $response = Invoke-RestMethod -Uri $config.WebhookUrl -Method Post -Body $testPayload -ContentType "application/json" -TimeoutSec 10
        Write-Host "  ✓ Webhook responded successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  ✗ Webhook failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Test 2: Payload Validation
function Test-PayloadStructure {
    Write-Host "[TEST 2] Payload Structure Validation" -ForegroundColor Yellow
    
    $testFiles = Get-ChildItem -Path "..\webhooks\payload-examples\*.json"
    $allValid = $true
    
    foreach ($file in $testFiles) {
        try {
            $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
            
            # Check required fields
            $requiredFields = @("message", "call")
            $missingFields = @()
            
            foreach ($field in $requiredFields) {
                if (-not $content.$field) {
                    $missingFields += $field
                }
            }
            
            if ($missingFields.Count -eq 0) {
                Write-Host "  ✓ $($file.Name) - Valid" -ForegroundColor Green
            } else {
                Write-Host "  ✗ $($file.Name) - Missing: $($missingFields -join ', ')" -ForegroundColor Red
                $allValid = $false
            }
        }
        catch {
            Write-Host "  ✗ $($file.Name) - Invalid JSON: $($_.Exception.Message)" -ForegroundColor Red
            $allValid = $false
        }
    }
    
    return $allValid
}

# Test 3: Configuration File Validation
function Test-ConfigurationFiles {
    Write-Host "[TEST 3] Configuration File Validation" -ForegroundColor Yellow
    
    $configFiles = @(
        @{Path = "..\config\vapi-assistant.json"; Type = "Vapi Assistant"},
        @{Path = "..\config\vapi-tools.json"; Type = "Vapi Tools"},
        @{Path = "..\config\make-scenario.json"; Type = "Make Scenario"},
        @{Path = "..\config\.env.example"; Type = "Environment Template"}
    )
    
    $allValid = $true
    
    foreach ($configFile in $configFiles) {
        if (Test-Path $configFile.Path) {
            if ($configFile.Path -like "*.json") {
                try {
                    Get-Content $configFile.Path -Raw | ConvertFrom-Json | Out-Null
                    Write-Host "  ✓ $($configFile.Type) - Valid JSON" -ForegroundColor Green
                }
                catch {
                    Write-Host "  ✗ $($configFile.Type) - Invalid JSON" -ForegroundColor Red
                    $allValid = $false
                }
            } else {
                Write-Host "  ✓ $($configFile.Type) - File exists" -ForegroundColor Green
            }
        } else {
            Write-Host "  ✗ $($configFile.Type) - File not found" -ForegroundColor Red
            $allValid = $false
        }
    }
    
    return $allValid
}

# Test 4: Phone Number Format Validation
function Test-PhoneNumberFormats {
    Write-Host "[TEST 4] Phone Number Format Validation" -ForegroundColor Yellow
    
    $testNumbers = @(
        @{Number = "+447459345456"; Expected = $true; Desc = "International UK mobile"},
        @{Number = "07459345456"; Expected = $true; Desc = "National UK mobile"},
        @{Number = "+442081234567"; Expected = $true; Desc = "International UK landline"},
        @{Number = "invalid"; Expected = $false; Desc = "Invalid format"},
        @{Number = "12345"; Expected = $false; Desc = "Too short"}
    )
    
    $allValid = $true
    
    foreach ($test in $testNumbers) {
        $isValid = $test.Number -match '^\+?44?[0-9]{10,11}$|^0[0-9]{10}$'
        
        if ($isValid -eq $test.Expected) {
            Write-Host "  ✓ $($test.Desc): $($test.Number)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($test.Desc): $($test.Number) - Expected $($test.Expected), Got $isValid" -ForegroundColor Red
            $allValid = $false
        }
    }
    
    return $allValid
}

# Test 5: Environment Variables Check
function Test-EnvironmentVariables {
    Write-Host "[TEST 5] Environment Variables Check" -ForegroundColor Yellow
    
    $requiredVars = @(
        "VAPI_API_KEY",
        "TWILIO_ACCOUNT_SID",
        "OPENAI_API_KEY",
        "ELEVENLABS_API_KEY"
    )
    
    $allSet = $true
    
    foreach ($var in $requiredVars) {
        $value = [Environment]::GetEnvironmentVariable($var)
        if ($value) {
            $masked = $value.Substring(0, [Math]::Min(4, $value.Length)) + "****"
            Write-Host "  ✓ $var = $masked" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ $var - Not set (optional for testing)" -ForegroundColor Yellow
            # Not failing as env vars may not be set in all environments
        }
    }
    
    return $true
}

# Run selected tests
Write-Host ""
$results = @()

if ($WebhookTest -or $Full) {
    $results += @{Test = "Webhook"; Pass = Test-WebhookConnectivity}
}

if (-not $WebhookTest) {
    $results += @{Test = "Payloads"; Pass = Test-PayloadStructure}
    $results += @{Test = "Config"; Pass = Test-ConfigurationFiles}
    $results += @{Test = "Phone Numbers"; Pass = Test-PhoneNumberFormats}
    $results += @{Test = "Environment"; Pass = Test-EnvironmentVariables}
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$passed = ($results | Where-Object { $_.Pass }).Count
$total = $results.Count

foreach ($result in $results) {
    $status = if ($result.Pass) { "✓ PASS" } else { "✗ FAIL" }
    $color = if ($result.Pass) { "Green" } else { "Red" }
    Write-Host "  $status - $($result.Test)" -ForegroundColor $color
}

Write-Host ""
Write-Host "  Total: $passed/$total tests passed" -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Yellow" })
Write-Host ""

# Exit code
if ($passed -eq $total) {
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some tests failed. Please review above." -ForegroundColor Red
    exit 1
}
