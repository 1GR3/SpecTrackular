import clock from "clock";
import document from "document";
import { preferences } from "user-settings";
import * as util from "../common/utils";
import { display } from "display";
import { HeartRateSensor } from "heart-rate";
import { me as appbit } from "appbit";
import {userActivity, today, goals} from "user-activity";
import { battery } from "power";

//grab the elements from the display
const btLabel = document.getElementById("btr");
const acLabel = document.getElementById("act");
const hrLabel = document.getElementById("hrm");
const stLabel = document.getElementById("stp");

const dateLabel = document.getElementById("date");

const hourText = document.getElementById("hourTxt");
const minText = document.getElementById("minTxt");
const secText = document.getElementById("secTxt");

const hourHand = document.getElementById("hours");
const minHand = document.getElementById("mins");
const secHand = document.getElementById("secs");



// display settings
display.autoOff = true;
display.on = false;

// define colors

let FitBitHuez = ["#F83C40", "#FC6B3A", "#FFFF00", 
                 "#B8FC68", "#00A629", "#5BE37D",
                 "#3BF7DE", "#14D3F5", "#3182DE",
                 "#BD4EFC", "#F80070", "#F83478"];
let colorz = FitBitHuez;

//heart rate
hrLabel.text = "--";
var hrm = new HeartRateSensor();

hrm.onreading = function() {
  hrLabel.text = hrm.heartRate+"";
}
hrm.start();



// clock
clock.granularity = "seconds";

// Returns an angle (0-360) for the current hour in the day, including minutes
function hoursToAngle(hours, minutes) {

  
  let hourAngle = (360 / 12) * hours;
  let minAngle = (360 / 12 / 60) * minutes;
  return hourAngle + minAngle;
  //console.log(hours);
}

// Returns an angle (0-360) for minutes
function minutesToAngle(minutes) {
  return (360 / 60) * minutes;
}

// Returns an angle (0-360) for seconds
function secondsToAngle(seconds) {
  return (360 / 60) * seconds;
}

// Rotate the hands every tick
function updateClock() {
  var Today = new Date();
  var hours = Today.getHours() % 12;
  var mins = Today.getMinutes();
  var secs = Today.getSeconds();
  
  hourHand.groupTransform.rotate.angle = hoursToAngle(hours, mins);
  minHand.groupTransform.rotate.angle = minutesToAngle(mins);
  secHand.groupTransform.rotate.angle = secondsToAngle(secs);
  
  console.log(minutesToAngle(mins));
  
  //hourText.text = hours;
  //minText.text = mins;
  //secText.text = secs;
  // if ( mins==0 || mins==12 || mins==24 || mins==36 || mins==48 ) {
  //   logActivity();
  // }
  //logActivity();
  
  const days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
  dateLabel.text = days[Today.getDay()] + " " + Today.getDate();
  
  // acLabel.text = (userActivity.today.adjusted["activeMinutes"] || 0);
  acLabel.text = (today.adjusted.activeZoneMinutes.total || 0);
  // stLabel.text = (userActivity.today.adjusted["steps"] || 0);
  stLabel.text = (today.adjusted.steps || 0);
  if ( battery.chargeLevel >= 17) {
    btLabel.text = Math.floor(battery.chargeLevel) + "%";
    btLabel.style.opacity = 1;
  } else {
    btLabel.style.opacity = 0;
  }
}



// Update the clock every tick event
clock.ontick = () => updateClock();


// turning display on and off
display.onchange = () => { 
  if (display.on) {
    wake();
  } else {
    sleep();
  }
}

var oval = document.getElementsByClassName("oval");
var activityWheel = document.getElementById("activityWheel");

var rosette= document.getElementById("rosette");


var drawActivities = function() {
  for (var a=0; a<60; a++) {
    document.getElementById("a"+a).groupTransform.rotate.angle = a*6;
    document.getElementById("a"+a).style.fill = util.HSLToHex(a*6,50,50);
    //document.getElementById("a"+a).getElementsByTagName("circle")[0].r = 1+a/6;
    document.getElementById("a"+a).getElementsByTagName("circle")[0].r = 1 + Math.floor(Math.random()*16);
    //document.getElementById("a"+a).getElementsByTagName("circle")[0].r = 1 + activityLog[a][0];
  }
}



function wake() {
  oval.forEach((item) => {
    item.animate("enable");
  })
  drawActivities();
  rosette.animate("enable");
  minHand.animate("enable");
  hourHand.animate("enable");
  secHand.animate("enable");
  activityWheel.animate("enable");
  
}

function sleep() {
  flashlightOff();
  minHand.animate("disable");
  hourHand.animate("disable");
  secHand.animate("disable");
  activityWheel.animate("disable");
  oval.forEach((item) => {
    item.animate("disable");
  })
}


goals.addEventListener("reachgoal", (goal, evt) => {
  if (today.adjusted.steps >= goal.steps) {
    // step goal reached
  }
})

// flaslight on double click
const flash = document.getElementById("flash");
const flashBtn = document.getElementById("flashBtn");
var  flashlightToggle = function() {
  if (flash.style.opacity == 0) {
    flashlightOn();
  } else {
    flashlightOff();
  }
};
var  flashlightOn = function() {
  flash.style.opacity = 1;
  display.autoOff = false;
  //display.brightnessOverride = 1.0;
  display.brightnessOverride = "max";
};
var  flashlightOff = function() {
  flash.style.opacity = 0;
  display.autoOff = true;
  display.brightnessOverride = undefined;
  //display.brightnessOverride = "normal";
};

var clickCount = 0;
var timeout;

flashBtn.onclick = function() { 
  clickCount++;
  if(timeout){
    clearTimeout(timeout);
  }
  if (clickCount === 1) {
    timeout = setTimeout(function () {
      clickCount=0;
    }, 250);
  } else if(clickCount === 2) {
    clickCount=0;
    flashlightToggle(); 
  }  
}

const battrBtn = document.getElementById("battrBtn");
const powerBtn = document.getElementById("powerBtn");
const heartBtn = document.getElementById("heartBtn");
const stepsBtn = document.getElementById("stepsBtn");
const timeBtn  = document.getElementById("timeBtn");

const bigText = document.getElementById("bigText");
const bigDisplay = document.getElementById("bigDisplay");

bigDisplay.style.opacity=0;

battrBtn.onmousedown = function() {
  bigText.text = btLabel.text = Math.floor(battery.chargeLevel) + "%";
  bigDisplay.style.opacity=1;
}
battrBtn.onmouseup = function() {
  bigDisplay.style.opacity=0;
}

powerBtn.onmousedown = function() {
  // bigText.text = (userActivity.today.adjusted["activeMinutes"] || 0);
  bigText.text = (today.adjusted.activeZoneMinutes.total || 0);
  bigDisplay.style.opacity=1;
}
powerBtn.onmouseup = function() {
  bigDisplay.style.opacity=0;
}

heartBtn.onmousedown = function() {
  bigText.text = hrm.heartRate+"";
  bigDisplay.style.opacity=1;
}
heartBtn.onmouseup = function() {
  bigDisplay.style.opacity=0;
}

stepsBtn.onmousedown = function() {
  bigText.text = stLabel.text = (today.adjusted.steps || 0);
  bigDisplay.style.opacity=1;
}
stepsBtn.onmouseup = function() {
  bigDisplay.style.opacity=0;
}

timeBtn.onmousedown = function() {
  var Today = new Date();
  bigText.text = stLabel.text = Today.getHours() + ":" + Today.getMinutes();
  bigDisplay.style.opacity=1;
}
timeBtn.onmouseup = function() {
  bigDisplay.style.opacity=0;
}
