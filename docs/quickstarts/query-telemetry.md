# Сценарий: история показаний

## Цель

Получить агрегированные значения по входам за период: `GET /api/customer/v1/units/{unitId}/ticks`.

## Предусловия

- Пользователь авторизован, получен `accessToken`
- Выполнен сценарий [Привязка устройства](bind-and-provision.md), получен `unitId`.
- В модели устройства есть сенсор с кодом **`temperature`** (или свой код — укажите в скрипте).

## Шаги

### 1. Найти `inputId`

=== "Python"

    ```python
    import requests

    BASE = "https://api.rumecdev.deviot.cloud"
    headers = {"Authorization": f"Bearer {access_token}"}

    d = requests.get(
        f"{BASE}/api/customer/v1/units/{unit_id}",
        headers=headers,
        timeout=30,
    )
    d.raise_for_status()
    temp = next(i for i in d.json()["inputs"] if i["code"] == "temperature")
    input_id = temp["id"]
    ```

=== "PowerShell"

    ```powershell
    $Base = "https://api.rumecdev.deviot.cloud"
    $hdr = @{ Authorization = "Bearer $accessToken" }

    $details = Invoke-RestMethod -Method Get -Uri "$Base/api/customer/v1/units/$unitId" -Headers $hdr
    $tempInput = $details.inputs | Where-Object { $_.code -eq "temperature" }
    $inputId = $tempInput.id
    ```

### 2. Запрос тиков

`begin` / `end` — Unix-секунды.

=== "Python"

    ```python
    params = [
        ("inputIds", input_id),
        ("begin", 1719705600),
        ("end", 1719792000),
        ("timeFrame", 3600),
    ]
    t = requests.get(
        f"{BASE}/api/customer/v1/units/{unit_id}/ticks",
        headers=headers,
        params=params,
        timeout=60,
    )
    t.raise_for_status()
    rows = t.json()["items"]
    ```

=== "PowerShell"

    ```powershell
    $q = "inputIds=$inputId&begin=1719705600&end=1719792000&timeFrame=3600"
    $ticks = Invoke-RestMethod -Method Get `
        -Uri "$Base/api/customer/v1/units/${unitId}/ticks?$q" -Headers $hdr
    $rows = $ticks.items
    ```

## Ожидаемый результат

- В **`items`** — список **временных окон**: у каждой записи есть **`begin`** и **`end`** (границы окна в Unix-секундах) и **агрегаты показаний** за это окно — в частности **`meanValue`** (среднее) и **`firstValue`** (первое значение в окне). Остальные поля см. в OpenAPI в описании **`GetInputTicksResponseItem`**.

## Итоговый скрипт сценария

=== "Python"

    ```python
    --8<-- "scripts/query-telemetry.py"
    ```

=== "PowerShell"

    ```powershell
    --8<-- "scripts/query-telemetry.ps1"
    ```
