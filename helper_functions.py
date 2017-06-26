import os
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation

from integral_try import i_image, get_integral

def load_data(filepath):
    """Returns data from `filepath`."""
    with open(os.path.abspath(filepath), 'r') as _file:
        raw = _file.read().replace('t', ',').split(',')
    _raw_array = np.asarray(raw)
    try:
        _data = _raw_array[0:32000].reshape((10, 40, 40, 2))
        _data = _data.astype(np.float)
    except ValueError:
        print("Incomplete data sample found at ", filepath)
        return None
    return _data


def get_data_files(data_dir, gesture=None):
    files = [os.path.abspath(os.path.join(data_dir, file))
             for file in os.listdir(data_dir)]
    files = [filename for filename in files if any(
        ext in filename for ext in ['.csv', '.txt'])]
    if gesture is not None:
        return [x for x in files if gesture in x]
    else:
        return files


def get_gesture_data(files, gesture=''):
    """Get all data samples from `files` with `gesture` if specified.

    Args:
        files (list<str>)
        gesture (str)

    Returns:
        data (dict<list<numpy.array>>)
    """
    # Find `files` containing `gesture`
    file_list = [file for file in files if gesture in file]
    gestures = get_gesture_set(file_list, gesture)
    data = {}
    for g in gestures:
        gesture_files = [file for file in file_list if g in file]
        gesture_data = [load_data(gesture_file)
                        for gesture_file in gesture_files]
        # In case incomplete data
        gesture_data = [x for x in gesture_data if x is not None]
        data[g] = gesture_data
    return data


def get_gesture_set(file_list, gesture=''):
    """Get set of unique gestures in list of `files`

    Args:
        file_list (list<str>)
        gesture (string)

    Returns:
        gestures (set<str>)

    """
    if gesture is not '':
        gestures = set([gesture])
    else:
        # Get set of gestures
        gestures = set([file.split('_')[-1].split('.')[0]
                        for file in file_list])
        return gestures


def reduce_dimensions(sample, rows = 4, cols = 4):
    '''Reduce dimensions of images in `sample` using integral image.'''
    array = np.zeros((10,rows*cols,2))
    sections = []
    for i in range(rows):
        for j in range(cols):
            x0 = (40/rows) * (i)
            y0 = (40/rows) * (j)
            x1 = (40/rows) * (i+1) -1
            y1 = (40/rows) * (j+1) -1
            point = np.array([x0,y0,x1,y1])
            sections.append(point)
    for ind,frame in enumerate(sample):
        image = i_image(frame)
        for sect_ind, section in enumerate(sections):
            feature = get_integral(image, *section)
            array[ind][sect_ind] = feature
    return array

def display_frames(sample, coordinate=None):
    """Display frames in animation.

    Args:
        sample (numpy.array) - data sample containing 10 frames
        coordinate (int) - 0 for `x` coordinate, 1 for `y` coordinate

    """
    fig, (ax1, ax2) = plt.subplots(1, 2)
    fig.subplots_adjust(top=0.8)
    ax1.set_title('Lateral motion')
    ax2.set_title('Vertical motion')
    ax1.set(aspect=1)
    ax2.set(aspect=1)
    frame = sample[0]

    im1 = ax1.imshow(frame[...,0], animated=True,interpolation='gaussian',aspect='equal')
    im2 = ax2.imshow(frame[...,1], animated=True,interpolation='gaussian',aspect='equal')
    def update(i):
        fig.suptitle('Frame {}/10'.format(i+1))
        frameX = sample[i][..., 0]
        im1.set_array(frameX)
        frameY = sample[i][..., 1]
        im2.set_array(frameY)
        return im1,im2,

    ani = animation.FuncAnimation(
        fig, update, frames=range(10), interval=200, repeat=True)
    return ani

def feature_extract(data,rows=4,cols=4):
    """Extract features from 40*40 optical flow samples in `data` by using integral image
    of dimensions `rows` and `cols`.

    Args:
        data: np.ndarray
        rows: int
        cols: int

    Returns:
        df_red: Pandas DataFrame

    """
    df_red = pd.DataFrame()
    for gesture in list(data):
        gesture_samples = []
        df = pd.DataFrame()
        for sample in data[gesture]:
            red = reduce_dimensions(sample,rows=rows,cols=cols)
            red = red[4].flatten() # Get middle frame
            df = df.append(pd.Series(red),ignore_index=True)
        df['label'] = gesture
        df_red = df_red.append(df,ignore_index=True)
    return df_red
