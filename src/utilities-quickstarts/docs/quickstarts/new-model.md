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

=== "C#"
    ```csharp
    using System.Net.Http.Json;

    var baseUrl = "https://api.umecdev.deviot.cloud";
    var vendorCode = "demo_vendor_001";
    var vendorName = "Demo Vendor";
    var vendorSecret = "change_me_secret";

    using var http = new HttpClient();
    var resp = await http.PostAsJsonAsync($"{baseUrl}/api/vendor/v1/vendors", new
    {
        code = vendorCode,
        name = vendorName,
        secret = vendorSecret
    });
    Console.WriteLine((int)resp.StatusCode);
    Console.WriteLine(await resp.Content.ReadAsStringAsync());
    resp.EnsureSuccessStatusCode();
    ```

=== "Node.js"
    ```javascript
    const baseUrl = "https://api.umecdev.deviot.cloud";
    const vendorCode = "demo_vendor_001";
    const vendorName = "Demo Vendor";
    const vendorSecret = "change_me_secret";

    const resp = await fetch(`${baseUrl}/api/vendor/v1/vendors`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code: vendorCode, name: vendorName, secret: vendorSecret }),
    });
    console.log(resp.status);
    console.log(await resp.text());
    if (!resp.ok) throw new Error("Vendor registration failed");
    ```

### 2. Получите токен доступа (`access token`) через Identity (`POST /connect/token`).

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

=== "C#"
    ```csharp
    using System.Net.Http.Json;
    using System.Text.Json;

    var tokenEndpoint = "https://http-identity.umecdev.deviot.cloud/connect/token";
    var form = new Dictionary<string, string>
    {
        ["grant_type"] = "client_credentials",
        ["client_id"] = "demo_vendor_001",
        ["client_secret"] = "change_me_secret"
    };

    using var http = new HttpClient();
    var tokenResp = await http.PostAsync(tokenEndpoint, new FormUrlEncodedContent(form));
    tokenResp.EnsureSuccessStatusCode();
    var tokenPayload = await tokenResp.Content.ReadFromJsonAsync<JsonElement>();
    var accessToken = tokenPayload.GetProperty("access_token").GetString();
    Console.WriteLine($"token acquired: {!string.IsNullOrEmpty(accessToken)}");
    ```

=== "Node.js"
    ```javascript
    const tokenEndpoint = "https://http-identity.umecdev.deviot.cloud/connect/token";
    const form = new URLSearchParams({
      grant_type: "client_credentials",
      client_id: "demo_vendor_001",
      client_secret: "change_me_secret",
    });

    const tokenResp = await fetch(tokenEndpoint, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form.toString(),
    });
    if (!tokenResp.ok) throw new Error(await tokenResp.text());
    const token = await tokenResp.json();
    const accessToken = token.access_token;
    console.log("token acquired:", Boolean(accessToken));
    ```

### 3. Добавьте сенсор температуры (`POST /api/vendor/v1/sensors`).

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

=== "C#"
    ```csharp
    var baseUrl = "https://api.umecdev.deviot.cloud";
    var accessToken = "<access_token_from_step_2>";
    using var http = new HttpClient();
    http.DefaultRequestHeaders.Authorization =
        new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", accessToken);

    var resp = await http.PostAsJsonAsync($"{baseUrl}/api/vendor/v1/sensors", new
    {
        items = new[] { new { code = "temp_c", name = "Temperature", unitOfMeasure = "C" } }
    });
    Console.WriteLine((int)resp.StatusCode);
    Console.WriteLine(await resp.Content.ReadAsStringAsync());
    resp.EnsureSuccessStatusCode();
    ```

