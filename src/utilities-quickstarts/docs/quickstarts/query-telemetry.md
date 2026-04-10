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

=== "C#"
    ```csharp
    using System.Net.Http.Json;

    var baseUrl = "https://api.umecdev.deviot.cloud";
    using var http = new HttpClient();

    var signInResponse = await http.PostAsJsonAsync(
        $"{baseUrl}/api/customer/v1/signin",
        new { userName = "customer_demo", password = "change_me_password" }
    );
    signInResponse.EnsureSuccessStatusCode();
    var signInPayload = await signInResponse.Content.ReadFromJsonAsync<JsonElement>();
    var accessToken = signInPayload.GetProperty("accessToken").GetString();

    http.DefaultRequestHeaders.Authorization =
        new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", accessToken);
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
    const headers = { Authorization: `Bearer ${accessToken}` };
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

=== "C#"
    ```csharp
    var unitsResponse = await http.GetAsync($"{baseUrl}/api/customer/v1/units");
    unitsResponse.EnsureSuccessStatusCode();
    var unitsPayload = await unitsResponse.Content.ReadFromJsonAsync<JsonElement>();
    var items = unitsPayload.GetProperty("items");
    if (items.GetArrayLength() == 0) throw new Exception("У пользователя нет устройств");
    var unitId = items[0].GetProperty("unitId").GetInt64();
    ```

=== "Node.js"
    ```javascript
    const unitsResp = await fetch(`${baseUrl}/api/customer/v1/units`, { headers });
    if (!unitsResp.ok) throw new Error(await unitsResp.text());
    const unitsData = await unitsResp.json();
    if (!unitsData.items?.length) throw new Error("У пользователя нет устройств");
    const unitId = unitsData.items[0].unitId;
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

=== "C#"
    ```csharp
    var unitDetailsResponse = await http.GetAsync($"{baseUrl}/api/customer/v1/units/{unitId}");
    unitDetailsResponse.EnsureSuccessStatusCode();
    var unitDetails = await unitDetailsResponse.Content.ReadFromJsonAsync<JsonElement>();
    var inputs = unitDetails.GetProperty("item").GetProperty("inputs");
    if (inputs.GetArrayLength() == 0) throw new Exception("У устройства отсутствуют входы");
    var inputIds = new[] { inputs[0].GetProperty("id").GetString()! };
    ```

=== "Node.js"
    ```javascript
    const unitDetailsResp = await fetch(`${baseUrl}/api/customer/v1/units/${unitId}`, { headers });
    if (!unitDetailsResp.ok) throw new Error(await unitDetailsResp.text());
    const unitDetails = await unitDetailsResp.json();
    const inputs = unitDetails.item?.inputs ?? [];
    if (!inputs.length) throw new Error("У устройства отсутствуют входы");
    const inputIds = [inputs[0].id];
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

=== "C#"
    ```csharp
    var query = $"inputIds={Uri.EscapeDataString(inputIds[0])}&begin=1710000000000&end=1710086400000&timeFrame=60&difference=false";
    var ticksResponse = await http.GetAsync($"{baseUrl}/api/customer/v1/units/{unitId}/ticks?{query}");
    ticksResponse.EnsureSuccessStatusCode();
    Console.WriteLine(await ticksResponse.Content.ReadAsStringAsync());
    ```

=== "Node.js"
    ```javascript
    const params = new URLSearchParams({
      inputIds: inputIds[0],
      begin: "1710000000000",
      end: "1710086400000",
      timeFrame: "60",
      difference: "false",
    });
    const ticks = await fetch(`${baseUrl}/api/customer/v1/units/${unitId}/ticks?${params}`, { headers });
    if (!ticks.ok) throw new Error(await ticks.text());
    console.log(await ticks.json());
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

