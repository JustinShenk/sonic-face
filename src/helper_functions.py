import os
import numpy as np

def load_data(data_dir, filename):
    with open(os.path.join(data_dir,filename), 'r') as file:
        raw = file.read().replace('t', ',').split(',')

    data = np.asarray(raw)[0:32000].reshape((10,40,40,2))
    data = data.astype(np.float)
    return data
