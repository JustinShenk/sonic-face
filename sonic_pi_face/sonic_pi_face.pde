import oscP5.*; //libraries required
import netP5.*;
import gab.opencv.*;
import processing.video.*;
import java.awt.*;
import java.awt.Rectangle;
import java.util.Collections;
import java.util.List;

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
int fps = 10;
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
boolean rotationFeature = true;
float angle = 2 * PI / divisions;
float controllerStartOffsetY = 2;
int handRectWidth = 40;
int handRectHeight = 40;
Rectangle[] activityBar = new Rectangle[4];
PVector[] activityMeasure = {new PVector(0, 0), new PVector(0, 0), new PVector(0, 0), new PVector(0, 0)};
color RED = color(255, 0, 0);
color BLUE = color(0, 0, 255);
color GREEN = color(0, 255, 0);
color VIOLET = color(138, 43, 226);
color ORANGE = color(229, 166, 93);
color GRAY = color(50, 50, 50);
color LIGHTGRAY = color(200, 200, 200);
color WHITE = color(255, 255, 255);

color[] colorList = {RED, BLUE, GREEN, VIOLET};
// [Modes]
// 0: 1 face is kick + clap, 2 face is synth
int[] selectorPosition = {0, 0, 0, 0, 0};
int mode = 0; // First player controls which instruments (FIXME)
// TODO: Refactor booleans within `HashMap<String, boolean>`
boolean brightPointMode = false;
boolean debugMode = false;
boolean isOpticalFlow = false;
boolean isRecording = false;
boolean isActivityBar = false;
boolean isHandRect = false;
boolean isClassifying = false;
int framesPerGesture = 10;
PVector[][] motionData = new PVector[framesPerGesture][handRectWidth*handRectHeight];

float[] URQuadMotionFrames = new float[5];
int [] faceSizes = new int[5];
int [] faceRatios = new int[5];
int [] players = new int[5];
String[] activityBarText = {"", "", "", " "};
int modes=3;
float[] instrumentAmps = {1., 1., 1., 1., 1.};
String[][] faceTexts = {
  {"Beat", "Clap", "Cello + Snare", "Mod Saw", "Vocals"}, 
  {"", "", "", "", ""}, 
  {"", "", "", "", ""}
};

int recordTimer = 10;
PrintWriter output;
int currRecordFrame = 0;
String[] gestureClassification = {"none"};
String currGesture = "";

void setup() {
  size(640, 480);
  f = createFont("Arial", 16, true);
  initializeCamera();
  noFill();
  stroke(GREEN);
  strokeWeight(3);
  textSize(32);
  textAlign(LEFT, TOP);
  oscP5 = new OscP5(this, 8000);
  sonicPi = new NetAddress("127.0.0.1", 4559);
  initializeUI();
  frameRate(fps);  
  makeDataDir();
}

void makeDataDir() {
  File dataDir = new File("data");
  if (!dataDir.exists()) {

    try {
      dataDir.mkdir();
    }
    catch(SecurityException e) {
      println("You don't have permissions to create the `data` directory.");
    }
  }
}

void initializeUI() {  
  setupActivityBar();
}

