# Сценарий: создание новой модели устройства

## Цель

**Создать** описание **модели устройства** в платформе.

## Предусловия

не требуются

## Шаги

### 1. Создать вендора (при необходимости)

Сохраните **секрет** вендора в надёжном месте: необходим для аутентификации в **Identity**.

=== "Python"

    ```python
    import requests

    BASE = "https://api.rumecdev.deviot.cloud"
    vendor_secret = "<секрет>"

    r = requests.post(
        f"{BASE}/api/vendor/v1/vendors",
        json={
            "code": "ACME_LABS",
            "name": "ACME Labs",
            "secret": vendor_secret,
        },
        headers={"Content-Type": "application/json"},
        timeout=30,
    )
    r.raise_for_status()
    ```

=== "PowerShell"

    ```powershell
    $Base = "https://api.rumecdev.deviot.cloud"
    $VendorSecret = "<секрет>"

    $body = @{
        code   = "ACME_LABS"
        name   = "ACME Labs"
        secret = $VendorSecret
    } | ConvertTo-Json

    Invoke-RestMethod -Method Post -Uri "$Base/api/vendor/v1/vendors" `
        -ContentType "application/json" -Body $body
    ```

### 2. Получить токен доступа в Identity (TODO)

Для вызовов Vendor API в заголовке `Authorization: Bearer` нужен **токен доступа**. Его выдаёт сервис **Identity**: вы передаёте учётные данные вендора (код вендора и секрет), в ответ получаете токен с ограниченным временем жизни. Конкретный базовый URL Identity, путь эндпоинта и формат тела запроса смотрите в документации платформы для выбранного стенда.

### 3. Создать тип сенсора и описание модели

В примерах ниже в `Bearer` подставьте **токен с шага 2**.

Сначала **создайте** запись в каталоге сенсоров (`POST /sensors`), затем **создайте** модель (`PUT /models`). Поле `connectedSensorCode` в модели должно совпадать с `code` в каталоге.

=== "Python"

    ```python
    import requests

    BASE = "https://api.rumecdev.deviot.cloud"
    access_token = "<токен из Identity>"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }

    requests.post(
        f"{BASE}/api/vendor/v1/sensors",
        json={
            "items": [
                {"code": "TEMP_C", "name": "Temperature", "unitOfMeasure": "°C"}
            ]
        },
        headers=headers,
        timeout=30,
    ).raise_for_status()

    requests.put(
        f"{BASE}/api/vendor/v1/models",
        json={
            "model": {
                "modelCode": "ACME_TEMP_V1",
                "name": "ACME Temperature Node",
                "firmwareVersion": "1.0.0",
                "hardwareVersion": "1.0",
                "units": {
                    "main": {
                        "name": "Main",
                        "sensors": {
                            "temperature": {
                                "connectedSensorCode": "TEMP_C",
                                "name": "Ambient temperature",
                                "valueType": "SENSOR_VALUE_TYPE_CONSUMPTION",
                                "isPersistent": True,
                            }
                        },
                    }
                },
            }
        },
        headers=headers,
        timeout=60,
    ).raise_for_status()
    ```

=== "PowerShell"

    ```powershell
    $Base = "https://api.rumecdev.deviot.cloud"
    $AccessToken = "<токен из Identity>"
    $hdr = @{ Authorization = "Bearer $AccessToken" }

    $sensors = @{
        items = @(
            @{ code = "TEMP_C"; name = "Temperature"; unitOfMeasure = "°C" }
        )
    } | ConvertTo-Json -Depth 5

    Invoke-RestMethod -Method Post -Uri "$Base/api/vendor/v1/sensors" `
        -Headers $hdr -ContentType "application/json" -Body $sensors

    $model = @{
        model = @{
            modelCode        = "ACME_TEMP_V1"
            name             = "ACME Temperature Node"
            firmwareVersion  = "1.0.0"
            hardwareVersion  = "1.0"
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

    Invoke-RestMethod -Method Put -Uri "$Base/api/vendor/v1/models" `
        -Headers $hdr -ContentType "application/json" -Body $model
    ```

Ключ **`temperature`** в модели — код **входа** в карточке юнита у пользователя.

## Ожидаемый результат

- Секрет вендора сохранён у вас; для Vendor API используется **токен из Identity**. В каталоге **создан** тип **`TEMP_C`**, **создана** модель **`ACME_TEMP_V1`** с юнитом **`main`** и входом **`temperature`**.
- Итоговый скрипт для краткости передаёт в `Authorization` значение из `--secret`; в реальной интеграции подставляйте **токен Identity** (как в шаге 2), когда платформа этого требует.

## Итоговый скрипт сценария

=== "Python"

    ```python
    #!/usr/bin/env python3
    
    from __future__ import annotations
    
    import argparse
    import os
    import sys
    
    try:
        import requests
    except ImportError:
        print("Установите requests: pip install requests", file=sys.stderr)
        sys.exit(1)
    
    
    def main() -> int:
        p = argparse.ArgumentParser(
            description="Создание новой модели: вендор (опционально), тип сенсора в каталоге, публикация модели.",
        )
        p.add_argument(
            "--base",
            default=os.environ.get("UMEC_BASE", "https://api.rumecdev.deviot.cloud"),
            help="Базовый URL API",
        )
        p.add_argument("--vendor-code", default=os.environ.get("UMEC_VENDOR_CODE", "ACME_LABS"))
        p.add_argument("--vendor-name", default=os.environ.get("UMEC_VENDOR_NAME", "ACME Labs"))
        p.add_argument(
            "--secret",
            default=os.environ.get("UMEC_VENDOR_SECRET"),
            required=False,
            help="Секрет вендора (Bearer). Обязателен, если не используется --create-vendor.",
        )
        p.add_argument(
            "--create-vendor",
            action="store_true",
            help="POST /vendors (секрет задаётся через --secret)",
        )
        p.add_argument("--model-code", default="ACME_TEMP_V1")
        p.add_argument("--firmware-version", default="1.0.0")
        p.add_argument("--hardware-version", default="1.0")
        args = p.parse_args()
    
        secret = args.secret
        # Шаг 1 — создать вендора (опционально): POST /vendors.
        if args.create_vendor:
            if not secret:
                p.error("Для --create-vendor укажите --secret (будет сохранён у вендора).")
            r = requests.post(
                f"{args.base}/api/vendor/v1/vendors",
                json={"code": args.vendor_code, "name": args.vendor_name, "secret": secret},
                headers={"Content-Type": "application/json"},
                timeout=30,
            )
            r.raise_for_status()
            print("Вендор создан:", args.vendor_code)
        elif not secret:
            p.error("Укажите --secret или используйте --create-vendor.")
    
        # Шаг 2 — токен из Identity здесь не запрашивается; в Bearer подставляется --secret.
        headers = {"Authorization": f"Bearer {secret}", "Content-Type": "application/json"}
    
        # Шаг 3 — каталог сенсоров (POST /sensors) и модель (PUT /models).
        requests.post(
            f"{args.base}/api/vendor/v1/sensors",
            json={"items": [{"code": "TEMP_C", "name": "Temperature", "unitOfMeasure": "°C"}]},
            headers=headers,
            timeout=30,
        ).raise_for_status()
        print("Каталог сенсоров: TEMP_C")
    
        requests.put(
            f"{args.base}/api/vendor/v1/models",
            json={
                "model": {
                    "modelCode": args.model_code,
                    "name": "ACME Temperature Node",
                    "firmwareVersion": args.firmware_version,
                    "hardwareVersion": args.hardware_version,
                    "units": {
                        "main": {
                            "name": "Main",
                            "sensors": {
                                "temperature": {
                                    "connectedSensorCode": "TEMP_C",
                                    "name": "Ambient temperature",
                                    "valueType": "SENSOR_VALUE_TYPE_CONSUMPTION",
                                    "isPersistent": True,
                                }
                            },
                        }
                    },
                }
            },
            headers=headers,
            timeout=60,
        ).raise_for_status()
        print("Модель опубликована:", args.model_code)
        return 0
    
    
    if __name__ == "__main__":
        raise SystemExit(main())
    ```

=== "PowerShell"

    ```powershell
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
    ```
