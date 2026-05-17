import Toybox.Application;
import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

class SpecTrackularApp extends Application.AppBase {
    public function initialize() {
        AppBase.initialize();
    }

    public function onStart(state as Dictionary?) as Void {
    }

    public function onStop(state as Dictionary?) as Void {
    }

    public function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new SpecTrackularView();
        return [view, new SpecTrackularWatchFaceDelegate(view)];
    }
}

class SpecTrackularView extends WatchUi.WatchFace {
    private var _center;
    private var _flashlight;
    private var _hues;
    private var _azmIcon;
    private var _heartIcon;
    private var _stepIcon;
    private var _batteryFrames;
    private var _bodyBatteryIcon;
    private var _heartRateComplicationId;
    private var _heartRateComplicationValue;
    private var _bodyBatteryComplicationId;
    private var _bodyBatteryComplicationValue;
    private var _activitySeed;

    public function initialize() {
        WatchFace.initialize();
        _flashlight = false;
        _azmIcon = WatchUi.loadResource($.Rez.Drawables.AzmIcon);
        _heartIcon = WatchUi.loadResource($.Rez.Drawables.HeartRateIcon);
        _stepIcon = WatchUi.loadResource($.Rez.Drawables.StepsIcon);
        _batteryFrames = [
            WatchUi.loadResource($.Rez.Drawables.BatteryFrame0),
            WatchUi.loadResource($.Rez.Drawables.BatteryFrame1),
            WatchUi.loadResource($.Rez.Drawables.BatteryFrame2),
            WatchUi.loadResource($.Rez.Drawables.BatteryFrame3)
        ];
        _bodyBatteryIcon = WatchUi.loadResource($.Rez.Drawables.BodyBatteryIcon);
        _heartRateComplicationId = new Complications.Id(Complications.COMPLICATION_TYPE_HEART_RATE);
        _heartRateComplicationValue = null;
        _bodyBatteryComplicationId = new Complications.Id(Complications.COMPLICATION_TYPE_BODY_BATTERY);
        _bodyBatteryComplicationValue = null;
        _activitySeed = null;
        _hues = [
            0xF83C40, 0xFC6B3A, 0xFFFF00, 0xB8FC68,
            0x00A629, 0x5BE37D, 0x3BF7DE, 0x14D3F5,
            0x3182DE, 0xBD4EFC, 0xF80070, 0xF83478
        ];

        try {
            Complications.registerComplicationChangeCallback(method(:onComplicationChanged));
            Complications.subscribeToUpdates(_heartRateComplicationId);
            Complications.subscribeToUpdates(_bodyBatteryComplicationId);
            _refreshHeartRateComplication(_heartRateComplicationId);
            _refreshBodyBatteryComplication(_bodyBatteryComplicationId);
        } catch (ex) {
        }
    }

    public function onLayout(dc as Dc) as Void {
        _center = [dc.getWidth() / 2, dc.getHeight() / 2];
    }

    private function _angleForHour(hour as Number, minute as Number) {
        return ((hour % 12) * 30 + (minute * 0.5)) * Math.PI / 180.0;
    }

    private function _angleForMinute(minute as Number) {
        return (minute * 6) * Math.PI / 180.0;
    }

    private function _angleForSecond(second as Number) {
        return (second * 6) * Math.PI / 180.0;
    }

    private function _pointAt(angle, radius) {
        return [
            (_center[0] + Math.sin(angle) * radius).toNumber(),
            (_center[1] - Math.cos(angle) * radius).toNumber()
        ];
    }

