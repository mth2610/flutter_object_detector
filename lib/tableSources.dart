import 'package:flutter/material.dart';

class DetailObjectDataSource extends DataTableSource {
  final Map data;
  DetailObjectDataSource(this.data);
  int _selectedCount = 0;

  @override
  DataRow getRow(int index) {
    assert(index >= 0);
    if (index >= data["id"].length)
      return null;
    return DataRow.byIndex(
      index: index,
      cells: <DataCell>[
        DataCell(Text('${data["id"][index]}')),
        DataCell(Text('${data["label"][index]}')),
        DataCell(Text('${data["confidence"][index]}')),
      ]
    );
  }

  @override
  int get rowCount => data['id'].length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => _selectedCount;
}

class SumaryObjectDataSource extends DataTableSource {
  final Map data;
  SumaryObjectDataSource(this.data);
  int _selectedCount = 0;

  @override
  DataRow getRow(int index) {
    assert(index >= 0);
    if (index >= data["label"].length)
      return null;
    return DataRow.byIndex(
      index: index,
      cells: <DataCell>[
        DataCell(Text('${index + 1}')),
        DataCell(Text('${data["label"][index]}')),
        DataCell(Text('${data["number"][index]}')),
      ]
    );
  }

  @override
  int get rowCount => data['label'].length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => _selectedCount;
}
