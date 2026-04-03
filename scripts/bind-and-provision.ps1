# Скрипт к сценарию docs/quickstarts/bind-and-provision.md — вход, привязка, refresh.
param(
    [string] $Base = $(if ($env:UMEC_BASE) { $env:UMEC_BASE } else { "https://api.rumecdev.deviot.cloud" }),
    [Parameter(Mandatory)]
    [string] $User,
    [Parameter(Mandatory)]
    [string] $Password,
    [string] $DeviceSerial = $(if ($env:UMEC_DEVICE_SERIAL) { $env:UMEC_DEVICE_SERIAL } else { "SN-ACME-00042" }),
    [Parameter(Mandatory)]
    [string] $UserCode,
    [string] $VendorCode = $(if ($env:UMEC_VENDOR_CODE) { $env:UMEC_VENDOR_CODE } else { "ACME_LABS" }),
    [string] $ModelCode = $(if ($env:UMEC_MODEL_CODE) { $env:UMEC_MODEL_CODE } else { "ACME_TEMP_V1" }),
    [string] $FirmwareVersion = "1.0.0",
    [string] $HardwareVersion = "1.0",
    [double] $Lat = 55.7558,
    [double] $Lon = 37.6173,
    [switch] $DoRefresh
)

$Base = $Base.TrimEnd("/")
# Шаг 1 — вход: POST /signin.
$login = @{ userName = $User; password = $Password } | ConvertTo-Json
$auth = Invoke-RestMethod -Method Post -Uri "$Base/api/customer/v1/signin" -ContentType "application/json" -Body $login
Write-Host "signin: OK"

$hdr = @{ Authorization = "Bearer $($auth.accessToken)" }
# Шаг 2 — привязка: POST /units/bind.
$bindBody = @{
    deviceSerial = $DeviceSerial
    userCode     = $UserCode
    firmware     = @{
        vendorCode       = $VendorCode
        modelCode        = $ModelCode
        firmwareVersion  = $FirmwareVersion
        hardwareVersion  = $HardwareVersion
    }
    location = @{ latitude = $Lat; longitude = $Lon }
} | ConvertTo-Json -Depth 6

$bind = Invoke-RestMethod -Method Post -Uri "$Base/api/customer/v1/units/bind" -Headers $hdr -ContentType "application/json" -Body $bindBody
if (-not $bind.items -or $bind.items.Count -eq 0) { $bind | ConvertTo-Json -Depth 10; throw "bind: пустой items" }

Write-Host "bind: OK"
Write-Host "unitId:" $bind.items[0].unitId
Write-Host "accessToken:" ($auth.accessToken.Substring(0, [Math]::Min(24, $auth.accessToken.Length)) + "…")

# Шаг 3 — обновить access-токен (опционально): POST /refresh.
if ($DoRefresh) {
    $refBody = @{ refreshToken = $auth.refreshToken } | ConvertTo-Json
    $ref = Invoke-RestMethod -Method Post -Uri "$Base/api/customer/v1/refresh" -ContentType "application/json" -Body $refBody
    Write-Host "refresh: OK"
    Write-Host "new accessToken:" ($ref.accessToken.Substring(0, [Math]::Min(24, $ref.accessToken.Length)) + "…")
}
