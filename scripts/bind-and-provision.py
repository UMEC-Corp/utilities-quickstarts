#!/usr/bin/env python3
"""Скрипт к сценарию docs/quickstarts/bind-and-provision.md — вход, привязка устройства, опционально refresh."""

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
    p = argparse.ArgumentParser(description="Вход, привязка устройства (units/bind), опционально refresh.")
    p.add_argument("--base", default=os.environ.get("UMEC_BASE", "https://api.rumecdev.deviot.cloud"))
    p.add_argument("--user", default=os.environ.get("UMEC_CUSTOMER_USER"))
    p.add_argument("--password", default=os.environ.get("UMEC_CUSTOMER_PASSWORD"))
    p.add_argument("--device-serial", default=os.environ.get("UMEC_DEVICE_SERIAL", "SN-ACME-00042"))
    p.add_argument("--user-code", default=os.environ.get("UMEC_DEVICE_USER_CODE"), required=True)
    p.add_argument("--vendor-code", default=os.environ.get("UMEC_VENDOR_CODE", "ACME_LABS"))
    p.add_argument("--model-code", default=os.environ.get("UMEC_MODEL_CODE", "ACME_TEMP_V1"))
    p.add_argument("--firmware-version", default="1.0.0")
    p.add_argument("--hardware-version", default="1.0")
    p.add_argument("--lat", type=float, default=55.7558)
    p.add_argument("--lon", type=float, default=37.6173)
    p.add_argument("--refresh", action="store_true", help="После bind вызвать POST /refresh и показать новый accessToken")
    args = p.parse_args()
    if not args.user or not args.password:
        p.error("Задайте --user и --password или UMEC_CUSTOMER_USER / UMEC_CUSTOMER_PASSWORD.")

    base = args.base.rstrip("/")
    # Шаг 1 — вход: POST /signin.
    r = requests.post(
        f"{base}/api/customer/v1/signin",
        json={"userName": args.user, "password": args.password},
        headers={"Content-Type": "application/json"},
        timeout=30,
    )
    r.raise_for_status()
    auth = r.json()
    access = auth["accessToken"]
    refresh = auth["refreshToken"]
    print("signin: OK")

    headers = {"Authorization": f"Bearer {access}", "Content-Type": "application/json"}
    # Шаг 2 — привязка: POST /units/bind.
    bind = requests.post(
        f"{base}/api/customer/v1/units/bind",
        json={
            "deviceSerial": args.device_serial,
            "userCode": args.user_code,
            "firmware": {
                "vendorCode": args.vendor_code,
                "modelCode": args.model_code,
                "firmwareVersion": args.firmware_version,
                "hardwareVersion": args.hardware_version,
            },
            "location": {"latitude": args.lat, "longitude": args.lon},
        },
        headers=headers,
        timeout=60,
    )
    bind.raise_for_status()
    data = bind.json()
    items = data.get("items") or []
    if not items:
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return 1
    unit_id = items[0]["unitId"]
    print("bind: OK")
    print("unitId:", unit_id)
    print("accessToken:", access[:24] + "…")
    print("refreshToken:", refresh[:24] + "…")

    # Шаг 3 — обновить access-токен (опционально): POST /refresh.
    if args.refresh:
        rr = requests.post(
            f"{base}/api/customer/v1/refresh",
            json={"refreshToken": refresh},
            headers={"Content-Type": "application/json"},
            timeout=30,
        )
        rr.raise_for_status()
        access2 = rr.json()["accessToken"]
        print("refresh: OK, accessToken:", access2[:24] + "…")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
