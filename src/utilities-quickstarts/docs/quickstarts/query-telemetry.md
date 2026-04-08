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
        p = argparse.ArgumentParser(description="Карточка юнита и история тиков по входу.")
        p.add_argument("--base", default=os.environ.get("UMEC_BASE", "https://api.rumecdev.deviot.cloud"))
        p.add_argument("--access-token", default=os.environ.get("UMEC_ACCESS_TOKEN"))
        p.add_argument("--unit-id", type=int, default=None)
        p.add_argument("--input-code", default=os.environ.get("UMEC_INPUT_CODE", "temperature"))
        p.add_argument("--begin", type=int, default=int(os.environ.get("UMEC_TICKS_BEGIN", "1719705600")))
        p.add_argument("--end", type=int, default=int(os.environ.get("UMEC_TICKS_END", "1719792000")))
        p.add_argument("--time-frame", type=int, default=int(os.environ.get("UMEC_TICKS_TIMEFRAME", "3600")))
        args = p.parse_args()
        if not args.access_token:
            p.error("Укажите --access-token или UMEC_ACCESS_TOKEN.")
        if args.unit_id is None and os.environ.get("UMEC_UNIT_ID"):
            args.unit_id = int(os.environ["UMEC_UNIT_ID"])
        if args.unit_id is None:
            p.error("Укажите --unit-id или UMEC_UNIT_ID.")
    
        base = args.base.rstrip("/")
        headers = {"Authorization": f"Bearer {args.access_token}"}
    
        # Шаг 1 — найти inputId: GET /units/{unitId}, выбор входа по code.
        d = requests.get(f"{base}/api/customer/v1/units/{args.unit_id}", headers=headers, timeout=30)
        d.raise_for_status()
        inputs = d.json().get("inputs") or []
        match = next((i for i in inputs if i.get("code") == args.input_code), None)
        if not match:
            print(json.dumps(inputs, indent=2, ensure_ascii=False))
            p.error(f"Вход с code={args.input_code!r} не найден")
    
        input_id = match["id"]
        print("inputId:", input_id)
    
        # Шаг 2 — история тиков: GET /units/{unitId}/ticks.
        params = [
            ("inputIds", input_id),
            ("begin", args.begin),
            ("end", args.end),
            ("timeFrame", args.time_frame),
        ]
        t = requests.get(
            f"{base}/api/customer/v1/units/{args.unit_id}/ticks",
            headers=headers,
            params=params,
            timeout=60,
        )
        t.raise_for_status()
        out = t.json()
        print(json.dumps(out, indent=2, ensure_ascii=False))
        return 0
    
    
    if __name__ == "__main__":
        raise SystemExit(main())
    ```

=== "PowerShell"

    ```powershell
    param(
        [string] $Base = $(if ($env:UMEC_BASE) { $env:UMEC_BASE } else { "https://api.rumecdev.deviot.cloud" }),
        [Parameter(Mandatory)]
        [string] $AccessToken,
        [Parameter(Mandatory)]
        [long] $UnitId,
        [string] $InputCode = $(if ($env:UMEC_INPUT_CODE) { $env:UMEC_INPUT_CODE } else { "temperature" }),
        [long] $Begin = $(if ($env:UMEC_TICKS_BEGIN) { [long]$env:UMEC_TICKS_BEGIN } else { 1719705600 }),
        [long] $End = $(if ($env:UMEC_TICKS_END) { [long]$env:UMEC_TICKS_END } else { 1719792000 }),
        [int] $TimeFrame = $(if ($env:UMEC_TICKS_TIMEFRAME) { [int]$env:UMEC_TICKS_TIMEFRAME } else { 3600 })
    )
    
    $Base = $Base.TrimEnd("/")
    $hdr = @{ Authorization = "Bearer $AccessToken" }
    
    # Шаг 1 — найти inputId: GET /units/{unitId}.
    $details = Invoke-RestMethod -Method Get -Uri "$Base/api/customer/v1/units/$UnitId" -Headers $hdr
    $inp = $details.inputs | Where-Object { $_.code -eq $InputCode } | Select-Object -First 1
    if (-not $inp) {
        $details.inputs | ConvertTo-Json -Depth 6
        throw "Вход с code=$InputCode не найден"
    }
    
    $inputId = $inp.id
    Write-Host "inputId:" $inputId
    
    # Шаг 2 — GET /units/{unitId}/ticks.
    $q = "inputIds=$inputId&begin=$Begin&end=$End&timeFrame=$TimeFrame"
    $ticks = Invoke-RestMethod -Method Get -Uri "$Base/api/customer/v1/units/${UnitId}/ticks?$q" -Headers $hdr
    $ticks | ConvertTo-Json -Depth 10
    ```
