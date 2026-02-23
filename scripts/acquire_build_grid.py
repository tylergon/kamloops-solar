import pandas as pd

# Read out the data frame & get its shape
df = pd.read_csv('input/kamloops_template.csv', header=None)
nrow, ncol = df.shape

# Iterate through rows (north to south)
for i in range(nrow):
    row_id = 61 - (i // 2)
    grid_options = ('A', 'B') if (i % 2 == 1) else ('C', 'D')

    # Iterate through cols (west to east)
    for j in range(ncol):
        entry = df.iloc[i,j]

        # If we're not looking at a valid location, skip to next
        if not isinstance(entry, str):
            continue

        # Add the plot name into our dataframe
        col_id = 50 + j // 2
        grid_id = grid_options[j % 2]
        df.iloc[i, j] = f'{row_id}{col_id}{grid_id}'

df.to_csv('output/kamloops_grid.csv', header=False, index=False)
