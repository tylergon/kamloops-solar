import pandas as pd
import requests

# Get the tile codes
df = pd.read_csv('scripts/output/kamloops_grid.csv')
values = [code for code in df.values.flatten() if str(code) != 'nan']

# Loop through tile codes. Save each zip.
for trg in values:
    print(f">>> Beginning download for tile {trg}")
    r = requests.get(f'https://maps.kamloops.ca/opendata/Lidar/2024/{trg}.zip', stream=True)
    with open(f"data/{trg}.zip", mode="wb") as f:
        for (i, chunk) in enumerate(r.iter_content(chunk_size=10*1024)):
            print(f"  > Saving chunk {i}")
            f.write(chunk)

# TODO: Write an error message