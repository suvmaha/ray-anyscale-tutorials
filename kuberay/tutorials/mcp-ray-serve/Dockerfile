FROM rayproject/ray:2.44.0

WORKDIR /app
COPY weather_mcp_ray.py .

RUN pip install --no-cache-dir \
    "mcp[cli]>=1.2.0" \
    "httpx>=0.24.0" \
    "pydantic>=2.0.0" \
    "fastapi>=0.115.0"

# /app is on PYTHONPATH so RayService import_path resolves weather_mcp_ray:app
ENV PYTHONPATH=/app
