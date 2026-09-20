# Optional ARM64 CPU parser, pinned to the RAGFlow file_parse API.
FROM python:3.13-slim@sha256:8d9d0b8bcf6506481eae4907c18f5e3e7902e629f5f6d684f9e7c32e85e3ddf0

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    MINERU_TOOLS_CONFIG_JSON=/data/mineru.json \
    HF_HOME=/data/hf \
    MODELSCOPE_CACHE=/data/modelscope

# libgl1/libglib2.0-0/libglx-mesa0: runtime deps of opencv-python
# libgomp1: OpenMP runtime used by torch
# fonts-noto-cjk: CJK glyphs for rendered text detection
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl libgl1 libglib2.0-0 libglx-mesa0 libgomp1 fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

# pipeline extra = torch + torchvision + onnxruntime + transformers (CPU inference).
# `six` is an undeclared runtime dependency of the 3.4.5 pipeline stack
# (first parse otherwise dies with "No module named 'six'").
# Official CPython 3.13 ARM64 CPU wheels avoid PyPI's CUDA dependencies.
RUN pip install --no-cache-dir "mineru[pipeline]==3.4.5" six==1.17.0 \
    "https://download.pytorch.org/whl/cpu/torch-2.14.0%2Bcpu-cp313-cp313-manylinux_2_28_aarch64.whl#sha256=092d5c12938850dfbd90a654b3c8dac34c33e300f88eb19ee6f4ef93992c6347" \
    "https://download.pytorch.org/whl/cpu/torchvision-0.29.0%2Bcpu-cp313-cp313-manylinux_2_28_aarch64.whl#sha256=4d5138e00e117cfd5b7fe70af57d65d00abff2ce9f8581dc97805ecc62a510f5" \
    onnxruntime==1.30.0 transformers==4.57.6

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8886
ENTRYPOINT ["/entrypoint.sh"]
