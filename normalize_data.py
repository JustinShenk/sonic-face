# for each frame(1-10) and each axis(x and y), do normalizing

def normalize_data(data):
    normalized = np.empty([10,40,40,2])
    for i in range(len(data)):
        for n in range(len(data[0][0][0])):
            normalized[i,:,:,n]=pp.normalize(data[i,:,:,n])
            data = normalized
    return data

