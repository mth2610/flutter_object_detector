import 'package:flutter/material.dart';
import 'package:firebase_admob/firebase_admob.dart';
import 'tableSources.dart';

class DetectedDetails extends StatefulWidget {
  final Map data;
  const DetectedDetails({Key key, @required this.data}) : super(key: key);

  @override
  DetectedDetailsState createState() => new DetectedDetailsState();
}

class DetectedDetailsState extends State<DetectedDetails>{

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Map _buildPivotData(){
    List sortedLabelList = widget.data["recognitions"]["label"];
    sortedLabelList.sort((a, b) {
      int compare = a.toLowerCase().compareTo(b.toLowerCase());
      return compare;
      });
    List setLabels = sortedLabelList.toSet().toList();
    List objectNumbers = [];

    int firstPoint = 0;
    for(String label in setLabels){
      int first = sortedLabelList.indexOf(label);
      int last = sortedLabelList.lastIndexOf(label);
      objectNumbers.add(last - first + 1);
    }

    Map<String, Object> results = {
      "label": setLabels,
      "number": objectNumbers,
    };

    return results;
  }

  Widget _buildTable(){
    return PaginatedDataTable(
        header: const Text('Detected objects'),
        rowsPerPage: widget.data["recognitions"]["id"].length>5?5:widget.data["recognitions"]["id"].length,
        columns: <DataColumn>[
          DataColumn(
            label: const Text('ID'),
          ),
          DataColumn(
            label: const Text('Object'),
          ),
          DataColumn(
            label: const Text('Confidence'),
          ),
      ],
      source: DetailObjectDataSource(widget.data["recognitions"])
    );
  }

  Widget _builPivotTable(){
    var sumaryData = _buildPivotData();
    return PaginatedDataTable(
        header: const Text('Sumary'),
        rowsPerPage: sumaryData["label"].length>5?5:sumaryData["label"].length,
        columns: <DataColumn>[
          DataColumn(
            label: const Text('ID'),
          ),
          DataColumn(
            label: const Text('Object'),
          ),
          DataColumn(
            label: const Text('Number'),
          ),
      ],
      source: SumaryObjectDataSource(sumaryData)
    );
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('tflite example app'),
      ),
      body:
        widget.data!=null?
          widget.data["recognitions"]!=null && widget.data["recognitions"]["label"].length!=0?
            ListView(
              padding: const EdgeInsets.all(3.0),
              children: [
                Container(
                  child: Image.memory(
                    widget.data["detectedImage"]
                  ),
                ),
                _builPivotTable(),
                _buildTable(),
              ],
            ):
            ListView(
              padding: const EdgeInsets.all(3.0),
              children: [
                Container(
                  child: Image.memory(
                    widget.data["detectedImage"]
                  ),
                ),
                Container(
                  child: Center(
                    child: Text("Nothing was detected.")
                  )
                )
              ],
            ):
        Container()
    );
  }
}
