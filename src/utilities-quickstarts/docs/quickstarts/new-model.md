**Сценарий: Создание новой модели**

## Цель

Зарегистрировать нового вендора и создать модель устройства.

## Предусловия

- Предварительных действий в системе не требуется.

## Шаги

### 1. Зарегистрируйте вендора через Vendor API (`POST /api/vendor/v1/vendors`).

=== "Python"
    ```python
    import requests

    base_url = "https://api.umecdev.deviot.cloud"
    vendor_code = "demo_vendor_001"
    vendor_name = "Demo Vendor"
    vendor_secret = "change_me_secret"

    resp = requests.post(
        f"{base_url}/api/vendor/v1/vendors",
        json={
            "code": vendor_code,
            "name": vendor_name,
            "secret": vendor_secret,
        },
        timeout=30,
    )
    print(resp.status_code)
    print(resp.text)
    resp.raise_for_status()
    ```

=== "PowerShell"
    ```powershell
    $BaseUrl = "https://api.umecdev.deviot.cloud"
    $VendorCode = "demo_vendor_001"
    $VendorName = "Demo Vendor"
    $VendorSecret = "change_me_secret"

    $Body = @{
      code = $VendorCode
      name = $VendorName
      secret = $VendorSecret
    } | ConvertTo-Json

    $Resp = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/vendor/v1/vendors" -ContentType "application/json" -Body $Body
    $Resp | ConvertTo-Json -Depth 10
    ```

### 2. Получите access token через Identity (`POST /connect/token`).

Формат запроса: `application/x-www-form-urlencoded`.

=== "Python"
    ```python
    import requests

    token_endpoint = "https://http-identity.umecdev.deviot.cloud/connect/token"

    # Сопоставление бизнес-данных:
    # vendorCode -> client_id
    # vendorSecret -> client_secret
    form = {
        "grant_type": "client_credentials",
        "client_id": "demo_vendor_001",
        "client_secret": "change_me_secret",
    }

    token_resp = requests.post(token_endpoint, data=form, timeout=30)
    print(token_resp.status_code)
    print(token_resp.text)
    token_resp.raise_for_status()
    access_token = token_resp.json().get("access_token")
    print("token acquired:", bool(access_token))
    ```

=== "PowerShell"
    ```powershell
    $TokenEndpoint = "https://http-identity.umecdev.deviot.cloud/connect/token"

    # Сопоставление бизнес-данных:
    # vendorCode -> client_id
    # vendorSecret -> client_secret
    $Form = @{
      grant_type = "client_credentials"
      client_id = "demo_vendor_001"
      client_secret = "change_me_secret"
    }

    $Token = Invoke-RestMethod -Method Post -Uri $TokenEndpoint -ContentType "application/x-www-form-urlencoded" -Body $Form
    $AccessToken = $Token.access_token
    $AccessToken
    ```

### 3. Добавьте модель сенсора температуры (`POST /api/vendor/v1/sensors`).

=== "Python"
    ```python
    import requests

    base_url = "https://api.umecdev.deviot.cloud"
    access_token = "<access_token_from_step_2>"

    resp = requests.post(
        f"{base_url}/api/vendor/v1/sensors",
        headers={"Authorization": f"Bearer {access_token}"},
        json={
            "items": [
                {
                    "code": "temp_c",
                    "name": "Temperature",
                    "unitOfMeasure": "C",
                }
            ]
        },
        timeout=30,
    )
    print(resp.status_code)
    print(resp.text)
    resp.raise_for_status()
    ```

=== "PowerShell"
    ```powershell
    $BaseUrl = "https://api.umecdev.deviot.cloud"
    $AccessToken = "<access_token_from_step_2>"

    $Headers = @{ Authorization = "Bearer $AccessToken" }
    $Body = @{
      items = @(
        @{
          code = "temp_c"
          name = "Temperature"
          unitOfMeasure = "C"
        }
      )
    } | ConvertTo-Json -Depth 10

    $Resp = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/vendor/v1/sensors" -Headers $Headers -ContentType "application/json" -Body $Body
    $Resp | ConvertTo-Json -Depth 10
    ```

