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

String[] instruments = {"Beat", "Clap", "Cello + Snare", "Mod Saw", "Vocals"};
int[] instrumentIndex = {0, 1, 2, 3, 4};
int instrumentIndexOffset = 0;
// FIXME: Remove `mx` and `my` variable references
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
int divisions = 16;
int changeInstrumentCountdown;

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

  String[] buttons = {"A", "B", "C", "D"}; // Placeholders
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
    //text(buttons[i], buttonX, activityBarY0);
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
  /**
   * Main loop for drawing.
   */
  // Set up environment
  noFill();
  scale(2);
  opencv.loadImage(video);
  filter(GRAY);
  opencv.flip(OpenCV.HORIZONTAL);
  textFont(f, 16);  
  //Rectangle[] facesPrev = faces;
  faces = opencv.detect();
  Rectangle[] sortedFaces = sortFaces(faces);
  //ensureContinuity(facesPrev, faces);
  image(opencv.getOutput(), 0, 0 );

  if (isOpticalFlow) {
    opencv.calculateOpticalFlow();
    //opencv.drawOpticalFlow();    
    // Reset stroke and text display
    stroke(0, 255, 0);
    strokeWeight(1);
    textSize(8);  
    textFont(f, 16);
    drawController(faces); // Give each player an augmented reality controller
    drawActivityBar();
  }
  // Reset empty players 1 and 2 x-positions.
  if (mx1 == 0) mx1 = 320/2;
  if (mx2 == 0) mx2 = 320/2;
  // Show brightest point for debugging
  drawBrightestPoint();
  drawFaces(sortedFaces);
  drawLines();
  if (isOpticalFlow) {
  }
  // Write debug, etc., on screen
  drawText();
  //tempo = int(100 * mx / (640./2) + 50);
  //amp = (2.0 * my) / (screenheight);
  //if (amp < 0.5) amp = 0.5;
  updateTimers();
  sendOscNote(facesCount, mode, mx1, mx2, activeColumn);
  //sendOscNote(tempo, amp); //send the mx and my values to SP
  //sendOscNote(70+tickCount/100,80);

  //fill(204, 102, 0);  
  //text("Tempo: %" + str(tempo), 10, 200);
  //text("Volume: %" + str(amp), 10, 215);
}

void updateTimers() {
  if (changeInstrumentCountdown > 0) changeInstrumentCountdown--;
}

