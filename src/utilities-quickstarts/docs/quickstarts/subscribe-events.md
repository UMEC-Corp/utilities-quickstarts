# Сценарий: события юнита по WebSocket (customer)

## Цель

Подключиться к сервису **WebSocket** от имени **customer**, подписаться на юнит и **получить push-уведомления** об изменениях (показания, мониторы, алерты). В открытой REST-спецификации Customer API этот поток не описан: контракт реализован в сервисе **Utilities.WebSockets** — JSON-RPC 2.0 поверх WebSocket, машиночитаемое описание методов — **OpenRPC** (`/openrpc.json`).

## Предусловия

- Пользователь авторизован, получен `accessToken`
- Выполнен сценарий [Привязка устройства](bind-and-provision.md), получен `unitId`.
- Известен **базовый URL WebSocket** на вашем стенде. Пример из типового окружения: `wss://ws.umecdev.deviot.cloud/ws` (маршрут контроллера — **`/ws`**, протокол — **WSS**).
- Нужен **источник события**: реальное устройство, тестовый поток телеметрии или действие в системе, которое публикует обновление в шину, на которую подписан сервис WebSocket.
- Для запуска итоговых скриптов на Python: пакеты **`requests`** и **`websocket-client`** (`pip install websocket-client`).

## Как устроен сервис (кратко)

Исходники: проект **`Utilities.WebSockets`** (хост: `Utilities.WebSockets.Host`).

| Что | Где в коде |
|-----|------------|
| Точка входа WebSocket | `WebSocketController`, маршрут `[Route("ws")]` + `GET` → upgrade |
| Методы JSON-RPC | `RpcServer`: `connect-customer`, `subscribe-units`, `unsubscribe-units` (для других ролей — `connect-maintainer`, `connect-vendor`) |
| Уведомления с сервера | метод **`unit-event`**, тело — DTO как в `UnitEventNotification` (поля вроде `subject`, `unitKey`, `timestamp`, `properties`, `monitors`, `alerts`) |
| OpenRPC | по умолчанию путь **`/openrpc.json`** на том же хосте, что и HTTP(S) сервиса |

**Составной идентификатор юнита** для `subscribe-units`: строка вида **`{deviceId}/{unitCode}`**, где `deviceId` — GUID устройства, `unitCode` — код юнита (для модели с одним юнитом часто `main`). Сервер проверяет доступ customer через ACL (`CustomersService.ListUnits`). Числовой `unitId` из REST привязки — это другой идентификатор; для WebSocket возьмите пару `deviceId` + `unitCode` из **карточки юнита** в Customer API (OpenAPI) или из списка юнитов.

## Шаги

### 1. Собрать `unitIds` для подписки

