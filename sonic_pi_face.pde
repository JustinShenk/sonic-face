import oscP5.*; //libraries required
import netP5.*;
import gab.opencv.*;
import processing.video.*;
import java.awt.*;

OscP5 oscP5;
NetAddress sonicPi;

Capture video;
OpenCV opencv;
OpenCV cvFlip;
PFont f;   

int screenheight = 240;
int screenwidth = 320;

int mx1=0;
int my1;
int mx2=0;
int my2;
int columns = 4;
int facesCount = 0;
PVector loc;
int tempo;
float amp;
int cvWidth; 
int cvHeight;
int cvDivider = 2; 
PImage detectionImg;
Rectangle[] faces;
float easing = 1; //change to 1 to get immediate following
int inner = 0;
int tickCount = 0;
int value = 0;
float pan1 = 0;
float pan2 = 0;
int activeColumn = 0;

color red = color(255, 0, 0);
color blue = color(0, 0, 255);
color green = color(0, 255, 0);
color purple = color(100, 0, 100);
color[] colorList = {red, blue, green, purple};
// [Modes]
// 0: 1 face is kick + clap, 2 face is synth

int mode = 0; // First player controls which instruments (FIXME)
boolean brightPointMode = false;
boolean debugMode = false;

String[] face1texts = {"Kicks", "Beat + Lands", "Beat + Lands + Low"};
String[] face2texts = {"Clap", "Low", "New"};
String[] face3texts = {"Cello + Snare", "Low", "New"};
String[] face4texts = {"Mod Saw", "Low", "New"};
String[] face5texts = {"Vocals", "Low", "New"};

int modeLength = face1texts.length;

void setup() {
  size(640, 480);
  f = createFont("Arial", 16, true);
  video = new Capture(this, screenwidth, screenheight);
  video.start();
  opencv = new OpenCV(this, screenwidth, screenheight);
  //opencv.useColor(); 
  opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);
  faces = opencv.detect();

  cvWidth = screenwidth;
  cvHeight = screenheight;
  noFill();
  stroke(0, 255, 0);
  strokeWeight(3);
  textSize(32);
  textAlign(LEFT, TOP);

  oscP5 = new OscP5(this, 8000);
  sonicPi = new NetAddress("127.0.0.1", 4559);
}

void sendOscNote(int facesCount, int mode, int mx1, int mx2, int activeColumn) {
  OscMessage toSend = new OscMessage("/notesend");
  if (mx1 < 0) mx1 = 240;
  if (mx2 < 0) mx2 = 240;
  pan1 = ((float(mx1) / (320.0)) - 0.5) * 2;
  if (pan1 > 1) pan1 = 1;
  else if (pan1 < -1) pan1 = -1;

  pan2 = ((float(mx2) / (320.0)) - 0.5) * 2;
  if (pan2 > 1) {
    pan2 = 1;
  } else if (pan2 < -1) pan2 = -1;

  toSend.add(facesCount);
  toSend.add(mode);
  toSend.add(pan1);
  toSend.add(pan2);
  toSend.add(activeColumn);
  oscP5.send(toSend, sonicPi);
}