void ensureContinuity(Rectangle[] prevFaces) {
  /**
   * Preserve allignment of faces/instrument.
   * @param  prevFaces array of rectangles
   */
  // FIXME: Complete this.

  int threshold = 5;
  int[] indexOffsetVector = new int[faces.length];
  for (int i = 0; i < faces.length; i++) {
    for (int j = 0; j < prevFaces.length; j++) {      
      int distX = faces[i].x - prevFaces[j].x;
      if (distX < threshold) {
        // Assume it is the same faces
      }
    }
  }
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
  /** Draw selector wheel for each player.
   */
  PVector[] controllerActivities = {};
  float angle = 2 * PI / divisions;
  // Draw selector wheel with spokes
  for (int i = 0; i < faces.length && i < 4; i++) { // Limit to 4 faces for testing
    Rectangle face = faces[i];
    stroke(0, 255, 0);
    // Draw wheel
    ellipse(face.x + face.width/2, face.y + face.height*2, face.width, face.height);
    int radius = face.width;
    int circleCenterX = face.x + face.width/2;
    int circleCenterY = face.y + face.height *2;
    // Draw spokes on selector
    float innerRadius = radius * 0.45;
    float outerRadius = radius * 0.55;
    int j = selectorPosition[i]; // Default in vertical position      
    int referenceY = circleCenterY + int(innerRadius * sin(angle * j));
    int referenceX = circleCenterX + int(innerRadius * cos(angle * j));
    int targetY = circleCenterY + int(outerRadius * sin(angle * j));
    int targetX = circleCenterX + int(outerRadius * cos(angle * j));
    // Draw spokes
    line(referenceX, referenceY, targetX, targetY);
    ellipse(referenceX, referenceY, 5f, 5f);

    // Move the wheel using the motion on the sides of the cirle
    Rectangle clockwiseRotate = new Rectangle(circleCenterX + face.width/2, circleCenterY - face.height/2, face.width/2, face.height);    
    PVector clockwiseActivity = getMotion(clockwiseRotate, i, false, false);
    if (clockwiseActivity.mag() > 0.01) {
      selectorPosition[i]++;
      if (selectorPosition[i] > divisions - 1) {
        selectorPosition[i] = divisions - 1;
        // Draw line below face
        stroke(255, 0, 0);
        strokeWeight(3);
        int lineLength = faces[i].width * selectorPosition[i] / divisions;
        line(faces[i].x+lineLength, faces[i].y+faces[i].height-3, faces[i].x+lineLength, faces[i].y+faces[i].height+3);
      }
    }
    append(controllerActivities, clockwiseActivity);
    Rectangle counterClockwiseRotate = new Rectangle(circleCenterX-face.width/2, circleCenterY - face.height/2, face.width/2, face.height);
    PVector counterClockwiseActivity = getMotion(counterClockwiseRotate, i, false, false);
    if (counterClockwiseActivity.mag() > 0.01) {
      selectorPosition[i]--;
      if (selectorPosition[i] < 0) selectorPosition[i] = 0;
    }
    append(controllerActivities, counterClockwiseActivity);
    int lineRightEnd = circleCenterX, lineLeftEnd = circleCenterX;
    if (clockwiseActivity.x > 0.01) {
      lineRightEnd = circleCenterX + int(clockwiseActivity.x * 100);
      lineRightEnd = constrain(lineRightEnd, circleCenterX, circleCenterX + face.width/2);
      stroke(229, 166, 93);
      line(circleCenterX, circleCenterY, lineRightEnd, circleCenterY);
    }
    if (counterClockwiseActivity.x < -0.01) {
      lineLeftEnd = circleCenterX + int(counterClockwiseActivity.x * 100);
      lineLeftEnd = constrain(lineLeftEnd, circleCenterX-face.width/2, circleCenterX);
      stroke(229, 166, 93);
      line(circleCenterX, circleCenterY, lineLeftEnd, circleCenterY);
    }
    // User changes instrument if contralateral motion detected in controller
    if (clockwiseActivity.x > 0.1 
      && counterClockwiseActivity.x < -0.1 
      && changeInstrumentCountdown == 0) {
      strokeWeight(3);
      ellipse(circleCenterX, circleCenterY, face.width, face.width);
      changeInstrumentCountdown = 10;
      faceTexts[0][faceTexts[0].length-1] = faceTexts[0][0];
      // Shift instruments to the left.
      for (int k = 1; k < faceTexts[0].length; k++) {    
        faceTexts[0][k-1] = faceTexts[0][k];
      }
    }
  }
  readSigns(faces);
}
void drawFaces(Rectangle[] faces) {
  /**
   * Draw face line, update text and faceRectangle data.
   * @ param  faces Array of face rectangles
   */
  for (int i = 0; i < faces.length; i++) {  
    stroke(colorList[i% colorList.length]);

    if (i < 5) { // Draw instrument name below first 5 faces 
      if (mode == 0) {
        for (Rectangle face : faces) print(face.x + " " + face.y);
        text(faceTexts[mode][i], faces[i].x, faces[i].y + faces[i].height + 10);
      }
      // Update the area of faces
      faceSizes[i] = faces[i].width * faces[i].height;
    }    

    if (i == faces.length -1 || i == 4) { // Last face only      
      getFaceRatios(i);
    }

    // Draw line below face
    strokeWeight(3);
    int lineLength = faces[i].width * selectorPosition[i] / divisions;
    line(faces[i].x, faces[i].y+faces[i].height, faces[i].x+lineLength, faces[i].y+faces[i].height);
  }

  if (!debugMode) {
    // Allow override
    facesCount = faces.length;
  }
}

