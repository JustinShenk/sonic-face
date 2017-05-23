#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys

print('y1')


def main(filename):
    raw_data = load_data(filename)

    # TODO - Clean data
    print(raw_data[0])
    return raw_data


def load_data(filename):
    with open(filename, 'r') as file:
        raw = file.read()
    raw_data = frames = raw.split('\n')
    return raw_data

if __name__ == "__main__":
    print(sys.argv)
    args = sys.argv[1:]
    import os
    filename = os.path.join('sonic_pi_face', 'data', args[0])
    main(filename)