void setupActivityBar() { 
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
  toSend.add(instrumentAmps[0]); // beat
  toSend.add(instrumentAmps[1]); // clap
  toSend.add(instrumentAmps[2]); // cello
  toSend.add(instrumentAmps[3]); // mod saw
  toSend.add(instrumentAmps[4]); // voices
  toSend.add(currGesture);
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
  //filter(GRAY);
  opencv.flip(OpenCV.HORIZONTAL);
  textFont(f, 16);
  //Rectangle[] facesPrev = faces;
  faces = opencv.detect();
  faces = dropDistantFaces(faces);
  Rectangle[] sortedFaces = sortFaces(faces);
  //ensureContinuity(facesPrev, faces);
  image(opencv.getOutput(), 0, 0 );

  if (isOpticalFlow) {
    opencv.calculateOpticalFlow();
    if (debugMode) opencv.drawOpticalFlow();
    // Reset stroke and text displlay
    strokeWeight(1);
    textSize(8);
    textFont(f, 16);
    drawController(faces); // Give each player an augmented reality controller
    if (isActivityBar) drawActivityBar(); // Optional
  } 
  // Reset empty players 1 and 2 x-positions.
  if (mx1 == 0) mx1 = 320/2;
  if (mx2 == 0) mx2 = 320/2;
  // Show brightest point for debugging
  drawBrightestPoint();
  drawFaces(sortedFaces);
  drawLines();
  drawPartyText();

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

void drawPartyText() {
  textFont(f, 20);
  text("Raise the ", 10, 30);
  fill(GREEN);
  text("volume", 96, 30);

  fill(WHITE);
  textFont(f, 16); // Reset
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
   * @param  faces array of faces
   */

  // Draw selector wheel with spokes
  for (int i = 0; i < faces.length && i < 5; i++) { // Limit to 5 faces for testing
    Rectangle face = faces[i];
    int controllerStartX = face.x;
    int controllerStartY = face.y + int(controllerStartOffsetY * face.height);

    // Draw volume bar below face
    stroke(RED);
    strokeWeight(3);
    int lineLength = faces[i].width * selectorPosition[i] / divisions;
    int volumeY = controllerStartY-face.height;
    line(controllerStartX, volumeY, face.x+lineLength, volumeY);

    stroke(GREEN);
    strokeWeight(1);
    int radius = face.width;
    int circleCenterX = controllerStartX + face.width/2;
    int circleCenterY = controllerStartY + face.height/2;

    // Draw wheel    
    ellipse(circleCenterX, circleCenterY, face.width, face.height);

    float innerRadius = radius * 0.45;
    float outerRadius = radius * 0.55;
    int j = selectorPosition[i]; // Default in vertical position      
    int referenceY = circleCenterY + int(innerRadius * sin(angle * j));
    int referenceX = circleCenterX + int(innerRadius * cos(angle * j));
    int targetY = circleCenterY + int(outerRadius * sin(angle * j));
    int targetX = circleCenterX + int(outerRadius * cos(angle * j));

    // Draw spokes
    line(referenceX, referenceY, targetX, targetY);

    // Draw circle indicating position of selector
    ellipse(referenceX, referenceY, 5f, 5f);

    // Get rotation around wheel (volume change)
    if (rotationFeature) getRotation(circleCenterX, circleCenterY, face, i);

    //    if (debugMode) { // Draw columns and get activity
    //      PVector[] columnActivity = getColumnActivity(circleCenterX, circleCenterY, face, i);
    //    }
    if (debugMode) detectInstrumentChange(circleCenterX, circleCenterY, face);
  }
  updateCurrInstruments(faces.length);
  readSigns(faces, controllerStartOffsetY);
}
void updateCurrInstruments(int facesPresent) {
  for (int i =0; i < facesPresent; i++) {
  }
}
void detectInstrumentChange(int circleCenterX, int circleCenterY, Rectangle face) {
  // User changes instrument if contralateral motion detected in controller
  Rectangle leftWheel = new Rectangle(circleCenterX - face.width, circleCenterY-face.height/5, face.width, face.height*2/5);
  Rectangle rightWheel = new Rectangle(circleCenterX, circleCenterY-face.height/5, face.width, face.height*2/5);

  // Draw the receptive fields for instrument change for development
  if (debugMode) {
    // Draw receptor fields for instrument change
    stroke(GRAY);
    strokeWeight(1);
    rect(leftWheel.x, leftWheel.y, leftWheel.width, leftWheel.height);
    rect(rightWheel.x, rightWheel.y, rightWheel.width, rightWheel.height);
  }
  PVector rightWheelActivity = getMotion(rightWheel, 0, false, false);
  PVector leftWheelActivity = getMotion(leftWheel, 0, false, false);

  // Draw orange horizontal volume bar in the circle
  int lineRightEnd = circleCenterX, lineLeftEnd = circleCenterX;
  if (rightWheelActivity.x > 0.01) {
    lineRightEnd = circleCenterX + int(rightWheelActivity.x * 100);
    lineRightEnd = constrain(lineRightEnd, circleCenterX, circleCenterX + face.width/2);
    stroke(ORANGE);
    line(circleCenterX, circleCenterY, lineRightEnd, circleCenterY);
  }    
  if (leftWheelActivity.x < -0.01) {
    lineLeftEnd = circleCenterX + int(leftWheelActivity.x * 100);
    lineLeftEnd = constrain(lineLeftEnd, circleCenterX-face.width/2, circleCenterX);
    stroke(ORANGE);
    line(circleCenterX, circleCenterY, lineLeftEnd, circleCenterY);
  }

  // Change instrument
  if (rightWheelActivity.x > 0.03 
    && leftWheelActivity.x < -0.03 
    && changeInstrumentCountdown == 0) {
    print("Instrument changed");
    strokeWeight(3);
    ellipse(circleCenterX, circleCenterY, face.width, face.width);
    strokeWeight(1);
    changeInstrumentCountdown = 10; // reset countdown to limit to one gesture
    String temp = faceTexts[0][0];
    // Shift instruments to the left.
    for (int k = 1; k < faceTexts[0].length; k++) {    
      faceTexts[0][k-1] = faceTexts[0][k];
    }
    faceTexts[0][4] = temp;
  }
}
PVector[] getColumnActivity(int circleCenterX, int circleCenterY, Rectangle face, int faceIndex) {
  /** Get activity of columns on the side of the controller.
   * @param  circleCenterX
   * @param  circleCenterY
   * @param  face
   * @param  faceIndex
   * @return array of average motion in each columns
   */
  PVector[] columnActivities = new PVector[2];
  int i = faceIndex;

  // Get left column activity
  PVector leftColumnUL = new PVector(circleCenterX-face.width/2 - face.width/5, circleCenterY - face.height/2);
  Rectangle leftColumn = new Rectangle(int(leftColumnUL.x), int(leftColumnUL.y), face.width/5, face.height);
  PVector leftColumnActivity = getMotion(leftColumn, i, false, false);

  stroke(GRAY);
  strokeWeight(1);
  rect(leftColumn.x, leftColumn.y, leftColumn.width, leftColumn.height);
  append(columnActivities, leftColumnActivity);
  PVector rightColumnUL = new PVector(circleCenterX + face.width/2, circleCenterY - face.height/2);
  Rectangle rightColumn = new Rectangle(int(rightColumnUL.x), int(rightColumnUL.y), face.width/5, face.height);
  PVector rightColumnActivity = getMotion(rightColumn, i, false, false);

  // Draw rotation receptive fields for debugging
  stroke(RED);
  strokeWeight(1);
  rect(rightColumn.x, rightColumn.y, rightColumn.width, rightColumn.height);
  append(columnActivities, rightColumnActivity);

  boolean isCClockRot = leftColumnActivity.y - rightColumnActivity.y > 0.05;
  boolean isClockRot = rightColumnActivity.y - leftColumnActivity.y > 0.05;
  if (isCClockRot ^ isClockRot) { // Only adjust if one but not both active 
    if (isCClockRot) adjustSelector(-1, face, i);
    if (isClockRot) adjustSelector(1, face, i);
  }

  return columnActivities;
}

void adjustSelector(int direction, Rectangle face, int facesIndex) {
  int i = facesIndex;
  if (direction < 0) {
    selectorPosition[i]--; // FIXME: replace with constrain function
    if (selectorPosition[i] < 0) selectorPosition[i] = 0;
  } else {
    selectorPosition[i]++; // FIXME: replace with constrain function    
    if (selectorPosition[i] > divisions) {
      selectorPosition[i] = divisions;
      // Draw vertial line at right side of volume bar when maximum volume is reached
      stroke(RED);
      strokeWeight(3);
      int lineLength = face.width * selectorPosition[i] / divisions;
      int volumeY = int(controllerStartOffsetY-1) * face.height + face.y;
      line(face.x+lineLength, volumeY-3, face.x+lineLength, volumeY+3);
    }
  }
  // Update Sonic Pi amplitude
  instrumentAmps[i] = float(selectorPosition[i])/float(divisions);
}
void getRotation(int circleCenterX, int circleCenterY, Rectangle face, int faceIndex) {
  /** Get rotation within controller.
   */

  // Minimal approach using extreme subspaces of quadrants    
  Rectangle upperSub = new Rectangle(
    circleCenterX-face.width/2, 
    circleCenterY-face.height/2, 
    face.width, face.height/4);
  Rectangle rightSub = new Rectangle(
    circleCenterX+face.width/4, 
    circleCenterY - face.height/2, 
    face.width/4, 
    face.height);
  Rectangle lowerSub = new Rectangle(
    circleCenterX-face.width/2, 
    circleCenterY+face.height/4, 
    face.width, face.height/4);
  Rectangle leftSub = new Rectangle(
    circleCenterX-face.width/2, 
    circleCenterY-face.height/2, 
    face.width/4, 
    face.height);

  PVector[] subExtrema = new PVector[4];
  Rectangle[] subs = {upperSub, rightSub, lowerSub, leftSub};
  for (int i = 0; i < 4; i++) {
    Rectangle sub = subs[i];
    // Draw subspaces
    stroke(LIGHTGRAY);
    if (debugMode) rect(sub.x, sub.y, sub.width, sub.height);
    PVector subMotion = getMotion(sub, 0, false, false);
    subExtrema[i] = subMotion;
  }
  activityBarText[3] = nfs(subExtrema[0].x, 1, 2);
  float min = 0.015; // Threshold or minimum
  boolean clockRot = (subExtrema[0].x > min) 
    || (subExtrema[1].y > min) 
    || (subExtrema[2].x < -min) 
    || (subExtrema[3].y < -min);
  boolean counterClockRot = (subExtrema[0].x < -min) 
    || (subExtrema[1].y < -min) 
    || (subExtrema[2].x > min) 
    || (subExtrema[3].y > min);
  if (clockRot) {   
    adjustSelector(1, face, faceIndex);
  }
  if (counterClockRot) {
    adjustSelector(-1, face, faceIndex);
  }
}

void drawFaces(Rectangle[] faces) {
  /**
   * Draw volume bar under face, update text and faceRectangle data.
   * @ param  faces Array of face rectangles
   */
  for (int i = 0; i < faces.length; i++) {  
    stroke(colorList[i % colorList.length]);

    if (i < 5) { // Draw instrument name below first 5 faces 
      if (mode == 0) { 
        text(faceTexts[mode][i], faces[i].x, faces[i].y + faces[i].height + 10);
      }
      // Update the area of faces
      faceSizes[i] = faces[i].width * faces[i].height;
    }    

    if (i == faces.length -1 || i == 4) { // Last face only      
      getFaceRatios(i);
    }
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
  stroke(RED);
  strokeWeight(4);
  noFill();
  // Draw brightest point with ellipse
  ellipse(loc.x, loc.y, 10, 10);
  // Reset stroke
  resetStroke();
}

void resetStroke() {
  stroke(RED);
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
  stroke(RED);
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
    fill(WHITE);
    text("Debug Mode: " + str(facesCount) + " faces present", 10, 10);
  }
}

Rectangle[] dropDistantFaces(Rectangle[] faces) {
  /**
   * Exclude remote or artifact faces.
   * @param  faces array of face rectangles
   * @return faces array of face rectanlges without remote faces
   */
  int maxWidth = 0;
  // Get largest (nearest) face for comparison
  for (Rectangle face : faces) {
    if (face.width > maxWidth) maxWidth = face.width;
  }

  for (int i = 0; i < faces.length; i++) {
    if (faces[i].width < 40) {
      // Skip small faces
      removeRect(faces, i);
    } else {
      //cleanFaces.e, face);
    }
  }
  return faces;
}

void checkContinuity() {
  // TODO Complete this
}

Rectangle[] removeRect(Rectangle[] faces, int item) {
  Rectangle outgoing[] = new Rectangle[faces.length - 1];
  System.arraycopy(faces, 0, outgoing, 0, item);
  System.arraycopy(faces, item+1, outgoing, item, faces.length - (item + 1));
  return outgoing;
}

void readSigns(Rectangle[] faces, float controllerStartOffsetY) {
  /**
   * Read signs on users' controllers
   * @param  faces array of player face rectangles used for position
   */
  // Draw `rows` x `columns` air-writing grid
  int rows = 8;
  int columns = 8;
  float activationThreshold = 0.015;
  PVector[] gridMotion = new PVector[rows*columns];
  stroke(GRAY);
  strokeWeight(0.3);
  for (int i = 0; i < faces.length; i++) {
    // Draw grid
    int gridX0 = faces[i].x;
    int gridY0 = faces[i].y + int(faces[i].height * (controllerStartOffsetY));

    // Show the grid
    for (int j = 1; j <= rows; j++) {
      if (debugMode) line(gridX0, gridY0 + (j * faces[i].height) / rows, gridX0 + faces[i].width, gridY0 + (j * faces[i].height) / rows);
      for (int k = 0; k < columns; k++) {
        int boxWidth = faces[i].width / columns;
        int boxHeight = faces[i].height / rows;
        int boxULX = gridX0 + k * faces[i].width/ columns;
        int boxULY = gridY0 + (j-1) * faces[i].height/ rows;
        Rectangle box = new Rectangle(boxULX, boxULY, boxWidth, boxHeight);
        PVector boxMotion = getMotion(box, j+ k * j, false, false); // FIXME: indexing
        if (boxMotion.mag() > activationThreshold && debugMode) {          
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

    if (isHandRect) {
      // Draw hand gesture rectangle
      Rectangle handRect = new Rectangle(faces[i].x + faces[i].width, faces[i].y + faces[i].height, handRectWidth, handRectHeight);
      rect(handRect.x, handRect.y, handRect.width, handRect.height);
      text("gesture:" + gestureClassification[0], 10, 160);
      if (isRecording) {
        if (recordTimer > 0) { // Between-loop timer 
          text("Countdown: " + recordTimer, 200, 50);
          recordTimer -= 1;
        } else {
          recordData(handRect, gestureClassification[0]);
        }
      }
      if (isClassifying) {
        try {
          currGesture = classifyGesture(handRect);
        text(currGesture, handRect.x, handRect.y + handRect.height + 10);
        } catch(Exception e){
          print(e);
        }
      }
    }
  }
}

String classifyGesture(Rectangle handRect) {
  PVector motion = opencv.getTotalFlowInRegion(handRect.x, handRect.y, handRect.width, handRect.height);
  print(motion.x+ "    ");
  activityBarText[0] = str(motion.x);
  activityBarText[1] = str(motion.y);
  if ( motion.x > 4000) { 
    currGesture = "slide_horizontal_right";
  } else if (motion.x < -4000) {
     currGesture = "slide_horizontal_left";
  }
  else if ( motion.y > 4000 || motion.y < -4000) {
    currGesture = "slide_vertical";
  }
  else {
    currGesture = "None";
  }
  return currGesture;
}

void recordData(Rectangle handRect, String gestureClass) {  
  PVector[] handFrameFlow = new PVector[handRect.width * handRect.height];
  // Vectorize window matrix into (`handRect.width` x `handRect.height`) x 1 column vector
  PVector flowAtPoint;            
  for (int handRow = 0; handRow < handRect.height; handRow++) {
    for (int handCol = 0; handCol < handRect.width; handCol++) {
      try {
        flowAtPoint = opencv.getFlowAt(handRect.x + handCol, handRect.y + handRow);
        handFrameFlow[handRow * 40 + handCol] = flowAtPoint;
      } 
      catch(NullPointerException e) {
        println("failure at " + handRow + handCol + handRect.x + handRect.y);
      }
    }
  }
  textFont(f, 32);
  text(currRecordFrame, 10, 60);
  motionData[currRecordFrame] = handFrameFlow;  
  currRecordFrame++;  
  if (currRecordFrame == framesPerGesture) {
    currRecordFrame = 0; // Reset
    saveData(gestureClass); // Save to file with timestamp
    recordTimer = 10; // Reset
  }
  textFont(f, 16); // Reset
}

void saveData(String gestureClass) {
  try {
    getWriter(gestureClass);
    for (int i= 0; i < framesPerGesture; i++) {    
      PVector[] frameFlow = motionData[i];    
      for (int j = 0; j < handRectWidth*handRectHeight; j++) {
        PVector pixel = frameFlow[j];      
        output.print(nfs(pixel.x, 3, 4) + "t" + nfs(pixel.y, 3, 4) + ",");
      }
      output.println();
    }
    output.flush();
    output.close();
    output = null;
  } 
  catch (NullPointerException e) {
    println("Cannot save.");
  }
}

void getWriter(String gestureClass) {
  int s = second();
  int m = minute();
  int h = hour();
  int d = day();
  int month = month();
  int y = year();
  String filename = y + "-" + nf(month, 2) + "-" + nf(d, 2) + "_" + nf(h, 2) + nf(m, 2) + nf(s, 2) + "_" + gestureClass + ".txt";
  output = createWriter("data/" + filename);
}

void keyPressed() {
  if (keyCode == UP) {
    incrementMode(1);
  } else if (keyCode == DOWN) {
    incrementMode(-1);
  } else if (key == 'b' || key == 'B') {
    brightPointMode = !brightPointMode;
    isActivityBar = !isActivityBar;
    if (!brightPointMode) activeColumn = -1;
  } else if (key == 'd') {
    debugMode = !debugMode;
    if (!isOpticalFlow) isOpticalFlow = true;
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
  } else if (key == 'r') {    
    isRecording = !isRecording;
    if (isRecording) saveData(gestureClassification[0]);
  } else if (key == 'g') {
    isHandRect = !isHandRect;    
  } else if (key == 'c') {
    isClassifying = !isClassifying;
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

  // Catch for going out of frame
  if (r.x + r.width > screenwidth) r.width = screenwidth - r.x -1;
  if (r.y + r.height > screenheight) r.height = screenheight - r.y -1;

  // Catch empty rectangle
  if (r.height < 1 || r.width < 1) {
    return motion.set(0., 0.);
  }
  try {
    if (totalMotion) // As opposed to average motion
      motion = opencv.getTotalFlowInRegion(r.x, r.y, r.width, r.height);
    else
      motion = opencv.getAverageFlowInRegion(r.x, r.y, r.width, r.height);
  }
  catch (Exception e) {
    print("`getMotion()` error");
  }
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
    String buttonText = "";
    if (activityBarText[button] != "") { // If set somewhere else (for dev only)
      buttonText = activityBarText[button];
    } else {
      PVector motion = getMotion(activityBar[button], button, true, false);
      float combinedVector = motion.mag();
      buttonText = nfs(combinedVector*10, 1, 2);
    }
    text(buttonText, activityBar[button].x + (activityButtonWidth / 4), activityBar[button].y + 5);
  }
  textFont(f, 16); // Reset font size
}
void captureEvent(Capture c) {
  c.read();
}