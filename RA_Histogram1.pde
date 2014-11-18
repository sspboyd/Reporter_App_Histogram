import processing.pdf.*;
import org.joda.time.*;

JSONObject raj;
JSONArray snapshots;

DateTimeFormatter dtf;
int startTime; // starting time/point (?) of the scale in minutes
int finishTime; // finishing time/point (?) in minutes
int scaleDuration; // pretty clear, finishTime - startTime (done in setup())
int bucketSize; // what is the range of time (in minutes) covered by each histogram bucket

int[] buckets; // the yes buckets
int[] noBuckets; // clearly, the no buckets
// Not sure if I need a "timeline type" variable to specify if measuring intra day, or week or year etc...

String question;
int productiveRespCounter = 0;
int missingQuestionPromptCount = 0;
int maxBucketVal = 0;
float binW;


//Declare Globals
int rSn; // randomSeed number. put into var so can be saved in file name. defaults to 47
final float PHI = 0.618033989;

// Declare Font Variables
PFont mainTitleF;
PFont detailF;

boolean PDFOUT = false;

// Declare Positioning Variables
float margin;
float PLOT_X1, PLOT_X2, PLOT_Y1, PLOT_Y2, PLOT_W, PLOT_H;


/*////////////////////////////////////////
 SETUP
 ////////////////////////////////////////*/

void setup() {
  background(255);
  if (PDFOUT) {
    size(1350, 450, PDF, generateSaveImgFileName(".pdf"));
  }
  else {
    size(1350, 450); // quarter page size
  }

  mainTitleF = createFont("Helvetica", 20);  //requires a font file in the data folder?
  detailF = createFont("Helvetica", 14);  //requires a font file in the data folder?
  textFont(detailF);
  margin = width * pow(PHI, 7);
  println("margin: " + margin);
  PLOT_X1 = margin;
  PLOT_X2 = width-margin;
  PLOT_Y1 = margin;
  PLOT_Y2 = height - (margin + margin);
  PLOT_W = PLOT_X2 - PLOT_X1;
  PLOT_H = PLOT_Y2 - PLOT_Y1;

  rSn = 47; // 29, 18;
  randomSeed(rSn);

  dtf = ISODateTimeFormat.dateTimeNoMillis();

  // Global Vars to hold the JSON data from Reporter App
  raj = loadJSONObject("reporter-export-20140903.json");
  snapshots = raj.getJSONArray("snapshots");

  // Define Variables for histogram bucket size and scale durations
  startTime = 0 * 60; // in minutes
  finishTime = 24 * 60; // in minutes
  scaleDuration = (finishTime - startTime); 


  //  bucketSize = 60 * 24; // in minutes for a week view
  bucketSize = 30; // in minutes
  buckets = new int[scaleDuration/bucketSize];
  noBuckets = new int[buckets.length];

  binW = PLOT_W / buckets.length;

  // If measuring over the course of a day
  // no need to declare twice. Already declaring at start of draw. 
  // Maybe reconfigure later so that I'm not calculating this everytime through the draw func and only 
  // when one of the config options is changed, e.g. question, scale duration, bucket size?
  // buckets = new int[scaleDuration/bucketSize]; 
  // noBuckets = new int[scaleDuration/bucketSize];


  // Pick one of the Yes/No questions
  question = "Have you been productive over the last couple of hours?";
  // question = "Are you in front of a screen?";
  // question = "Has today been productive so far?"
  // question = "Did you eat after 9pm?";
  // question = "Are you working?";



  // noLoop();
  println("setup done: " + nf(millis() / 1000.0, 1, 2));
}


/*////////////////////////////////////////
 DRAW
 ////////////////////////////////////////*/

void draw() {
  background(255);
  renderHisto();
  renderSig();
  if (PDFOUT) exit();
}