    private function _drawHand(dc as Dc, angle, length, width as Number, color as Number) as Void {
        var points = [
            [_center[0] - width / 2, _center[1]],
            [_center[0] - width / 2, _center[1] - length],
            [_center[0] + width / 2, _center[1] - length],
            [_center[0] + width / 2, _center[1]]
        ];

        var cos = Math.cos(angle);
        var sin = Math.sin(angle);
        var transformed = new Array<[Number, Number]>[4];
        for (var i = 0; i < points.size(); i++) {
            var x = points[i][0] - _center[0];
            var y = points[i][1] - _center[1];
            transformed[i] = [
                (_center[0] + x * cos - y * sin).toNumber(),
                (_center[1] + x * sin + y * cos).toNumber()
            ];
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(transformed);
    }

    private function _drawColorWheel(dc as Dc, radius) as Void {
        dc.setPenWidth(3);
        for (var i = 0; i < 12; i++) {
            var angle = i * 30 * Math.PI / 180.0;
            var inner = _pointAt(angle, radius - 20);
            var outer = _pointAt(angle, radius);
            dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(inner[0], inner[1], outer[0], outer[1]);
        }
        dc.setPenWidth(1);
    }

    private function _lerpChannel(from as Number, to as Number, amount as Float) as Number {
        return (from + ((to - from) * amount)).toNumber();
    }

    private function _interpolatedHue(index as Number) as Number {
        var scaled = index * 12.0 / 60.0;
        var base = scaled.toNumber();
        var next = (base + 1) % 12;
        var amount = scaled - base;
        var from = _hues[base];
        var to = _hues[next];

        var red = _lerpChannel((from >> 16) & 0xFF, (to >> 16) & 0xFF, amount);
        var green = _lerpChannel((from >> 8) & 0xFF, (to >> 8) & 0xFF, amount);
        var blue = _lerpChannel(from & 0xFF, to & 0xFF, amount);

        return (red << 16) | (green << 8) | blue;
    }

    private function _mixSeed(value as Number) as Number {
        value = ((value * 1103515245) + 12345) & 0x7FFFFFFF;
        value = value ^ (value >> 11);
        value = ((value * 1664525) + 1013904223) & 0x7FFFFFFF;
        return value;
    }

    private function _activityDotSize(seed as Number, index as Number) as Number {
        var primary = _mixSeed(seed + index * 97);
        var secondary = _mixSeed(seed + index * index * 13);
        var size = 2 + (primary % 8);

        if ((secondary % 17) == 0) {
            size += 5;
        } else if ((secondary % 7) == 0) {
            size += 2;
        }

        return size;
    }

    private function _activityWheelSeed(steps as Number, battery as Number, active as Number, heartRate as Number) as Number {
        if (_activitySeed == null) {
            _activitySeed = steps + battery * 173 + active * 977 + heartRate * 389;
        }

        return _activitySeed;
    }

    private function _drawActivityWheel(dc as Dc, radius, seed as Number) as Void {
        for (var i = 0; i < 60; i++) {
            var angle = i * 6 * Math.PI / 180.0;
            var point = _pointAt(angle, radius);
            var dotSize = _activityDotSize(seed, i);
            var color = _interpolatedHue(i);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(point[0], point[1], dotSize);
        }
    }

    private function _drawRosette(dc as Dc, radius) as Void {
        dc.setPenWidth(1);
        for (var i = 0; i < 24; i++) {
            var angle = i * 15 * Math.PI / 180.0;
            var point = _pointAt(angle, radius);
            dc.setColor(_hues[i % 12], Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(point[0], point[1], (radius / 3).toNumber());
        }
    }

    private function _formatDate(clockTime) as String {
        var months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
        var moment = new Time.Moment(Time.now().value());
        var info = Time.Gregorian.info(moment, Time.FORMAT_SHORT);
        return months[info.month - 1] + " " + info.day.toString();
    }

    private function _drawBoldText(dc as Dc, x as Number, y as Number, font, text as String, justification as Number) as Void {
        dc.drawText(x, y, font, text, justification);
        dc.drawText(x + 1, y, font, text, justification);
    }

    private function _batteryFrame(battery as Number) as Number {
        if (battery <= 25) {
            return 3;
        } else if (battery <= 50) {
            return 2;
        } else if (battery <= 75) {
            return 1;
        }
        return 0;
    }

    private function _activityInfo() {
        try {
            return ActivityMonitor.getInfo();
        } catch (ex) {
            return null;
        }
    }

    private function _steps(info) as Number {
        if (info != null && info has :steps && info.steps != null) {
            return info.steps;
        }
        return 0;
    }

    private function _activeMinuteTotal(value) as Number {
        if (value == null) {
            return 0;
        }
        if (value has :total && value.total != null) {
            return value.total;
        }
        if (value has :moderate || value has :vigorous) {
            var moderate = (value has :moderate && value.moderate != null) ? value.moderate : 0;
            var vigorous = (value has :vigorous && value.vigorous != null) ? value.vigorous : 0;
            return moderate + vigorous;
        }
        return value.toNumber();
    }

    private function _activeMinutes(info) as Number {
        if (info != null && info has :activeMinutesDay && info.activeMinutesDay != null) {
            return _activeMinuteTotal(info.activeMinutesDay);
        }
        if (info != null && info has :activeMinutesWeek && info.activeMinutesWeek != null) {
            return _activeMinuteTotal(info.activeMinutesWeek);
        }
        return 0;
    }

    private function _validBodyBatteryValue(value) {
        if (value == null) {
            return null;
        }

        var number = null;
        try {
            number = value.toNumber();
        } catch (ex) {
            return null;
        }

        if (number != null && number >= 0 && number <= 100) {
            return number;
        }

        return null;
    }

    private function _validHeartRateValue(value) {
        if (value == null) {
            return null;
        }

        var number = null;
        try {
            number = value.toNumber();
        } catch (ex) {
            return null;
        }

        if (number == null || number == ActivityMonitor.INVALID_HR_SAMPLE || number >= 255) {
            return null;
        }

        if (number >= 30 && number <= 220) {
            return number;
        }

        return null;
    }

    public function onComplicationChanged(id as Complications.Id) as Void {
        _refreshHeartRateComplication(id);
        _refreshBodyBatteryComplication(id);
        WatchUi.requestUpdate();
    }

    private function _refreshHeartRateComplication(id as Complications.Id) as Void {
        try {
            if (id != null && id.equals(_heartRateComplicationId)) {
                var complication = Complications.getComplication(id);
                if (complication != null && complication.value != null) {
                    _heartRateComplicationValue = _validHeartRateValue(complication.value);
                }
            }
        } catch (ex) {
        }
    }

    private function _refreshBodyBatteryComplication(id as Complications.Id) as Void {
        try {
            if (id != null && id.equals(_bodyBatteryComplicationId)) {
                var complication = Complications.getComplication(id);
                if (complication != null && complication.value != null) {
                    _bodyBatteryComplicationValue = _validBodyBatteryValue(complication.value);
                }
            }
        } catch (ex) {
        }
    }

    private function _bodyBatteryValue() {
        if (_bodyBatteryComplicationValue != null) {
            return _bodyBatteryComplicationValue;
        }

        try {
            if (SensorHistory has :getBodyBatteryHistory) {
                var iterator = SensorHistory.getBodyBatteryHistory({:period => 1});
                var sample = iterator.next();
                if (sample != null && sample has :data && sample.data != null) {
                    var value = _validBodyBatteryValue(sample.data);
                    if (value != null) {
                        return value;
                    }
                }
            }
        } catch (ex) {
        }

        return null;
    }

    private function _bodyBattery() as String {
        var value = _bodyBatteryValue();
        var validValue = _validBodyBatteryValue(value);
        if (validValue != null) {
            return validValue.toString();
        }
        return "--";
    }

    private function _bodyBatteryNumber() as Number {
        var value = _bodyBatteryValue();
        var validValue = _validBodyBatteryValue(value);
        if (validValue != null) {
            return validValue;
        }
        return 0;
    }

    private function _heartRateValue(info) {
        if (_heartRateComplicationValue != null) {
            return _heartRateComplicationValue;
        }

        if (info != null && info has :currentHeartRate && info.currentHeartRate != null) {
            var current = _validHeartRateValue(info.currentHeartRate);
            if (current != null) {
                return current;
            }
        }

        try {
            if (ActivityMonitor has :getHeartRateHistory) {
                var hrIterator = ActivityMonitor.getHeartRateHistory(1, true);
                var hrSample = hrIterator.next();
                if (hrSample != null) {
                    if (hrSample has :heartRate && hrSample.heartRate != null) {
                        var activityHr = _validHeartRateValue(hrSample.heartRate);
                        if (activityHr != null) {
                            return activityHr;
                        }
                    }
                    if (hrSample has :data && hrSample.data != null) {
                        var activityData = _validHeartRateValue(hrSample.data);
                        if (activityData != null) {
                            return activityData;
                        }
                    }
                }
            }
        } catch (ex) {
        }

        try {
            if (SensorHistory has :getHeartRateHistory) {
                var sensorIterator = SensorHistory.getHeartRateHistory({:period => 1});
                var sensorSample = sensorIterator.next();
                if (sensorSample != null && sensorSample has :data && sensorSample.data != null) {
                    var sensorHr = _validHeartRateValue(sensorSample.data);
                    if (sensorHr != null) {
                        return sensorHr;
                    }
                }
            }
        } catch (ex) {
        }

        return null;
    }

    private function _heartRate(info) as String {
        var value = _heartRateValue(info);
        var validValue = _validHeartRateValue(value);
        if (validValue != null) {
            return validValue.toString();
        }
        return "--";
    }

    private function _heartRateNumber(info) as Number {
        var value = _heartRateValue(info);
        var validValue = _validHeartRateValue(value);
        if (validValue != null) {
            return validValue;
        }
        return 0;
    }

    public function toggleFlashlight() as Void {
        _flashlight = !_flashlight;
        WatchUi.requestUpdate();
    }

    public function openZone(x as Number, y as Number, width as Number, height as Number) as Void {
        var complicationType = null;

        if (x > width * 0.30 && x < width * 0.70 && y > height * 0.30 && y < height * 0.70) {
            toggleFlashlight();
            return;
        } else if (x < width * 0.30 && y < height * 0.30) {
            complicationType = Complications.COMPLICATION_TYPE_BATTERY;
        } else if (x > width * 0.70 && y < height * 0.30) {
            complicationType = Complications.COMPLICATION_TYPE_BODY_BATTERY;
        } else if (x < width * 0.30 && y > height * 0.70) {
            complicationType = Complications.COMPLICATION_TYPE_HEART_RATE;
        } else if (x > width * 0.70 && y > height * 0.70) {
            complicationType = Complications.COMPLICATION_TYPE_STEPS;
        }

        if (complicationType != null) {
            try {
                Complications.exitTo(new Complications.Id(complicationType));
            } catch (ex) {
            }
        }
    }

    public function onUpdate(dc as Dc) as Void {
        var now = System.getClockTime();
        var width = dc.getWidth();
        var height = dc.getHeight();
        var radius = ((width < height) ? width : height) / 2;
        var battery = System.getSystemStats().battery;
        var info = _activityInfo();
        var steps = _steps(info);
        var bodyBatteryNumber = _bodyBatteryNumber();
        var bodyBattery = _bodyBattery();
        var heartRateNumber = _heartRateNumber(info);
        var heartRate = _heartRate(info);

        dc.clear();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, width, height);

        if (_flashlight) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, width, height);
            return;
        }

