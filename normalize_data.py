import numpy as np
from sklearn import preprocessing as pp

print('data normalized')
#for each frame(1-10) and each axis(x and y), do normalizing
def normalize_data(data):
    for i in range(len(data)):
        for n in range(len(data[0][0][0])):
            data[i,:,:,n]=pp.normalize(data[i,:,:,n])
    return data

