FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV QT_QPA_PLATFORM=offscreen
ENV QGIS_PLUGINPATH=/root/.local/share/QGIS/QGIS3/profiles/default/python/plugins

# QGIS + UbuntuGIS repos
RUN apt-get update && apt-get install -y \
	software-properties-common gnupg wget curl unzip git \
	&& add-apt-repository ppa:ubuntugis/ubuntugis-unstable \
	&& mkdir -p /etc/apt/keyrings \
	&& wget -qO /etc/apt/keyrings/qgis-archive-keyring.gpg \
	https://download.qgis.org/downloads/qgis-archive-keyring.gpg \
	&& echo "deb [signed-by=/etc/apt/keyrings/qgis-archive-keyring.gpg] \
	https://qgis.org/ubuntu-ltr noble main" \
	> /etc/apt/sources.list.d/qgis.list \
	&& apt-get update && apt-get install -y \
	qgis \
	python3-qgis \
	python3-pip \
	r-base \
	libssl-dev \
	libcurl4-openssl-dev \
	libxml2-dev \
	gdal-bin \
	libgdal-dev \
	libgeos-dev \
	libproj-dev \
	libabsl-dev	\
	libuv1-dev \
	libudunits2-dev \
	&& rm -rf /var/lib/apt/lists/*


RUN Rscript -e "install.packages( \
	c('processx', 'jsonlite', 'fs', 'stringr'), \ 
	dependencies = TRUE, repos = 'https://cloud.r-project.org')"


# UMEP for Processing only
RUN mkdir -p ${QGIS_PLUGINPATH} \
	&& cd ${QGIS_PLUGINPATH} \
	&& curl -L "https://plugins.qgis.org/plugins/processing_umep/version/3.0/download/" \
	-o umep-processing.zip \
	&& unzip umep-processing.zip && rm umep-processing.zip


# Pin numpy version for safety
RUN python3 -m pip install --break-system-packages "numpy<2"

# Install supy alone with --ignore-installed for the typing-extensions conflict
RUN python3 -m pip install --break-system-packages --ignore-installed --no-cache-dir supy

# Install remaining packages separately (no --ignore-installed needed)
RUN python3 -m pip install --break-system-packages --no-cache-dir \
	jaydebeapi \
	numba \
	geopandas \
	netCDF4



WORKDIR /app

RUN git clone https://github.com/tylergon/kamloops-solar.git .
