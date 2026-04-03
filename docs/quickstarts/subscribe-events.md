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
    --8<-- "scripts/subscribe-events.py"
    ```

=== "PowerShell"

    ```powershell
    --8<-- "scripts/subscribe-events.ps1"
    ```

