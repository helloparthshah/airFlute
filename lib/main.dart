import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:flutter_midi/flutter_midi.dart';
import 'package:volume/volume.dart';
import 'package:particle_fountain/particle_fountain.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIOverlays([]);
    return MaterialApp(
      title: 'Flute',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: TextTheme(
          headline4: TextStyle(
            color: Colors.white.withAlpha(200),
          ),
        ),
      ),
      home: MyHomePage(title: 'Flute'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  Map<int, bool> _isRecording = {};
  StreamSubscription<NoiseReading> _noiseSubscription;
  NoiseMeter _noiseMeter = new NoiseMeter();
  double _db = 0.0;
  final _flutterMidi = FlutterMidi();
  int _note = 60;
  AudioManager audioManager;
  int maxV;
  double minDb = 70;
  bool conf = false;
  int currVol;

  @override
  void initState() {
    load('assets/Flute.sf2');
    audioManager = AudioManager.STREAM_MUSIC;
    initAudioStreamType();
    config();
    super.initState();
  }

  Future<void> initAudioStreamType() async {
    await Volume.controlVolume(AudioManager.STREAM_MUSIC);
    maxV = await Volume.getMaxVol;
  }

  void load(String asset) async {
    _flutterMidi.unmute(); // Optionally Unmute
    ByteData _byte = await rootBundle.load(asset);
    _flutterMidi.prepare(sf2: _byte);
  }

  void start(int note) async {
    bool flag = false;
    if (!_isRecording.containsValue(true)) {
      await changeVol(0);
      flag = true;
    }
    this.setState(() {
      if (!this._isRecording[note]) {
        this._isRecording[note] = true;
      }
    });
    _flutterMidi.playMidiNote(midi: note);

    if (flag)
      try {
        _noiseSubscription =
            _noiseMeter.noiseStream.listen((NoiseReading noiseReading) async {
          /* this.setState(() {
          if (!this._isRecording[note]) {
            this._isRecording[note] = true;
          }
        }); */

          setState(() {
            _db = noiseReading.meanDecibel;
          });
          await changeVol(((maxV / (90.3 - minDb)) * (_db - minDb)));
        });
      } catch (exception) {
        print(exception);
      }
  }

  Future<void> changeVol(double v) async {
    // for (double i = 0; i < v; i += 1) {
    await Volume.setVol(v.floor(), showVolumeUI: ShowVolumeUI.HIDE);
    // }
  }

  void config() async {
    try {
      _noiseSubscription =
          _noiseMeter.noiseStream.listen((NoiseReading noiseReading) {
        setState(() {
          minDb = noiseReading.meanDecibel + 10;
          _db = 0;
        });

        stopRecorder(_note);
        setState(() {
          conf = true;
        });

        print(minDb);

        _scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text('Configured at $minDb Decibels'),
        ));
      });
    } catch (exception) {
      print(exception);
    }
  }

  void stopRecorder(int note) async {
    this.setState(() {
      this._isRecording[note] = false;
      _flutterMidi.stopMidiNote(midi: note);
      if (!_isRecording.containsValue(true)) _db = 0;
    });
    try {
      if (_noiseSubscription != null && !_isRecording.containsValue(true)) {
        _noiseSubscription.cancel();
        _noiseSubscription = null;
      }

      // if (!_isRecording.containsValue(true)) await changeVol(maxV.toDouble());
    } catch (err) {
      print('stopRecorder error: $err');
    }
    // if (!_isRecording.containsValue(true)) _db = 0;
  }

  Widget createHole(s, int note) {
    this._isRecording.putIfAbsent(note, () => false);
    return GestureDetector(
      onTapDown: (TapDownDetails t) {
        start(note);
      },
      onTapUp: (TapUpDetails t) {
        stopRecorder(note);
      },
      onTapCancel: () {
        stopRecorder(note);
      },
      child: AnimatedContainer(
        height: 70,
        width: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: _isRecording[note] ? Colors.red : Colors.green,
        ),
        duration: Duration(milliseconds: 100),
        child: Center(
          child: Text(s),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // print(_isRecording);
    return Scaffold(
      key: _scaffoldKey,
      body: conf
          ? Center(
              child: Stack(
                // mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    color: Colors.black,
                    constraints: BoxConstraints.expand(),
                    child: ParticleFountain(
                      numberOfParticles: 30,
                      height: 0 + ((1) / (90.3 - minDb)) * (_db - minDb),
                      width: 0.5,
                      color: Colors.orange.withAlpha(150),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          _db.toString(),
                          style: Theme.of(context).textTheme.headline4,
                        ),
                        createHole("C", 60),
                        createHole("B", 59),
                        createHole("A", 57),
                        createHole("G", 55),
                        createHole("F", 53),
                        createHole("E", 52),
                        createHole("D", 50),
                        createHole("C", 48),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: CircularProgressIndicator(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            conf = false;
          });
          config();
        },
        child: Icon(Icons.settings),
        // backgroundColor: Colors.green,
      ),
    );
  }
}
