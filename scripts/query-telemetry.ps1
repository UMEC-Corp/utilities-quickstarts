# Скрипт к сценарию docs/quickstarts/query-telemetry.md — карточка юнита и тики.
param(
    [string] $Base = $(if ($env:UMEC_BASE) { $env:UMEC_BASE } else { "https://api.rumecdev.deviot.cloud" }),
    [Parameter(Mandatory)]
    [string] $AccessToken,
    [Parameter(Mandatory)]
    [long] $UnitId,
    [string] $InputCode = $(if ($env:UMEC_INPUT_CODE) { $env:UMEC_INPUT_CODE } else { "temperature" }),
    [long] $Begin = $(if ($env:UMEC_TICKS_BEGIN) { [long]$env:UMEC_TICKS_BEGIN } else { 1719705600 }),
    [long] $End = $(if ($env:UMEC_TICKS_END) { [long]$env:UMEC_TICKS_END } else { 1719792000 }),
    [int] $TimeFrame = $(if ($env:UMEC_TICKS_TIMEFRAME) { [int]$env:UMEC_TICKS_TIMEFRAME } else { 3600 })
)

$Base = $Base.TrimEnd("/")
$hdr = @{ Authorization = "Bearer $AccessToken" }

# Шаг 1 — найти inputId: GET /units/{unitId}.
$details = Invoke-RestMethod -Method Get -Uri "$Base/api/customer/v1/units/$UnitId" -Headers $hdr
$inp = $details.inputs | Where-Object { $_.code -eq $InputCode } | Select-Object -First 1
if (-not $inp) {
    $details.inputs | ConvertTo-Json -Depth 6
    throw "Вход с code=$InputCode не найден"
}

$inputId = $inp.id
Write-Host "inputId:" $inputId

# Шаг 2 — GET /units/{unitId}/ticks.
$q = "inputIds=$inputId&begin=$Begin&end=$End&timeFrame=$TimeFrame"
$ticks = Invoke-RestMethod -Method Get -Uri "$Base/api/customer/v1/units/${UnitId}/ticks?$q" -Headers $hdr
$ticks | ConvertTo-Json -Depth 10
