#!/usr/bin/env python3
"""Скрипт к сценарию docs/quickstarts/subscribe-events.md — WebSocket JSON-RPC: connect-customer, subscribe-units, ожидание unit-event."""

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
