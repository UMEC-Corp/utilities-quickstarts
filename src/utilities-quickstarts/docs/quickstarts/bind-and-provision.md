**Сценарий: Привязка устройства**

## Цель

Привязать устройство к пользователю через `device_code`/`user_code`, проверить привязку и получить токен устройства.

## Предусловия

- **Выполнен сценарий [Создание новой модели](new-model.md), получены `vendorCode`, `modelCode`, `firmwareVersion`, `hardwareVersion`.**
- Доступны учетные данные customer-пользователя: `UMEC_CUSTOMER_USER`, `UMEC_CUSTOMER_PASSWORD`.
- Доступны параметры устройства: `UMEC_DEVICE_SERIAL`, `UMEC_DEVICE_MAC`.

## Шаги

### 1. Авторизоваться как customer и получить `accessToken` (`POST /api/customer/v1/signin`).

=== "Python"
    ```python
    import os
    import requests

    base_url = "https://api.umecdev.deviot.cloud"
    user_name = os.environ["UMEC_CUSTOMER_USER"]
    password = os.environ["UMEC_CUSTOMER_PASSWORD"]

    signin = requests.post(
        f"{base_url}/api/customer/v1/signin",
        json={"userName": user_name, "password": password},
        timeout=30,
    )
    signin.raise_for_status()
    customer_access_token = signin.json()["accessToken"]
    print("customer_access_token acquired:", bool(customer_access_token))
    ```

=== "PowerShell"
    ```powershell
    $BaseUrl = 'https://api.umecdev.deviot.cloud'
    $UserName = $env:UMEC_CUSTOMER_USER
    $Password = $env:UMEC_CUSTOMER_PASSWORD
    if (-not $UserName -or -not $Password) { throw 'Не заданы UMEC_CUSTOMER_USER/UMEC_CUSTOMER_PASSWORD' }

    $SignInBody = @{ userName = $UserName; password = $Password } | ConvertTo-Json
    $SignIn = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/customer/v1/signin" -ContentType 'application/json' -Body $SignInBody
    $CustomerAccessToken = $SignIn.accessToken
    "customer_access_token acquired: $([bool]$CustomerAccessToken)"
    ```

### 2. Получить `device_code`, `user_code`, `verification_uri`, `verification_uri_complete` в Identity (`POST /connect/deviceauthorization`).

=== "Python"
    ```python
    import requests

    device_authorization_endpoint = "https://http-identity.umecdev.deviot.cloud/connect/deviceauthorization"

    device_auth = requests.post(
        device_authorization_endpoint,
        data={"client_id": "controller"},
        timeout=30,
    )
    device_auth.raise_for_status()
    device_data = device_auth.json()

    device_code = device_data["device_code"]
    user_code = device_data["user_code"]
    verification_uri = device_data["verification_uri"]
    verification_uri_complete = device_data["verification_uri_complete"]
    poll_interval = int(device_data.get("interval", 5))

    print("Open:", verification_uri_complete)
    print("User code:", user_code)
    ```

=== "PowerShell"
    ```powershell
    $DeviceAuthorizationEndpoint = 'https://http-identity.umecdev.deviot.cloud/connect/deviceauthorization'

    $DeviceAuth = Invoke-RestMethod -Method Post -Uri $DeviceAuthorizationEndpoint -ContentType 'application/x-www-form-urlencoded' -Body @{ client_id = 'controller' }
    $DeviceCode = $DeviceAuth.device_code
    $UserCode = $DeviceAuth.user_code
    $VerificationUri = $DeviceAuth.verification_uri
    $VerificationUriComplete = $DeviceAuth.verification_uri_complete
    $PollInterval = [int]($DeviceAuth.interval)
    if (-not $PollInterval -or $PollInterval -le 0) { $PollInterval = 5 }

    "Open: $VerificationUriComplete"
    "User code: $UserCode"
    ```

### 3. Выполнить привязку устройства (`POST /api/customer/v1/units/bind`).

