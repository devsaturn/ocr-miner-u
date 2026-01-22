import os
import base64
import logging
import runpod
import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Union

# Imports MinerU
from magic_pdf.pipe.UNIPipe import UNIPipe
from magic_pdf.rw.DiskReaderWriter import DiskReaderWriter

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# --- LOGIQUE MINERU ---
def process_mineru(file_bytes: bytes):
    # Similaire à la logique précédente, 
    # utilise UNIPipe pour transformer le PDF en Markdown
    import tempfile
    with tempfile.TemporaryDirectory() as temp_dir:
        output_dir = os.path.join(temp_dir, "output")
        os.makedirs(output_dir, exist_ok=True)
        image_writer = DiskReaderWriter(output_dir)
        pipe = UNIPipe(file_bytes, {"_pdf_type": ""}, image_writer)
        pipe.pipe_classify()
        pipe.pipe_analyze()
        pipe.pipe_parse()
        return pipe.pipe_mk_markdown(img_parent_path=output_dir, drop_mode="none")

# --- PARTIE FASTAPI (Cloud Run / OpenAI) ---
app = FastAPI()

class ChatCompletionRequest(BaseModel):
    messages: List[dict]
    model: str = "mineru"

@app.post("/v1/chat/completions")
async def chat_openai(request: ChatCompletionRequest):
    try:
        # On cherche le base64 dans le dernier message
        last_msg = request.messages[-1].get("content")
        b64_data = None
        if isinstance(last_msg, list):
            for item in last_msg:
                if item.get("type") == "image_url":
                    url = item["image_url"]["url"]
                    b64_data = url.split("base64,")[-1]
        
        if not b64_data: raise HTTPException(400, "No base64 found")
        
        markdown = process_mineru(base64.b64decode(b64_data))
        return {
            "choices": [{"message": {"role": "assistant", "content": str(markdown)}}]
        }
    except Exception as e:
        raise HTTPException(500, str(e))

# --- PARTIE RUNPOD (Serverless) ---
def runpod_handler(job):
    try:
        inputs = job["input"]
        # Supporte soit pdf_base64 soit le format OpenAI
        b64 = inputs.get("pdf_base64") or inputs.get("image_base64")
        result = process_mineru(base64.b64decode(b64))
        return {"status": "success", "markdown": result}
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    # Cette partie n'est appelée que par start_server.sh sur RunPod
    runpod.serverless.start({"handler": runpod_handler})