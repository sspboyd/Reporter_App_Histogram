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


//Declare Globals
int rSn; // randomSeed number. put into var so can be saved in file name. defaults to 47
final float PHI = 0.618033989;

// Declare Font Variables
PFont mainTitleF;

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
    size(1200, 450); // quarter page size
  }

  mainTitleF = createFont("Helvetica", 20);  //requires a font file in the data folder?
  textFont(mainTitleF);
  margin = width * pow(PHI, 6);
  println("margin: " + margin);
  PLOT_X1 = margin;
  PLOT_X2 = width-margin;
  PLOT_Y1 = margin;
  PLOT_Y2 = height-margin;
  PLOT_W = PLOT_X2 - PLOT_X1;
  PLOT_H = PLOT_Y2 - PLOT_Y1;

  rSn = 47; // 29, 18;
  randomSeed(rSn);


  raj = loadJSONObject("reporter-export-20140903.json");

  dtf = ISODateTimeFormat.dateTimeNoMillis();

  snapshots = raj.getJSONArray("snapshots");

  // Define Variables for histogram bucket size and scale durations
   startTime = 0 * 60; // in minutes
   finishTime = 24 * 60; // in minutes
   scaleDuration = (finishTime - startTime); 


  //  bucketSize = 60 * 24; // in minutes for a week view
   bucketSize = 30; // in minutes

  // If measuring over the course of a day
  // no need to declare twice. Already declaring at start of draw. 
  // Maybe reconfigure later so that I'm not calculating this everytime through the draw func and only 
  // when one of the config options is changed, e.g. question, scale duration, bucket size?
  // buckets = new int[scaleDuration/bucketSize]; 
  // noBuckets = new int[scaleDuration/bucketSize];



  // noLoop();
  println("setup done: " + nf(millis() / 1000.0, 1, 2));
}

void draw() {

  background(255);

  // renderHisto("Has today been productive so far?");
  renderHisto("Have you been productive over the last couple of hours?");
  // renderHisto("Did you eat after 9pm?");
  // renderHisto("Are you working?");


  fill(100);
  stroke(0);
  textFont(mainTitleF);
  text("sspboyd", PLOT_X2-textWidth("sspboyd"), PLOT_Y2);

  if (PDFOUT) exit();
}


void renderHisto(String _q) {
  buckets = new int[scaleDuration/bucketSize];
  noBuckets = new int[scaleDuration/bucketSize];

  String question = _q;
  int productiveRespCounter = 0;
  int missingQuestionPromptCount = 0;
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

    JSONArray resps = snap.getJSONArray("responses");
    for (int j = 0; j < resps.size(); j+=1) { // +=100 to make sure it only shows 1 for each snap
      JSONObject resp = resps.getJSONObject(j);
      // println("resp == " + resp);
      String questionPrompt = "";
      if (resp.hasKey("questionPrompt")) {  
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

  float rectW = PLOT_W/buckets.length;
  // noStroke();
  int maxBucketVal = max(buckets) > max(noBuckets) ? max(buckets) : max(noBuckets); // find the bucket with the highest # of responses
  for (int i=0; i<buckets.length; i++) {
    // println(i + " " + buckets[i]);
    float rectX = i * rectW + PLOT_X1;
    // fill(map(buckets[i],0,max(buckets),0,250));
    strokeWeight(.25);
    stroke(0);
    fill(225);
    rect(rectX, height/2, rectW, map(buckets[i], 0, maxBucketVal, 0, -PLOT_H/2));
    stroke(255);
    fill(75);
    rect(rectX, height/2, rectW, map(noBuckets[i], 0, maxBucketVal, 0, PLOT_H/2));
  }

for (int k = 0; k < buckets.length; k++) {
      // println("buckets["+k+"] == " + buckets[k]);
}
  
  // Plus / Minus trend line
  noFill();
  strokeWeight(4);
  stroke(50);
  beginShape();
  // extra vertex added so that line starts on the first bucket
    float pmv = buckets[buckets.length-1] - noBuckets[buckets.length-1];
    float pmvY = map(pmv, maxBucketVal, -maxBucketVal, PLOT_Y1, PLOT_Y2);
    float pmvX = PLOT_X1 - rectW/2;
    curveVertex(pmvX, pmvY);
  
  for (int i=0; i<buckets.length; i++) {
   pmv = buckets[i]-noBuckets[i];
   pmvY = map(pmv, maxBucketVal, -maxBucketVal, PLOT_Y1, PLOT_Y2);
   pmvX = map(i, 0, buckets.length, PLOT_X1, PLOT_X2)+rectW/2;
    // fill(0);
    // ellipse(pmvX, pmvY, rectW/2, rectW/2);
    curveVertex(pmvX, pmvY);
  }
  // extra vertex added so that the line ends on the last bucket
     pmv = buckets[0]-noBuckets[0];
     pmvY = map(pmv, maxBucketVal, -maxBucketVal, PLOT_Y1, PLOT_Y2);
     pmvX = PLOT_X2 + rectW/2;
    curveVertex(pmvX, pmvY);
  endShape();
  
  
  // Title
  fill(0);
  text(question + " " + productiveRespCounter + " responses.", PLOT_X1, PLOT_Y2);
  
  // Vertical Scale
  strokeWeight(.25);
  stroke(47);
  line(PLOT_X1, PLOT_Y1,PLOT_X1, PLOT_Y2);
  text(maxBucketVal, PLOT_X1 - textWidth(str(maxBucketVal)) - 5, PLOT_Y1 + textAscent()/2);  
  text(maxBucketVal, PLOT_X1 - textWidth(str(maxBucketVal)) - 5, PLOT_Y2 - textAscent()/2);
  
  // Horizontal Scale (Time in hours)
  for(int i = startTime/60; i < (finishTime) / 60; i++){
      float timeX = map(i, startTime/60, finishTime/60, PLOT_X1, PLOT_X2);
      fill(29);
      text(str(i), timeX+1, (PLOT_H/2 + PLOT_Y1)+1+textAscent()/2);
      fill(250);
      text(str(i), timeX, (PLOT_H/2 + PLOT_Y1)+textAscent()/2);
  }
  
 // Draw labels
if(mouseX > PLOT_X1 && mouseX < PLOT_X2 && mouseY > PLOT_Y1 && mouseY < PLOT_Y2){
  // print("In the box!");
  float labelX, labelY;
  // labelX = mouseX;
  int bucketIndx = floor((mouseX - PLOT_X1) / rectW);
  labelX = PLOT_X1 + (bucketIndx * rectW) + (rectW / 2);
  pmv = buckets[bucketIndx]-noBuckets[bucketIndx];
  labelY = map(pmv, maxBucketVal, -maxBucketVal, PLOT_Y1, PLOT_Y2);
  String labelText = "Yes: " + buckets[bucketIndx] + "\nNo: " + noBuckets[bucketIndx];
  fill(255,227);
  noStroke();
  rect(labelX, labelY-18, 100, 47);
  fill(0,227);
  ellipse(labelX, labelY, 10, 10);
  fill(0);
  text(labelText+11, labelX, labelY);
}


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