        _drawColorWheel(dc, (radius * 0.90).toNumber());
        var activitySeed = _activityWheelSeed(steps, battery.toNumber(), bodyBatteryNumber, heartRateNumber);
        _drawActivityWheel(dc, (radius * 0.80 + 3).toNumber(), activitySeed);

        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        _drawBoldText(dc, _center[0], (_center[1] + radius * 0.30 - 30).toNumber(), Graphics.FONT_TINY, _formatDate(now), Graphics.TEXT_JUSTIFY_CENTER);

        _drawHand(dc, _angleForHour(now.hour, now.min), (height * 0.25).toNumber(), 8, Graphics.COLOR_WHITE);
        _drawHand(dc, _angleForMinute(now.min), (height * 0.37).toNumber(), 4, Graphics.COLOR_WHITE);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var sec = _pointAt(_angleForSecond(now.sec), (radius * 0.82).toNumber());
        dc.fillCircle(sec[0], sec[1], 4);
        dc.fillCircle(_center[0], _center[1], 10);

        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        var topTextY = -4;
        var bottomTextY = height - 37;
        var leftIconX = 3;
        var leftTextX = 19;
        var rightIconX = width - 32;
        var rightTextX = width - 34;
        var iconYOffset = 4;
        var topIconY = -1 + iconYOffset;
        var topLargeIconY = -5 + iconYOffset;
        var bottomIconY = height - 36 + iconYOffset;