=== "Python"
    ```python
    import os
    import requests

    base_url = "https://api.umecdev.deviot.cloud"
    customer_access_token = "<полученный_на_шаге_1_token>"
    user_code = "<полученный_на_шаге_2_user_code>"
    verification_uri = "<полученный_на_шаге_2_verification_uri>"

    headers = {"Authorization": f"Bearer {customer_access_token}"}
    bind_payload = {
        "deviceSerial": os.environ["UMEC_DEVICE_SERIAL"],
        "userCode": user_code,
        "verificationUrl": verification_uri,
        "firmware": {
            "vendorCode": os.environ["UMEC_VENDOR_CODE"],
            "modelCode": os.environ["UMEC_MODEL_CODE"],
            "firmwareVersion": os.environ["UMEC_FIRMWARE_VERSION"],
            "hardwareVersion": os.environ["UMEC_HARDWARE_VERSION"],
        },
        "deviceMacAddress": os.environ["UMEC_DEVICE_MAC"],
        "location": {
            "latitude": 55.7558,
            "longitude": 37.6173,
        },
    }

    bind_resp = requests.post(
        f"{base_url}/api/customer/v1/units/bind",
        headers=headers,
        json=bind_payload,
        timeout=30,
    )
    bind_resp.raise_for_status()
    bind_items = bind_resp.json().get("items", [])
    if not bind_items:
        raise RuntimeError("Bind выполнен без items в ответе")
    bound_unit_ids = [item["unitId"] for item in bind_items if "unitId" in item]
    if not bound_unit_ids:
        raise RuntimeError("В ответе bind отсутствуют unitId")
    print("bound unitIds:", bound_unit_ids)
    ```

=== "PowerShell"
    ```powershell
    $BaseUrl = 'https://api.umecdev.deviot.cloud'
    $CustomerAccessToken = '<полученный_на_шаге_1_token>'
    $UserCode = '<полученный_на_шаге_2_user_code>'
    $VerificationUri = '<полученный_на_шаге_2_verification_uri>'

    $DeviceSerial = $env:UMEC_DEVICE_SERIAL
    $VendorCode = $env:UMEC_VENDOR_CODE
    $ModelCode = $env:UMEC_MODEL_CODE
    $FirmwareVersion = $env:UMEC_FIRMWARE_VERSION
    $HardwareVersion = $env:UMEC_HARDWARE_VERSION
    $DeviceMac = $env:UMEC_DEVICE_MAC
    if (-not $DeviceSerial -or -not $VendorCode -or -not $ModelCode -or -not $FirmwareVersion -or -not $HardwareVersion -or -not $DeviceMac) {
      throw 'Не заданы UMEC_DEVICE_SERIAL/UMEC_VENDOR_CODE/UMEC_MODEL_CODE/UMEC_FIRMWARE_VERSION/UMEC_HARDWARE_VERSION/UMEC_DEVICE_MAC'
    }

    $Headers = @{ Authorization = "Bearer $CustomerAccessToken" }
    $BindBody = @{
      deviceSerial = $DeviceSerial
      userCode = $UserCode
      verificationUrl = $VerificationUri
      firmware = @{
        vendorCode = $VendorCode
        modelCode = $ModelCode
        firmwareVersion = $FirmwareVersion
        hardwareVersion = $HardwareVersion
      }
      deviceMacAddress = $DeviceMac
      location = @{ latitude = 55.7558; longitude = 37.6173 }
    } | ConvertTo-Json -Depth 10

    $BindResp = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/customer/v1/units/bind" -Headers $Headers -ContentType 'application/json' -Body $BindBody
    if (-not $BindResp.items -or $BindResp.items.Count -eq 0) { throw 'Bind выполнен без items в ответе' }
    $BoundUnitIds = @($BindResp.items | Where-Object { $_.unitId } | ForEach-Object { $_.unitId })
    if (-not $BoundUnitIds -or $BoundUnitIds.Count -eq 0) { throw 'В ответе bind отсутствуют unitId' }
    "bound unitIds: $($BoundUnitIds -join ', ')"
    ```

### 4. Проверить наличие привязанного устройства: получить список устройств и убедиться, что в нем присутствует хотя бы один `unitId` из ответа bind.

=== "Python"
    ```python
    import requests

    base_url = "https://api.umecdev.deviot.cloud"
    customer_access_token = "<полученный_на_шаге_1_token>"
    bound_unit_ids = [12345]  # unitId из шага 3

    headers = {"Authorization": f"Bearer {customer_access_token}"}
    units_resp = requests.get(f"{base_url}/api/customer/v1/units", headers=headers, timeout=30)
    units_resp.raise_for_status()
    items = units_resp.json().get("items", [])
    if not items:
        raise RuntimeError("Список units пуст после bind")

    actual_unit_ids = {item["unitId"] for item in items if "unitId" in item}
    if not any(unit_id in actual_unit_ids for unit_id in bound_unit_ids):
        raise RuntimeError("Привязанное устройство не найдено в GET /api/customer/v1/units")

    print("bind verification passed")
    ```