### 4. Создайте/обновите модель устройства (`PUT /api/vendor/v1/models`).

=== "Python"
    ```python
    import requests

    base_url = "https://api.umecdev.deviot.cloud"
    access_token = "<access_token_from_step_2>"

    payload = {
        "model": {
            "modelCode": "demo-temp-model-v1",
            "name": "Demo Temperature Device",
            "firmwareVersion": "1.0.0",
            "hardwareVersion": "1.0",
            "units": {
                "main": {
                    "name": "Main unit",
                    "sensors": {
                        "temperature": {
                            "connectedSensorCode": "temp_c",
                            "name": "Temperature sensor",
                        }
                    },
                }
            },
        }
    }

    resp = requests.put(
        f"{base_url}/api/vendor/v1/models",
        headers={"Authorization": f"Bearer {access_token}"},
        json=payload,
        timeout=30,
    )
    print(resp.status_code)
    print(resp.text)
    resp.raise_for_status()
    ```

=== "PowerShell"
    ```powershell
    $BaseUrl = "https://api.umecdev.deviot.cloud"
    $AccessToken = "<access_token_from_step_2>"
    $Headers = @{ Authorization = "Bearer $AccessToken" }

    $Body = @{
      model = @{
        modelCode = "demo-temp-model-v1"
        name = "Demo Temperature Device"
        firmwareVersion = "1.0.0"
        hardwareVersion = "1.0"
        units = @{
          main = @{
            name = "Main unit"
            sensors = @{
              temperature = @{
                connectedSensorCode = "temp_c"
                name = "Temperature sensor"
              }
            }
          }
        }
      }
    } | ConvertTo-Json -Depth 20

    $Resp = Invoke-RestMethod -Method Put -Uri "$BaseUrl/api/vendor/v1/models" -Headers $Headers -ContentType "application/json" -Body $Body
    $Resp | ConvertTo-Json -Depth 10
    ```

### 5. (Опционально) Проверьте созданную модель (`GET /api/vendor/v1/models/{modelCode}`).

=== "Python"
    ```python
    import requests

    base_url = "https://api.umecdev.deviot.cloud"
    access_token = "<access_token_from_step_2>"
    model_code = "demo-temp-model-v1"

    resp = requests.get(
        f"{base_url}/api/vendor/v1/models/{model_code}",
        headers={"Authorization": f"Bearer {access_token}"},
        timeout=30,
    )
    print(resp.status_code)
    print(resp.text)
    resp.raise_for_status()
    ```

=== "PowerShell"
    ```powershell
    $BaseUrl = "https://api.umecdev.deviot.cloud"
    $AccessToken = "<access_token_from_step_2>"
    $ModelCode = "demo-temp-model-v1"

    $Headers = @{ Authorization = "Bearer $AccessToken" }
    $Resp = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/vendor/v1/models/$ModelCode" -Headers $Headers
    $Resp | ConvertTo-Json -Depth 20
    ```

## Ожидаемый результат

- Вендор зарегистрирован.
- Сенсор `temp_c` добавлен в каталог сенсоров вендора.
- Модель `demo-temp-model-v1` создана/обновлена и содержит unit с температурным сенсором.

## Полный скрипт сценария

