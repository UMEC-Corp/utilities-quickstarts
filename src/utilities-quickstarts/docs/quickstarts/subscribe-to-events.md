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

=== "C#"
    ```csharp
    using System.Net.Http.Json;
    using System.Text.Json;

    var baseUrl = "https://api.umecdev.deviot.cloud";
    using var http = new HttpClient();
    var signInResponse = await http.PostAsJsonAsync(
        $"{baseUrl}/api/customer/v1/signin",
        new { userName = "customer_demo", password = "change_me_password" }
    );
    signInResponse.EnsureSuccessStatusCode();
    var signInPayload = await signInResponse.Content.ReadFromJsonAsync<JsonElement>();
    var accessToken = signInPayload.GetProperty("accessToken").GetString();
    ```

=== "Node.js"
    ```javascript
    const baseUrl = "https://api.umecdev.deviot.cloud";
    const signIn = await fetch(`${baseUrl}/api/customer/v1/signin`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userName: "customer_demo", password: "change_me_password" }),
    });
    if (!signIn.ok) throw new Error(await signIn.text());
    const { accessToken } = await signIn.json();
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

=== "C#"
    ```csharp
    using System.Net.WebSockets;
    using System.Text;
    using System.Text.Json;

    var wsUrl = "wss://ws.rumecdev.deviot.cloud/ws";
    using var ws = new ClientWebSocket();
    await ws.ConnectAsync(new Uri(wsUrl), CancellationToken.None);

    var connectRequest = JsonSerializer.Serialize(new
    {
        jsonrpc = "2.0",
        id = 1,
        method = "connect-customer",
        @params = new { authToken = accessToken }
    });
    var connectBytes = Encoding.UTF8.GetBytes(connectRequest);
    await ws.SendAsync(connectBytes, WebSocketMessageType.Text, true, CancellationToken.None);
    ```

=== "Node.js"
    ```javascript
    import WebSocket from "ws";

    const wsUrl = "wss://ws.rumecdev.deviot.cloud/ws";
    const ws = new WebSocket(wsUrl);
    await new Promise((resolve, reject) => {
      ws.once("open", resolve);
      ws.once("error", reject);
    });

    ws.send(JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "connect-customer",
      params: { authToken: accessToken },
    }));
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

=== "C#"
    ```csharp
    var unitIds = new[] { "8f8a6df4f7f54e7aaf12e4b3f8112c13/main" };
    var connectionKey = "connection-key-from-connect-response";

    var subscribeRequest = JsonSerializer.Serialize(new
    {
        jsonrpc = "2.0",
        id = 2,
        method = "subscribe-units",
        @params = new { connectionKey, unitIds }
    });
    var subscribeBytes = Encoding.UTF8.GetBytes(subscribeRequest);
    await ws.SendAsync(subscribeBytes, WebSocketMessageType.Text, true, CancellationToken.None);
    ```

=== "Node.js"
    ```javascript
    const unitIds = ["8f8a6df4f7f54e7aaf12e4b3f8112c13/main"];
    const connectionKey = "connection-key-from-connect-response";

    ws.send(JSON.stringify({
      jsonrpc: "2.0",
      id: 2,
      method: "subscribe-units",
      params: { connectionKey, unitIds },
    }));
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

=== "C#"
    ```csharp
    var buffer = new byte[8192];
    while (true)
    {
        var result = await ws.ReceiveAsync(buffer, CancellationToken.None);
        var message = Encoding.UTF8.GetString(buffer, 0, result.Count);
        var json = JsonDocument.Parse(message).RootElement;
        if (json.TryGetProperty("method", out var method) && method.GetString() == "unit-event")
        {
            Console.WriteLine($"unit-event: {message}");
        }
    }
    ```

=== "Node.js"
    ```javascript
    ws.on("message", (raw) => {
      const msg = JSON.parse(raw.toString());
      if (msg.method === "unit-event") {
        console.log("unit-event:", msg);
      }
    });
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

