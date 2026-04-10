**Сценарий: Привязка устройства**

## Цель

Привязать устройство к пользователю через `device_code`/`user_code`, проверить привязку и получить токен устройства.

## Предусловия

- **Выполнен сценарий [Создание новой модели](new-model.md), получены `vendorCode`, `modelCode`, `firmwareVersion`, `hardwareVersion`.**
- Доступны учетные данные пользователя: `UMEC_CUSTOMER_USER`, `UMEC_CUSTOMER_PASSWORD`.
- Доступны параметры устройства: `UMEC_DEVICE_SERIAL`, `UMEC_DEVICE_MAC`.

## Шаги

### 1. Авторизуйтесь как customer и получите `accessToken` (`POST /api/customer/v1/signin`).

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

=== "C#"
    ```csharp
    using System.Net.Http.Json;
    using System.Text.Json;

    var baseUrl = "https://api.umecdev.deviot.cloud";
    var userName = Environment.GetEnvironmentVariable("UMEC_CUSTOMER_USER");
    var password = Environment.GetEnvironmentVariable("UMEC_CUSTOMER_PASSWORD");
    if (string.IsNullOrWhiteSpace(userName) || string.IsNullOrWhiteSpace(password))
        throw new Exception("Не заданы UMEC_CUSTOMER_USER/UMEC_CUSTOMER_PASSWORD");

    using var http = new HttpClient();
    var signIn = await http.PostAsJsonAsync($"{baseUrl}/api/customer/v1/signin", new { userName, password });
    signIn.EnsureSuccessStatusCode();
    var payload = await signIn.Content.ReadFromJsonAsync<JsonElement>();
    var customerAccessToken = payload.GetProperty("accessToken").GetString();
    Console.WriteLine($"customer_access_token acquired: {!string.IsNullOrEmpty(customerAccessToken)}");
    ```

=== "Node.js"
    ```javascript
    const baseUrl = "https://api.umecdev.deviot.cloud";
    const userName = process.env.UMEC_CUSTOMER_USER;
    const password = process.env.UMEC_CUSTOMER_PASSWORD;
    if (!userName || !password) throw new Error("Не заданы UMEC_CUSTOMER_USER/UMEC_CUSTOMER_PASSWORD");

    const signIn = await fetch(`${baseUrl}/api/customer/v1/signin`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userName, password }),
    });
    if (!signIn.ok) throw new Error(await signIn.text());
    const { accessToken: customerAccessToken } = await signIn.json();
    console.log("customer_access_token acquired:", Boolean(customerAccessToken));
    ```

### 2. Получите `device_code`, `user_code`, `verification_uri`, `verification_uri_complete` в Identity (`POST /connect/deviceauthorization`).

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

=== "C#"
    ```csharp
    using System.Text.Json;

    var endpoint = "https://http-identity.umecdev.deviot.cloud/connect/deviceauthorization";
    using var http = new HttpClient();
    var deviceAuth = await http.PostAsync(endpoint, new FormUrlEncodedContent(new Dictionary<string, string>
    {
        ["client_id"] = "controller"
    }));
    deviceAuth.EnsureSuccessStatusCode();
    var devicePayload = await deviceAuth.Content.ReadFromJsonAsync<JsonElement>();

    var deviceCode = devicePayload.GetProperty("device_code").GetString();
    var userCode = devicePayload.GetProperty("user_code").GetString();
    var verificationUri = devicePayload.GetProperty("verification_uri").GetString();
    var verificationUriComplete = devicePayload.GetProperty("verification_uri_complete").GetString();
    var pollInterval = devicePayload.TryGetProperty("interval", out var intervalEl) ? intervalEl.GetInt32() : 5;

    Console.WriteLine($"Open: {verificationUriComplete}");
    Console.WriteLine($"User code: {userCode}");
    ```

=== "Node.js"
    ```javascript
    const endpoint = "https://http-identity.umecdev.deviot.cloud/connect/deviceauthorization";
    const deviceAuth = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ client_id: "controller" }),
    });
    if (!deviceAuth.ok) throw new Error(await deviceAuth.text());
    const deviceData = await deviceAuth.json();

    const deviceCode = deviceData.device_code;
    const userCode = deviceData.user_code;
    const verificationUri = deviceData.verification_uri;
    const verificationUriComplete = deviceData.verification_uri_complete;
    let pollInterval = Number(deviceData.interval || 5);

    console.log("Open:", verificationUriComplete);
    console.log("User code:", userCode);
    ```

