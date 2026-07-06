FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    QT_QPA_PLATFORM=offscreen \
    QGIS_PLUGINPATH=/root/.local/share/QGIS/QGIS3/profiles/default/python/plugins \
    UV_BREAK_SYSTEM_PACKAGES=1

# ==========================================
# STEP 1: QGIS Repository & Binary Installation
# ==========================================

RUN apt-get update && apt-get install -y \
    software-properties-common gnupg wget curl unzip \
    && mkdir -p /etc/apt/keyrings \
    && wget -qO /etc/apt/keyrings/qgis-archive-keyring.gpg https://download.qgis.org/downloads/qgis-archive-keyring.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/qgis-archive-keyring.gpg] https://qgis.org/ubuntu-ltr noble main" > /etc/apt/sources.list.d/qgis.list \
    && apt-get update && apt-get install -y \
    qgis \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# ==========================================
# STEP 2: Python Compiler Setup & Supy/UMEP Compilation
# ==========================================

RUN apt-get update && apt-get install -y \
    build-essential \
    gfortran \
    python3-dev \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && . $HOME/.local/bin/env \
    && uv pip install --system --prerelease=allow "umep-reqs[numpy1]" "numpy<2.0" geopandas \
    # Force everything to use the system numpy that QGIS was built against
    && rm -rf /usr/local/lib/python3.12/dist-packages/numpy \
    && rm -rf /usr/local/lib/python3.12/dist-packages/numpy-*.dist-info \
    && apt-get purge -y build-essential gfortran python3-dev software-properties-common \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# ==========================================
# STEP 3: UMEP QGIS Plugin Download
# ==========================================

RUN mkdir -p ${QGIS_PLUGINPATH} && cd ${QGIS_PLUGINPATH} \
    && curl -L "https://plugins.qgis.org/plugins/processing_umep/version/3.0/download/" -o umep.zip \
    && unzip umep.zip && rm umep.zip

# Enable UMEP processing and ignore output due to faulty QGIS output
RUN qgis_process plugins enable processing_umep || true

