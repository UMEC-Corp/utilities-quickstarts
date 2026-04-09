**Сценарий: Подписка на события по вебсокетам**

## Цель

Подключиться к WebSocket, подписаться на устройства и получать события `unit-event` в реальном времени.

## Предусловия

- **Выполнен сценарий [Привязка устройства](bind-and-provision.md), получен `unitId`.**
- Нужны учетные данные пользователя (`userName`, `password`)
- Нужен хотя бы один идентификатор юнита в формате `{deviceId}/{unitCode}`.

## Шаги

### 1. Получите customer `accessToken` через `POST /api/customer/v1/signin`.

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
    ```

=== "PowerShell"
    ```powershell
    $BaseUrl = "https://api.umecdev.deviot.cloud"
    $SignInBody = @{ userName = "customer_demo"; password = "change_me_password" } | ConvertTo-Json
    $SignIn = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/customer/v1/signin" -ContentType "application/json" -Body $SignInBody
    $AccessToken = $SignIn.accessToken
    ```

### 2. Откройте WebSocket-соединение, вызовите RPC-метод `connect-customer` и сохраните `connectionKey`.

=== "Python"
    ```python
    import asyncio
    import json
    import websockets

    ws_url = "wss://ws.rumecdev.deviot.cloud/ws"

    async def connect_customer(token: str):
        async with websockets.connect(ws_url) as ws:
            await ws.send(json.dumps({
                "jsonrpc": "2.0",
                "id": 1,
                "method": "connect-customer",
                "params": {"authToken": token}
            }))
            response = json.loads(await ws.recv())
            connection_key = response["result"]["connectionKey"]
            return ws, connection_key
    ```

=== "PowerShell"
    ```powershell
    Add-Type -AssemblyName System.Net.WebSockets
    Add-Type -AssemblyName System.Text

    $WsUri = [Uri]"wss://ws.rumecdev.deviot.cloud/ws"
    $Ws = [System.Net.WebSockets.ClientWebSocket]::new()
    $Ws.ConnectAsync($WsUri, [Threading.CancellationToken]::None).GetAwaiter().GetResult()

    $ConnectRequest = @{
      jsonrpc = "2.0"
      id = 1
      method = "connect-customer"
      params = @{ authToken = $AccessToken }
    } | ConvertTo-Json -Depth 10

    $Bytes = [Text.Encoding]::UTF8.GetBytes($ConnectRequest)
    $Ws.SendAsync([ArraySegment[byte]]::new($Bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    ```

### 3. Подпишитесь методом `subscribe-units` на нужные `unitIds`.

=== "Python"
    ```python
    async def subscribe_units(ws, connection_key: str, unit_ids: list[str]):
        await ws.send(json.dumps({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "subscribe-units",
            "params": {
                "connectionKey": connection_key,
                "unitIds": unit_ids
            }
        }))
        response = json.loads(await ws.recv())
        print(response)
    ```

=== "PowerShell"
    ```powershell
    $UnitIds = @("8f8a6df4f7f54e7aaf12e4b3f8112c13/main")
    $ConnectionKey = "connection-key-from-connect-response"

    $SubscribeRequest = @{
      jsonrpc = "2.0"
      id = 2
      method = "subscribe-units"
      params = @{
        connectionKey = $ConnectionKey
        unitIds = $UnitIds
      }
    } | ConvertTo-Json -Depth 10

    $SubscribeBytes = [Text.Encoding]::UTF8.GetBytes($SubscribeRequest)
    $Ws.SendAsync([ArraySegment[byte]]::new($SubscribeBytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    ```

### 4. Принимайте входящие уведомления с методом `unit-event`.

=== "Python"
    ```python
    async def read_events(ws):
        while True:
            msg = json.loads(await ws.recv())
            if msg.get("method") == "unit-event":
                print("unit-event:", msg)
    ```

=== "PowerShell"
    ```powershell
    $Buffer = New-Object byte[] 8192
    $Segment = [ArraySegment[byte]]::new($Buffer)
    $Result = $Ws.ReceiveAsync($Segment, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    $Message = [Text.Encoding]::UTF8.GetString($Buffer, 0, $Result.Count)
    $Message
    ```

## Ожидаемый результат

- Получен `connectionKey` после `connect-customer`.
- Подписка подтверждена ответом `subscribe-units` (`subscribedCount`, `subscribedUnitIds`).
- В сокет приходят JSON-RPC уведомления с методом `unit-event`.

## Полный скрипт сценария

=== "Python"
    ```python
    import asyncio
    import json
    import requests
    import websockets

    base_url = "https://api.umecdev.deviot.cloud"
    ws_url = "wss://ws.rumecdev.deviot.cloud/ws"
    unit_ids = ["8f8a6df4f7f54e7aaf12e4b3f8112c13/main"]

    # Шаг 1: авторизация customer
    signin = requests.post(
        f"{base_url}/api/customer/v1/signin",
        json={"userName": "customer_demo", "password": "change_me_password"},
        timeout=30,
    )
    signin.raise_for_status()
    access_token = signin.json()["accessToken"]

    async def main():
        # Шаг 2: connect-customer
        async with websockets.connect(ws_url) as ws:
            await ws.send(json.dumps({
                "jsonrpc": "2.0",
                "id": 1,
                "method": "connect-customer",
                "params": {"authToken": access_token}
            }))
            connect_resp = json.loads(await ws.recv())
            connection_key = connect_resp["result"]["connectionKey"]

            # Шаг 3: subscribe-units
            await ws.send(json.dumps({
                "jsonrpc": "2.0",
                "id": 2,
                "method": "subscribe-units",
                "params": {"connectionKey": connection_key, "unitIds": unit_ids}
            }))
            subscribe_resp = json.loads(await ws.recv())
            print(subscribe_resp)

            # Шаг 4: получение unit-event
            while True:
                msg = json.loads(await ws.recv())
                if msg.get("method") == "unit-event":
                    print("unit-event:", msg)

    asyncio.run(main())
    ```

=== "PowerShell"
    ```powershell
    Add-Type -AssemblyName System.Net.WebSockets
    Add-Type -AssemblyName System.Text

    $BaseUrl = "https://api.umecdev.deviot.cloud"
    $WsUri = [Uri]"wss://ws.rumecdev.deviot.cloud/ws"
    $UnitIds = @("8f8a6df4f7f54e7aaf12e4b3f8112c13/main")

    # Шаг 1: авторизация customer
    $SignInBody = @{ userName = "customer_demo"; password = "change_me_password" } | ConvertTo-Json
    $SignIn = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/customer/v1/signin" -ContentType "application/json" -Body $SignInBody
    $AccessToken = $SignIn.accessToken

    # Шаг 2: connect-customer
    $Ws = [System.Net.WebSockets.ClientWebSocket]::new()
    $Ws.ConnectAsync($WsUri, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    $ConnectRequest = @{ jsonrpc = "2.0"; id = 1; method = "connect-customer"; params = @{ authToken = $AccessToken } } | ConvertTo-Json -Depth 10
    $ConnectBytes = [Text.Encoding]::UTF8.GetBytes($ConnectRequest)
    $Ws.SendAsync([ArraySegment[byte]]::new($ConnectBytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()

    # Шаг 3: subscribe-units
    $ConnectionKey = "connection-key-from-connect-response"
    $SubscribeRequest = @{ jsonrpc = "2.0"; id = 2; method = "subscribe-units"; params = @{ connectionKey = $ConnectionKey; unitIds = $UnitIds } } | ConvertTo-Json -Depth 10
    $SubscribeBytes = [Text.Encoding]::UTF8.GetBytes($SubscribeRequest)
    $Ws.SendAsync([ArraySegment[byte]]::new($SubscribeBytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()

    # Шаг 4: получение unit-event
    $Buffer = New-Object byte[] 8192
    $Segment = [ArraySegment[byte]]::new($Buffer)
    $Result = $Ws.ReceiveAsync($Segment, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    $Message = [Text.Encoding]::UTF8.GetString($Buffer, 0, $Result.Count)
    $Message
    ```