void draw() {
  // Set up environment
  noFill();
  scale(2);

  opencv.loadImage(video);
  opencv.flip(OpenCV.HORIZONTAL);
  textFont(f, 16);  
  Rectangle[] faces = opencv.detect();
  image(opencv.getOutput(), 0, 0 );

  opencv.calculateOpticalFlow();
  opencv.drawOpticalFlow();
  int columnWidth = screenwidth / 4;
  PVector column1Motion = opencv.getTotalFlowInRegion(0, 0, screenwidth/columns, screenheight);
  PVector column2Motion = opencv.getTotalFlowInRegion(columnWidth * 1, 0, screenwidth/columns, screenheight);
  PVector column3Motion = opencv.getTotalFlowInRegion(columnWidth * 2, 0, screenwidth/columns, screenheight);
  PVector column4Motion = opencv.getTotalFlowInRegion(columnWidth * 3, 0, screenwidth/columns, screenheight);
  stroke(0, 255, 0);
  strokeWeight(1);
  textSize(8);
  text("column1: " +column1Motion.x/1000 +' ' + column1Motion.y/1000, 10, 40);

  if (mx1 == 0) mx1 = 320/2;
  if (mx2 == 0) mx2 = 320/2;

  for (int i = 0; i < faces.length; i++) {
    stroke(colorList[i% colorList.length]);
    if (i ==0) {
      text(face1texts[mode], faces[i].x, faces[i].y + faces[i].height + 10);
      //control the with lateral motion
      mx1 = faces[i].x + faces[i].width / 2;
      my1 = faces[i].y;
    } else if (i == 1) {
      // Second person fills in the music
      text(face2texts[mode], faces[i].x, faces[i].y + faces[i].height + 10);
      mx2 = faces[i].x + faces[i].width / 2;
      my2 = faces[i].y;
    } else if (i == 2) {
      // Second person fills in the music
      text(face3texts[mode], faces[i].x, faces[i].y + faces[i].height + 10);
      mx2 = faces[i].x + faces[i].width / 2;
      my2 = faces[i].y;
    } else if (i == 3) {
      // Second person fills in the music
      text(face3texts[mode], faces[i].x, faces[i].y + faces[i].height + 10);
    } else if (i == 4) {
      // Third person fills in the music
      text(face4texts[mode], faces[i].x, faces[i].y + faces[i].height + 10);
    } else if (i == 5) {
      // Fourth person fills in the music
      text(face5texts[mode], faces[i].x, faces[i].y + faces[i].height + 10);
    }
    rect(faces[i].x, faces[i].y, faces[i].width, faces[i].height);
  }

  if (!debugMode) {
    // Allow override
    facesCount = faces.length;
  }

  // Reset pan settings if no faces found
  if (facesCount == 0) {
    mx1 = -1;
    mx2 = -1;
  } else if (facesCount == 1) {
    mx2 = -1;
  }
  drawLines();
  drawBrightestPoint();
  drawText();
  //tempo = int(100 * mx / (640./2) + 50);
  //amp = (2.0 * my) / (screenheight);
  //if (amp < 0.5) amp = 0.5;

  sendOscNote(facesCount, mode, mx1, mx2, activeColumn);
  //sendOscNote(tempo, amp); //send the mx and my values to SP
  //sendOscNote(70+tickCount/100,80);

  //fill(204, 102, 0);  
  //text("Tempo: %" + str(tempo), 10, 200);
  //text("Volume: %" + str(amp), 10, 215);
}
void drawBrightestPoint() {
  if (!brightPointMode) return;
  loc = opencv.max();
  activeColumn = int((loc.x / screenwidth) * columns); // zero-indexing
  stroke(255, 0, 0);
  strokeWeight(4);
  noFill();
  ellipse(loc.x, loc.y, 10, 10);
    // Reset stroke
  stroke(255, 0, 0);
  strokeWeight(1);
  noFill();
}

void incrementMode(int delta) {
  if (mode + delta < 0)
    mode = modeLength - 1;
  else {
    mode = (mode + delta) % (modeLength);
  }
}

void drawLines() {
  // Draw lines for columns
  if (!brightPointMode) return;

  for (int i = 1; i <= columns; i++) {
    stroke(180);
    strokeWeight(0.7);
    int x = (screenwidth * i) / columns;
    line(x, 0, x, screenheight);
  }
  // Reset stroke
  stroke(255, 0, 0);
  strokeWeight(1);
  noFill();
}

void drawText() {
  if (debugMode) {
    fill(255, 255, 255);  
    text("Debug Mode: " + str(facesCount) + " faces present", 10, 10);
  }
}
void keyPressed() {
  if (keyCode == UP) {
    incrementMode(1);
  } else if (keyCode == DOWN) {
    incrementMode(-1);
  } else if (key == 'b' || key == 'B') {
    brightPointMode = !brightPointMode;
    if (!brightPointMode) activeColumn = -1;
  } else if (key == 'd') {
    debugMode = !debugMode;
  } else if (key == '0' && debugMode) {
    facesCount = 0;
  } else if (key == '1' && debugMode) {
    facesCount = 1;
  } else if (key == '2' && debugMode) {
    facesCount = 2;
  } else if (key == '3' && debugMode) {
    facesCount = 3;
  } else if (key == '4' && debugMode) {
    facesCount = 4;
  } else if (key == '5' && debugMode) {
    facesCount = 5;
  }
  if (value == 0) {
    value = 255;
  } else {
    value = 0;
  }
}

void captureEvent(Capture c) {
  c.read();
}