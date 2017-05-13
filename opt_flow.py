#!/usr/bin/env python

'''
example to show optical flow

USAGE: opt_flow.py [<video_source>]

Keys:
 1 - toggle HSV flow visualization
 2 - toggle glitch

Keys:
    ESC    - exit
'''

# Python 2/3 compatibility
from __future__ import print_function

import numpy as np
import cv2
import video
import os
from psonic import *
from threading import Thread

screenwidth = 480
screenheight = 320

# Set Haar cascade path.
CASCADE_PATH = '/usr/local/opt/opencv3/share/OpenCV/haarcascades/haarcascade_frontalface_default.xml'
if not os.path.exists(CASCADE_PATH):
    # Try alternative file path
    CASCADE_PATH = 'face.xml'
    if not os.path.exists(CASCADE_PATH):
        raise NameError('File not found:', CASCADE_PATH)

FACE_CASCADE = cv2.CascadeClassifier(CASCADE_PATH)


def find_faces(frame):
    """
    Find faces using Haar cascade.
    """

    faces = FACE_CASCADE.detectMultiScale(
        frame,
        scaleFactor=1.3,
        minNeighbors=5,
        minSize=(50, 50),
        #         flags=cv2.cv.CV_HAAR_SCALE_IMAGE
        flags=0)
    return faces


from threading import Thread


rate = 1.5


def drum_loop():
    global rate

    sample(LOOP_AMEN, rate=rate)
    print('drum_loop entered')
    sleep(1)


drum_looping = True


def looper():
    global drum_looping

    while drum_looping:
        drum_loop()


looper_thread = Thread(name='looper', target=looper)

looper_thread.start()


def play_tone(faces):
    global tickCount
    global tone
    global rate

    for (x, y, w, h) in faces:
        rate = (y / screenheight) * 1.5 + 0.2
        pan = (x / screenwidth) - screenwidth / 2
        tone = (x / screenwidth) * 30 + 70
        # if x < screenwidth / 3:
        #     tone = 70
        # elif x < screenwidth * 2 / 3:
        #     tone = 80
        # elif x <= screenwidth:
        #     tone = 90
        #     pan = 1
        # else:
        #     tone = 100
        play(tone, pan=pan)


def draw_faces(faces, frame):
    # Draw a rectangle around the faces.
    for (x, y, w, h) in faces:
        cv2.rectangle(frame, (x, y),
                      (x + w, y + h), (0, 255, 0), 2)


def my_loop():
    use_synth(TB303)
    play(chord(E3, MINOR), release=0.3)
    sleep(0.5)


# def looper():
#     while True:
#         my_loop()

# looper_thread = Thread(name='looper', target=looper)

# looper_thread.start()


debug = True


def draw_flow(img, flow, step=16):
    global debug
    h, w = img.shape[:2]
    y, x = np.mgrid[step / 2:h:step, step /
                    2:w:step].reshape(2, -1).astype(int)
    fx, fy = flow[y, x].T
    if debug:
        pass
        # print(len(fx), len(fy))
    lines = np.vstack([x, y, x + fx, y + fy]).T.reshape(-1, 2, 2)
    lines = np.int32(lines + 0.5)
    vis = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
    if debug:
        # Print sum of differences
        # print(np.sum(lines[0:100,1]) - np.sum(lines[0:100,0]))
        debug = False

    # TODO: Change this...
    cv2.polylines(vis, lines, 0, (0, 255, 0))
    # np.amax()
    for ind, line in enumerate(lines):
        (x1, y1), (x2, y2) = line
        if x1 < 200:
            cv2.circle(vis, (x1, y1), 1, (0, 255, 0), -1)
        else:
            cv2.circle(vis, (x1, y1), 1, (0, 255, 100), -1)
        # print(ind)

    return vis


def draw_hsv(flow):
    h, w = flow.shape[:2]
    fx, fy = flow[:, :, 0], flow[:, :, 1]
    ang = np.arctan2(fy, fx) + np.pi
    v = np.sqrt(fx * fx + fy * fy)
    hsv = np.zeros((h, w, 3), np.uint8)
    hsv[..., 0] = ang * (180 / np.pi / 2)
    hsv[..., 1] = 255
    hsv[..., 2] = np.minimum(v * 4, 255)
    bgr = cv2.cvtColor(hsv, cv2.COLOR_HSV2BGR)
    return bgr


def warp_flow(img, flow):
    h, w = flow.shape[:2]
    flow = -flow
    flow[:, :, 0] += np.arange(w)
    flow[:, :, 1] += np.arange(h)[:, np.newaxis]
    res = cv2.remap(img, flow, None, cv2.INTER_LINEAR)
    return res

if __name__ == '__main__':
    import sys
    print(__doc__)
    try:
        fn = sys.argv[1]
    except IndexError:
        fn = 0

    cam = video.create_capture(fn)
    cam.set(3, screenwidth)
    cam.set(4, screenheight)
    import time
    time.sleep(1)
    ret, prev = cam.read()
    prevgray = cv2.cvtColor(prev, cv2.COLOR_BGR2GRAY)
    show_hsv = False
    show_glitch = False
    cur_glitch = prev.copy()

    while True:
        ret, img = cam.read()
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        flow = cv2.calcOpticalFlowFarneback(
            prevgray, gray, None, 0.5, 3, 15, 3, 5, 1.2, 0)
        prevgray = gray

        faces = find_faces(gray)
        draw_faces(faces, gray)
        play_tone(faces)
        cv2.imshow('flow', draw_flow(gray, flow))
        if show_hsv:
            cv2.imshow('flow HSV', draw_hsv(flow))
        if show_glitch:
            cur_glitch = warp_flow(cur_glitch, flow)
            cv2.imshow('glitch', cur_glitch)

        ch = 0xFF & cv2.waitKey(5)
        if ch == 27:
            break
        if ch == ord('1'):
            show_hsv = not show_hsv
            print('HSV flow visualization is', ['off', 'on'][show_hsv])
        if ch == ord('2'):
            show_glitch = not show_glitch
            if show_glitch:
                cur_glitch = img.copy()
            print('glitch is', ['off', 'on'][show_glitch])
    cv2.destroyAllWindows()
