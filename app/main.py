from fastapi import FastAPI

app = FastAPI()


@app.get("/")
async def root():
    return {"message": "Hello World"}


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.get("/test")
async def test():
    return {"message": "This is a test endpoint"}