=== "Python"
    ```python
    import requests

    base_url = "https://api.umecdev.deviot.cloud"
    token_endpoint = "https://http-identity.umecdev.deviot.cloud/connect/token"
    vendor_code = "demo_vendor_001"
    vendor_name = "Demo Vendor"
    vendor_secret = "change_me_secret"

    # Шаг 1: регистрация вендора (без авторизации)
    requests.post(
        f"{base_url}/api/vendor/v1/vendors",
        json={"code": vendor_code, "name": vendor_name, "secret": vendor_secret},
        timeout=30,
    ).raise_for_status()

    # Шаг 2: получение токена в Identity (client_credentials)
    token_resp = requests.post(
        token_endpoint,
        data={
            "grant_type": "client_credentials",
            "client_id": vendor_code,
            "client_secret": vendor_secret,
        },
        timeout=30,
    )
    token_resp.raise_for_status()
    access_token = token_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {access_token}"}

    # Шаг 3: добавление сенсора
    requests.post(
        f"{base_url}/api/vendor/v1/sensors",
        headers=headers,
        json={
            "items": [
                {"code": "temp_c", "name": "Temperature", "unitOfMeasure": "C"}
            ]
        },
        timeout=30,
    ).raise_for_status()

    # Шаг 4: создание/обновление модели
    requests.put(
        f"{base_url}/api/vendor/v1/models",
        headers=headers,
        json={
            "model": {
                "modelCode": "demo-temp-model-v1",
                "name": "Demo Temperature Device",
                "firmwareVersion": "1.0.0",
                "hardwareVersion": "1.0",
                "units": {
                    "main": {
                        "name": "Main unit",
                        "sensors": {
                            "temperature": {
                                "connectedSensorCode": "temp_c",
                                "name": "Temperature sensor"
                            }
                        }
                    }
                }
            }
        },
        timeout=30,
    ).raise_for_status()

    # Шаг 5: проверка модели
    check = requests.get(
        f"{base_url}/api/vendor/v1/models/demo-temp-model-v1",
        headers=headers,
        timeout=30,
    )
    check.raise_for_status()
    print(check.json())
    ```

=== "PowerShell"
    ```powershell
    $BaseUrl = "https://api.umecdev.deviot.cloud"
    $TokenEndpoint = "https://http-identity.umecdev.deviot.cloud/connect/token"
    $VendorCode = "demo_vendor_001"
    $VendorName = "Demo Vendor"
    $VendorSecret = "change_me_secret"

    # Шаг 1: регистрация вендора (без авторизации)
    $RegisterBody = @{
      code = $VendorCode
      name = $VendorName
      secret = $VendorSecret
    } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/vendor/v1/vendors" -ContentType "application/json" -Body $RegisterBody | Out-Null

    # Шаг 2: получение токена в Identity (client_credentials)
    $TokenForm = @{
      grant_type = "client_credentials"
      client_id = $VendorCode
      client_secret = $VendorSecret
    }
    $Token = Invoke-RestMethod -Method Post -Uri $TokenEndpoint -ContentType "application/x-www-form-urlencoded" -Body $TokenForm
    $AccessToken = $Token.access_token
    $Headers = @{ Authorization = "Bearer $AccessToken" }

    # Шаг 3: добавление сенсора
    $SensorsBody = @{
      items = @(
        @{
          code = "temp_c"
          name = "Temperature"
          unitOfMeasure = "C"
        }
      )
    } | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/vendor/v1/sensors" -Headers $Headers -ContentType "application/json" -Body $SensorsBody | Out-Null

    # Шаг 4: создание/обновление модели
    $ModelBody = @{
      model = @{
        modelCode = "demo-temp-model-v1"
        name = "Demo Temperature Device"
        firmwareVersion = "1.0.0"
        hardwareVersion = "1.0"
        units = @{
          main = @{
            name = "Main unit"
            sensors = @{
              temperature = @{
                connectedSensorCode = "temp_c"
                name = "Temperature sensor"
              }
            }
          }
        }
      }
    } | ConvertTo-Json -Depth 20
    Invoke-RestMethod -Method Put -Uri "$BaseUrl/api/vendor/v1/models" -Headers $Headers -ContentType "application/json" -Body $ModelBody | Out-Null

    # Шаг 5: проверка модели
    $Check = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/vendor/v1/models/demo-temp-model-v1" -Headers $Headers
    $Check | ConvertTo-Json -Depth 20
    ```
