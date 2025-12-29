import runpod
import base64
import os
import tempfile
import logging
from magic_pdf.pipe.UNIPipe import UNIPipe
from magic_pdf.rw.DiskReaderWriter import DiskReaderWriter

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def process_pdf(pdf_base64: str) -> dict:
    """
    Traite un PDF avec MinerU
    """
    try:
        # Décoder le PDF
        pdf_bytes = base64.b64decode(pdf_base64)
        logger.info(f"PDF decoded, size: {len(pdf_bytes)} bytes")
        
        # Créer un répertoire temporaire
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = os.path.join(temp_dir, "output")
            os.makedirs(output_dir, exist_ok=True)
            
            # Initialiser le reader/writer
            image_writer = DiskReaderWriter(output_dir)
            
            # Créer le pipeline MinerU
            logger.info("Creating MinerU pipeline...")
            pipe = UNIPipe(pdf_bytes, {"_pdf_type": ""}, image_writer)
            
            # Exécuter l'OCR
            logger.info("Running classification...")
            pipe.pipe_classify()
            
            logger.info("Running analysis...")
            pipe.pipe_analyze()
            
            logger.info("Parsing document...")
            pipe.pipe_parse()
            
            # Récupérer les résultats
            logger.info("Generating markdown...")
            markdown_content = pipe.pipe_mk_markdown(
                img_parent_path=output_dir,
                drop_mode="none"
            )
            
            logger.info("Processing complete")
            
            return {
                "status": "success",
                "markdown": markdown_content,
                "message": "PDF processed successfully"
            }
            
    except Exception as e:
        logger.error(f"Error processing PDF: {str(e)}", exc_info=True)
        return {
            "status": "error",
            "error": str(e)
        }

def handler(event):
    """
    Handler pour RunPod Serverless
    Format d'entrée attendu:
    {
        "input": {
            "pdf_base64": "base64_encoded_pdf_data"
        }
    }
    """
    try:
        input_data = event.get("input", {})
        
        # Vérifier le format
        if "pdf_base64" not in input_data:
            return {
                "error": "Missing 'pdf_base64' in input",
                "example": {
                    "input": {
                        "pdf_base64": "JVBERi0xLjQK..."
                    }
                }
            }
        
        pdf_base64 = input_data["pdf_base64"]
        logger.info("Received PDF processing request")
        
        # Traiter le PDF
        result = process_pdf(pdf_base64)
        
        return result
        
    except Exception as e:
        logger.error(f"Handler error: {str(e)}", exc_info=True)
        return {
            "error": str(e),
            "status": "error"
        }

if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})