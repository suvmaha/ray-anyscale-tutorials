"""
Locust load test — launches a web UI to visually drive load against the deployment.

Usage (local):
  locust -f locustfile.py --host http://localhost:8000

Usage (AWS):
  locust -f locustfile.py --host http://<lb-hostname>

Then open http://localhost:8089 in your browser and start the swarm.
Watch replicas scale: kubectl get pods -l ray.io/cluster -w
"""
import random
from locust import HttpUser, between, task

LOCATIONS = [
    ("CA", 37.7749, -122.4194),  # San Francisco
    ("NY", 40.7128, -74.0060),   # New York
    ("TX", 29.7604, -95.3698),   # Houston
    ("FL", 25.7617, -80.1918),   # Miami
    ("WA", 47.6062, -122.3321),  # Seattle
]


class WeatherMCPUser(HttpUser):
    wait_time = between(0.1, 1.0)

    @task(3)
    def health_check(self):
        self.client.get("/health")

    @task(5)
    def get_forecast(self):
        _, lat, lon = random.choice(LOCATIONS)
        payload = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "get_forecast",
                "arguments": {"latitude": lat, "longitude": lon},
            },
        }
        self.client.post("/mcp", json=payload, name="/mcp [get_forecast]")

    @task(2)
    def get_alerts(self):
        state, _, _ = random.choice(LOCATIONS)
        payload = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "get_alerts",
                "arguments": {"state": state},
            },
        }
        self.client.post("/mcp", json=payload, name="/mcp [get_alerts]")
