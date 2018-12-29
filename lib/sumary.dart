import 'package:flutter/material.dart';
import 'tableSources.dart';

class SumaryTable extends StatefulWidget {
  final List data;
  const SumaryTable({Key key, @required this.data}) : super(key: key);

  @override
  SumaryTableState createState() => new SumaryTableState();
}


class SumaryTableState extends State<SumaryTable>{
  Map _buildPivotData(){
    List sortedLabelList = widget.data;
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
    return ListView(
        padding: const EdgeInsets.all(3.0),
        children: [
          _builPivotTable(),
        ],
      );
  }
}
