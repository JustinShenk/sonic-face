# Sonic Face

Testing repository for using OpenCV face detection and Sonic Pi to cue music loops.

## Getting started

Install [Sonic Pi](http://sonic-pi.net/) and [Processing](https://processing.org/download/).

```
git clone https://github.com/JustinShenk/sonic-face.git
cd sonic-face
```

Open Sonic Pi and load the `.rb` file. Change the `dir` path to the path on your computer, e.g., `/path/to/sonic-face/samples`.

Run the file and then open the `.pde` file in Processing. Install "OpenCV for Processing", "oscP5," and other missing dependencies in Processing via `Sketch` -> `Import Library...`.

## Demo
![Early demo of the interface](interface_early_demo.gif)

## How it works

Instruments are cued by the presence of faces. The `d` key can be used to debug, followed by the number of faces (5 for the maximum). The `o` key activates the user interface. The `up` key scrolls through modes.

## Collect data for gesture analysis with optical flow

After activating the user interface with `o`, press `g` to get the hand gesture bounding box and `r` to start the recording loop. Data is saved to the `data` folder.

See the data preparation and analysis [notebook](PrepareData.ipynb).

## Todo

 - [X] Presence of faces triggers hierarchy of instruments (Beat, Clap, Cello + Snare, Mod Saw, and Vocals)
 - [X] Users can cycle through instruments via an augmented reality interface
 - [X] Proximity of faces determines volume of instruments
 - [X] Instantaneous activation of instrument by parsing loops
 - [X] Hand-activated direction of music
 - [ ] Brightest point activation of music
 - [ ] Visualization of music (e.g., pulse) on the screen activated by triangle of instruments (faces or hands)

## Note

Optical flow visualization is available for testing purposes. Eventually it would be nice to add motion activation. A previous version used face position for panning, and that code is still present.

## Contribute

 * Fork it!
 * Create your feature branch: git checkout -b my-new-feature
 * Commit your changes: git commit -am 'Add some feature'
 * Push to the branch: git push origin my-new-feature
 * Submit a pull request :D *
