import runpod
import base64
import os
import tempfile
import logging
from magic_pdf.pipe.UNIPipe import UNIPipe
from magic_pdf.rw.DiskReaderWriter import DiskReaderWriter
import magic  # Pour détecter le type MIME

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def detect_file_type(file_bytes: bytes) -> str:
    """
    Détecte le type de fichier à partir des bytes
    """
    # Magic bytes pour détection
    if file_bytes.startswith(b'%PDF'):
        return 'pdf'
    elif file_bytes.startswith(b'\xff\xd8\xff'):
        return 'jpeg'
    elif file_bytes.startswith(b'\x89PNG'):
        return 'png'
    elif file_bytes.startswith(b'BM'):
        return 'bmp'
    elif file_bytes.startswith(b'II*\x00') or file_bytes.startswith(b'MM\x00*'):
        return 'tiff'
    else:
        return 'unknown'

def process_document(file_base64: str, file_type: str = None) -> dict:
    """
    Traite un document (PDF ou image) avec MinerU
    
    Args:
        file_base64: Document encodé en base64
        file_type: Type de fichier ('pdf', 'image', ou None pour auto-détection)
    """
    try:
        # Décoder le fichier
        file_bytes = base64.b64decode(file_base64)
        logger.info(f"File decoded, size: {len(file_bytes)} bytes")
        
        # Auto-détection du type si non spécifié
        if file_type is None:
            detected_type = detect_file_type(file_bytes)
            logger.info(f"Auto-detected file type: {detected_type}")
            if detected_type in ['jpeg', 'png', 'bmp', 'tiff']:
                file_type = 'image'
            elif detected_type == 'pdf':
                file_type = 'pdf'
            else:
                return {
                    "status": "error",
                    "error": f"Unsupported file type: {detected_type}"
                }
        
        # Créer un répertoire temporaire
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = os.path.join(temp_dir, "output")
            os.makedirs(output_dir, exist_ok=True)
            
            # Sauvegarder le fichier temporairement
            if file_type == 'pdf':
                input_file = os.path.join(temp_dir, "input.pdf")
            else:
                # Pour les images, on crée un PDF à partir de l'image
                input_file = os.path.join(temp_dir, "input.jpg")
            
            with open(input_file, "wb") as f:
                f.write(file_bytes)
            
            logger.info(f"Processing {file_type} file: {input_file}")
            
            # Initialiser le reader/writer
            image_writer = DiskReaderWriter(output_dir)
            
            # Créer le pipeline MinerU
            logger.info("Creating MinerU pipeline...")
            pipe = UNIPipe(file_bytes, {"_pdf_type": ""}, image_writer)
            
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
            
            # Récupérer le contenu structuré
            content_list = pipe.pipe_mk_uni_format(
                img_parent_path=output_dir,
                drop_mode="none"
            )
            
            logger.info("Processing complete")
            
            return {
                "status": "success",
                "markdown": markdown_content,
                "content": content_list,
                "file_type": file_type,
                "message": f"{file_type.upper()} processed successfully"
            }
            
    except Exception as e:
        logger.error(f"Error processing document: {str(e)}", exc_info=True)
        return {
            "status": "error",
            "error": str(e)
        }

def handler(event):
    """
    Handler pour RunPod Serverless
    
    Formats d'entrée acceptés:
    
    1. PDF:
    {
        "input": {
            "pdf_base64": "base64_encoded_pdf_data"
        }
    }
    
    2. Image:
    {
        "input": {
            "image_base64": "base64_encoded_image_data"
        }
    }
    
    3. Auto-détection:
    {
        "input": {
            "file_base64": "base64_encoded_data",
            "file_type": "pdf" ou "image" (optionnel)
        }
    }
    """
    try:
        input_data = event.get("input", {})
        
        # Déterminer le type et les données
        if "pdf_base64" in input_data:
            file_base64 = input_data["pdf_base64"]
            file_type = "pdf"
        elif "image_base64" in input_data:
            file_base64 = input_data["image_base64"]
            file_type = "image"
        elif "file_base64" in input_data:
            file_base64 = input_data["file_base64"]
            file_type = input_data.get("file_type", None)  # Auto-détection si None
        else:
            return {
                "error": "Missing file data in input",
                "example": {
                    "input": {
                        "pdf_base64": "JVBERi0xLjQK...",
                        # or
                        "image_base64": "iVBORw0KGgo...",
                        # or
                        "file_base64": "...",
                        "file_type": "pdf"  # optional
                    }
                }
            }
        
        logger.info(f"Received document processing request (type: {file_type or 'auto'})")
        
        # Traiter le document
        result = process_document(file_base64, file_type)
        
        return result
        
    except Exception as e:
        logger.error(f"Handler error: {str(e)}", exc_info=True)
        return {
            "error": str(e),
            "status": "error"
        }

if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})