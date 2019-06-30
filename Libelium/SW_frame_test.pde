/*  
 *  ------------  [SW_test] - Libelium Smart Water Board Test  -------------- 
 *  
 *  Copyright (C) 2018 CAD-IT Consultants Pte Ltd
 *  
 *  
 *  Version : 0.1
 *  Author  : Aldi Faizal Dimara, Mehul Gupta
 */

#include <WaspSensorSW.h>
#include <WaspGPS.h>
#include <WaspXBeeZB.h>
#include <WaspFrame.h>

long  sequenceNumber = 0; 
char* sleepTime = "00:00:00:05"; 
char data[100];

// define buffer to store the message
char message[100];
// define local buffer for float to string conversion
char Temp_str[10];
char pH_str[10];
char ORP_str[10];
char DO_str[10];
char COND_str[10];
char ACC_str[20];

int accelerometerX;
int accelerometerY;
int accelerometerZ;

// define folder and file to store data
char path[]="/data";
char filename[]="/data/log";

// define variable
uint8_t sd_answer;

//unsigned long timestamp;
//timestamp_t time;

bool  gpsStatus;

int   batteryLevel;

// Destination MAC address
char RX_ADDRESS[] = "0013A20041030D54";

uint8_t error;

float valuePH;
float valueTemp;
float valuePHCalculated;
float valueORP;
float valueORPCalculated;
float valueDO;
float valueDOCalculated;
float valueCond;
float valueCondCalculated;

// pH Sensor Calibration values
#define CAL_POINT_10 1.985
#define CAL_POINT_7 2.070
#define CAL_POINT_4 2.227
// Temperature at which pH calibration was carried out
#define CAL_TEMP 23.7
// Offset obtained from ORP sensor calibration
#define CALIBRATION_OFFSET 0.0
// Calibration of the DO sensor in normal air
#define AIR_CALIBRATION 2.65
// Calibration of the DO sensor under 0% solution
#define ZERO_CALIBRATION 0.0
// Value 1 used to calibrate the Conductivity sensor
#define POINT1_COND 10500
// Value 2 used to calibrate the Conductivity sensor
#define POINT2_COND 40000
// Point 1 of the Conductivity calibration 
#define POINT1_CAL 197.00
// Point 2 of the Conductivity calibration 
#define POINT2_CAL 150.00

char nodeID[] = "SWat_01";

pHClass pHSensor;
ORPClass ORPSensor;
DOClass DOSensor;
conductivityClass ConductivitySensor;
pt1000Class TemperatureSensor;

void setup() 
{
  // init USB port
  USB.ON();
  //USB.println(F("Sending packets example"));

  // Set the Waspmote ID
  frame.setID(nodeID); 

  // Switch on the board
  SensorSW.ON();
  
  // init XBee
  xbeeZB.ON();
    
  // Set SD ON
  SD.ON();

  // create path
  sd_answer = SD.mkdir(path);

  // Create file for Waspmote Frames
  sd_answer = SD.create(filename);
  
  delay(1000);
  
  //////////////////////////
  // check XBee's network parameters
  //////////////////////////
  //checkNetworkParams();
  
  // Configure the calibration values
  pHSensor.setCalibrationPoints(CAL_POINT_10, CAL_POINT_7, CAL_POINT_4, CAL_TEMP);
  DOSensor.setCalibrationPoints(AIR_CALIBRATION, ZERO_CALIBRATION);
  ConductivitySensor.setCalibrationPoints(POINT1_COND, POINT1_CAL, POINT2_COND, POINT2_CAL);

  
}