=== "C#"
    ```csharp
    using System.Net.Http.Headers;
    using System.Net.Http.Json;
    using System.Text.Json;

    var baseUrl = "https://api.umecdev.deviot.cloud";
    using var http = new HttpClient();

    // Шаг 1: авторизация customer
    var signInResponse = await http.PostAsJsonAsync(
        $"{baseUrl}/api/customer/v1/signin",
        new { userName = "customer_demo", password = "change_me_password" }
    );
    signInResponse.EnsureSuccessStatusCode();
    var signInPayload = await signInResponse.Content.ReadFromJsonAsync<JsonElement>();
    var accessToken = signInPayload.GetProperty("accessToken").GetString();
    http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

    // Шаг 2: получение unitId
    var unitsResponse = await http.GetAsync($"{baseUrl}/api/customer/v1/units");
    unitsResponse.EnsureSuccessStatusCode();
    var unitsPayload = await unitsResponse.Content.ReadFromJsonAsync<JsonElement>();
    var items = unitsPayload.GetProperty("items");
    if (items.GetArrayLength() == 0) throw new Exception("У пользователя нет устройств");
    var unitId = items[0].GetProperty("unitId").GetInt64();

    // Шаг 3: получение inputIds
    var unitDetailsResponse = await http.GetAsync($"{baseUrl}/api/customer/v1/units/{unitId}");
    unitDetailsResponse.EnsureSuccessStatusCode();
    var unitDetails = await unitDetailsResponse.Content.ReadFromJsonAsync<JsonElement>();
    var inputs = unitDetails.GetProperty("item").GetProperty("inputs");
    if (inputs.GetArrayLength() == 0) throw new Exception("У устройства отсутствуют входы");
    var inputId = inputs[0].GetProperty("id").GetString();

    // Шаг 4: запрос телеметрии
    var query = $"inputIds={Uri.EscapeDataString(inputId!)}&begin=1710000000000&end=1710086400000&timeFrame=60&difference=false";
    var ticksResponse = await http.GetAsync($"{baseUrl}/api/customer/v1/units/{unitId}/ticks?{query}");
    ticksResponse.EnsureSuccessStatusCode();
    Console.WriteLine(await ticksResponse.Content.ReadAsStringAsync());
    ```

=== "Node.js"
    ```javascript
    const baseUrl = "https://api.umecdev.deviot.cloud";

    // Шаг 1: авторизация customer
    const signIn = await fetch(`${baseUrl}/api/customer/v1/signin`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userName: "customer_demo", password: "change_me_password" }),
    });
    if (!signIn.ok) throw new Error(await signIn.text());
    const { accessToken } = await signIn.json();
    const headers = { Authorization: `Bearer ${accessToken}` };

    // Шаг 2: получение unitId
    const unitsResp = await fetch(`${baseUrl}/api/customer/v1/units`, { headers });
    if (!unitsResp.ok) throw new Error(await unitsResp.text());
    const unitsData = await unitsResp.json();
    if (!unitsData.items?.length) throw new Error("У пользователя нет устройств");
    const unitId = unitsData.items[0].unitId;

    // Шаг 3: получение inputIds
    const unitDetailsResp = await fetch(`${baseUrl}/api/customer/v1/units/${unitId}`, { headers });
    if (!unitDetailsResp.ok) throw new Error(await unitDetailsResp.text());
    const unitDetails = await unitDetailsResp.json();
    const inputs = unitDetails.item?.inputs ?? [];
    if (!inputs.length) throw new Error("У устройства отсутствуют входы");
    const inputId = inputs[0].id;

    // Шаг 4: запрос телеметрии
    const params = new URLSearchParams({
      inputIds: String(inputId),
      begin: "1710000000000",
      end: "1710086400000",
      timeFrame: "60",
      difference: "false",
    });
    const ticks = await fetch(`${baseUrl}/api/customer/v1/units/${unitId}/ticks?${params}`, { headers });
    if (!ticks.ok) throw new Error(await ticks.text());
    console.log(await ticks.json());
    ```