void renderHisto() {
  buckets = new int[scaleDuration/bucketSize]; // reset array
  noBuckets = new int[buckets.length]; // reset array

  productiveRespCounter = 0;
  missingQuestionPromptCount = 0;

  // Begin parsing the JSON from Reporter App
  for (int i = 0; i < snapshots.size(); i+=1) {
    JSONObject snap = snapshots.getJSONObject(i);
    String sdts = snap.getString("date"); // sdts = snapshot datetime string
    DateTime sdt;
    try {
      sdt = dtf.parseDateTime(sdts); // sdt = snapshot date time
      // println("snap #" + i + " minute of day = " + sdt.minuteOfDay().getAsText());
      // println("snap #" + i + " dateime = " + sdt);
    } 
    catch (IllegalArgumentException e) {
      sdt = null;
      // println(i + " oops, something went wrong");
    }

    JSONArray resps = snap.getJSONArray("responses"); // grab the responses from the current snapshot
    for (int j = 0; j < resps.size(); j+=1) { // +=100 to make sure it only shows 1 for each snap
      JSONObject resp = resps.getJSONObject(j); // grab each of the responses individually
      // println("resp == " + resp);
      String questionPrompt = "";
      if (resp.hasKey("questionPrompt")) {  // test to make sure there is a question prompt associated with this response. I've found a few times that responses are missing questions!
        questionPrompt = resp.getString("questionPrompt");
        // println("resp question: " + question);
      }
      else {
        // println("Missing Question Prompt? #" + ++missingQuestionPromptCount +" " + sdt);
      }

      if (questionPrompt.equals(question) == true) {
        if (resp.hasKey("answeredOptions")) { 
          JSONArray ans = resp.getJSONArray("answeredOptions");
          if (ans.getString(0).equals("Yes")) {
            productiveRespCounter++;
            // println("snap #" + i + " minute of day = " + sdt.minuteOfDay());
            // println("snap #" + i + " time of day = " + sdt);
            // println("questions response # " + productiveRespCounter++ +" == " + ans.getString(0));
            int bucketNo = floor(parseInt(sdt.minuteOfDay().getAsText())/bucketSize); // intra day // need better var name
            // int bucketNo = sdt.getDayOfWeek()-1; // intra week
            buckets[bucketNo]++;
          } 
          else {
            productiveRespCounter++;
            int bucketNo = floor(parseInt(sdt.minuteOfDay().getAsText())/bucketSize);
            // int bucketNo = sdt.getDayOfWeek()-1;
            noBuckets[bucketNo]++;
          }
        }
      }
    }
  }
  maxBucketVal = max(buckets) > max(noBuckets) ? max(buckets) : max(noBuckets); // find the bucket with the highest # of responses
  maxBucketVal = (floor(maxBucketVal / 10) + 1) * 10;


  renderBarChart();
  renderPlusMinusPoints();
  // pctProductiveLine();
  renderPlusMinusLine();
  renderVertScale(); 
  renderHorizScale();
  renderLabels();
  renderTitles();
}

/*////////////////////////////////////////
 RENDER FUNCTIONS
 ////////////////////////////////////////*/

void renderBarChart(){
  // noStroke();
  // float rectW = binW * pow(PHI, 3);
  float rectW = binW;

  for (int i=0; i<buckets.length; i++) {
    // println(i + " " + buckets[i]);
    float rectX = i * binW + (binW / 2) + (-rectW / 2) + PLOT_X1;
    // fill(map(buckets[i],0,max(buckets),0,250));
    noStroke();
    fill(0, 47);
    rect(rectX, PLOT_X1 + (PLOT_H / 2), rectW, map(buckets[i], 0, maxBucketVal, 0, -PLOT_H / 2));
    // stroke(255);
    fill(0, 123);
    rect(rectX, PLOT_X1 + (PLOT_H / 2), rectW, map(noBuckets[i], 0, maxBucketVal, 0, PLOT_H / 2));
  }
}

