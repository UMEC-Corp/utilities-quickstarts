**Сценарий: Запрос телеметрии**

## Цель

Получить агрегированные телеметрические значения по устройству

## Предусловия

- **Выполнен сценарий [Привязка устройства](bind-and-provision.md), получен `unitId`.**
- Нужны учетные данные пользователя (`userName`, `password`)


## Шаги

### 1. Авторизуйтесь как customer и получите `accessToken`.

=== "Python"
    ```python
    import requests

    base_url = "https://api.umecdev.deviot.cloud"

    signin = requests.post(
        f"{base_url}/api/customer/v1/signin",
        json={"userName": "customer_demo", "password": "change_me_password"},
        timeout=30,
    )
    signin.raise_for_status()
    access_token = signin.json()["accessToken"]
    headers = {"Authorization": f"Bearer {access_token}"}
    ```

=== "PowerShell"
    ```powershell
    $BaseUrl = "https://api.umecdev.deviot.cloud"

    $SignInBody = @{ userName = "customer_demo"; password = "change_me_password" } | ConvertTo-Json
    $SignIn = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/customer/v1/signin" -ContentType "application/json" -Body $SignInBody
    $AccessToken = $SignIn.accessToken
    $Headers = @{ Authorization = "Bearer $AccessToken" }
    ```

### 2. Получите `unitId` из списка устройств customer (`GET /api/customer/v1/units`).

=== "Python"
    ```python
    units_resp = requests.get(f"{base_url}/api/customer/v1/units", headers=headers, timeout=30)
    units_resp.raise_for_status()
    units = units_resp.json().get("items", [])
    if not units:
        raise RuntimeError("У пользователя нет устройств")
    unit_id = units[0]["unitId"]
    ```

=== "PowerShell"
    ```powershell
    $UnitsResp = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/customer/v1/units" -Headers $Headers
    if (-not $UnitsResp.items -or $UnitsResp.items.Count -eq 0) { throw "У пользователя нет устройств" }
    $UnitId = $UnitsResp.items[0].unitId
    ```

### 3. Получите ID сенсоров (`inputIds`) из деталей устройства (`GET /api/customer/v1/units/{unitId}`), затем сформируйте список `inputIds` для запроса телеметрии.

=== "Python"
    ```python
    unit_details = requests.get(
        f"{base_url}/api/customer/v1/units/{unit_id}",
        headers=headers,
        timeout=30,
    )
    unit_details.raise_for_status()
    inputs = unit_details.json().get("item", {}).get("inputs", [])
    if not inputs:
        raise RuntimeError("У устройства отсутствуют входы")
    input_ids = [inputs[0]["id"]]
    ```

=== "PowerShell"
    ```powershell
    $UnitDetails = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/customer/v1/units/$UnitId" -Headers $Headers
    $Inputs = $UnitDetails.item.inputs
    if (-not $Inputs -or $Inputs.Count -eq 0) { throw "У устройства отсутствуют входы" }
    $InputIds = @($Inputs[0].id)
    ```

### 4. Запросите телеметрию по `inputIds` через `GET /api/customer/v1/units/{unitId}/ticks`.

=== "Python"
    ```python
    params = {
        "inputIds": input_ids,
        "begin": 1710000000000,
        "end": 1710086400000,
        "timeFrame": 60,
        "difference": False,
    }

    ticks = requests.get(
        f"{base_url}/api/customer/v1/units/{unit_id}/ticks",
        headers=headers,
        params=params,
        timeout=30,
    )
    ticks.raise_for_status()
    print(ticks.json())
    ```

=== "PowerShell"
    ```powershell
    $Query = @(
      "inputIds=$($InputIds[0])",
      "begin=1710000000000",
      "end=1710086400000",
      "timeFrame=60",
      "difference=false"
    ) -join "&"

    $Ticks = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/customer/v1/units/$UnitId/ticks?$Query" -Headers $Headers
    $Ticks | ConvertTo-Json -Depth 20
    ```

## Ожидаемый результат

- В `GetInputTicksResponse` в `items[]` возвращаются агрегаты (`firstValue`, `lastValue`, `minValue`, `maxValue`, `meanValue`) и временной диапазон (`begin`, `end`) по каждому `inputId`.

## Полный скрипт сценария

=== "Python"
    ```python
    import requests

    base_url = "https://api.umecdev.deviot.cloud"

    # Шаг 1: авторизация customer
    signin = requests.post(
        f"{base_url}/api/customer/v1/signin",
        json={"userName": "customer_demo", "password": "change_me_password"},
        timeout=30,
    )
    signin.raise_for_status()
    access_token = signin.json()["accessToken"]
    headers = {"Authorization": f"Bearer {access_token}"}

    # Шаг 2: получение unitId
    units_resp = requests.get(f"{base_url}/api/customer/v1/units", headers=headers, timeout=30)
    units_resp.raise_for_status()
    units = units_resp.json().get("items", [])
    if not units:
        raise RuntimeError("У пользователя нет устройств")
    unit_id = units[0]["unitId"]

    # Шаг 3: получение inputIds
    unit_details = requests.get(f"{base_url}/api/customer/v1/units/{unit_id}", headers=headers, timeout=30)
    unit_details.raise_for_status()
    inputs = unit_details.json().get("item", {}).get("inputs", [])
    if not inputs:
        raise RuntimeError("У устройства отсутствуют входы")
    input_ids = [inputs[0]["id"]]

    # Шаг 4: запрос телеметрии
    params = {
        "inputIds": input_ids,
        "begin": 1710000000000,
        "end": 1710086400000,
        "timeFrame": 60,
        "difference": False,
    }
    ticks = requests.get(
        f"{base_url}/api/customer/v1/units/{unit_id}/ticks",
        headers=headers,
        params=params,
        timeout=30,
    )
    ticks.raise_for_status()
    print(ticks.json())
    ```

=== "PowerShell"
    ```powershell
    $BaseUrl = "https://api.umecdev.deviot.cloud"

    # Шаг 1: авторизация customer
    $SignInBody = @{ userName = "customer_demo"; password = "change_me_password" } | ConvertTo-Json
    $SignIn = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/customer/v1/signin" -ContentType "application/json" -Body $SignInBody
    $AccessToken = $SignIn.accessToken
    $Headers = @{ Authorization = "Bearer $AccessToken" }

    # Шаг 2: получение unitId
    $UnitsResp = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/customer/v1/units" -Headers $Headers
    if (-not $UnitsResp.items -or $UnitsResp.items.Count -eq 0) { throw "У пользователя нет устройств" }
    $UnitId = $UnitsResp.items[0].unitId

    # Шаг 3: получение inputIds
    $UnitDetails = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/customer/v1/units/$UnitId" -Headers $Headers
    $Inputs = $UnitDetails.item.inputs
    if (-not $Inputs -or $Inputs.Count -eq 0) { throw "У устройства отсутствуют входы" }
    $InputIds = @($Inputs[0].id)

    # Шаг 4: запрос телеметрии
    $Query = @(
      "inputIds=$($InputIds[0])",
      "begin=1710000000000",
      "end=1710086400000",
      "timeFrame=60",
      "difference=false"
    ) -join "&"

    $Ticks = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/customer/v1/units/$UnitId/ticks?$Query" -Headers $Headers
    $Ticks | ConvertTo-Json -Depth 20
    ```
