import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Filc Download stats',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: GraphPage(),
    );
  }
}

const String dirPath = "E:\\Provide\\Filc\\Release Stats\\";
//const String dirPath = "";

class GraphPage extends StatefulWidget {
  @override
  _GraphPageState createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  List<DataPoint> dataPoints = [];
  bool hasNewData = false;
  GlobalKey _globalKey = GlobalKey();

  Future<Uint8List> _capturePng() async {
    try {
      print('inside');
      RenderRepaintBoundary boundary =
          _globalKey.currentContext.findRenderObject();
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      var pngBytes = byteData.buffer.asUint8List();
      setState(() {});
      return pngBytes;
    } catch (e) {
      print(e);
      return null;
    }
  }

  File graph;
  File latestGraph = File(dirPath + "graph_latest.png");
  File log;

  @override
  void initState() {
    doLog().then((_) {
      setState(() {
        hasNewData = true;
        var dataLines = log.readAsLinesSync();
        int i = 0;
        dataLines.forEach((line) {
          var parts = line.split("\t");
          dataPoints
              .add(DataPoint(i, DateTime.parse(parts[0]), int.parse(parts[1])));
          print(dataPoints.last.time);
          i++;
        });
      });
      graph.createSync();
      Future.delayed(Duration(seconds: 1))
          .then((value) => _capturePng().then((value) {
                graph.writeAsBytesSync(value);
                latestGraph.writeAsBytesSync(value);
              }))
          .then((value) => exit(0));
    });
    super.initState();
  }

  var responseJson;

  Future<bool> doLog() async {
    //log.createSync();

    try {
      var response = await http
          .get(Uri.parse('https://api.github.com/repos/filc/naplo/releases'));
      responseJson = json.decode(response.body);

      String thisLine = DateTime.now().toString().split('.')[0] +
          '\t' +
          responseJson
              .firstWhere((e) => e['prerelease'] == false)['assets'][0]
                  ['download_count']
              .toString() +
          '\r\n';
      print(thisLine);
      log = File(dirPath +
          "log_" +
          responseJson.firstWhere((e) => e['prerelease'] == false)['tag_name'] +
          ".txt");
      print(log);
      log.createSync();
      graph = File(dirPath +
          "graph_" +
          responseJson.firstWhere((e) => e['prerelease'] == false)['tag_name'] +
          ".png");
      try {
        String file = log.readAsStringSync();
        file += thisLine;
        log.writeAsStringSync(file);
      } catch (e) {
        print("error writing to file! " + e.toString());
        return false;
      }
    } catch (e) {
      print("error in gh request! " + e.toString());
      return false;
    }
    return true;
  }

  List<FlSpot> getSpots() {
    List<FlSpot> spots = [];
    dataPoints.forEach((point) {
      spots.add(FlSpot(point.time.millisecondsSinceEpoch.toDouble(),
          point.downloads.toDouble()));
      print(spots.last);
    });
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 500, maxWidth: 600),
        child: RepaintBoundary(
          key: _globalKey,
          child: Container(
            padding: EdgeInsets.all(15),
            color: Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    responseJson.firstWhere(
                            (e) => e['prerelease'] == false)['tag_name'] +
                        " letöltések: " +
                        dataPoints.last.downloads.toString(),
                    style: Theme.of(context).textTheme.headline5,
                  ),
                ),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          verticalInterval: 21600000),
                      lineBarsData: [
                        LineChartBarData(
                          preventCurveOverShooting: true,
                          preventCurveOvershootingThreshold: 0.0,
                          dotData: FlDotData(show: false),
                          spots: getSpots(),
                          isCurved: true,
                          barWidth: 7,
                          colors: [Colors.teal],
                        ),
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: SideTitles(
                          interval: 10,
                          showTitles: true,
                        ),
                        bottomTitles: SideTitles(
                          showTitles: true,
                          interval: //null,
                              getBottomTitlesInterval(),
                          getTitles: (value) => DateFormat("HH:mm").format(
                              DateTime.fromMillisecondsSinceEpoch(
                                  value.toInt())),
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Frissítve: " + DateTime.now().toString().split('.')[0],
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  double getBottomTitlesInterval() {
    double interval = (dataPoints.last.time.millisecondsSinceEpoch -
            dataPoints.first.time.millisecondsSinceEpoch) /
        16;
    return interval < 1 ? 1 : interval;
  }
}

class DataPoint {
  int index;
  DateTime time;
  int downloads;
  DataPoint(this.index, this.time, this.downloads);
}