=== "Node.js"
    ```javascript
    const baseUrl = "https://api.umecdev.deviot.cloud";
    const accessToken = "<access_token_from_step_2>";

    const resp = await fetch(`${baseUrl}/api/vendor/v1/sensors`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        items: [{ code: "temp_c", name: "Temperature", unitOfMeasure: "C" }],
      }),
    });
    console.log(resp.status);
    console.log(await resp.text());
    if (!resp.ok) throw new Error("Create sensor failed");
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

=== "C#"
    ```csharp
    var baseUrl = "https://api.umecdev.deviot.cloud";
    var accessToken = "<access_token_from_step_2>";
    using var http = new HttpClient();
    http.DefaultRequestHeaders.Authorization =
        new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", accessToken);

    var payload = new
    {
        model = new
        {
            modelCode = "demo-temp-model-v1",
            name = "Demo Temperature Device",
            firmwareVersion = "1.0.0",
            hardwareVersion = "1.0",
            units = new
            {
                main = new
                {
                    name = "Main unit",
                    sensors = new { temperature = new { connectedSensorCode = "temp_c", name = "Temperature sensor" } }
                }
            }
        }
    };
    var resp = await http.PutAsJsonAsync($"{baseUrl}/api/vendor/v1/models", payload);
    Console.WriteLine((int)resp.StatusCode);
    Console.WriteLine(await resp.Content.ReadAsStringAsync());
    resp.EnsureSuccessStatusCode();
    ```

=== "Node.js"
    ```javascript
    const baseUrl = "https://api.umecdev.deviot.cloud";
    const accessToken = "<access_token_from_step_2>";

    const payload = {
      model: {
        modelCode: "demo-temp-model-v1",
        name: "Demo Temperature Device",
        firmwareVersion: "1.0.0",
        hardwareVersion: "1.0",
        units: {
          main: {
            name: "Main unit",
            sensors: { temperature: { connectedSensorCode: "temp_c", name: "Temperature sensor" } },
          },
        },
      },
    };
    const resp = await fetch(`${baseUrl}/api/vendor/v1/models`, {
      method: "PUT",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${accessToken}` },
      body: JSON.stringify(payload),
    });
    console.log(resp.status);
    console.log(await resp.text());
    if (!resp.ok) throw new Error("Upsert model failed");
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

=== "C#"
    ```csharp
    var baseUrl = "https://api.umecdev.deviot.cloud";
    var accessToken = "<access_token_from_step_2>";
    var modelCode = "demo-temp-model-v1";
    using var http = new HttpClient();
    http.DefaultRequestHeaders.Authorization =
        new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", accessToken);

    var resp = await http.GetAsync($"{baseUrl}/api/vendor/v1/models/{modelCode}");
    Console.WriteLine((int)resp.StatusCode);
    Console.WriteLine(await resp.Content.ReadAsStringAsync());
    resp.EnsureSuccessStatusCode();
    ```

=== "Node.js"
    ```javascript
    const baseUrl = "https://api.umecdev.deviot.cloud";
    const accessToken = "<access_token_from_step_2>";
    const modelCode = "demo-temp-model-v1";

    const resp = await fetch(`${baseUrl}/api/vendor/v1/models/${modelCode}`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    console.log(resp.status);
    console.log(await resp.text());
    if (!resp.ok) throw new Error("Get model failed");
    ```

## Ожидаемый результат

- Вендор зарегистрирован.
- Сенсор `temp_c` добавлен в каталог сенсоров вендора.
- Модель `demo-temp-model-v1` создана/обновлена и содержит юнит `main` с температурным сенсором.

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

=== "C#"
    ```csharp
    using System.Net.Http.Headers;
    using System.Net.Http.Json;
    using System.Text.Json;

    var baseUrl = "https://api.umecdev.deviot.cloud";
    var tokenEndpoint = "https://http-identity.umecdev.deviot.cloud/connect/token";
    var vendorCode = "demo_vendor_001";
    var vendorName = "Demo Vendor";
    var vendorSecret = "change_me_secret";

    using var http = new HttpClient();

    await http.PostAsJsonAsync($"{baseUrl}/api/vendor/v1/vendors", new { code = vendorCode, name = vendorName, secret = vendorSecret });
    var tokenResp = await http.PostAsync(tokenEndpoint, new FormUrlEncodedContent(new Dictionary<string, string>
    {
        ["grant_type"] = "client_credentials",
        ["client_id"] = vendorCode,
        ["client_secret"] = vendorSecret
    }));
    tokenResp.EnsureSuccessStatusCode();
    var tokenPayload = await tokenResp.Content.ReadFromJsonAsync<JsonElement>();
    var accessToken = tokenPayload.GetProperty("access_token").GetString();
    http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

    await http.PostAsJsonAsync($"{baseUrl}/api/vendor/v1/sensors", new
    {
        items = new[] { new { code = "temp_c", name = "Temperature", unitOfMeasure = "C" } }
    });

    await http.PutAsJsonAsync($"{baseUrl}/api/vendor/v1/models", new
    {
        model = new
        {
            modelCode = "demo-temp-model-v1",
            name = "Demo Temperature Device",
            firmwareVersion = "1.0.0",
            hardwareVersion = "1.0",
            units = new { main = new { name = "Main unit", sensors = new { temperature = new { connectedSensorCode = "temp_c", name = "Temperature sensor" } } } }
        }
    });

    var check = await http.GetAsync($"{baseUrl}/api/vendor/v1/models/demo-temp-model-v1");
    check.EnsureSuccessStatusCode();
    Console.WriteLine(await check.Content.ReadAsStringAsync());
    ```

=== "Node.js"
    ```javascript
    const baseUrl = "https://api.umecdev.deviot.cloud";
    const tokenEndpoint = "https://http-identity.umecdev.deviot.cloud/connect/token";
    const vendorCode = "demo_vendor_001";
    const vendorName = "Demo Vendor";
    const vendorSecret = "change_me_secret";

    await fetch(`${baseUrl}/api/vendor/v1/vendors`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code: vendorCode, name: vendorName, secret: vendorSecret }),
    });

    const tokenResp = await fetch(tokenEndpoint, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "client_credentials",
        client_id: vendorCode,
        client_secret: vendorSecret,
      }),
    });
    if (!tokenResp.ok) throw new Error(await tokenResp.text());
    const { access_token: accessToken } = await tokenResp.json();
    const authHeaders = { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" };

    await fetch(`${baseUrl}/api/vendor/v1/sensors`, {
      method: "POST",
      headers: authHeaders,
      body: JSON.stringify({ items: [{ code: "temp_c", name: "Temperature", unitOfMeasure: "C" }] }),
    });

    await fetch(`${baseUrl}/api/vendor/v1/models`, {
      method: "PUT",
      headers: authHeaders,
      body: JSON.stringify({
        model: {
          modelCode: "demo-temp-model-v1",
          name: "Demo Temperature Device",
          firmwareVersion: "1.0.0",
          hardwareVersion: "1.0",
          units: { main: { name: "Main unit", sensors: { temperature: { connectedSensorCode: "temp_c", name: "Temperature sensor" } } } },
        },
      }),
    });

    const check = await fetch(`${baseUrl}/api/vendor/v1/models/demo-temp-model-v1`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!check.ok) throw new Error(await check.text());
    console.log(await check.json());
    ```
