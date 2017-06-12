import numpy as np
from sklearn import preprocessing as pp

print('normalization function imported')

#normalize data in respect with keys in dictionary
def normalize_data(data):
    # get keys from original data
    gestures = list(data)
    
    # create empty dictionary to store normalized data with gestures
    gdata = {}

    # get max/min of x/y across samples and frames
    for gesture in gestures:
        data_gesture = np.asarray(data[gesture])
        max_x = np.max(data_gesture[...,0])
        min_x = np.min(data_gesture[...,0])
        max_y = np.max(data_gesture[...,1])
        min_y = np.min(data_gesture[...,1])
        data_gesture[...,0]=(data_gesture[...,0]-min_x)/(max_x - min_x)
        data_gesture[...,1]=(data_gesture[...,1]-min_y)/(max_y - min_y)

        #store normalized data into dictionary
        gdata[gesture] = data_gesture
    data = gdata
    return data
    return print('data normalized')
