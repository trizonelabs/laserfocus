/*laserfocus_testbed_blob210303 //<>// //<>// //<>// //<>// //<>// //<>//
 20210301rh
 20210304 normalze print data 
 proj.laserfocus
 
 test_bd_image.pde
 test detect blobs
 20210228rh
 20210301rh blob filter added
 ref.https://github.com/AndreasRef/blobDetectionTools/blob/master/DepthThresholdBlobButtons/DepthThresholdBlobButtons.pde
 Superfastblur & newBlobDetectedEvent
 https://github.com/AndreasRef/blobDetectionTools/blob/master/DepthThresholdBlobButtons/DepthThresholdBlobButtons.pde
 */

import blobDetection.*;
BlobDetection theBlobDetection;

import gab.opencv.*;
OpenCV ocv;

import processing.serial.*;
import java.net.*;
import java.io.*;

import java.io.IOException;
/*
 import java.nio.file.Files;
 import java.nio.file.Path;
 
 import java.io.FilenameFilter;
 import java.io.InputStream;
 */
import java.util.Arrays;
import java.util.ListIterator;
import java.util.Date;

//PGraphics img;
PImage img, src;

/* datafiles */

String  datRootDir = "C:/Users/T71597/Documents/Processing/Data/", //"C:\\Users\\RH\\Documents\\Processing\\Data\\Laserfocus\\Camera Roll\\",
  datWorkDir = "testBlobs/", //"redauto1/", // "DarkAll/",  //"Dark/",   // "Filter1/"
  datWorkFullDir = datRootDir + datWorkDir;

File datWorkPath = new File(datWorkFullDir);
int picNum = 0;
int picIdx = 0;
String[] datFN;  // array dataFileName 

String workImageFileName;  // main loop woking

/* dowload source */
static final String httpServerURL = "http://192.168.4.1/", // URL of camera http server
  captExt = ".jpg";

String pfname;

String dateStamp = str(year()) + "." + str(month()) + "." + str(day()) +"."  + str(hour())+ str(minute())+ str(second())+ "-" + captExt;

PFont f;

PrintWriter fp ;   // = createWriter("find_edges_report.txt"); 
String reportFile = datWorkFullDir + "blob_data_capt.txt";

//################# serial GBRL 
Serial myPort; //create object from Serial class
String inString;  //data rx frm serialport
byte bytes;
char LF = 10, CR = 13 ;  //ASCII linefeed .. end of serial record/message

int num_ports;
String serialList;                // list of serial ports
int numSerialPorts = 0;          // number of serial ports in the list

String serial_list;                // list of serial ports
int serial_list_index = 0;         // currently selected serial port 
int num_serial_ports = 0;          // number of serial ports in the list

/* GBRL commands
 Z-axis : jogging 
 $J=G91G21Z1F4978  Z 1 Speed F4978
 $J=G91G21Z1F1000  Z1 F 1000
 $J=G91G21 Z-10 F100  Z-10 speed F100 (slow)
 jCmd = $J=G91G21 + axis(X,Y,Z) + -travel (mm) F( pulses )  std =   4978  slow 1000 , 100,1
 */
String jCmd="$J=G91G21", 
  axis="Z", 
  travel="10", 
  speed="1000";

String CMD=jCmd+axis+travel+"F"+speed;

//#######################################
//error Blob[] blobs = ocv.blobs( 10, width*height/2, 100, true, OpenCV.MAX_VERTICES*4 );

int posIdx = 0;  // position index ..filename
float currBlobCnt = 0.0f;
/*functions ####################################### */

void keyPressed() {  // return value  in global "key" var
  if (!keyPressed) return;
  if (keyCode == 0) return;

  // println(" keys : UP DOWN RETURN ESC");
  // println("key ["+key+"] (character code "+keyCode+") is being pressed!");
  switch(key) {
  case 'a':  //autoBlob
    println("autoBlob start");
    autoBlob(maxFiles);
    break;
  case 'g' :  //download the file name with index
    key=0; 
    getCam2Img();
    draw();
    break;
  case 'j' :
    print("jpd2image src");
    cam2img();
    println(" done");
    ;
    break;
  case 'l' :
    println("luninosity:", luminosityThreshold);
    break;
  case 'k' :
    luminosityThreshold -= 0.1;
    println("luninosity dec 0.1:", luminosityThreshold);
    break;
  case 'o' :
    luminosityThreshold += 0.1;
    println("luninosity inc 0.1:", luminosityThreshold);
    break;
  case 'b' :  //blobalazie file
    doBlob(src);  //doBloblarize()
    break;
  case 't' :  //autoTest
    println("autoTest started");
    autoTest();  //
    break; 
  case 'w':  // laser forward
    gStep(1.0);
    break;
  case  'x' :
    gStep(-1.0);
    break; 
  case 'r': 
    println("brenner1d :", brenner1D(src));
    break;
  case UP : 
    println("key : UP");  
    break;
  case DOWN : 
    println("key : DOWN");  
    break;
  case 10 : 
    println("key : RETURN");  
    break;
  case LEFT : 
    println("key : LEFT");  
    break;
  case RIGHT : 
    println("key : RIGHT");  
    break;
  case ESC :
    println("key : ESC 27");  
    break;
  default : 
    println("unknown key", keyCode);
    break;
  }//switch
} //keypressed