void drawBrightestPoint() {
  /* Draws the brights point on the screen.
   */
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
  /* Draw lines for columns
   */
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
  // NOTE: Disabled
  // TODO: Remove until useful
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

Rectangle[] dropDistantFaces(Rectangle[] faces) {
  /**
   * Exclude remote faces.
   * @param  faces array of face rectangles
   * @return faces array of face rectanlges without remote faces
   */
  Rectangle[] cleanFaces = new Rectangle[0];
  int maxWidth = 0;
  for (Rectangle face : faces) {
    if (face.width > maxWidth) maxWidth = face.width;
  }
  for (Rectangle face : faces) {
    if (face.width < maxWidth / 2) {
      // Skip small faces
    } else {
      append(cleanFaces, face);
    }
  }
  return cleanFaces;
}
void checkContinuity() {
}
void readSigns(Rectangle[] faces) {
  /**
   * Read signs on users' controllers
   * @param  faces array of player face rectangles used for position
   */
  // Draw writing grid
  int rows = 8;
  int columns = 8;
  float activationThreshold = 0.015;
  PVector[] gridMotion = new PVector[rows*columns];
  stroke(200, 200, 200);
  strokeWeight(0.3);
  for (int i = 0; i < faces.length; i++) {
    // Draw grid
    int gridX0 = faces[i].x;
    int gridY0 = faces[i].y + int(faces[i].height * 1.5);  

    // Show the grid
    for (int j = 1; j < rows; j++) {
      if (debugMode) line(gridX0, gridY0 + (j * faces[i].height) / rows, gridX0 + faces[i].width, gridY0 + (j * faces[i].height) / rows);
      for (int k = 0; k < columns; k++) {
        int boxWidth = faces[i].width / columns;
        int boxHeight = faces[i].height / rows;
        int boxULX = gridX0 + k * faces[i].width/ columns;
        int boxULY = gridY0 + (j-1) * faces[i].height/ rows;
        int boxURX = boxULX + boxWidth;
        int boxURY = boxULY;
        int boxBLX = boxULX;
        int boxBLY = boxULY + boxHeight;
        int boxBRX = boxBLX + boxWidth;
        int boxBRY = boxBLY;
        Rectangle box = new Rectangle(boxULX, boxULY, boxWidth, boxHeight);
        PVector boxMotion = getMotion(box, j+ k * j, false, false); // FIXME: indexing
        if (boxMotion.mag() > activationThreshold) {          
          fill(204, 102, 0);            
          rect(box.x, box.y, box.width, box.height);
          noFill();
        }
        append(gridMotion, boxMotion);
      }
    }
    for (int j = 1; j < columns; j++) {
      if (debugMode) line(gridX0 + (j * faces[i].width) / columns, gridY0, gridX0 + j * faces[i].width / columns, gridY0 + faces[i].height);
    }
    resetStroke();
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

Rectangle[] sortFaces(Rectangle[] faces) {
  // Initialize sortedFaces array
  if (faces.length == 0) return faces;
  Rectangle[] sortedFaces = new Rectangle[faces.length];
  IntList facesX = new IntList();
  // Sort list of face x-positions 
  for (int i = 0; i < faces.length; i++) {
    facesX.append(faces[i].x);
  }
  facesX.sort();
  // Sort faces according to facesX order
  for (int i = 0; i < faces.length; i++) {
    for (int j= 0; j < facesX.size(); j++) {       
      if (faces[i].x == facesX.get(j)) {
        sortedFaces[j] = faces[i];
      }
    }
  }
  return sortedFaces;
}
PVector getMotion(Rectangle r, int index, boolean activityBar, boolean totalMotion) {
  /**
   * This method gets motion within a rectanlge `r`.
   * @param  r          the rectangle surrounding the area
   * @param activityBar hack for selecting activityBar as the location
   * @param totalMotion using total motion vs average motion calculation
   * @return            the vector of motion in the rectangle
   */
  PVector motion = new PVector();
  if (r.x + r.width > screenwidth) r.width = screenwidth - r.x -1;
  if (r.y + r.height > screenheight) r.height = screenheight - r.y -1;
  if (r.height < 1 || r.width < 1) {
    return motion.set(0., 0.);
  }
  if (totalMotion) 
    motion = opencv.getTotalFlowInRegion(r.x, r.y, r.width, r.height);    
  else
    motion = opencv.getAverageFlowInRegion(r.x, r.y, r.width, r.height);

  // Update global motion
  if (activityBar) activityMeasure[index] = motion; 
  if (Float.isNaN(motion.x) || Float.isNaN(motion.y)) {
    //print("motion set to zero", "R:", r.x, r.y, r.width, r.height, "buttonwidth:", activityButtonWidth, motion.x, motion.y);  
    motion.set(0., 0.);
  }
  return motion;
}
void getFaceRatios(int i) {         
  /**
   * Calculate proportion of faces at the end of drawing 5 faces.
   * Reset non-player areas.
   * Note: i+1 is the number of faces.
   * @param  i maximum number of faces present
   */
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
  /** 
   * Used for displaying arbitrary information. Currently disploys motion within buttons, visible 
   * by pressing `b`.
   */
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