=== "PowerShell"
    ```powershell
    $BaseUrl = 'https://api.umecdev.deviot.cloud'
    $CustomerAccessToken = '<полученный_на_шаге_1_token>'
    $BoundUnitIds = @(12345) # unitId из шага 3

    $Headers = @{ Authorization = "Bearer $CustomerAccessToken" }
    $UnitsResp = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/customer/v1/units" -Headers $Headers
    if (-not $UnitsResp.items -or $UnitsResp.items.Count -eq 0) { throw 'Список units пуст после bind' }

    $ActualUnitIds = @($UnitsResp.items | Where-Object { $_.unitId } | ForEach-Object { $_.unitId })
    $HasBoundUnit = $false
    foreach ($id in $BoundUnitIds) {
      if ($ActualUnitIds -contains $id) { $HasBoundUnit = $true; break }
    }
    if (-not $HasBoundUnit) { throw 'Привязанное устройство не найдено в GET /api/customer/v1/units' }

    "bind verification passed"
    ```

### 5. Получить device token в Identity (`POST /connect/token`).

=== "Python"
    ```python
    import os
    import time
    import requests

    token_endpoint = "https://http-identity.umecdev.deviot.cloud/connect/token"
    device_code = "<полученный_на_шаге_2_device_code>"
    client_id = "controller"
    poll_interval = 5

    service_device_access_token = None
    for _ in range(120):
        token_resp = requests.post(
            token_endpoint,
            data={
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                "device_code": device_code,
                "client_id": client_id,
            },
            timeout=30,
        )
        payload = token_resp.json()

        if token_resp.status_code == 200 and "access_token" in payload:
            service_device_access_token = payload["access_token"]
            break

        if payload.get("error") == "authorization_pending":
            time.sleep(poll_interval)
            continue

        if payload.get("error") == "slow_down":
            poll_interval += 5
            time.sleep(poll_interval)
            continue

        raise RuntimeError(payload)

    if not service_device_access_token:
        raise RuntimeError("Не удалось получить device token за отведенное время")

    print("device token acquired:", bool(service_device_access_token))
    ```

=== "PowerShell"
    ```powershell
    $TokenEndpoint = 'https://http-identity.umecdev.deviot.cloud/connect/token'
    $DeviceCode = '<полученный_на_шаге_2_device_code>'
    $ClientId = 'controller'

    $PollInterval = 5
    $ServiceDeviceAccessToken = $null

    for ($i = 0; $i -lt 120; $i++) {
      try {
        $TokenResp = Invoke-RestMethod -Method Post -Uri $TokenEndpoint -ContentType 'application/x-www-form-urlencoded' -Body @{
          grant_type = 'urn:ietf:params:oauth:grant-type:device_code'
          device_code = $DeviceCode
          client_id = $ClientId
        }

        if ($TokenResp.access_token) {
          $ServiceDeviceAccessToken = $TokenResp.access_token
          break
        }
      }
      catch {
        $ErrPayload = $_.ErrorDetails.Message | ConvertFrom-Json
        if ($ErrPayload.error -eq 'authorization_pending') { Start-Sleep -Seconds $PollInterval; continue }
        if ($ErrPayload.error -eq 'slow_down') { $PollInterval += 5; Start-Sleep -Seconds $PollInterval; continue }
        throw
      }
    }

    if (-not $ServiceDeviceAccessToken) { throw 'Не удалось получить device token за отведенное время' }
    "device token acquired: $([bool]$ServiceDeviceAccessToken)"
    ```

## Ожидаемый результат

- Привязка успешно выполнена, в ответе получены `items` с `unitId`.
- В результате проверки найдено хотя бы одно устройство с `unitId` из ответа bind.
- Получен токен устройства.

## Полный скрипт сценария

