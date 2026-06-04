#!/usr/bin/env python3
"""Query the running service-hello-world endpoint.

Usage:
    python query.py --token <SERVICE_TOKEN> --url <BASE_URL>

The deploy output prints a line like:
    curl -H "Authorization: Bearer <TOKEN>" <BASE_URL>
"""
import argparse
from urllib.parse import urljoin
import requests

parser = argparse.ArgumentParser()
parser.add_argument("--token", required=True, help="Service bearer token")
parser.add_argument("--url", required=True, help="Service base URL")
parser.add_argument("--name", default="World", help="Name to greet")
args = parser.parse_args()

headers = {"Authorization": f"Bearer {args.token}"}

# Health check
resp = requests.get(urljoin(args.url, "health"), headers=headers)
print(f"Health: {resp.json()}")

# Hello endpoint
resp = requests.get(
    urljoin(args.url, "hello"),
    params={"name": args.name},
    headers=headers,
)
print(f"Response: {resp.text}")
