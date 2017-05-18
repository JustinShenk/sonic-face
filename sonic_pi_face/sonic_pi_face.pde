import oscP5.*; //libraries required
import netP5.*;
import gab.opencv.*;
import processing.video.*;
import java.awt.*;
import java.awt.Rectangle;

OscP5 oscP5;
NetAddress sonicPi;

Capture video;
OpenCV opencv;
PFont f;   

int screenheight = 240;
int screenwidth = 320;
int activityButtonWidth;

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
Rectangle[] faces;
float easing = 1; //change to 1 to get immediate following
int inner = 0;
int tickCount = 0;
int value = 0;
float pan1 = 0;
float pan2 = 0;
int activeColumn = 0;

Rectangle[] activityBar = new Rectangle[4];
PVector[] activityMeasure = {new PVector(0, 0), new PVector(0, 0), new PVector(0, 0), new PVector(0, 0)}; 
color red = color(255, 0, 0);
color blue = color(0, 0, 255);
color green = color(0, 255, 0);
color purple = color(100, 0, 100);
color[] colorList = {red, blue, green, purple};
// [Modes]
// 0: 1 face is kick + clap, 2 face is synth
int[] selectorPosition = {0, 0, 0, 0, 0};
int mode = 0; // First player controls which instruments (FIXME)
boolean brightPointMode = false;
boolean debugMode = false;
boolean isOpticalFlow = false;

int [] faceSizes = new int[5];
int [] faceRatios = new int[5];
int [] players = new int[5];
int modes=3;
String[][] faceTexts = {
  {"Beat", "Clap", "Cello + Snare", "Mod Saw", "Vocals"}, 
  {"", "", "", "", ""}, 
  {"", "", "", "", ""}
};

void setup() {
  size(640, 480);
  f = createFont("Arial", 16, true);
  initializeCamera();
  noFill();
  stroke(0, 255, 0);
  strokeWeight(3);
  textSize(32);
  textAlign(LEFT, TOP);  
  oscP5 = new OscP5(this, 8000);
  sonicPi = new NetAddress("127.0.0.1", 4559);
  initializeUI();
}

void initializeUI() {    
  int activityBarX0 = screenwidth/6;
  int activityBarX1 = screenwidth * 5 / 6;
  int activityBarWidth = activityBarX1 - activityBarX0;
  int activityBarY0 = 25;
  //int activityBarWidth = screenwidth - 40;
  //int activityBarHeight = 40;
  int buttonsCount = 4;
  activityButtonWidth = activityBarWidth / buttonsCount;
  int activityButtonHeight = 20;  

  String[] buttons = {"A", "B", "C", "D"};
  for (int i = 0; i < buttons.length; i++) {
    int buttonX = activityBarX0 + i * activityButtonWidth;
    Rectangle rectangle = new Rectangle(
      buttonX, 
      activityBarY0, 
      activityButtonWidth, 
      activityButtonHeight);
    //rectangle.setStroke(color(255));
    //rectangle.setStrokeWeight(4);
    activityBar[i] = rectangle;    
    text(buttons[i], buttonX, activityBarY0);
  }
}

void initializeCamera() {
  video = new Capture(this, screenwidth, screenheight);
  video.start();
  opencv = new OpenCV(this, screenwidth, screenheight); 
  opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);
  faces = opencv.detect();
  cvWidth = screenwidth;
  cvHeight = screenheight;
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
  filter(GRAY);
  opencv.flip(OpenCV.HORIZONTAL);
  textFont(f, 16);  
  faces = opencv.detect();
  image(opencv.getOutput(), 0, 0 );

  if (isOpticalFlow) drawOpticalFlow();

  // Reset empty players 1 and 2 x-positions.
  if (mx1 == 0) mx1 = 320/2;
  if (mx2 == 0) mx2 = 320/2;

  drawFaces(faces);
  drawLines();
  drawController(faces); // Give each player an augmented reality controller
  moveController(faces);
  // Show brightest point for debugging
  drawBrightestPoint();
  if (isOpticalFlow) drawActivityBar();
  // Write debug, etc., on screen
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

