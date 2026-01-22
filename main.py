import os
import base64
import logging
import runpod
import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Union

# Imports spécifiques pour magic-pdf==0.7.1
from magic_pdf.pipe.UNIPipe import UNIPipe
from magic_pdf.rw.DiskReaderWriter import DiskReaderWriter

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# --- LOGIQUE MINERU ---
def process_mineru(file_bytes: bytes):
    """
    Traite le fichier binaire via MinerU et retourne une string Markdown propre.
    """
    import tempfile
    
    # Création d'un dossier temporaire pour les sorties intermédiaires
    with tempfile.TemporaryDirectory() as temp_dir:
        output_dir = os.path.join(temp_dir, "output")
        os.makedirs(output_dir, exist_ok=True)
        
        # Initialisation du writer
        image_writer = DiskReaderWriter(output_dir)
        
        # Initialisation du Pipeline
        # Note: _pdf_type="" laisse MinerU deviner (utile pour 0.7.1)
        pipe = UNIPipe(file_bytes, {"_pdf_type": ""}, image_writer)
        
        # Étapes du pipeline OCR
        pipe.pipe_classify()
        pipe.pipe_analyze()
        pipe.pipe_parse()
        
        # Génération du Markdown
        # result est généralement une liste de dictionnaires (un par page)
        result = pipe.pipe_mk_markdown(img_parent_path=output_dir, drop_mode="none")
        
        # --- CORRECTION CRITIQUE : Extraction du texte ---
        full_text = ""
        
        if isinstance(result, list):
            for page_data in result:
                # MinerU 0.7.x stocke le texte dans 'md_content' ou 'text_content' selon les sous-versions
                # On essaie de récupérer le contenu le plus pertinent
                if isinstance(page_data, dict):
                    content = page_data.get("md_content") or page_data.get("text_content") or ""
                    full_text += content + "\n\n"
                elif isinstance(page_data, str):
                    full_text += page_data + "\n\n"
        else:
            # Fallback si le format de retour change
            full_text = str(result)
            
        if not full_text.strip():
            return "Oups, l'OCR n'a extrait aucun texte ou l'image est illisible."
            
        return full_text.strip()

# --- PARTIE FASTAPI (Cloud Run / OpenAI Compatible) ---
app = FastAPI(title="MinerU OCR API")

class ChatCompletionRequest(BaseModel):
    messages: List[dict]
    model: str = "mineru"

@app.post("/v1/chat/completions")
async def chat_openai(request: ChatCompletionRequest):
    try:
        # 1. Récupération de l'image/pdf dans le dernier message
        last_msg = request.messages[-1].get("content")
        b64_data = None
        
        if isinstance(last_msg, list):
            for item in last_msg:
                if item.get("type") == "image_url":
                    url = item["image_url"]["url"]
                    # Nettoyage du header base64 standard (data:image/png;base64,...)
                    if "base64," in url:
                        b64_data = url.split("base64,")[-1]
                    else:
                        b64_data = url # Cas où c'est déjà du raw base64
        
        if not b64_data: 
            raise HTTPException(400, "No base64 image_url found in the last message")
        
        # 2. Traitement
        markdown = process_mineru(base64.b64decode(b64_data))
        
        # 3. Réponse format OpenAI
        return {
            "id": "chatcmpl-mineru",
            "object": "chat.completion",
            "created": 1234567890,
            "model": request.model,
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant", 
                    "content": markdown
                },
                "finish_reason": "stop"
            }]
        }
    except Exception as e:
        logger.error(f"Error in FastAPI endpoint: {str(e)}", exc_info=True)
        raise HTTPException(500, detail=str(e))

# --- PARTIE RUNPOD (Serverless Worker) ---
def runpod_handler(job):
    try:
        inputs = job["input"]
        
        # Support flexible des entrées
        raw_b64 = inputs.get("pdf_base64") or inputs.get("image_base64") or inputs.get("file_base64")
        
        if not raw_b64:
            return {"error": "Input must contain pdf_base64 or image_base64"}

        # Nettoyage de sécurité pour RunPod aussi (si l'utilisateur envoie le prefixe data:...)
        if "," in raw_b64 and "base64" in raw_b64[:30]:
            raw_b64 = raw_b64.split(",")[1]

        # Décodage et Traitement
        file_bytes = base64.b64decode(raw_b64)
        result_markdown = process_mineru(file_bytes)
        
        return {
            "status": "success", 
            "markdown": result_markdown,
            # On retourne aussi 'content' pour compatibilité si besoin
            "content": result_markdown 
        }
        
    except Exception as e:
        logger.error(f"Error in RunPod handler: {str(e)}", exc_info=True)
        return {"status": "error", "error": str(e)}

if __name__ == "__main__":
    # Point d'entrée pour RunPod Serverless
    # start_server.sh lance "python3 -u main.py" sur RunPod
    runpod.serverless.start({"handler": runpod_handler})