=== "Python"
    ```python
    import os
    import time
    import requests

    base_url = "https://api.umecdev.deviot.cloud"
    identity_base = "https://http-identity.umecdev.deviot.cloud"

    # Шаг 1: авторизация customer
    user_name = os.environ["UMEC_CUSTOMER_USER"]
    password = os.environ["UMEC_CUSTOMER_PASSWORD"]
    signin = requests.post(
        f"{base_url}/api/customer/v1/signin",
        json={"userName": user_name, "password": password},
        timeout=30,
    )
    signin.raise_for_status()
    customer_access_token = signin.json()["accessToken"]
    customer_headers = {"Authorization": f"Bearer {customer_access_token}"}

    # Шаг 2: получение device_code/user_code
    device_auth = requests.post(
        f"{identity_base}/connect/deviceauthorization",
        data={"client_id": "controller"},
        timeout=30,
    )
    device_auth.raise_for_status()
    device_data = device_auth.json()
    device_code = device_data["device_code"]
    user_code = device_data["user_code"]
    verification_uri = device_data["verification_uri"]
    poll_interval = int(device_data.get("interval", 5))

    # Шаг 3: bind устройства
    bind_payload = {
        "deviceSerial": os.environ["UMEC_DEVICE_SERIAL"],
        "userCode": user_code,
        "verificationUrl": verification_uri,
        "firmware": {
            "vendorCode": os.environ["UMEC_VENDOR_CODE"],
            "modelCode": os.environ["UMEC_MODEL_CODE"],
            "firmwareVersion": os.environ["UMEC_FIRMWARE_VERSION"],
            "hardwareVersion": os.environ["UMEC_HARDWARE_VERSION"],
        },
        "deviceMacAddress": os.environ["UMEC_DEVICE_MAC"],
        "location": {"latitude": 55.7558, "longitude": 37.6173},
    }
    bind_resp = requests.post(
        f"{base_url}/api/customer/v1/units/bind",
        headers=customer_headers,
        json=bind_payload,
        timeout=30,
    )
    bind_resp.raise_for_status()
    bind_items = bind_resp.json().get("items", [])
    if not bind_items:
        raise RuntimeError("Bind выполнен без items в ответе")
    bound_unit_ids = [item["unitId"] for item in bind_items if "unitId" in item]
    if not bound_unit_ids:
        raise RuntimeError("В ответе bind отсутствуют unitId")

    # Шаг 4: проверка, что привязанное устройство присутствует в профиле
    units_resp = requests.get(f"{base_url}/api/customer/v1/units", headers=customer_headers, timeout=30)
    units_resp.raise_for_status()
    units = units_resp.json().get("items", [])
    if not units:
        raise RuntimeError("Список units пуст после bind")
    actual_unit_ids = {item["unitId"] for item in units if "unitId" in item}
    if not any(unit_id in actual_unit_ids for unit_id in bound_unit_ids):
        raise RuntimeError("Привязанное устройство не найдено в GET /api/customer/v1/units")

    # Шаг 5: получение device token
    service_device_access_token = None
    for _ in range(120):
        token_resp = requests.post(
            f"{identity_base}/connect/token",
            data={
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                "device_code": device_code,
                "client_id": "controller",
            },
            timeout=30,
        )
        payload = token_resp.json()
        if token_resp.status_code == 200 and "access_token" in payload:
            service_device_access_token = payload["access_token"]
            break
        if payload.get("error") == "authorization_pending":
            time.sleep(poll_interval)
            continue
        if payload.get("error") == "slow_down":
            poll_interval += 5
            time.sleep(poll_interval)
            continue
        raise RuntimeError(payload)

    if not service_device_access_token:
        raise RuntimeError("Не удалось получить device token за отведенное время")

    print("device token acquired:", bool(service_device_access_token))
    ```

