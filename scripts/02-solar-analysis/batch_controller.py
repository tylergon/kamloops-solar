import subprocess
import os
import os.path
import pandas as pd

# Paths
QGIS_PROCESS = r"C:/Users/tyler/AppData/Local/Programs/OSGeo4W/bin/qgis_process-qgis.bat"
MODEL = r"D:/Dev/Geomatics/kamloops-solar/scripts/02-solar-analysis/process_insolation.py"
METEOROLOGICAL_DATA = r"D:/Dev/Geomatics/kamloops-solar/data/weather/metprocessor-output-kamloops-a.txt"

INPUT_DIR = r"D:/Dev/Geomatics/kamloops-solar/output/01-base-geospatial"
OUTPUT_DIR = r"D:/Dev/Geomatics/kamloops-solar/output/02-insolation"
CSV = pd.read_csv(r"D:/Dev/Geomatics/kamloops-solar/scratch/neighbourhood_tiles.csv")

# File suffixes
dsm_suffix = "-ADJUSTED-DSM.tif"
chm_suffix = "-ADJUSTED-CHM.tif"

for nbhd in CSV['neighbourhood'].tolist():
    # Build input paths
    dsm_path = os.path.join(INPUT_DIR, nbhd, f"{nbhd}{dsm_suffix}")
    chm_path = os.path.join(INPUT_DIR, nbhd, f"{nbhd}{chm_suffix}")
    
    # Build output paths
    irradiance_out_path = os.path.join(OUTPUT_DIR, f"{nbhd}.tif")
    out_sub_dir = os.path.join(OUTPUT_DIR, nbhd)

    # << UNCOMMENT IF THE DIRECTORIES ARE NEEDED >>
    if not os.path.exists(out_sub_dir):
        os.makedirs(out_sub_dir)
    
    # Setup the commands
    cmd = [
        QGIS_PROCESS, "run", MODEL,
        "--", 
        f"building__ground_dsm={dsm_path}",
        f"vegetation_dsm={chm_path}",
        f"meteorological_data_umeped={METEOROLOGICAL_DATA}",
        f"Outputdir={out_sub_dir}",
        f"Rooftopirradiance={irradiance_out_path}"
    ]

    print(f"Processing {nbhd}...")
    subprocess.run(cmd, check=True)

