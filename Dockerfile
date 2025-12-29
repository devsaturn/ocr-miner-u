# Utiliser une version vLLM compatible avec CUDA 11.8/12.1
FROM --platform=linux/amd64 vllm/vllm-openai:v0.6.3

# Ou essayez cette version
# FROM --platform=linux/amd64 vllm/vllm-openai:v0.8.0

LABEL org.opencontainers.image.source=https://github.com/devsaturn/mineru-ocr
LABEL org.opencontainers.image.description="MinerU OCR Server for RunPod"

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
        fonts-noto-core \
        fonts-noto-cjk \
        fontconfig \
        libgl1 \
        curl && \
    fc-cache -fv && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install mineru and runpod
RUN python3 -m pip install -U 'mineru[core]' runpod --break-system-packages && \
    python3 -m pip cache purge

# Download models
RUN /bin/bash -c "mineru-models-download -s huggingface -m all"

# Set environment
ENV MINERU_MODEL_SOURCE=local
WORKDIR /app

# Copy handler
COPY handler.py /app/handler.py

EXPOSE 8000

# RunPod Serverless handler
CMD ["python3", "-u", "/app/handler.py"]