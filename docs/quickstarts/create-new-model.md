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
    --8<-- "scripts/create-new-model.py"
    ```

=== "PowerShell"

    ```powershell
    --8<-- "scripts/create-new-model.ps1"
    ```