void pctProductiveLine(){
  // Plus / Minus trend line
  noFill();
  strokeWeight(2);
  stroke(0, 76);
  beginShape();
  // extra vertex added so that line starts on the first bucket
  float pmv = buckets[buckets.length-1] / (buckets[buckets.length-1] + noBuckets[buckets.length-1]*1.0);
  float pmvY = map(pmv, 1, 0, PLOT_Y1, PLOT_Y2);
  float pmvX = PLOT_X1 - binW/2;
  curveVertex(pmvX, pmvY);

  for (int i=0; i<buckets.length; i++) {
    pmv = buckets[i] / (buckets[i] + noBuckets[i] * 1.0);
    pmvY = map(pmv, 1, 0, PLOT_Y1, PLOT_Y2);
    pmvX = map(i, 0, buckets.length, PLOT_X1, PLOT_X2)+binW/2;
    // fill(0);
    // ellipse(pmvX, pmvY, binW/2, binW/2);
    curveVertex(pmvX, pmvY);
  }
  // extra vertex added so that the line ends on the last bucket
  pmv = buckets[0] / (buckets[0] + noBuckets[0]);
  pmvY = map(pmv, 1, 0, PLOT_Y1, PLOT_Y2);
  pmvX = PLOT_X2 + binW/2;
  curveVertex(pmvX, pmvY);
  endShape();
}

void renderPlusMinusLine(){
  // Plus / Minus trend line
  noFill();
  strokeWeight(2);
  stroke(0, 76);
  beginShape();
  // extra vertex added so that line starts on the first bucket
  float pmv = buckets[buckets.length-1] - noBuckets[buckets.length-1];
  float pmvY = map(pmv, maxBucketVal, -maxBucketVal, PLOT_Y1, PLOT_Y2);
  float pmvX = PLOT_X1 - binW/2;
  curveVertex(pmvX, pmvY);

  for (int i=0; i<buckets.length; i++) {
    pmv = buckets[i]-noBuckets[i];
    pmvY = map(pmv, maxBucketVal, -maxBucketVal, PLOT_Y1, PLOT_Y2);
    pmvX = map(i, 0, buckets.length, PLOT_X1, PLOT_X2)+binW/2;
    // fill(0);
    // ellipse(pmvX, pmvY, binW/2, binW/2);
    curveVertex(pmvX, pmvY);
  }
  // extra vertex added so that the line ends on the last bucket
  pmv = buckets[0]-noBuckets[0];
  pmvY = map(pmv, maxBucketVal, -maxBucketVal, PLOT_Y1, PLOT_Y2);
  pmvX = PLOT_X2 + binW/2;
  curveVertex(pmvX, pmvY);
  endShape();
}

void renderPlusMinusPoints(){
  // Plus / Minus trend line
  // extra vertex added so that line starts on the first bucket
  float pmv, pmvY, pmvX;
  // float circDia = binW * pow(PHI,3); // too big when binW is large
  float circDia = 7;
  for (int i=0; i<buckets.length; i++) {
    pmv  = buckets[i] - noBuckets[i];
    pmvX = map(i, 0, buckets.length, PLOT_X1, PLOT_X2) + (binW / 2);
    pmvY = map(pmv, maxBucketVal, -maxBucketVal, PLOT_Y1, PLOT_Y2);
    fill(255, 200);
    stroke(29);
    strokeWeight(0.5);
    ellipse(pmvX, pmvY, circDia, circDia);
    }  
}

void renderVertScale(){
  // Vertical Scale
  strokeWeight(0.25);
  stroke(0, 29);
  line(PLOT_X1, PLOT_Y1, PLOT_X1, PLOT_Y2);
  fill(0, 76);
  textFont(detailF);
  text(maxBucketVal, PLOT_X1 - textWidth(str(maxBucketVal)) - 5, PLOT_Y1 + textAscent()); // Yes top scale #
  text("YES", PLOT_X1 - textWidth("YES") - 5, PLOT_Y1 + (PLOT_H / 4));
  text(maxBucketVal, PLOT_X1 - textWidth(str(maxBucketVal)) - 5, PLOT_Y2 - 0); // No top scale #
  text("NO", PLOT_X1 - textWidth("NO") - 5, PLOT_Y2 - (PLOT_H / 4));
}