### 3. Выполните привязку устройства (`POST /api/customer/v1/units/bind`).

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

=== "C#"
    ```csharp
    using System.Net.Http.Headers;
    using System.Net.Http.Json;
    using System.Text.Json;

    var baseUrl = "https://api.umecdev.deviot.cloud";
    var customerAccessToken = "<полученный_на_шаге_1_token>";
    var userCode = "<полученный_на_шаге_2_user_code>";
    var verificationUri = "<полученный_на_шаге_2_verification_uri>";

    using var http = new HttpClient();
    http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", customerAccessToken);
    var bindResp = await http.PostAsJsonAsync($"{baseUrl}/api/customer/v1/units/bind", new
    {
        deviceSerial = Environment.GetEnvironmentVariable("UMEC_DEVICE_SERIAL"),
        userCode,
        verificationUrl = verificationUri,
        firmware = new
        {
            vendorCode = Environment.GetEnvironmentVariable("UMEC_VENDOR_CODE"),
            modelCode = Environment.GetEnvironmentVariable("UMEC_MODEL_CODE"),
            firmwareVersion = Environment.GetEnvironmentVariable("UMEC_FIRMWARE_VERSION"),
            hardwareVersion = Environment.GetEnvironmentVariable("UMEC_HARDWARE_VERSION")
        },
        deviceMacAddress = Environment.GetEnvironmentVariable("UMEC_DEVICE_MAC"),
        location = new { latitude = 55.7558, longitude = 37.6173 }
    });
    bindResp.EnsureSuccessStatusCode();
    var bindPayload = await bindResp.Content.ReadFromJsonAsync<JsonElement>();
    var boundUnitIds = bindPayload.GetProperty("items").EnumerateArray()
        .Where(x => x.TryGetProperty("unitId", out _))
        .Select(x => x.GetProperty("unitId").GetInt64())
        .ToArray();
    Console.WriteLine($"bound unitIds: {string.Join(", ", boundUnitIds)}");
    ```