// Creates a new File instance by converting the given pathname string into an abstract pathname.
static final FilenameFilter JPGFILES = new FilenameFilter() {
  boolean accept(File f, String s) {
    return s.endsWith(".jpg");
  }
};

boolean checkPort(String pn) //check COM16 is in portlist
{
  int sll = Serial.list().length;
  for (int i = 0; i < sll; i++) {
    if ( pn == Serial.list()[i] );  
    {
      System.out.println("port :"+ pn + "found"); 
      return true;
    } //if
  } //for
  System.out.println("port :"+ pn + "NOT found");
  return false;
} //checkPort

void serialEvent(Serial p)
{
  inString = p.readStringUntil(LF);  // '\n'
  if (inString == null) return; 
  inString.trim();  //leading & trailing whitespaces
  // System.out.print("inString rx:" + inString);
} //serialEvent

public static void downloadFile(String hcmd, String fileName) {
  try {
    URL url = null;
    URLConnection con = null;
    int i;
    url = new URL(httpServerURL + hcmd);
    con = url.openConnection();
    con.setReadTimeout(5*1000);
    File file = new File(fileName); // goes to C:\Program Files\processing-3.5.4
    BufferedInputStream bis = new BufferedInputStream(con.getInputStream());
    BufferedOutputStream bos = new BufferedOutputStream(new FileOutputStream(file));
    while ((i = bis.read()) != -1) {
      bos.write(i);
    }
    bos.flush();
    bis.close();
  } 
  catch(MalformedURLException e) {
    e.printStackTrace();
  } 
  catch(IOException e) {
    e.printStackTrace();
  }
}    

void cam2img() {
  //src = loadImage("http://192.168.4.1/capture?", "jpg");
  src = requestImage("http://192.168.4.1/capture?", "jpg");
  if ( src.width == -1 ) {
    println("loadimage jpeg2cam error");
  }
}

float luminosityThreshold = 0.5f;

void httpESP32Cmd(String varName, String varVal) {
  //send http:// control command to webserver ESP32 webswerver interface
  // http://<ip>/control?var=<variableName>&val=<varValue>
  String hcmd = "/control?var=" + varName + "&val=" + varVal;
  println("downloadFile :", hcmd);
  downloadFile(hcmd, "");
}

//################ Data 

class PosFile {    // stores blobdata postion and filename
  int index;
  float position;
  String fileName;
  float blobPixels;
  float min;
};

PosFile[] posfile;
int maxFiles = 50;
float gStepSpread= 1.0;

// data Array store measurements to normalize data   o..1  (val-minData)/(maxData-minData)
// analog to print file data struct
//    fp.println(str(i) + ";" + str(dualf[1]) + ";" +  str(dualf[0]) + ";" + str(brennerVal));

int position[];  //laser position
float blobNum[]; // number of blobs detected
float blobPix[];  // pixel in biggest blob 
float brVal[];  // brenner image analysis value 

// ==================================================
// setup()
// ==================================================
void setup()
{
  //screen
  size (1024, 768);
  f = createFont("Arial", 50);
  //error ??? PrintWriter fp =  new createWriter(reportFile);
  fp = createWriter(reportFile);

  // datafiles  
  posfile = new PosFile[maxFiles];  // array of position files create object
  for (int i = 0; i < maxFiles; i++) posfile[i] = new PosFile(); // create array

  /*
  blobDatAr = new BlobData[maxFiles];  // init
   for (int i = 0; i < maxFiles; i++) blobDatAr[i] = new BlobData(); // create array
   */
  /* class BlobData {    
   int position;  //laser position
   float blobNum; // number of blobs detected
   float blobPix;  // pixel in biggest blob 
   float brVal;  // brenner image analysis value 
   */

  datFN = datWorkPath.list(JPGFILES); // getDatFiles();
  picNum = datFN.length; // maxIdx = picNum -1 
  //fp.println("DatFile,nZCnt,brsum,brmean,stdev"); // prepare csv data print

  printArray(Serial.list());  // List all the available serial ports:
  serialList = Serial.list()[serial_list_index];
  //println(Serial.list());
  println(Serial.list().length);
  num_serial_ports = Serial.list().length;  // get the number of serial ports in the list

  String portName = "COM15";  // Serial.list()[0];
  if ( checkPort(portName)==true ) {
    System.out.println("port :"+ portName + "found");
  } else {
    System.out.println("port :"+ portName + "NOT found");
  } //else

  myPort = new Serial(this, portName, 115200);  
  myPort.clear();
  myPort.bufferUntil(LF); //buff er until linefeed (println)

  final String captHref = httpServerURL + "capture";  // "http://192.168.4.1/capture";
}