        dc.drawBitmap(leftIconX, topIconY, _batteryFrames[_batteryFrame(battery.toNumber())]);
        dc.drawBitmap(rightIconX, topLargeIconY, _bodyBatteryIcon);
        dc.drawBitmap(leftIconX - 3, bottomIconY, _heartIcon);
        dc.drawBitmap(rightIconX, bottomIconY, _stepIcon);

        dc.drawText(leftTextX, topTextY, Graphics.FONT_XTINY, battery.toNumber().toString() + "%", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(rightTextX, topTextY, Graphics.FONT_XTINY, bodyBattery, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(leftTextX + 18, bottomTextY, Graphics.FONT_XTINY, heartRate, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(rightTextX, bottomTextY, Graphics.FONT_XTINY, steps.toString(), Graphics.TEXT_JUSTIFY_RIGHT);
    }
}

class SpecTrackularWatchFaceDelegate extends WatchUi.WatchFaceDelegate {
    private var _view;

    public function initialize(view) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    public function onPress(clickEvent as ClickEvent) as Boolean {
        try {
            var coords = clickEvent.getCoordinates();
            var settings = System.getDeviceSettings();
            _view.openZone(coords[0], coords[1], settings.screenWidth, settings.screenHeight);
        } catch (ex) {
        }
        return true;
    }
}