void loop()
{
  ///////////////////////////////////////////
  // Turn on the board
  /////////////////////////////////////////// 
  // init XBee
  xbeeZB.ON();
  SensorSW.ON();
  delay(1000);

  //Turn on the RTC
  RTC.ON();
  
  //Turn on the accelerometer
  ACC.ON();

  ///////////////////////////////////////////
  // Read sensors
  ///////////////////////////////////////////  

  accelerometerX = ACC.getX();

  //Reading acceleration in Y axis
  accelerometerY = ACC.getY();
  
  //Reading acceleration in Z axis
  accelerometerZ = ACC.getZ();

  // Getting Time
  //GPS.getPosition();

  // First dummy reading for analog-to-digital converter channel selection
  PWR.getBatteryLevel();
  // Getting Battery Level
  batteryLevel = PWR.getBatteryLevel();



  // Read the ph sensor
  valuePH = pHSensor.readpH();
  // Read the temperature sensor
  valueTemp = TemperatureSensor.readTemperature();
  // Convert the value read with the information obtained in calibration
  valuePHCalculated = pHSensor.pHConversion(valuePH,valueTemp);  
  // Reading of the ORP sensor
  valueORP = ORPSensor.readORP();
  // Apply the calibration offset
  valueORPCalculated = valueORP - CALIBRATION_OFFSET;
  // Reading of the ORP sensor
  valueDO = DOSensor.readDO();
  // Conversion from volts into dissolved oxygen percentage
  valueDOCalculated = DOSensor.DOConversion(valueDO);
  // Reading of the Conductivity sensor
  valueCond = ConductivitySensor.readConductivity();
  // Conversion from resistance into ms/cm
  valueCondCalculated = ConductivitySensor.conductivityConversion(valueCond);  
  

  // Create new frame (ASCII)
  frame.createFrame(ASCII);
  // Add Data values
  
  // Add battery value
  frame.addSensor(SENSOR_BAT, batteryLevel);
  // Add Date values
  frame.addSensor(SENSOR_DATE, RTC.year, RTC.month, RTC.date);
  // Add Time values
  frame.addSensor(SENSOR_TIME, RTC.hour, RTC.minute, RTC.second);
  // Add Accelerometer values
  frame.addSensor(SENSOR_ACC, accelerometerX, accelerometerY, accelerometerZ);

  // Display sent frame
  //frame.showFrame();
  
  // Create New Frame
  sendPacket();
  
  frame.createFrame(ASCII);
  // Add temperature
  frame.addSensor(SENSOR_WT, valueTemp);
  // Add PH
  frame.addSensor(SENSOR_PH, valuePHCalculated);
  // Add ORP value
  frame.addSensor(SENSOR_ORP, valueORP);
  // Add DO value
  frame.addSensor(SENSOR_DO, valueDOCalculated);
  // Add conductivity value
  frame.addSensor(SENSOR_COND, valueCondCalculated);

  dtostrf( valueTemp, 1, 2, Temp_str);
  dtostrf( valuePHCalculated, 1, 2, pH_str);
  dtostrf( valueORP, 1, 3, ORP_str);
  dtostrf( valueDOCalculated, 1, 1, DO_str);
  dtostrf( valueCondCalculated, 1, 1, COND_str);
  sprintf(ACC_str, "%d;%d;%d", accelerometerX, accelerometerY, accelerometerZ);
  
  // Display sent frame
  //frame.showFrame();
  
  sendPacket();
  
  //snprintf( message, sizeof(message), "%d/%d/%d,%d:%d:%d,%d,%s,%s,%s,%s,%s", RTC.date, RTC.month, RTC.year, RTC.hour, RTC.minute, RTC.second, batteryLevel, Temp_str, pH_str, ORP_str, DO_str, COND_str );
  snprintf( message, sizeof(message), "%d/%d/%d,%d:%d:%d,%d,%s,%s,%s,%s,%s,%s,%i", RTC.date, RTC.month, RTC.year, RTC.hour, RTC.minute, RTC.second, batteryLevel, ACC_str, Temp_str, pH_str, ORP_str, DO_str, COND_str, error );
  USB.println( message );
  
  /////////////////////////////////////////////////////   
  // Append data into file
  /////////////////////////////////////////////////////  
  sd_answer = SD.appendln(filename, message);
  
  // Turn off the sensors
  SensorSW.OFF();
  
  // Sleep
  PWR.deepSleep(sleepTime,RTC_OFFSET,RTC_ALM1_MODE1,ALL_OFF);
  //Increase the sequence number after wake up
  sequenceNumber++;
}


void sendPacket()
{
  // send XBee packet
  error = xbeeZB.send( RX_ADDRESS, frame.buffer, frame.length );   

  // check TX flag
  if( error == 0 )
  {
    //USB.println(F("send ok"));
    
    // blink green LED
    Utils.blinkGreenLED();
    
  }
  else 
  {
    // Print error message:
    /*
     * '7' : Buffer full. Not enough memory space
     * '6' : Error escaping character within payload bytes
     * '5' : Error escaping character in checksum byte
     * '4' : Checksum is not correct	  
     * '3' : Checksum byte is not available	
     * '2' : Frame Type is not valid
     * '1' : Timeout when receiving answer   
    */
    //USB.print(F("Error Code: "));
    //USB.println(error,DEC);         
    
    // blink red LED
    Utils.blinkRedLED();
  }
}