void moveController(Rectangle[] faces) {
  // Move the wheel based on motion in controller
  //for (int i = 0; i < faces.length && i < 4; i++) {
  //  Rectangle faceWheel = new Rectangle(faces[i].x, 
  //  faces[i].y + faces[i].height, 
  //  faces[i].x+faces[i].width,
  //  faces[i].y+ faces[i].height);

  //  PVector motion = getMotion(faceWheel, i, false, false); // Use average motion rathern than total
  //  // TODO link motion with selector position
  //}
}
void drawController(Rectangle[] faces) {
  // Draw selector wheel
  int divisions = 16;
  float angle = 2 * PI / divisions;
  for (int i = 0; i < faces.length && i < 4; i++) { // Limit to 4 faces for testing
    Rectangle face = faces[i];
    ellipse(face.x + face.width/2, face.y + face.height*2, face.width, face.height);
    int radius = face.width;
    int circleCenterX = face.x + face.width/2;
    int circleCenterY = face.y + face.height *2;
    // Draw spokes on selector
    float innerRadius = radius * 0.45;
    float outerRadius = radius * 0.55;
    int j = selectorPosition[i]; // Default in up position for testing      
    int referenceY = circleCenterY + int(innerRadius * sin(angle * j));
    int referenceX = circleCenterX + int(innerRadius * cos(angle * j));
    int targetY = circleCenterY + int(outerRadius * sin(angle * j));
    int targetX = circleCenterX + int(outerRadius * cos(angle * j));    
    line(referenceX, referenceY, targetX, targetY);

    // Move the wheel
    if (activityMeasure[i].mag() > 0.01) {
      selectorPosition[i]++;
      print("position for face " + i + ": " + selectorPosition[i]);
      if (selectorPosition[i] > divisions - 1) selectorPosition[i] = 0;
    }
  }
}
void drawFaces(Rectangle[] faces) {
  // Draw face line, update text and faceRectangle data
  for (int i = 0; i < faces.length; i++) {  
    stroke(colorList[i% colorList.length]);

    if (i < 5) {
      if (mode == 0) {
        text(faceTexts[mode][i], faces[i].x, faces[i].y + faces[i].height + 10);
      }
      // Update the area of faces
      faceSizes[i] = faces[i].width * faces[i].height;
    }

    if (i ==0) {      
      //control the with lateral motion
      mx1 = faces[i].x + faces[i].width / 2;
      my1 = faces[i].y;
    } else if (i == 1) {
      mx2 = faces[i].x + faces[i].width / 2;
      my2 = faces[i].y;
    } else if (i == 2) {
      // Second person fills in the music
      mx2 = faces[i].x + faces[i].width / 2;
      my2 = faces[i].y;
    }

    if (i == faces.length -1 || i == 4) { // Last face only      
      getFaceRatios(i);
    }

    // Draw line below face
    line(faces[i].x, faces[i].y+faces[i].height, faces[i].x+faces[i].width, faces[i].y+faces[i].height);
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
}

void drawBrightestPoint() {
  if (!brightPointMode) return;
  // Get brightest point
  loc = opencv.max();
  activeColumn = int((loc.x / screenwidth) * columns); // zero-indexing
  stroke(255, 0, 0);
  strokeWeight(4);
  noFill();
  // Draw brightest point with ellipse
  ellipse(loc.x, loc.y, 10, 10);
  // Reset stroke
  resetStroke();
}

void resetStroke() {
  stroke(255, 0, 0);
  strokeWeight(1);
  noFill();
}
void incrementMode(int delta) {
  if (mode + delta < 0)
    mode = modes - 1;
  else {
    mode = (mode + delta) % (modes);
  }
}

void drawLines() {
  // Draw lines for columns
  if (!brightPointMode) return;

  //drawColumns(); // Disabled

  for (Rectangle button : activityBar) 
    rect(float(button.x), float(button.y), float(button.width), float(button.height));
  // Reset stroke
  stroke(255, 0, 0);
  strokeWeight(1);
  noFill();
}

void drawColumns() {
  // Disabled
  for (int i = 1; i <= columns; i++) {
    stroke(180);
    strokeWeight(0.7);
    int x = (screenwidth * i) / columns;
    line(x, 0, x, screenheight);
  }
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
  } else if (key == 'o') {
    isOpticalFlow = !isOpticalFlow;
  }
  if (value == 0) {
    value = 255;
  } else {
    value = 0;
  }
}

void drawOpticalFlow() {
  // Show movement using vector field
  opencv.calculateOpticalFlow();
  opencv.drawOpticalFlow();
  //int columnWidth = screenwidth / 4;
  //PVector column1Motion = opencv.getTotalFlowInRegion(0, 0, screenwidth/columns, screenheight);
  stroke(0, 255, 0);
  strokeWeight(1);
  textSize(8);  
  textFont(f, 16);  // Reset text size
}

PVector getMotion(Rectangle r, int index, boolean activityBar, boolean totalMotion) {  
  PVector motion = new PVector();
  if (totalMotion)
    motion = opencv.getTotalFlowInRegion(r.x, r.y, activityButtonWidth, 20);    
  else
    motion = opencv.getAverageFlowInRegion(r.x, r.y, activityButtonWidth, 20);
  // Update global motion
  if (activityBar) activityMeasure[index] = motion; 
  if (Float.isNaN(motion.x) || Float.isNaN(motion.y)) {
    //print("motion set to zero", "R:", r.x, r.y, r.width, r.height, "buttonwidth:", activityButtonWidth, motion.x, motion.y);  
    motion.set(0.,0.); 
  }
  return motion;
}
void getFaceRatios(int i) {         
  // Calculate proportion of faces at the end of drawing 5 faces.
  // Reset non-player areas.
  // Note: i+1 is the number of faces.
  for (int nonplayer = i + 1; nonplayer < 5; nonplayer++) {
    faceSizes[nonplayer] = 0;
  }
  int areaSum = 0;      
  for (int playerRectangle = 0; playerRectangle < 5; playerRectangle++) {
    areaSum += faceSizes[playerRectangle];
  }
  for (int player = 0; player < 5 && player < faces.length; player++) {
    int faceSize = faceSizes[player];
    // Skip empty faceSizes
    if (faceSize != 0 && mode > 1) {
      String faceRatioText = faceTexts[0][player] + ": %" + int(100 * faceSize / float(areaSum));
      text(faceRatioText, faces[player].x, faces[player].y + faces[player].height + 10);
    }
  }
}

void drawActivityBar() {
  textFont(f, 10);  
  for (int button = 0; button < activityBar.length; button++) {
    PVector motion = getMotion(activityBar[button], button, true, false);
    float combinedVector = motion.mag();    
    text(nfs(combinedVector*10, 1, 2), activityBar[button].x + (activityButtonWidth / 4), activityBar[button].y + 5);
  }
  textFont(f, 16);
}
void captureEvent(Capture c) {
  c.read();
}