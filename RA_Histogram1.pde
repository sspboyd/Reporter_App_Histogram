import processing.pdf.*;
import org.joda.time.*;

JSONObject raj;

int bucketSize = 60; // in minutes
int[] buckets = new int[(24*60)/bucketSize];
int[] noBuckets = new int[(24*60)/bucketSize];

/*
What is needed for a basic histogram:
 
 Set a bucket size{
 is it a time eg, 5mins, or a number of buckets eg, 24 buckets = 1hr each?
 }
 
 Create a table of data points to be _counted_
 Counted doesnt mean include every data point. Eg, if counting number of times I'm Reporter App reporting that I've been
 productive, I don't need to include the times I said I hadn't been productive. 
 This takes the need to test the data within the histogram code. Goes into a data cleaning/preparing stage. 
 
 for each recorded report, 
 If reported productive? add table row with reported time and boolean value true? (or do I just need the time? make it a 
 straight arraylist?)
 
 histogram(bucket size, Table/HashMap of Time and values){
 for each item in the Table/HashMap{
 if 
 }
 }
 
 */



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
    size(800, 450, PDF, generateSaveImgFileName(".pdf"));
  }
  else {
    size(800, 450); // quarter page size
  }

  mainTitleF = createFont("Helvetica", 18);  //requires a font file in the data folder?
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

  DateTimeFormatter dtf = ISODateTimeFormat.dateTimeNoMillis();

  JSONArray snapshots = raj.getJSONArray("snapshots");
  int productiveRespCounter = 0;
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
      println(i + " oops, something went wrong");
    }

    JSONArray resps = snap.getJSONArray("responses");
    for (int j = 0; j < resps.size(); j+=1) { // +=100 to make sure it only shows 1 for each snap
      JSONObject resp = resps.getJSONObject(j);
      // println("resp == " + resp);
      String question = "";
      if (resp.hasKey("questionPrompt")) {  
        question = resp.getString("questionPrompt");
        // println("resp question: " + question);
      }
      else {
        println("###########################");
        println("!!!QuestionPromptMissing!!!");
        println(sdt);
        println("###########################");
      }


      if (question.equals("Have you been productive over the last couple of hours?") == true) {
        if (resp.hasKey("answeredOptions")) {  
          JSONArray ans = resp.getJSONArray("answeredOptions");
          if (ans.getString(0).equals("Yes")) {
            // println("snap #" + i + " minute of day = " + sdt.minuteOfDay());
            // println("snap #" + i + " time of day = " + sdt);
            // println("questions response # " + productiveRespCounter++ +" == " + ans.getString(0));
            int bucketNo = floor(parseInt(sdt.minuteOfDay().getAsText())/bucketSize);
            buckets[bucketNo]++;
          } 
          else {
            int bucketNo = floor(parseInt(sdt.minuteOfDay().getAsText())/bucketSize);
            noBuckets[bucketNo]++;
          }
        }
      }
    }
  }
  float rectW = PLOT_W/buckets.length;
  // noStroke();
  int maxBucketVal = max(buckets) > max(noBuckets) ? max(buckets) : max(noBuckets); 
  for (int i=0; i<buckets.length; i++) {
    println(i + " " + buckets[i]);
    float rectX = i*rectW+PLOT_X1;
    // fill(map(buckets[i],0,max(buckets),0,250));
    strokeWeight(.25);
    stroke(0);
    fill(225);
    rect(rectX, height/2, rectW, map(buckets[i], 0, maxBucketVal, 0, -PLOT_H/2));
    stroke(255);
    fill(75);
    rect(rectX, height/2, rectW, map(noBuckets[i], 0, maxBucketVal, 0, PLOT_H/2));
    fill(29);
    text(i/1, rectX+rectW/3+1, height/2+1);
    fill(250);
    text(i/1, rectX+rectW/3, height/2);
  }

  noLoop();
  println("setup done: " + nf(millis() / 1000.0, 1, 2));
}

void draw() {
  //   background(255);
  fill(100);
  stroke(0);
  textFont(mainTitleF);
  text("sspboyd", PLOT_X2-textWidth("sspboyd"), PLOT_Y2);



  if (PDFOUT) exit();
}

void keyPressed() {
  if (key == 'S') screenCap(".tif");
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

