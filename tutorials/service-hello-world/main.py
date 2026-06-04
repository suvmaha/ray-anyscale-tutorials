from fastapi import FastAPI
from ray import serve

app = FastAPI()

@serve.deployment
@serve.ingress(app)
class HelloService:
    @app.get("/hello")
    def say_hello(self, name: str) -> str:
        return f"Hello {name}!"

    @app.get("/health")
    def health(self) -> dict:
        return {"status": "ok"}

app_deploy = HelloService.bind()