=== "C#"
    ```csharp
    using System.Net.Http.Json;
    using System.Net.WebSockets;
    using System.Text;
    using System.Text.Json;

    var baseUrl = "https://api.umecdev.deviot.cloud";
    var wsUrl = "wss://ws.rumecdev.deviot.cloud/ws";
    var unitIds = new[] { "8f8a6df4f7f54e7aaf12e4b3f8112c13/main" };

    using var http = new HttpClient();
    var signInResponse = await http.PostAsJsonAsync(
        $"{baseUrl}/api/customer/v1/signin",
        new { userName = "customer_demo", password = "change_me_password" }
    );
    signInResponse.EnsureSuccessStatusCode();
    var signInPayload = await signInResponse.Content.ReadFromJsonAsync<JsonElement>();
    var accessToken = signInPayload.GetProperty("accessToken").GetString();

    using var ws = new ClientWebSocket();
    await ws.ConnectAsync(new Uri(wsUrl), CancellationToken.None);

    var connectPayload = JsonSerializer.Serialize(new
    {
        jsonrpc = "2.0",
        id = 1,
        method = "connect-customer",
        @params = new { authToken = accessToken }
    });
    await ws.SendAsync(Encoding.UTF8.GetBytes(connectPayload), WebSocketMessageType.Text, true, CancellationToken.None);

    var recvBuffer = new byte[8192];
    var connectResult = await ws.ReceiveAsync(recvBuffer, CancellationToken.None);
    var connectJson = JsonDocument.Parse(Encoding.UTF8.GetString(recvBuffer, 0, connectResult.Count)).RootElement;
    var connectionKey = connectJson.GetProperty("result").GetProperty("connectionKey").GetString();

    var subscribePayload = JsonSerializer.Serialize(new
    {
        jsonrpc = "2.0",
        id = 2,
        method = "subscribe-units",
        @params = new { connectionKey, unitIds }
    });
    await ws.SendAsync(Encoding.UTF8.GetBytes(subscribePayload), WebSocketMessageType.Text, true, CancellationToken.None);

    while (true)
    {
        var result = await ws.ReceiveAsync(recvBuffer, CancellationToken.None);
        var message = Encoding.UTF8.GetString(recvBuffer, 0, result.Count);
        var msgJson = JsonDocument.Parse(message).RootElement;
        if (msgJson.TryGetProperty("method", out var method) && method.GetString() == "unit-event")
            Console.WriteLine($"unit-event: {message}");
    }
    ```

=== "Node.js"
    ```javascript
    import WebSocket from "ws";

    const baseUrl = "https://api.umecdev.deviot.cloud";
    const wsUrl = "wss://ws.rumecdev.deviot.cloud/ws";
    const unitIds = ["8f8a6df4f7f54e7aaf12e4b3f8112c13/main"];

    const signIn = await fetch(`${baseUrl}/api/customer/v1/signin`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userName: "customer_demo", password: "change_me_password" }),
    });
    if (!signIn.ok) throw new Error(await signIn.text());
    const { accessToken } = await signIn.json();

    const ws = new WebSocket(wsUrl);
    await new Promise((resolve, reject) => {
      ws.once("open", resolve);
      ws.once("error", reject);
    });

    ws.send(JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "connect-customer",
      params: { authToken: accessToken },
    }));

    const connectionKey = await new Promise((resolve) => {
      ws.once("message", (raw) => {
        const msg = JSON.parse(raw.toString());
        resolve(msg.result.connectionKey);
      });
    });

    ws.send(JSON.stringify({
      jsonrpc: "2.0",
      id: 2,
      method: "subscribe-units",
      params: { connectionKey, unitIds },
    }));

    ws.on("message", (raw) => {
      const msg = JSON.parse(raw.toString());
      if (msg.method === "unit-event") console.log("unit-event:", msg);
    });
    ```
