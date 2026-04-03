# Скрипт к сценарию docs/quickstarts/create-new-model.md — вендор, создание типа сенсора и модели.
param(
    [string] $Base = $env:UMEC_BASE,
    [string] $VendorCode = $env:UMEC_VENDOR_CODE,
    [string] $VendorName = $env:UMEC_VENDOR_NAME,
    [string] $Secret = $env:UMEC_VENDOR_SECRET,
    [switch] $CreateVendor,
    [string] $ModelCode = "ACME_TEMP_V1",
    [string] $FirmwareVersion = "1.0.0",
    [string] $HardwareVersion = "1.0"
)

if (-not $Base) { $Base = "https://api.rumecdev.deviot.cloud" }
if (-not $VendorCode) { $VendorCode = "ACME_LABS" }
if (-not $VendorName) { $VendorName = "ACME Labs" }

# Шаг 1 — создать вендора (опционально): POST /vendors.
if ($CreateVendor) {
    if (-not $Secret) { throw "Для -CreateVendor задайте -Secret" }
    $body = @{ code = $VendorCode; name = $VendorName; secret = $Secret } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$Base/api/vendor/v1/vendors" -ContentType "application/json" -Body $body
    Write-Host "Вендор создан: $VendorCode"
}
elseif (-not $Secret) {
    throw "Укажите -Secret или используйте -CreateVendor"
}

# Шаг 2 — токен из Identity здесь не запрашивается; в Bearer подставляется -Secret.
$hdr = @{ Authorization = "Bearer $Secret" }
# Шаг 3 — POST /sensors и PUT /models.
$sensors = @{ items = @(@{ code = "TEMP_C"; name = "Temperature"; unitOfMeasure = "°C" }) } | ConvertTo-Json -Depth 5
Invoke-RestMethod -Method Post -Uri "$Base/api/vendor/v1/sensors" -Headers $hdr -ContentType "application/json" -Body $sensors
Write-Host "Каталог сенсоров: TEMP_C"

$model = @{
    model = @{
        modelCode       = $ModelCode
        name            = "ACME Temperature Node"
        firmwareVersion = $FirmwareVersion
        hardwareVersion = $HardwareVersion
        units = @{
            main = @{
                name = "Main"
                sensors = @{
                    temperature = @{
                        connectedSensorCode = "TEMP_C"
                        name                = "Ambient temperature"
                        valueType           = "SENSOR_VALUE_TYPE_CONSUMPTION"
                        isPersistent        = $true
                    }
                }
            }
        }
    }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Method Put -Uri "$Base/api/vendor/v1/models" -Headers $hdr -ContentType "application/json" -Body $model
Write-Host "Модель опубликована: $ModelCode"