Один элемент массива — строка **`{deviceId}/{unitCode}`** (регистр GUID обычно не важен).

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
    body = d.json()
    compound_unit_id = f"{body['deviceId']}/{body['unitCode']}"
    ```

=== "PowerShell"

    ```powershell
    $Base = "https://api.rumecdev.deviot.cloud"
    $hdr = @{ Authorization = "Bearer $accessToken" }

    $u = Invoke-RestMethod -Method Get -Uri "$Base/api/customer/v1/units/$unitId" -Headers $hdr
    $compoundUnitId = "$($u.deviceId)/$($u.unitCode)"
    ```

Имена полей в JSON (`deviceId`, `unitCode`) сверьте с актуальной спецификацией; при отличии задайте строку вручную.

### 2. Подключиться по WebSocket и вызвать `connect-customer`

Отправляйте **текстовые** фреймы с одним JSON-RPC 2.0 сообщением на фрейм. В параметрах — **`authToken`**: тот же **access token** customer, что и для REST.

=== "Python"

    ```python
    import json
    from websocket import create_connection

    WS = "wss://ws.umecdev.deviot.cloud/ws"

    ws = create_connection(WS)

    def rpc(msg_id, method, params):
        ws.send(json.dumps({"jsonrpc": "2.0", "id": msg_id, "method": method, "params": params}))

    rpc(1, "connect-customer", {"authToken": access_token})
    hello = json.loads(ws.recv())
    connection_key = hello["result"]["connectionKey"]
    ```

=== "PowerShell"

    Пример ориентирован на **PowerShell 7+** (`System.Net.WebSockets.ClientWebSocket`).

    ```powershell
    $ws = [System.Net.WebSockets.ClientWebSocket]::new()
    $ws.ConnectAsync([Uri]"wss://ws.umecdev.deviot.cloud/ws", [Threading.CancellationToken]::None).GetAwaiter().GetResult()

    function Send-JsonRpc($id, $method, $params) {
        $payload = @{ jsonrpc = "2.0"; id = $id; method = $method; params = $params } | ConvertTo-Json -Compress -Depth 6
        $buf = [Text.Encoding]::UTF8.GetBytes($payload)
        $seg = [System.ArraySegment[byte]]::new($buf)
        $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    }
    function Receive-JsonRpc {
        $ms = [IO.MemoryStream]::new()
        $buf = [byte[]]::new(8192)
        do {
            $seg = [System.ArraySegment[byte]]::new($buf)
            $r = $ws.ReceiveAsync($seg, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
            $ms.Write($buf, 0, $r.Count)
        } while (-not $r.EndOfMessage)
        [Text.Encoding]::UTF8.GetString($ms.ToArray())
    }

    Send-JsonRpc 1 "connect-customer" @{ authToken = $accessToken }
    $hello = Receive-JsonRpc | ConvertFrom-Json
    $connectionKey = $hello.result.connectionKey
    ```

### 3. Подписаться: `subscribe-units`

Передайте **`connectionKey`** из ответа шага 2 и массив **`unitIds`** (составные строки из шага 1).

=== "Python"

    ```python
    rpc(2, "subscribe-units", {"connectionKey": connection_key, "unitIds": [compound_unit_id]})
    sub = json.loads(ws.recv())
    # sub["result"]["subscribedUnitIds"]
    ```

=== "PowerShell"

    ```powershell
    Send-JsonRpc 2 "subscribe-units" @{ connectionKey = $connectionKey; unitIds = @($compoundUnitId) }
    $sub = Receive-JsonRpc | ConvertFrom-Json
    ```

### 4. Ждать `unit-event` и проверить изменение

Сервер присылает **уведомления** без поля `id`: `method` = **`unit-event`**, в `params` — полезная нагрузка (обновления по юниту). Дождитесь события после действия, которое меняет состояние устройства или связанные данные.

=== "Python"

    ```python
    while True:
        raw = ws.recv()
        msg = json.loads(raw)
        if msg.get("method") == "unit-event":
            print(msg.get("params"))
            break
    ws.close()
    ```

=== "PowerShell"

    ```powershell
    while ($true) {
        $raw = Receive-JsonRpc | ConvertFrom-Json
        if ($raw.method -eq "unit-event") {
            $raw.params | ConvertTo-Json -Depth 10
            break
        }
    }
    $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "", [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    ```

На продакшене цикл обычно не завершается по первому событию: обрабатывайте поток до закрытия сокета или `unsubscribe-units`. Реализация StreamJsonRpc на сервере может отдавать полезную нагрузку `unit-event` как **массив из одного объекта** в `params` — учитывайте оба варианта при разборе.

## Ожидаемый результат

- Успешные ответы JSON-RPC на `connect-customer` и `subscribe-units`.
- При изменении данных по юниту приходит хотя бы одно уведомление **`unit-event`** с осмысленным содержимым (`properties` / `monitors` / `alerts` — в зависимости от типа события).

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
    
    try:
        from websocket import create_connection
    except ImportError:
        print("Установите websocket-client: pip install websocket-client", file=sys.stderr)
        sys.exit(1)
    
    
    def rpc_send(ws, msg_id: int, method: str, params: dict) -> None:
        ws.send(json.dumps({"jsonrpc": "2.0", "id": msg_id, "method": method, "params": params}))
    
    
    def rpc_recv(ws) -> dict:
        return json.loads(ws.recv())
    
    
    def compound_from_rest(base: str, access_token: str, unit_id: int) -> str:
        base = base.rstrip("/")
        r = requests.get(
            f"{base}/api/customer/v1/units/{unit_id}",
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=30,
        )
        r.raise_for_status()
        body = r.json()
        device_id = body.get("deviceId") or body.get("device_id")
        unit_code = body.get("unitCode") or body.get("unit_code")
        if not device_id or not unit_code:
            print(
                "В ответе GET /units/{id} нет пары deviceId/unitCode. Задайте --compound-unit-id.",
                file=sys.stderr,
            )
            sys.exit(1)
        return f"{device_id}/{unit_code}"
    
    
    def main() -> int:
        p = argparse.ArgumentParser(
            description="Customer WebSocket: connect-customer, subscribe-units, печать unit-event.",
        )
        p.add_argument(
            "--rest-base",
            default=os.environ.get("UMEC_BASE", "https://api.rumecdev.deviot.cloud"),
            help="Базовый URL REST Customer API (для разрешения составного unit id)",
        )
        p.add_argument(
            "--ws-url",
            default=os.environ.get("UMEC_WS_URL", "wss://ws.umecdev.deviot.cloud/ws"),
            help="URL WebSocket (JSON-RPC)",
        )
        p.add_argument("--access-token", default=os.environ.get("UMEC_ACCESS_TOKEN"))
        p.add_argument(
            "--compound-unit-id",
            default=os.environ.get("UMEC_COMPOUND_UNIT_ID"),
            help="Подписка: deviceId/unitCode (если не задан --unit-id)",
        )
        p.add_argument(
            "--unit-id",
            type=int,
            default=None,
            help="Числовой unit id REST — для GET карточки и сборки deviceId/unitCode",
        )
        p.add_argument(
            "--max-events",
            type=int,
            default=1,
            help="Сколько уведомлений unit-event вывести перед выходом (0 = бесконечно)",
        )
        args = p.parse_args()
    
        if not args.access_token:
            p.error("Укажите --access-token или UMEC_ACCESS_TOKEN.")
    
        # Шаг 1 — подготовить deviceId/unitCode (аргумент или GET /units/{id}).
        if args.compound_unit_id:
            compound = args.compound_unit_id
        elif args.unit_id is not None:
            compound = compound_from_rest(args.rest_base, args.access_token, args.unit_id)
        elif os.environ.get("UMEC_UNIT_ID"):
            compound = compound_from_rest(
                args.rest_base, args.access_token, int(os.environ["UMEC_UNIT_ID"])
            )
        else:
            p.error("Нужен --compound-unit-id или --unit-id (или UMEC_COMPOUND_UNIT_ID / UMEC_UNIT_ID).")
    
        # Шаг 2 — подключение по WebSocket и JSON-RPC connect-customer.
        ws = create_connection(args.ws_url)
        try:
            rpc_send(ws, 1, "connect-customer", {"authToken": args.access_token})
            r1 = rpc_recv(ws)
            if "error" in r1:
                print(json.dumps(r1, indent=2, ensure_ascii=False))
                return 1
            connection_key = r1["result"]["connectionKey"]
            print("connectionKey:", connection_key)
    
            # Шаг 3 — subscribe-units.
            rpc_send(
                ws,
                2,
                "subscribe-units",
                {"connectionKey": connection_key, "unitIds": [compound]},
            )
            r2 = rpc_recv(ws)
            if "error" in r2:
                print(json.dumps(r2, indent=2, ensure_ascii=False))
                return 1
            print("subscribe:", json.dumps(r2.get("result"), ensure_ascii=False))
    
            # Шаг 4 — ждать push unit-event.
            seen = 0
            while args.max_events == 0 or seen < args.max_events:
                msg = rpc_recv(ws)
                if msg.get("method") == "unit-event":
                    seen += 1
                    params = msg.get("params")
                    if isinstance(params, list) and len(params) == 1:
                        params = params[0]
                    print(json.dumps(params, indent=2, ensure_ascii=False))
                else:
                    print(json.dumps(msg, indent=2, ensure_ascii=False))
        finally:
            ws.close()
    
        return 0
    
    
    if __name__ == "__main__":
        raise SystemExit(main())
    ```

=== "PowerShell"

    ```powershell
    param(
        [string] $RestBase = $(if ($env:UMEC_BASE) { $env:UMEC_BASE } else { "https://api.rumecdev.deviot.cloud" }),
        [string] $WsUrl = $(if ($env:UMEC_WS_URL) { $env:UMEC_WS_URL } else { "wss://ws.umecdev.deviot.cloud/ws" }),
        [Parameter(Mandatory)]
        [string] $AccessToken,
        [string] $CompoundUnitId = $env:UMEC_COMPOUND_UNIT_ID,
        [long] $UnitId = 0,
        [int] $MaxEvents = 1
    )
    
    $ErrorActionPreference = "Stop"
    $RestBase = $RestBase.TrimEnd("/")
    
    # Шаг 1 — подготовить deviceId/unitCode (параметр или GET /units/{id}).
    if (-not $CompoundUnitId) {
        if ($UnitId -eq 0) {
            if ($env:UMEC_UNIT_ID) { $UnitId = [long]$env:UMEC_UNIT_ID }
        }
        if ($UnitId -eq 0) {
            throw "Укажите -CompoundUnitId или -UnitId (или переменные UMEC_COMPOUND_UNIT_ID / UMEC_UNIT_ID)."
        }
        $hdr = @{ Authorization = "Bearer $AccessToken" }
        $u = Invoke-RestMethod -Method Get -Uri "$RestBase/api/customer/v1/units/$UnitId" -Headers $hdr
        if (-not $u.deviceId -or -not $u.unitCode) {
            throw "В ответе API нет deviceId/unitCode; задайте -CompoundUnitId вручную."
        }
        $CompoundUnitId = "$($u.deviceId)/$($u.unitCode)"
    }
    
    # Шаг 2 — WebSocket: connect-customer.
    $ws = [System.Net.WebSockets.ClientWebSocket]::new()
    $ws.ConnectAsync([Uri]$WsUrl, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    
    function Send-JsonRpc {
        param([int]$Id, [string]$Method, [hashtable]$Params)
        $payload = @{ jsonrpc = "2.0"; id = $Id; method = $Method; params = $Params } | ConvertTo-Json -Compress -Depth 8
        $buf = [Text.Encoding]::UTF8.GetBytes($payload)
        $seg = [System.ArraySegment[byte]]::new($buf)
        $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    }
    
    function Receive-JsonRpc {
        $ms = [IO.MemoryStream]::new()
        $buf = [byte[]]::new(65536)
        do {
            $seg = [System.ArraySegment[byte]]::new($buf)
            $r = $ws.ReceiveAsync($seg, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
            if ($r.MessageType -ne [System.Net.WebSockets.WebSocketMessageType]::Text) { continue }
            $ms.Write($buf, 0, $r.Count)
        } while (-not $r.EndOfMessage)
        $txt = [Text.Encoding]::UTF8.GetString($ms.ToArray())
        $txt | ConvertFrom-Json
    }
    
    try {
        Send-JsonRpc -Id 1 -Method "connect-customer" -Params @{ authToken = $AccessToken }
        $hello = Receive-JsonRpc
        if ($null -ne $hello.error) {
            $hello | ConvertTo-Json -Depth 10
            exit 1
        }
        $connectionKey = $hello.result.connectionKey
        Write-Host "connectionKey: $connectionKey"
    
        # Шаг 3 — subscribe-units.
        Send-JsonRpc -Id 2 -Method "subscribe-units" -Params @{ connectionKey = $connectionKey; unitIds = @($CompoundUnitId) }
        $sub = Receive-JsonRpc
        if ($null -ne $sub.error) {
            $sub | ConvertTo-Json -Depth 10
            exit 1
        }
        Write-Host "subscribe:"
        $sub.result | ConvertTo-Json -Depth 10
    
        # Шаг 4 — ждать unit-event.
        $seen = 0
        while ($MaxEvents -eq 0 -or $seen -lt $MaxEvents) {
            $msg = Receive-JsonRpc
            if ($msg.method -eq "unit-event") {
                $seen++
                $p = $msg.params
                if ($p -is [System.Array] -and $p.Count -eq 1) { $p = $p[0] }
                $p | ConvertTo-Json -Depth 12
            }
            else {
                $msg | ConvertTo-Json -Depth 10
            }
        }
    }
    finally {
        if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "", [Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
        }
        $ws.Dispose()
    }
    ```