void renderHorizScale(){
  // Horizontal Scale (Time in hours)
  stroke(47);
  strokeWeight(.25);
  line(PLOT_X1, PLOT_Y1 + (PLOT_H / 2), PLOT_X2, PLOT_Y1 + (PLOT_H / 2));
  float timeX;
  textFont(detailF);
  for(int i = startTime / 60; i < finishTime / 60; i++){ // div by 60 to convert to hours
    timeX = map(i, startTime / 60, finishTime / 60, PLOT_X1, PLOT_X2) + (binW / 2);
    fill(0, 76);
    text(str(i), timeX - textWidth(str(i)) / 2, PLOT_Y2 + textAscent() + 2);
    stroke(0, 76);
    strokeWeight(0.25);
    line(timeX, PLOT_Y1, timeX, PLOT_Y2); // almost but not quite either
  }
}

void renderLabels(){
  if(mouseX > PLOT_X1 && mouseX < PLOT_X2 && mouseY > PLOT_Y1 && mouseY < PLOT_Y2){
    // print("In the box!");
    float labelX, labelY;
    // labelX = mouseX;
    int bucketIndx = floor((mouseX - PLOT_X1) / binW);
    labelX = PLOT_X1 + (bucketIndx * binW) + (binW / 2);
    float pmv = buckets[buckets.length-1] - noBuckets[buckets.length-1];
    pmv = buckets[bucketIndx] - noBuckets[bucketIndx];
    labelY = map(pmv, maxBucketVal, -maxBucketVal, PLOT_Y1, PLOT_Y2);
    String labelText = "Yes: " + buckets[bucketIndx] + "\nNo: " + noBuckets[bucketIndx];
    // String labelText = "No: " + noBuckets[bucketIndx];
    fill(255,123);
    noStroke();
    rect(labelX, labelY-18, 100, 47);
    fill(0,227);
    float circDia = binW * pow(PHI, 3);
    ellipse(labelX, labelY, circDia, circDia);
    fill(0);
    textFont(detailF);
    text(labelText, labelX + 11, labelY);
  }
}

void renderTitles(){
  // Title
  fill(0);
  textFont(mainTitleF);
  text("\"" + question + "\" " + productiveRespCounter + " responses.", PLOT_X1, PLOT_Y2+margin);
}

void renderSig(){
  fill(100);
  stroke(0);
  textFont(detailF);
  text("sspboyd", PLOT_X2-textWidth("sspboyd"), PLOT_Y2 + margin);
}

void drawFreqCurve(){
  // draws a line representing the percentage of times an answer is given during a period of time
  // eg. 29% yes in bin 1, 47% yes in bin 2, 76% yes in bin 3...
/*
  for (int i = 0; i < buckets.length; ++i) {
    if(i=0){
      wrap around value to be used
    } else if(i=buckets.length-1){
      use wrap around value...
    }
    // get the x,y values for each value in the buckets. 
    // probably a good idea to caluclate these once and then use the calc'd values 
    // calculate colour and transparency forthe segment
    stroke(...);
    curve(bucketVal[i-1].x, bucketVal[i-1].y, bucketVal[i] .....);
    
  }
  */
}

void keyPressed() {
  if (key == 'S') screenCap(".tif");

  if (key == 'L'){
    println("bucketSize == " + bucketSize);
    println("buckets == " + buckets.length);
    println("noBuckets == " + noBuckets.length);
    for (int i = 0; i < buckets.length; ++i) {
      println("Yes bucket #" + i + " == " + buckets[i]);
      println("No bucket  #" + i + " == " + noBuckets[i]);
    }
  }
}

void mousePressed() {
}

/*////////////////////////////////////////
 UTILITY FUNCTIONS
 ////////////////////////////////////////*/

String generateSaveImgFileName(String fileType) {
  String fileName;
  // save functionality in here
  String outputDir = "out/";
  String sketchName = getSketchName() + "-";
  String randomSeedNum = "rS" + rSn + "-";
  String dateTimeStamp = "" + year() + nf(month(), 2) + nf(day(), 2) + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
  fileName = outputDir + sketchName + dateTimeStamp + randomSeedNum + fileType;
  return fileName;
}

void screenCap(String fileType) {
  String saveName = generateSaveImgFileName(fileType);
  save(saveName);
  println("Screen shot saved to: " + saveName);
}

String getSketchName() {
  String[] path = split(sketchPath, "/");
  return path[path.length-1];
}