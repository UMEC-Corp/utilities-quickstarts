#!/usr/bin/env python3
"""Скрипт к сценарию docs/quickstarts/query-telemetry.md — карточка юнита и тики по входу."""

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