// ==================================================
// draw()
// ==================================================
void draw()
{
  //noloop
} // draw

/*##############################################################*/

void autoTest() { // get image ,blobulize ,brenner step
  maxFiles=30;
  float posCnt = 0;
  float stepSize = 0.1;
  float brennerVal= 0;

  float[] dualf = new float[2]; //blobPixMax, blobsCnt
  float position[] = new float[maxFiles];
  float blobPix[] = new float[maxFiles];  // pixel in biggest blob 
  float brVal[] = new float[maxFiles];
  float blobNum[] = new float[maxFiles];

  fp.println("position;blobsCnt;blopPIxMax;brennerVal");  // create reportfile
  for (int i=0; i < maxFiles; i++ ) {
    //cam2img();  // pic to src image  //src = loadImage("http://192.168.4.1/capture?", "jpg");  //src = requestImage("http://192.168.4.1/capture?", "jpg");
       println("i:",i,"position/posCnt:",posCnt);
      cam2img();
      int ret = 0, retMax=10;
      while ( ret < retMax ) {
        if  ( src.width > 0 ) {
          println("src loaded:", src.width);
          break; //ret = 10;
        }else{
          println("src.width = ", src.width, "  ..wait for requestimage delay 20000");
          delay(1000);
        } //else
      } //WEND
    // } //for rxcnt  recou8nt loop 

  doBlob(src);
  dualf = anaBlobs();  // number of pixels in smalles blob   nuber of blobs

  if ( dualf[1] > 0 ) { 
    brennerVal = brenner1D(src);
    println("cnt:", i, 
      "blobPixMax:", dualf[0], 
      "blobPixMax-pixel:", dualf[0]*width*height, 
      "blowbsCnt:", dualf[1] ); 
    // "pix/blowcnt:", (dualf[0]/dualf[1]) ); 
    // (dualf[0]/dualf[1]*width*height) );  division zero error
    //fp.println( str(posCnt) + ";" + str( dualf[1]) + ";" +  str(dualf[0]) + ";" + str(brennerVal) );
    // fill datAr with values to normalize
    position[i] = posCnt; //laser position
    blobNum[i] = dualf[1]; // number of blobs detected
    blobPix[i] = dualf[0];  // pixel in biggest blob 
    brVal[i] = brennerVal;  // brenner image analysis value 
    gStep(stepSize);
    posCnt += stepSize;
  } //if  blobCnt >0 
  delay(10);
} // steps maxFiles

//normalize in 0..1  & add to print  (x-min(x)) / ( max(x)-min(x) )
float maxBlobPix = max(blobPix);
float minBlobPix = min(blobPix);
float maxbrVal = max(brVal);
float minbrVal = min(brVal);
for ( int cnt=0; cnt < maxFiles; cnt++) {
  blobPix[cnt] = ( blobPix[cnt]-minBlobPix ) / ( maxBlobPix-minBlobPix );
  brVal[cnt] = ( brVal[cnt]-minbrVal ) / (maxbrVal-minbrVal);
  fp.println( str(position[cnt]) + ";" + str(blobNum[cnt]) + ";" + str(blobPix[cnt]) + ";" + str(brVal[cnt]) );
  println( str(position[cnt]) + ";" + str(blobNum[cnt]) + ";" + str(blobPix[cnt]) + ";" + str(brVal[cnt]) );
}; //for cnt though arrays

fp.flush();  //close prinf
fp.close();

println("autoTest ended");
}

