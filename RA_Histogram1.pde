import processing.pdf.*;
import org.joda.time.*;

JSONObject raj;
JSONArray snapshots;
DateTimeFormatter dtf;

int bucketSize = 30; // in minutes
int[] buckets = new int[(24*60)/bucketSize];
int[] noBuckets = new int[(24*60)/bucketSize];

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

  dtf = ISODateTimeFormat.dateTimeNoMillis();

  snapshots = raj.getJSONArray("snapshots");


  noLoop();
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
      println(i + " oops, something went wrong");
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
        println("Missing Question Prompt? #" + ++missingQuestionPromptCount +" " + sdt);
      }

      if (questionPrompt.equals(question) == true) {
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
    // println(i + " " + buckets[i]);
    float rectX = i*rectW+PLOT_X1;
    // fill(map(buckets[i],0,max(buckets),0,250));
    strokeWeight(.25);
    stroke(0);
    fill(225);
    rect(rectX, height/2, rectW, map(buckets[i], 0, maxBucketVal, 0, -PLOT_H/2));
    stroke(255);
    fill(75);
    rect(rectX, height/2, rectW, map(noBuckets[i], 0, maxBucketVal, 0, PLOT_H/2));
  }
  // Title
  fill(0);
  text(question, PLOT_X1, PLOT_Y2);
  
  // Vertical Scale
  strokeWeight(.25);
  stroke(47);
  line(PLOT_X1, PLOT_Y1,PLOT_X1, PLOT_Y2);
  text(maxBucketVal, PLOT_X1 - textWidth(str(maxBucketVal)) - 5, PLOT_Y1 + textAscent()/2);  
  text(-maxBucketVal, PLOT_X1 - textWidth(str(maxBucketVal)) - 5, PLOT_Y2 - textAscent()/2);
  
  // Horizontal Scale (Time in hours)
  int startTime = 0;
  int finishTime = 23;
  for(int i = startTime; i < finishTime+1; i++){
      float timeX = map(i, startTime, finishTime+1, PLOT_X1, PLOT_X2);
      fill(29);
      text(str(i), timeX+1, (PLOT_H/2 + PLOT_Y1)+1+textAscent()/2);
      fill(250);
      text(str(i), timeX, (PLOT_H/2 + PLOT_Y1)+textAscent()/2);
  }
  
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

