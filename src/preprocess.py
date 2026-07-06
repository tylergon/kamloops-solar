import json
import subprocess
from pathlib import Path

INPUT_DIR = Path("./raw")
OUTPUT_DIR = Path("./processed")
SRS = "EPSG:26910"

OUTPUT_DIR.mkdir(exist_ok=True)

def build_pipeline(infile: Path, outfile: Path) -> dict:
    return {
        "pipeline": [
            {
                "type": "readers.las",
                "filename": str(infile),
                "override_srs": SRS
            },
            {
                "type": "filters.reprojection",
                "in_srs": SRS,
                "out_srs": SRS
            },
            {
                "type": "filters.voxeldownsize",
                "cell": 0.001
            },
            {
                "type": "filters.range",
                "limits": "ReturnNumber[1:]"
            },
            {
                "type": "writers.copc",
                "filename": str(outfile),
                "a_srs": SRS
            }
        ]
    }

files = list(INPUT_DIR.glob("*.las"))

for f in files:
    outfile = OUTPUT_DIR / f.with_stem(f.stem).with_suffix(".copc.laz").name
    pipeline = json.dumps(build_pipeline(f, outfile))

    result = subprocess.run(
        ["pdal", "pipeline", "--stdin"],
        input = pipeline,
        text = True,
        capture_output = True
    )

    if result.returncode != 0:
        print(f"ERROR: {f.name}\n{result.stderr}")
    else:
        print(f"OK: {f.name} -> {outfile.name}")