//##########################################
void autoBlob(int tries) {
  float position=0.0;
  int phase =0;
  float min_blobPixels=1000000.0;  // garantie next is lower

  gStepSpread=1.0;
  posIdx=0;

  while ( posIdx < maxFiles-1 )
  {              
    posfile[posIdx].position=position;
    //getCam2Img();
    cam2img();
    doBlob(src); //doBloblarize();  //store data in posfile arrary

    println( "phase:", phase, "posIdx:", posIdx, "position:", posfile[posIdx].position, 
      "[posIdx].blobPixels:", nf(posfile[posIdx].blobPixels, 0, 8), 
      //"[posIdx-1].blobPixels:",nf( posfile[posIdx-1].blobPixels,0,8),
      //"diff:",nf( (posfile[posIdx].blobPixels - posfile[posIdx-1].blobPixels),0,8),
      "[posIdx].min:", nf( posfile[posIdx].min, 0, 8), 
      "min_diff:", nf( (posfile[posIdx].blobPixels - min_blobPixels ), 0, 8), 
      "min:", nf( min_blobPixels, 0, 8 )
      );

    if (posfile[posIdx].blobPixels >  0.0 )
    {   
      //if (  posfile[posIdx].blobPixels < (min_blobPixels)*1.05 )  //found pixelcnt lower //smaller found = new smallest
      if ( ( posIdx >0 ) && ( posfile[posIdx].blobPixels > posfile[posIdx-1].blobPixels ))
      {  // less pixels
        phase = 0; // reset phase if found lower value  
        min_blobPixels = posfile[posIdx].blobPixels; // store lowest measured pixelcount;
        posfile[posIdx].min = posfile[posIdx].blobPixels;
      } else  // more pixels found 
      {
        phase ++;
        println("pixcn higher phase:", phase, "min_blobPixels:", min_blobPixels, posfile[posIdx].fileName);
        switch(phase) 
        {
        case 0:
          gStepSpread=1.0;
          break;
        case 1: // first time new pixcnt higher dont store pixcount mib
          phase ++;
          break; //skip handling .....back to loop find lower pixcnt
        case 2 : //second time higher pixcnt
          gStepSpread=-0.1;  // try switch to "slowstep back"
          phase ++;
          break;
        case 3 :
          println("break autoBlob phase:", phase);
          gStepSpread=-0.1;
          phase = 0;
          exit();//break;
        } //switch
      }; //else new is bigger blobpixels

      posIdx++;
      gStep(gStepSpread); // suppose get smaller blob /pixCnt
      position +=gStepSpread;
    } // blobPix > 0
    else
    {
      println("blobPixel = 0 !!");
    }
  }//while for

  println("autoBlob finished with posIdx:", posIdx);
  println("printing posfile");
  for (int cnt = 0; cnt < posIdx; cnt++ ) {
    fp.println(str(cnt) +";"+str(posfile[cnt].position) +";"+ posfile[cnt].fileName + ";" + str(posfile[cnt].blobPixels) + ";" + str(posfile[cnt].min) );
    println(str(cnt) +" "+str(posfile[cnt].position) +" "+ posfile[cnt].fileName + " " + str(posfile[cnt].blobPixels) + " " + str(posfile[cnt].min) );
  };
  fp.flush();
  fp.close(); // close printer
} //autoBlob

void getCam2Img() { // use GLOBAL src image
  workImageFileName=camPic2File(posIdx);  // save cam pic to file
  posfile[posIdx].fileName=workImageFileName;
  src = loadImage(datWorkFullDir + workImageFileName, "jpg");  // load file to image
  image(src, 0, 0); // prepare to show loaded image ?
} //getPicFile

String camPic2File(int fileIndex )   //load image file from camera to file 
{
  String fname = str(fileIndex) + "-blob-Capture.jpg";
  //println("downloadFile:","capture",datWorkFullDir + fname);
  downloadFile("capture", datWorkFullDir + fname);
  return fname;
}

void gStep(float gStepSpread) {  // set index
  doGcmd(str(gStepSpread));
} //gstep

void doGcmd(String stepDir) { 
  axis = "Y";
  speed = str(1000);
  CMD = jCmd+axis+stepDir+"F"+speed;
  System.out.println("GBRL:" +CMD );
  myPort.write(CMD+"\n");
  delay(100);
  if (inString.contains("error")) {
    myPort.write("$X"+"\n");
  }
  while (!inString.contains("ok")) {
    println("wait for ok ... delay 10");
    delay(10);
  } //while
} //doGcmd

