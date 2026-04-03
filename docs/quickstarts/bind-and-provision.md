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
    --8<-- "scripts/bind-and-provision.py"
    ```

=== "PowerShell"

    ```powershell
    --8<-- "scripts/bind-and-provision.ps1"
    ```