=== "PowerShell"
    ```powershell
    $BaseUrl = 'https://api.umecdev.deviot.cloud'
    $IdentityBase = 'https://http-identity.umecdev.deviot.cloud'

    # Шаг 1: авторизация customer
    $UserName = $env:UMEC_CUSTOMER_USER
    $Password = $env:UMEC_CUSTOMER_PASSWORD
    if (-not $UserName -or -not $Password) { throw 'Не заданы UMEC_CUSTOMER_USER/UMEC_CUSTOMER_PASSWORD' }

    $SignInBody = @{ userName = $UserName; password = $Password } | ConvertTo-Json
    $SignIn = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/customer/v1/signin" -ContentType 'application/json' -Body $SignInBody
    $CustomerAccessToken = $SignIn.accessToken
    $CustomerHeaders = @{ Authorization = "Bearer $CustomerAccessToken" }

    # Шаг 2: получение device_code/user_code
    $DeviceAuth = Invoke-RestMethod -Method Post -Uri "$IdentityBase/connect/deviceauthorization" -ContentType 'application/x-www-form-urlencoded' -Body @{ client_id = 'controller' }
    $DeviceCode = $DeviceAuth.device_code
    $UserCode = $DeviceAuth.user_code
    $VerificationUri = $DeviceAuth.verification_uri
    $PollInterval = [int]$DeviceAuth.interval
    if (-not $PollInterval -or $PollInterval -le 0) { $PollInterval = 5 }

    # Шаг 3: bind устройства
    $DeviceSerial = $env:UMEC_DEVICE_SERIAL
    $VendorCode = $env:UMEC_VENDOR_CODE
    $ModelCode = $env:UMEC_MODEL_CODE
    $FirmwareVersion = $env:UMEC_FIRMWARE_VERSION
    $HardwareVersion = $env:UMEC_HARDWARE_VERSION
    $DeviceMac = $env:UMEC_DEVICE_MAC
    if (-not $DeviceSerial -or -not $VendorCode -or -not $ModelCode -or -not $FirmwareVersion -or -not $HardwareVersion -or -not $DeviceMac) {
      throw 'Не заданы UMEC_DEVICE_SERIAL/UMEC_VENDOR_CODE/UMEC_MODEL_CODE/UMEC_FIRMWARE_VERSION/UMEC_HARDWARE_VERSION/UMEC_DEVICE_MAC'
    }

    $BindBody = @{
      deviceSerial = $DeviceSerial
      userCode = $UserCode
      verificationUrl = $VerificationUri
      firmware = @{
        vendorCode = $VendorCode
        modelCode = $ModelCode
        firmwareVersion = $FirmwareVersion
        hardwareVersion = $HardwareVersion
      }
      deviceMacAddress = $DeviceMac
      location = @{ latitude = 55.7558; longitude = 37.6173 }
    } | ConvertTo-Json -Depth 10

    $BindResp = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/customer/v1/units/bind" -Headers $CustomerHeaders -ContentType 'application/json' -Body $BindBody
    if (-not $BindResp.items -or $BindResp.items.Count -eq 0) { throw 'Bind выполнен без items в ответе' }
    $BoundUnitIds = @($BindResp.items | Where-Object { $_.unitId } | ForEach-Object { $_.unitId })
    if (-not $BoundUnitIds -or $BoundUnitIds.Count -eq 0) { throw 'В ответе bind отсутствуют unitId' }

    # Шаг 4: проверка, что привязанное устройство присутствует в профиле
    $UnitsResp = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/customer/v1/units" -Headers $CustomerHeaders
    if (-not $UnitsResp.items -or $UnitsResp.items.Count -eq 0) { throw 'Список units пуст после bind' }
    $ActualUnitIds = @($UnitsResp.items | Where-Object { $_.unitId } | ForEach-Object { $_.unitId })
    $HasBoundUnit = $false
    foreach ($id in $BoundUnitIds) {
      if ($ActualUnitIds -contains $id) { $HasBoundUnit = $true; break }
    }
    if (-not $HasBoundUnit) { throw 'Привязанное устройство не найдено в GET /api/customer/v1/units' }

    # Шаг 5: получение device token

    $ServiceDeviceAccessToken = $null
    for ($i = 0; $i -lt 120; $i++) {
      try {
        $TokenResp = Invoke-RestMethod -Method Post -Uri "$IdentityBase/connect/token" -ContentType 'application/x-www-form-urlencoded' -Body @{
          grant_type = 'urn:ietf:params:oauth:grant-type:device_code'
          device_code = $DeviceCode
          client_id = 'controller'
        }

        if ($TokenResp.access_token) {
          $ServiceDeviceAccessToken = $TokenResp.access_token
          break
        }
      }
      catch {
        $ErrPayload = $_.ErrorDetails.Message | ConvertFrom-Json
        if ($ErrPayload.error -eq 'authorization_pending') { Start-Sleep -Seconds $PollInterval; continue }
        if ($ErrPayload.error -eq 'slow_down') { $PollInterval += 5; Start-Sleep -Seconds $PollInterval; continue }
        throw
      }
    }

    if (-not $ServiceDeviceAccessToken) { throw 'Не удалось получить device token за отведенное время' }
    "device token acquired: $([bool]$ServiceDeviceAccessToken)"
    ```