=== "Node.js"
    ```javascript
    const baseUrl = "https://api.umecdev.deviot.cloud";
    const customerAccessToken = "<полученный_на_шаге_1_token>";
    const userCode = "<полученный_на_шаге_2_user_code>";
    const verificationUri = "<полученный_на_шаге_2_verification_uri>";

    const bindResp = await fetch(`${baseUrl}/api/customer/v1/units/bind`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${customerAccessToken}`,
      },
      body: JSON.stringify({
        deviceSerial: process.env.UMEC_DEVICE_SERIAL,
        userCode,
        verificationUrl: verificationUri,
        firmware: {
          vendorCode: process.env.UMEC_VENDOR_CODE,
          modelCode: process.env.UMEC_MODEL_CODE,
          firmwareVersion: process.env.UMEC_FIRMWARE_VERSION,
          hardwareVersion: process.env.UMEC_HARDWARE_VERSION,
        },
        deviceMacAddress: process.env.UMEC_DEVICE_MAC,
        location: { latitude: 55.7558, longitude: 37.6173 },
      }),
    });
    if (!bindResp.ok) throw new Error(await bindResp.text());
    const bindData = await bindResp.json();
    const boundUnitIds = (bindData.items ?? []).map((x) => x.unitId).filter(Boolean);
    console.log("bound unitIds:", boundUnitIds);
    ```

### 4. Проверьте наличие привязанного устройства: получите список устройств и убедитесь, что в нем есть хотя бы один `unitId` из ответа привязки (`bind`).

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

=== "C#"
    ```csharp
    using System.Net.Http.Headers;
    using System.Text.Json;

    var baseUrl = "https://api.umecdev.deviot.cloud";
    var customerAccessToken = "<полученный_на_шаге_1_token>";
    var boundUnitIds = new[] { 12345L };

    using var http = new HttpClient();
    http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", customerAccessToken);
    var unitsResp = await http.GetAsync($"{baseUrl}/api/customer/v1/units");
    unitsResp.EnsureSuccessStatusCode();
    var unitsPayload = await unitsResp.Content.ReadFromJsonAsync<JsonElement>();
    var actualUnitIds = unitsPayload.GetProperty("items").EnumerateArray()
        .Where(x => x.TryGetProperty("unitId", out _))
        .Select(x => x.GetProperty("unitId").GetInt64())
        .ToHashSet();
    if (!boundUnitIds.Any(id => actualUnitIds.Contains(id)))
        throw new Exception("Привязанное устройство не найдено в GET /api/customer/v1/units");
    Console.WriteLine("bind verification passed");
    ```

=== "Node.js"
    ```javascript
    const baseUrl = "https://api.umecdev.deviot.cloud";
    const customerAccessToken = "<полученный_на_шаге_1_token>";
    const boundUnitIds = [12345];

    const unitsResp = await fetch(`${baseUrl}/api/customer/v1/units`, {
      headers: { Authorization: `Bearer ${customerAccessToken}` },
    });
    if (!unitsResp.ok) throw new Error(await unitsResp.text());
    const unitsData = await unitsResp.json();
    const actualUnitIds = new Set((unitsData.items ?? []).map((x) => x.unitId).filter(Boolean));
    if (!boundUnitIds.some((id) => actualUnitIds.has(id))) {
      throw new Error("Привязанное устройство не найдено в GET /api/customer/v1/units");
    }
    console.log("bind verification passed");
    ```

### 5. Получите токен устройства (`device token`) в Identity (`POST /connect/token`).

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

=== "C#"
    ```csharp
    using System.Text.Json;

    var tokenEndpoint = "https://http-identity.umecdev.deviot.cloud/connect/token";
    var deviceCode = "<полученный_на_шаге_2_device_code>";
    var clientId = "controller";
    var pollInterval = 5;
    string? serviceDeviceAccessToken = null;

    using var http = new HttpClient();
    for (var i = 0; i < 120; i++)
    {
        var resp = await http.PostAsync(tokenEndpoint, new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["grant_type"] = "urn:ietf:params:oauth:grant-type:device_code",
            ["device_code"] = deviceCode,
            ["client_id"] = clientId
        }));
        var payload = JsonDocument.Parse(await resp.Content.ReadAsStringAsync()).RootElement;
        if (resp.IsSuccessStatusCode && payload.TryGetProperty("access_token", out var tokenEl))
        {
            serviceDeviceAccessToken = tokenEl.GetString();
            break;
        }
        var error = payload.TryGetProperty("error", out var errorEl) ? errorEl.GetString() : null;
        if (error == "authorization_pending") { await Task.Delay(pollInterval * 1000); continue; }
        if (error == "slow_down") { pollInterval += 5; await Task.Delay(pollInterval * 1000); continue; }
        throw new Exception(payload.ToString());
    }
    if (string.IsNullOrWhiteSpace(serviceDeviceAccessToken))
        throw new Exception("Не удалось получить device token за отведенное время");
    Console.WriteLine($"device token acquired: {!string.IsNullOrEmpty(serviceDeviceAccessToken)}");
    ```

=== "Node.js"
    ```javascript
    const tokenEndpoint = "https://http-identity.umecdev.deviot.cloud/connect/token";
    const deviceCode = "<полученный_на_шаге_2_device_code>";
    const clientId = "controller";
    let pollInterval = 5;
    let serviceDeviceAccessToken = null;

    for (let i = 0; i < 120; i += 1) {
      const tokenResp = await fetch(tokenEndpoint, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          grant_type: "urn:ietf:params:oauth:grant-type:device_code",
          device_code: deviceCode,
          client_id: clientId,
        }),
      });
      const payload = await tokenResp.json();
      if (tokenResp.ok && payload.access_token) {
        serviceDeviceAccessToken = payload.access_token;
        break;
      }
      if (payload.error === "authorization_pending") {
        await new Promise((r) => setTimeout(r, pollInterval * 1000));
        continue;
      }
      if (payload.error === "slow_down") {
        pollInterval += 5;
        await new Promise((r) => setTimeout(r, pollInterval * 1000));
        continue;
      }
      throw new Error(JSON.stringify(payload));
    }
    if (!serviceDeviceAccessToken) throw new Error("Не удалось получить device token за отведенное время");
    console.log("device token acquired:", Boolean(serviceDeviceAccessToken));
    ```

## Ожидаемый результат

- Привязка успешно выполнена, в ответе получены `items` с `unitId`.
- В результате проверки найдено хотя бы одно устройство с `unitId` из ответа привязки (`bind`).
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

=== "C#"
    ```csharp
    using System.Net.Http.Headers;
    using System.Net.Http.Json;
    using System.Text.Json;

    var baseUrl = "https://api.umecdev.deviot.cloud";
    var identityBase = "https://http-identity.umecdev.deviot.cloud";
    using var http = new HttpClient();

    var userName = Environment.GetEnvironmentVariable("UMEC_CUSTOMER_USER");
    var password = Environment.GetEnvironmentVariable("UMEC_CUSTOMER_PASSWORD");
    var signIn = await http.PostAsJsonAsync($"{baseUrl}/api/customer/v1/signin", new { userName, password });
    signIn.EnsureSuccessStatusCode();
    var signInPayload = await signIn.Content.ReadFromJsonAsync<JsonElement>();
    var customerAccessToken = signInPayload.GetProperty("accessToken").GetString();
    http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", customerAccessToken);

    var deviceAuth = await http.PostAsync($"{identityBase}/connect/deviceauthorization", new FormUrlEncodedContent(new Dictionary<string, string> { ["client_id"] = "controller" }));
    deviceAuth.EnsureSuccessStatusCode();
    var deviceData = await deviceAuth.Content.ReadFromJsonAsync<JsonElement>();
    var deviceCode = deviceData.GetProperty("device_code").GetString();
    var userCode = deviceData.GetProperty("user_code").GetString();
    var verificationUri = deviceData.GetProperty("verification_uri").GetString();
    var pollInterval = deviceData.TryGetProperty("interval", out var intervalEl) ? intervalEl.GetInt32() : 5;

    var bindResp = await http.PostAsJsonAsync($"{baseUrl}/api/customer/v1/units/bind", new
    {
        deviceSerial = Environment.GetEnvironmentVariable("UMEC_DEVICE_SERIAL"),
        userCode,
        verificationUrl = verificationUri,
        firmware = new
        {
            vendorCode = Environment.GetEnvironmentVariable("UMEC_VENDOR_CODE"),
            modelCode = Environment.GetEnvironmentVariable("UMEC_MODEL_CODE"),
            firmwareVersion = Environment.GetEnvironmentVariable("UMEC_FIRMWARE_VERSION"),
            hardwareVersion = Environment.GetEnvironmentVariable("UMEC_HARDWARE_VERSION")
        },
        deviceMacAddress = Environment.GetEnvironmentVariable("UMEC_DEVICE_MAC"),
        location = new { latitude = 55.7558, longitude = 37.6173 }
    });
    bindResp.EnsureSuccessStatusCode();
    var bindData = await bindResp.Content.ReadFromJsonAsync<JsonElement>();
    var boundUnitIds = bindData.GetProperty("items").EnumerateArray().Select(x => x.GetProperty("unitId").GetInt64()).ToArray();

    var unitsResp = await http.GetAsync($"{baseUrl}/api/customer/v1/units");
    unitsResp.EnsureSuccessStatusCode();
    var unitsData = await unitsResp.Content.ReadFromJsonAsync<JsonElement>();
    var actualUnitIds = unitsData.GetProperty("items").EnumerateArray().Select(x => x.GetProperty("unitId").GetInt64()).ToHashSet();
    if (!boundUnitIds.Any(id => actualUnitIds.Contains(id))) throw new Exception("Привязанное устройство не найдено в GET /api/customer/v1/units");

    string? serviceDeviceAccessToken = null;
    for (var i = 0; i < 120; i++)
    {
        var tokenResp = await http.PostAsync($"{identityBase}/connect/token", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["grant_type"] = "urn:ietf:params:oauth:grant-type:device_code",
            ["device_code"] = deviceCode!,
            ["client_id"] = "controller"
        }));
        var payload = JsonDocument.Parse(await tokenResp.Content.ReadAsStringAsync()).RootElement;
        if (tokenResp.IsSuccessStatusCode && payload.TryGetProperty("access_token", out var tokenEl))
        {
            serviceDeviceAccessToken = tokenEl.GetString();
            break;
        }
        var error = payload.TryGetProperty("error", out var errorEl) ? errorEl.GetString() : null;
        if (error == "authorization_pending") { await Task.Delay(pollInterval * 1000); continue; }
        if (error == "slow_down") { pollInterval += 5; await Task.Delay(pollInterval * 1000); continue; }
        throw new Exception(payload.ToString());
    }

    if (string.IsNullOrWhiteSpace(serviceDeviceAccessToken)) throw new Exception("Не удалось получить device token за отведенное время");
    Console.WriteLine($"device token acquired: {!string.IsNullOrEmpty(serviceDeviceAccessToken)}");
    ```

=== "Node.js"
    ```javascript
    const baseUrl = "https://api.umecdev.deviot.cloud";
    const identityBase = "https://http-identity.umecdev.deviot.cloud";

    const userName = process.env.UMEC_CUSTOMER_USER;
    const password = process.env.UMEC_CUSTOMER_PASSWORD;
    const signIn = await fetch(`${baseUrl}/api/customer/v1/signin`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userName, password }),
    });
    if (!signIn.ok) throw new Error(await signIn.text());
    const { accessToken: customerAccessToken } = await signIn.json();
    const customerHeaders = { Authorization: `Bearer ${customerAccessToken}`, "Content-Type": "application/json" };

    const deviceAuth = await fetch(`${identityBase}/connect/deviceauthorization`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ client_id: "controller" }),
    });
    if (!deviceAuth.ok) throw new Error(await deviceAuth.text());
    const deviceData = await deviceAuth.json();
    const deviceCode = deviceData.device_code;
    const userCode = deviceData.user_code;
    const verificationUri = deviceData.verification_uri;
    let pollInterval = Number(deviceData.interval || 5);

    const bindResp = await fetch(`${baseUrl}/api/customer/v1/units/bind`, {
      method: "POST",
      headers: customerHeaders,
      body: JSON.stringify({
        deviceSerial: process.env.UMEC_DEVICE_SERIAL,
        userCode,
        verificationUrl: verificationUri,
        firmware: {
          vendorCode: process.env.UMEC_VENDOR_CODE,
          modelCode: process.env.UMEC_MODEL_CODE,
          firmwareVersion: process.env.UMEC_FIRMWARE_VERSION,
          hardwareVersion: process.env.UMEC_HARDWARE_VERSION,
        },
        deviceMacAddress: process.env.UMEC_DEVICE_MAC,
        location: { latitude: 55.7558, longitude: 37.6173 },
      }),
    });
    if (!bindResp.ok) throw new Error(await bindResp.text());
    const bindData = await bindResp.json();
    const boundUnitIds = (bindData.items ?? []).map((x) => x.unitId).filter(Boolean);

    const unitsResp = await fetch(`${baseUrl}/api/customer/v1/units`, { headers: { Authorization: `Bearer ${customerAccessToken}` } });
    if (!unitsResp.ok) throw new Error(await unitsResp.text());
    const unitsData = await unitsResp.json();
    const actualUnitIds = new Set((unitsData.items ?? []).map((x) => x.unitId).filter(Boolean));
    if (!boundUnitIds.some((id) => actualUnitIds.has(id))) throw new Error("Привязанное устройство не найдено в GET /api/customer/v1/units");

    let serviceDeviceAccessToken = null;
    for (let i = 0; i < 120; i += 1) {
      const tokenResp = await fetch(`${identityBase}/connect/token`, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          grant_type: "urn:ietf:params:oauth:grant-type:device_code",
          device_code: deviceCode,
          client_id: "controller",
        }),
      });
      const payload = await tokenResp.json();
      if (tokenResp.ok && payload.access_token) {
        serviceDeviceAccessToken = payload.access_token;
        break;
      }
      if (payload.error === "authorization_pending") { await new Promise((r) => setTimeout(r, pollInterval * 1000)); continue; }
      if (payload.error === "slow_down") { pollInterval += 5; await new Promise((r) => setTimeout(r, pollInterval * 1000)); continue; }
      throw new Error(JSON.stringify(payload));
    }

    if (!serviceDeviceAccessToken) throw new Error("Не удалось получить device token за отведенное время");
    console.log("device token acquired:", Boolean(serviceDeviceAccessToken));
    ```
