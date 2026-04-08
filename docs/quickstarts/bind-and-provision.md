# Сценарий: привязка устройства

## Цель

Войти под пользователем, **привязать устройство** и получить **`unitId`**.

## Предусловия

- Учётная запись пользователя.
- Выполнен сценарий [Создание новой модели устройства](create-new-model.md), получены `vendorCode`, `modelCode`, `firmwareVersion`, `hardwareVersion`.
- Серийный номер, **user code**

## Шаги

### 1. Вход

=== "Python"

    ```python
    import requests

    BASE = "https://api.rumecdev.deviot.cloud"
    r = requests.post(
        f"{BASE}/api/customer/v1/signin",
        json={"userName": "<логин>", "password": "<пароль>"},
        headers={"Content-Type": "application/json"},
        timeout=30,
    )
    r.raise_for_status()
    data = r.json()
    access_token = data["accessToken"]
    refresh_token = data["refreshToken"]
    ```

=== "PowerShell"

    ```powershell
    $Base = "https://api.rumecdev.deviot.cloud"
    $login = @{ userName = "<логин>"; password = "<пароль>" } | ConvertTo-Json

    $auth = Invoke-RestMethod -Method Post -Uri "$Base/api/customer/v1/signin" `
        -ContentType "application/json" -Body $login
    $accessToken = $auth.accessToken
    $refreshToken = $auth.refreshToken
    ```

### 2. Привязка

=== "Python"

    ```python
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }
    bind = requests.post(
        f"{BASE}/api/customer/v1/units/bind",
        json={
            "deviceSerial": "SN-ACME-00042",
            "userCode": "<код_с_устройства>",
            "firmware": {
                "vendorCode": "ACME_LABS",
                "modelCode": "ACME_TEMP_V1",
                "firmwareVersion": "1.0.0",
                "hardwareVersion": "1.0",
            },
            "location": {"latitude": 55.7558, "longitude": 37.6173},
        },
        headers=headers,
        timeout=60,
    )
    bind.raise_for_status()
    unit_id = bind.json()["items"][0]["unitId"]
    ```

=== "PowerShell"

    ```powershell
    $hdr = @{ Authorization = "Bearer $accessToken" }
    $bindBody = @{
        deviceSerial = "SN-ACME-00042"
        userCode     = "<код_с_устройства>"
        firmware     = @{
            vendorCode       = "ACME_LABS"
            modelCode        = "ACME_TEMP_V1"
            firmwareVersion  = "1.0.0"
            hardwareVersion  = "1.0"
        }
        location = @{ latitude = 55.7558; longitude = 37.6173 }
    } | ConvertTo-Json -Depth 6

    $bind = Invoke-RestMethod -Method Post -Uri "$Base/api/customer/v1/units/bind" `
        -Headers $hdr -ContentType "application/json" -Body $bindBody
    $unitId = $bind.items[0].unitId
    ```

### 3. Обновление access-токена

=== "Python"

    ```python
    r = requests.post(
        f"{BASE}/api/customer/v1/refresh",
        json={"refreshToken": refresh_token},
        headers={"Content-Type": "application/json"},
        timeout=30,
    )
    r.raise_for_status()
    access_token = r.json()["accessToken"]
    ```

=== "PowerShell"

    ```powershell
    $refBody = @{ refreshToken = $refreshToken } | ConvertTo-Json
    $auth = Invoke-RestMethod -Method Post -Uri "$Base/api/customer/v1/refresh" `
        -ContentType "application/json" -Body $refBody
    $accessToken = $auth.accessToken
    ```

## Ожидаемый результат

- `accessToken`, `refreshToken`, `unitId` (или несколько из `items`).

## Итоговый скрипт сценария

=== "Python"

    ```python
    #!/usr/bin/env python3
    
    from __future__ import annotations
    
    import argparse
    import json
    import os
    import sys
    
    try:
        import requests
    except ImportError:
        print("Установите requests: pip install requests", file=sys.stderr)
        sys.exit(1)
    
    
    def main() -> int:
        p = argparse.ArgumentParser(description="Вход, привязка устройства (units/bind), опционально refresh.")
        p.add_argument("--base", default=os.environ.get("UMEC_BASE", "https://api.rumecdev.deviot.cloud"))
        p.add_argument("--user", default=os.environ.get("UMEC_CUSTOMER_USER"))
        p.add_argument("--password", default=os.environ.get("UMEC_CUSTOMER_PASSWORD"))
        p.add_argument("--device-serial", default=os.environ.get("UMEC_DEVICE_SERIAL", "SN-ACME-00042"))
        p.add_argument("--user-code", default=os.environ.get("UMEC_DEVICE_USER_CODE"), required=True)
        p.add_argument("--vendor-code", default=os.environ.get("UMEC_VENDOR_CODE", "ACME_LABS"))
        p.add_argument("--model-code", default=os.environ.get("UMEC_MODEL_CODE", "ACME_TEMP_V1"))
        p.add_argument("--firmware-version", default="1.0.0")
        p.add_argument("--hardware-version", default="1.0")
        p.add_argument("--lat", type=float, default=55.7558)
        p.add_argument("--lon", type=float, default=37.6173)
        p.add_argument("--refresh", action="store_true", help="После bind вызвать POST /refresh и показать новый accessToken")
        args = p.parse_args()
        if not args.user or not args.password:
            p.error("Задайте --user и --password или UMEC_CUSTOMER_USER / UMEC_CUSTOMER_PASSWORD.")
    
        base = args.base.rstrip("/")
        # Шаг 1 — вход: POST /signin.
        r = requests.post(
            f"{base}/api/customer/v1/signin",
            json={"userName": args.user, "password": args.password},
            headers={"Content-Type": "application/json"},
            timeout=30,
        )
        r.raise_for_status()
        auth = r.json()
        access = auth["accessToken"]
        refresh = auth["refreshToken"]
        print("signin: OK")
    
        headers = {"Authorization": f"Bearer {access}", "Content-Type": "application/json"}
        # Шаг 2 — привязка: POST /units/bind.
        bind = requests.post(
            f"{base}/api/customer/v1/units/bind",
            json={
                "deviceSerial": args.device_serial,
                "userCode": args.user_code,
                "firmware": {
                    "vendorCode": args.vendor_code,
                    "modelCode": args.model_code,
                    "firmwareVersion": args.firmware_version,
                    "hardwareVersion": args.hardware_version,
                },
                "location": {"latitude": args.lat, "longitude": args.lon},
            },
            headers=headers,
            timeout=60,
        )
        bind.raise_for_status()
        data = bind.json()
        items = data.get("items") or []
        if not items:
            print(json.dumps(data, indent=2, ensure_ascii=False))
            return 1
        unit_id = items[0]["unitId"]
        print("bind: OK")
        print("unitId:", unit_id)
        print("accessToken:", access[:24] + "…")
        print("refreshToken:", refresh[:24] + "…")
    
        # Шаг 3 — обновить access-токен (опционально): POST /refresh.
        if args.refresh:
            rr = requests.post(
                f"{base}/api/customer/v1/refresh",
                json={"refreshToken": refresh},
                headers={"Content-Type": "application/json"},
                timeout=30,
            )
            rr.raise_for_status()
            access2 = rr.json()["accessToken"]
            print("refresh: OK, accessToken:", access2[:24] + "…")
    
        return 0
    
    
    if __name__ == "__main__":
        raise SystemExit(main())
    ```

=== "PowerShell"

    ```powershell
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
    ```
