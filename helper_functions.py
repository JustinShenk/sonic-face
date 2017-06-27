import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.animation as animation

from sklearn.tree import DecisionTreeClassifier, export_graphviz
from sklearn.neural_network import MLPClassifier as mlpc
from sklearn import linear_model as lm
from sklearn import svm as svm
from sklearn.ensemble import RandomForestClassifier, ExtraTreesClassifier, AdaBoostClassifier, BaggingClassifier, GradientBoostingClassifier
from sklearn.model_selection import train_test_split

def load_data(filepath):
    """Returns data from `filepath`."""
    with open(os.path.abspath(filepath), 'r') as _file:
        raw = _file.read().replace('t', ',').split(',')
    _raw_array = np.asarray(raw)
    try:
        _data = _raw_array[0:32000].reshape((10, 40, 40, 2))
        _data = _data.astype(np.float)
    except ValueError:
        print("Incomplete data sample found.")
        os.remove(filepath)
        print("{} removed.".format(filepath))
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

def reduce_dimensions(sample, rows=4, cols=4):
    array = np.zeros((10,rows*cols,2))
    sections = []
    for i in range(rows):
        for j in range(cols):
            x0 = (40//cols) * (j)
            y0 = (40//rows) * (i)
            x1 = (40//cols) * (j+1) -1
            y1 = (40//rows) * (i+1) -1
            point = np.array([x0,y0,x1,y1])
            sections.append(point)

    for ind,frame in enumerate(sample):
        image = i_image(frame)
        for sect_ind, section in enumerate(sections):
            feature = get_integral(image, *section)
            array[ind][sect_ind] = feature
    return array

# def reduce_dimensions(sample,rows,cols):
#     array = np.zeros((10,rows*cols,2))
#     for ind,frame in enumerate(sample):
#         image = i_image(frame)
#         for sect_ind, section in enumerate(sections):
#             feature = get_integral(image, *section)
#             array[ind][sect_ind] = feature
#     return array

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

# Takes an original image and calculates the integral image
# cumsum takes an array as input
# this works on our vector array as expected (sums over the vectors)
def i_image (orig_image):
	iimage = orig_image.cumsum(1).cumsum(0)
	return iimage;

## To get the integral over a certain rectangle, input the topleft and bottomright coordinates
## depending on the location of the corner points, take the correct values from the integral image
def get_integral (integral_image, topleftx, toplefty, bottomrightx, bottomrighty):

	integral = 0
	integral += integral_image[bottomrightx,bottomrighty]

	if (topleftx - 1 >= 0) and (toplefty - 1 >=0):
		integral += integral_image[topleftx - 1, toplefty - 1]

	if (topleftx - 1 >= 0):
		integral -= integral_image[topleftx - 1, bottomrighty]

	if (toplefty - 1 >= 0):
		integral -= integral_image[bottomrightx, toplefty - 1]

	return integral

def save_data_sets(data_sets,divs):
    """Saves each dataFrame in `data_sets` with coordinates of row x column
    in `divs` to csv.

    """
    if not os.path.exists('data'):
        os.mkdir('data')

    indx = 0
    for r in divs:
        for c in divs:
            filepath = 'data/data_red_{}x{}.csv'.format(r,c)
            if os.path.exists(filepath):
                print("File found at {}".format(filepath))
                indx+=1
            else:
                data_sets[indx].to_csv(filepath)
                indx+=1
                print("File saved to {}".format(filepath))

def get_feature_sets(data,divs=[2,3,4,5]):
    """Create various feature extraction sets from `data` for hyperparameter
    optimization with permutation `divs` rows and cols.

    Args:
        data: dict of np.ndarrays
        divs: list of ints

    Returns:
        list of dataFrames

    """
    data_sets = []
    for rows in divs:
        for cols in divs:
            df_red = feature_extract(data,rows=rows,cols=cols)
            data_sets.append(df_red)
    return data_sets

def get_data(data, key):
    """Returns flattened array from `data` dictionary with gesture `key`.

    Args:
        data: dict of np.ndarrays
        key: String

    Returns:
        flattened_data: np.ndarray

    """
    data_list = data[key]
    data_array = np.asarray(data_list)

    # Flatten array to n x 32000
    flattened_data = data_array.reshape((len(data_array),10*1600*2))
    return flattened_data

def scale(data, target_gesture):
    """Scale data using max and min within the `target_gesture` of `data`.

    """
    data *= (np.max(target_gesture) + np.abs(np.min(target_gesture))) - np.min(target_gesture)
    return data

def encode_target(df, target_column, gestures=['open-close','empty','slide-horizontally']):
    """Add column to df with integers for the target.
    Original from: https://github.com/joaocalixto/decisionTreeIdentityManagement/
        blob/master/decisionTree%5Bchrisstrelioff%5D.py

    Args:
        df: pandas DataFrame.
        target_column: column to map to int, producing
                     new Target column.

    Returns:
        df_mod: modified DataFrame.
        targets: list of target names.

    """
    df_mod = df.copy()

    targets = df_mod[target_column].unique()
    map_to_int = {name: n for n, name in enumerate(targets)}
    df_mod["Target"] = df_mod[target_column].replace(map_to_int)

    return (df_mod, targets)

def visualize_tree(tree, feature_names):
    """Create tree png using graphviz.
    *Source unknown.*

    Args
    ----
    tree -- scikit-learn DecsisionTree.
    feature_names -- list of feature names.
    """
    with open("dt.dot", 'w') as f:
        export_graphviz(tree, out_file=f,
                        feature_names=feature_names)

    command = ["dot", "-Tpng", "dt.dot", "-o", "dt.png"]
    try:
        subprocess.check_call(command)
    except:
        exit("Could not run dot, ie graphviz, to "
             "produce visualization")

def class_split(data,gestures=['open-close','empty','slide-horizontally']):
    """Collect data for training.

    Args:
        data:       dict of numpy arrays or pandas DataFrame
        gestures:   list of strings

    Returns:
        X:  numpy array (features)
        Y:  numpy array (targets)

    """
    if isinstance(data,pd.DataFrame):
        # Limit to `gesture` entries
        try:
            data = data.drop('Unnamed: 0', axis=1)
        except:
            pass
        data = data[data['label'].isin(gestures)]
        data, targets = encode_target(data, 'label')
        X = data.drop(['Target','label'], axis=1)
        Y = data['Target']
        return X, Y
    X_list = []
    Y_list = []
    for gesture in gestures:
        # Load target gesture data
        X = get_data(data, gesture)
        Y = np.ones((len(X)))
        X_list.append(X)
        Y_list.append(Y)

    X = np.vstack(X_list)
    Y = np.hstack(Y_list)
    return X, Y

def get_combis(divs):
    """Get permutations of `divs`.

    Args:
        divs: list of ints

    Returns:
        combis: list of tuples

    """
    combis = []
    # Get list of all combinations of rows and columns
    for r in divs:
        for c in divs:
            combis.append((r,c))
    return combis

def optimize_feature_dimensions(data_sets, divs,method='rf'):
    """Compare performance of random tree classifier on `data_sets` with `divs` number
    of factors.

    Args:
        data_sets
        divs: list of ints (divisions of feature space into row and columns)
        method: String {'rf','ada'}

    Returns:
        ax: Matplotlib axes object

    """
    combis = get_combis(divs)
    compare = np.zeros((len(divs),len(divs)))
    com_array = np.asarray(combis)
    x_labels = com_array[:,1]
    y_labels = com_array[:,1]
    x = np.arange(len(combis))
    y = x
    fig,ax = plt.subplots()
    plt.xticks(x, x_labels)
    plt.yticks(y, y_labels)

    accuracies = []
    for idx, df in enumerate(data_sets):
        if method=='rf':
            # Set number of features and get random forest classification
            n_features = len(df.columns)
            _, accuracy = random_forest(df, max_features=int(np.sqrt(n_features)),features=combis[idx])
        elif method=='ada':
            _, accuracy = adaboost(df)
        # Get row and col from idx
        row = idx // len(divs)
        col = idx % len(divs)
        compare[row,col] = accuracy
        accuracies.append(accuracy)
    im = ax.imshow(compare,vmin=min(accuracies),vmax=1.0,cmap=plt.get_cmap('Blues'))
    plt.title("Accuracy vs Feature dimension - \nMethod: {}".format(method))
    ax.set_xlabel('Number of columns per frame')
    ax.set_ylabel('Number of rows per frame')
    fig.colorbar(im,ax=ax)
    return ax


def random_forest(data,labels=['slide-vertically','slide-horizontally','open-close'],max_depth=None, max_features='auto',n_estimators=15, features=(-1,-1)):
    """Classify `df` using random forest.

    Args:
        data: pandas dataFrame or numpy array
        labels: list of strings
        features: tuple of ints

    Returns:
        clf_forest: scikit-learn object
        accuracy: float
    """
    # Split data into train and test
    X_train, X_test, y_train, y_test = data_split(data)

    clf_forest = RandomForestClassifier(n_estimators=n_estimators,max_features=max_features,max_depth = max_depth)
    clf_forest = clf_forest.fit(X_train, y_train)
    accuracy = clf_forest.score(X_test,y_test)
    print("Predictions:\n{}".format(clf_forest.predict(X_test)))
    print("Actual:\n{}".format(y_test[:10]))
    print("Score for {}x{}:\n{}".format(features[0],features[1], accuracy))
    return clf_forest, accuracy

def adaboost(data,max_depth=3,n_estimators=10):
    """Adaboost classifier.

    Args:
        data: dataFrame or numpy array

    Returns:
        clf_adaboost: AdaBoostClassifier object

    """

    # Split data into train and test
    X_train, X_test, y_train, y_test = data_split(data)

    clf_adaboost = AdaBoostClassifier(DecisionTreeClassifier(max_depth=max_depth), n_estimators=n_estimators)
    clf_adaboost = clf_adaboost.fit(X_train, y_train)
    accuracy = clf_adaboost.score(X_test,y_test)
    print("Predictions:\n{}".format(clf_adaboost.predict(X_test)))
    print("Actual:\n{}".format(y_test[:10]))
    print("Score:\n{}".format(accuracy))
    return clf_adaboost, accuracy

def bagging(data):
    """Bagging classifier.

    Args:
        data: dataFrame or numpy array

    Returns:
        clf_bagging: AdaBoostClassifier object

    """

    clf_bagging = BaggingClassifier()
    clf_bagging = clf_bagging.fit(X_train, y_train)
    print(clf_bagging.score(X_test,y_test))
    return clf_bagging

def data_split(data):
    """Split data into feature and target vectors and into train and test
    vectors.

    Args:
        data: pandas DataFrame or numpy array

    Returns:
        X_train: pandas DataFrame or numpy array
        X_test: pandas DataFrame or numpy array
        y_train: pandas DataFrame or numpy array
        y_test: pandas DataFrame or numpy array

    """
    X, Y = class_split(data,gestures=['open-close','empty','slide-horizontally'])
    X_train, X_test, y_train, y_test = train_test_split(X, Y, random_state=42)
    return X_train, X_test, y_train, y_test


def extra_trees(data):
    """Extra trees classifier.

    Args:
        data: pandas DataFrame or numpy array

    Returns:
        clf_extra_tree: ExtraTreesClassifier object

    """
    clf_extra_tree = ExtraTreesClassifier()
    clf_extra_tree = clf_extra_tree.fit(X_train, y_train)
    print(clf_extra_tree.score(X_test,y_test))
    return clf_extra_tree

def get_data_list(divs=[4,10,20]):
    """Get or create data sets with various feature dimensions.

    Args:
        divs: list of ints (rows and columns to permute for feature reduction)

    Returns:
        data_list: list of panda DataFrames

    """
    data_sets = []
    DATA_DIR = 'data'
    if os.path.exists(DATA_DIR):
        for file in os.listdir(DATA_DIR):
            if file.endswith('.csv'):
                df = pd.read_csv(os.path.join(DATA_DIR,file))
                df = df.drop('Unnamed: 0',axis=1)
                data_sets.append(df)
    data_list = []
    for df in data_sets:
        data, target = encode_target(df, 'label')
        data_list.append(data)
    print("Data loaded")
    return data_list
