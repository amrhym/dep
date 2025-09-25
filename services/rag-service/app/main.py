from fastapi import FastAPI, Request
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import hmac
import hashlib
import json

app = FastAPI()

class Message(BaseModel):
    role: str
    content: Any
    agent_name: Optional[str] = None

class GenerateRequest(BaseModel):
    messages: List[Message]
    retrieval: Optional[Dict[str, Any]] = None
    assistant_config: Optional[Dict[str, Any]] = None
    tools: Optional[List[Dict[str, Any]]] = None
    streaming: Optional[bool] = False

@app.post("/v1/generate")
async def generate(req: GenerateRequest, request: Request):
    # Optional HMAC verification
    hmac_key = None  # set via env + middleware in future
    if hmac_key:
        ts = request.headers.get("X-RAG-Timestamp", "")
        sig = request.headers.get("X-RAG-Signature", "")
        mac = hmac.new(hmac_key.encode(), (ts + json.dumps(req.model_dump())).encode(), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(mac, sig):
            return {"error": "unauthorized"}

    # Minimal stub that echoes the last user message content
    last_user = next((m for m in reversed(req.messages) if m.role == 'user'), None)
    output = (last_user.content if last_user else "Hello from rag-service")
    return {
        "answer": output,
        "citations": [],
        "usage": {"input_tokens": 0, "output_tokens": 0},
        "stop": True
    }

class IndexRequest(BaseModel):
    text: Optional[str] = None
    source: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None

@app.post("/v1/index")
async def index(req: IndexRequest, request: Request):
    # Stub: pretend we indexed and return a fake id and chunk count
    doc_id = "stub-doc-1"
    chunks = 1 if (req.text and len(req.text) > 0) else 0
    return {"document_id": doc_id, "chunks": chunks, "status": "indexed"}

class SearchRequest(BaseModel):
    query: str
    top_k: Optional[int] = 5
    filters: Optional[Dict[str, Any]] = None

@app.post("/v1/search")
async def search(req: SearchRequest, request: Request):
    # Stub: return the query as a single hit
    hit = {"chunk_id": "stub-chunk-1", "text": f"echo: {req.query}", "score": 0.99, "metadata": {}}
    return {"hits": [hit]}
