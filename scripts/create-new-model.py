#!/usr/bin/env python3
"""Скрипт к сценарию docs/quickstarts/create-new-model.md — вендор (опционально), создание типа сенсора и модели."""

from __future__ import annotations

import argparse
import os
import sys

try:
    import requests
except ImportError:
    print("Установите requests: pip install requests", file=sys.stderr)
    sys.exit(1)


def main() -> int:
    p = argparse.ArgumentParser(
        description="Создание новой модели: вендор (опционально), тип сенсора в каталоге, публикация модели.",
    )
    p.add_argument(
        "--base",
        default=os.environ.get("UMEC_BASE", "https://api.rumecdev.deviot.cloud"),
        help="Базовый URL API",
    )
    p.add_argument("--vendor-code", default=os.environ.get("UMEC_VENDOR_CODE", "ACME_LABS"))
    p.add_argument("--vendor-name", default=os.environ.get("UMEC_VENDOR_NAME", "ACME Labs"))
    p.add_argument(
        "--secret",
        default=os.environ.get("UMEC_VENDOR_SECRET"),
        required=False,
        help="Секрет вендора (Bearer). Обязателен, если не используется --create-vendor.",
    )
    p.add_argument(
        "--create-vendor",
        action="store_true",
        help="POST /vendors (секрет задаётся через --secret)",
    )
    p.add_argument("--model-code", default="ACME_TEMP_V1")
    p.add_argument("--firmware-version", default="1.0.0")
    p.add_argument("--hardware-version", default="1.0")
    args = p.parse_args()

    secret = args.secret
    # Шаг 1 — создать вендора (опционально): POST /vendors.
    if args.create_vendor:
        if not secret:
            p.error("Для --create-vendor укажите --secret (будет сохранён у вендора).")
        r = requests.post(
            f"{args.base}/api/vendor/v1/vendors",
            json={"code": args.vendor_code, "name": args.vendor_name, "secret": secret},
            headers={"Content-Type": "application/json"},
            timeout=30,
        )
        r.raise_for_status()
        print("Вендор создан:", args.vendor_code)
    elif not secret:
        p.error("Укажите --secret или используйте --create-vendor.")

    # Шаг 2 — токен из Identity здесь не запрашивается; в Bearer подставляется --secret.
    headers = {"Authorization": f"Bearer {secret}", "Content-Type": "application/json"}

    # Шаг 3 — каталог сенсоров (POST /sensors) и модель (PUT /models).
    requests.post(
        f"{args.base}/api/vendor/v1/sensors",
        json={"items": [{"code": "TEMP_C", "name": "Temperature", "unitOfMeasure": "°C"}]},
        headers=headers,
        timeout=30,
    ).raise_for_status()
    print("Каталог сенсоров: TEMP_C")

    requests.put(
        f"{args.base}/api/vendor/v1/models",
        json={
            "model": {
                "modelCode": args.model_code,
                "name": "ACME Temperature Node",
                "firmwareVersion": args.firmware_version,
                "hardwareVersion": args.hardware_version,
                "units": {
                    "main": {
                        "name": "Main",
                        "sensors": {
                            "temperature": {
                                "connectedSensorCode": "TEMP_C",
                                "name": "Ambient temperature",
                                "valueType": "SENSOR_VALUE_TYPE_CONSUMPTION",
                                "isPersistent": True,
                            }
                        },
                    }
                },
            }
        },
        headers=headers,
        timeout=60,
    ).raise_for_status()
    print("Модель опубликована:", args.model_code)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