void doBlob(PImage simg) {  // saves anablob number of blob-pixels to   posfile[posIdx].blobPixels=dualf[0];
  image(src, 0, 0);

  theBlobDetection = new BlobDetection(simg.width, simg.height); 
  theBlobDetection.setPosDiscrimination(false);
  theBlobDetection.setThreshold(luminosityThreshold); //0.38  test 0.6 0.t-less  ; 
  // will detect bright areas whose luminosity > luminosityThreshold (reverse if setPosDiscrimination(false);
  theBlobDetection.activeCustomFilter(this);  // filter small blobs
  theBlobDetection.computeBlobs(simg.pixels);
  drawBlobsAndEdges(true, true);
  loadPixels();
  /* Loads the pixel data of the current display window into the pixels[] array. 
   This function must always be called before reading from or writing to pixels[]. 
   Subsequent changes to the display window will not be reflected in pixels until loadPixels() is called again. 
   */
  float[] dualf = new float[2]; //blobPixMax, blobsCnt
  dualf = anaBlobs();  // number of pixels in smalles blob   nuber of blobs
  println("anablobs dualf:blobPixMax:", dualf[0], "blobPixMax-pixel:", dualf[0]*width*height, "blowbsCnt:", dualf[1], "pix/blowcnt:", (dualf[0]/dualf[1]), (dualf[0]/dualf[1]*width*height) );
  posfile[posIdx].blobPixels=dualf[0];
}

// ==================================================
// drawBlobsAndEdges()
// ==================================================
void drawBlobsAndEdges(boolean drawBlobs, boolean drawEdges)
{
  float bpixCnt = 0;
  noFill();
  Blob b;
  EdgeVertex eA, eB;
  // println("theBlobDetection.getBlobNb():", theBlobDetection.getBlobNb());
  for (int n=0; n<theBlobDetection.getBlobNb(); n++)
  {
    b=theBlobDetection.getBlob(n);
    if (b!=null)
    {
      // Edges
      if (drawEdges)
      {
        strokeWeight(2);
        stroke(0, 255, 0);
        for (int m=0; m<b.getEdgeNb(); m++)
        {
          eA = b.getEdgeVertexA(m);
          eB = b.getEdgeVertexB(m);
          if (eA !=null && eB !=null)
            line(
              eA.x*width, eA.y*height, 
              eB.x*width, eB.y*height
              );
        }
      }
      // Blobs
      if (drawBlobs)
      {
        strokeWeight(1);
        stroke(255, 0, 0);
        rect(
          b.xMin*width, b.yMin*height, 
          b.w*width, b.h*height);
        //blob pixel count 
        bpixCnt = b.w * b.h ;
        //println("bpixCnt norm :", bpixCnt); //pixel normalized
      } //drawblobs
    } //if b!
  } //for numbers of blobs getBlobNb()
  redraw();
} //drawbl

// analyse blobs return minimal blobcount with minimal pixel on biggest
float[] anaBlobs() {
  int minBlobs = 0;
  Blob b;
  int blobsCnt = theBlobDetection.getBlobNb() ; // number of blobs
  float blobPixCnt = 0;
  float blobPixMax = 0;
  //println("theBlobDetection.getBlobNb():", blobsCnt);
  float[] blobPixAr = new float[blobsCnt];
  if ( blobsCnt == 0) {
    println("blobsCnt zero:", blobsCnt);
    return new float[] { blobPixMax, blobsCnt};
  }
  for (int n=0; n < blobsCnt; n++) {  // for all blobs found 
    b=theBlobDetection.getBlob(n); //generate blob object
    if (b!=null)
    { 
      blobPixCnt = b.w * b.h ; //normalized
      //println("blobPixCnt :", blobPixCnt); //pixel normalized
      blobPixAr[n] = blobPixCnt; //blob pixel count into array for sort
    } //if !b
  } // for blobsCnt
  if (blobsCnt >0) {  //dont sort if 1
    blobPixAr = sort(blobPixAr);  // sort decent
    blobPixMax = blobPixAr[blobsCnt-1]; // last is the biggest one
  } else {
    blobPixMax = blobPixCnt;
  }
  //redraw();
  return new float[] { blobPixMax, blobsCnt};
}

boolean newBlobDetectedEvent(Blob b) // Filtering blobs (discard "little" ones)
  // nedded theBlobDetection.activeCustomFilter(this);
{
  int minimumBlobSize=25;
  int w = (int)(b.w * width); // recalc normalized to real xy
  int h = (int)(b.h * height);
  if (w >= minimumBlobSize || h >= minimumBlobSize) {
    return true;
  } else {
    return false;
  }
} 

float brenner1D(PImage wrkImg) {  // verion 1dim  pixel array in image
  int numPix = wrkImg.pixels.length, 
    pos;
  float bright, bright1, 
    brenner = 0 ;

  for ( pos=0; pos < numPix - 2; pos++) {  // parse  array
    bright=brightness(wrkImg.pixels[pos]);
    bright1=brightness(wrkImg.pixels[pos+2]);
    brenner += pow((bright1 - bright), 2);
  } // for
  return brenner;
}
