import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission/permission.dart';
import 'package:firebase_admob/firebase_admob.dart';
import 'details.dart';
import 'sumary.dart';

const platform = const MethodChannel('obdetector.com/tensorflow');
const String testDevice = 'test';

void main() => runApp(
  MaterialApp(
    title: 'Object detection',
    theme: ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: Colors.blueGrey[900],
    ),
    home: MyApp()
  )
);

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List _processedData = [];
  String maximumObject = "10";
  String confidenceThreshold = "0.5";
  InterstitialAd myInterstitial;
  int adClickAcc = 0;

  MobileAdTargetingInfo targetingInfo = MobileAdTargetingInfo(
    testDevices: testDevice != null ? <String>[testDevice] : null,
  );

  @override
  void initState() {
    super.initState();
    FirebaseAdMob.instance.initialize(appId: "[YOUR APPLICATION ID]");
    myInterstitial = InterstitialAd(
      adUnitId: "[YOUR AD UNIT ID]",
      targetingInfo: targetingInfo,
      listener: (MobileAdEvent event) {
        print("InterstitialAd event is $event");
      },
    );
  }

  @override
  void dispose() {
    myInterstitial?.dispose();
    super.dispose();
  }

  void removeProcessedData(int index){
    setState(() {
      _processedData.removeAt(index);
    });
  }

  void callbackToSetParameter(String inputMaximumObject, String inputConfidenceThreshold){
    setState(() {
      maximumObject = inputMaximumObject;
      confidenceThreshold = inputConfidenceThreshold;
    });
  }

  _getImageAndDectec(String imageSource, BuildContext context) async {
    File image = await getImage(imageSource);
    var results = await detectObjectFromImage(image, 10, double.parse(confidenceThreshold));
    setState(() {
      _processedData.add(
        results
      );
      if(adClickAcc > 1){
        adClickAcc = 0;
      } else {
        adClickAcc += 1;
      }
    });

    if(adClickAcc > 1){
      myInterstitial..load()..show();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> addContentChoices = <Widget>[
      IconButton(
        icon: Icon(Icons.video_call),
        onPressed: (){
          _getImageAndDectec('camera', context);
        }
      ),
      IconButton(
        icon: Icon(Icons.folder),
        onPressed: (){
          _getImageAndDectec('gallery', context);
        }
      ),
    ];

    Widget _selectedAddContentChoice = addContentChoices[0];

    void _selectAddContent(Widget choice) {
      setState(() {
        _selectedAddContentChoice = choice;
      });
    }

    void _settingParameterDialog() {
      showDialog<Null>(
        context: context,
        barrierDismissible: true, // user must tap button!
        builder: (BuildContext context) {
          return ParameterDialog(
            callbackToSetParameter: callbackToSetParameter,
            maximumObject: maximumObject,
            confidenceThreshold: confidenceThreshold,
          );
        },
      );
    }

    Widget _buildParameterSettingMenuButton(){
      return new IconButton(
         icon: const Icon(Icons.dehaze),
         onPressed: () async {
          _settingParameterDialog();
         },
      );
    }

    Widget _buildFloatingButton(BuildContext context){
      return FloatingActionButton(
        elevation: 0.0,
        child: PopupMenuButton<Widget>(
          onSelected: _selectAddContent,
          icon: Icon(Icons.add,
          ),
          itemBuilder: (BuildContext context) {
            return addContentChoices.map((Widget choice) {
              return PopupMenuItem<Widget>(
                value: choice,
                child: choice,
              );
            }).toList();
          },
        ),
        onPressed: (){
        }
      );
    }

    Widget _buildGridView(){
      return  _processedData.length!= 0 ? GridView.count(
        mainAxisSpacing: 4.0,
        crossAxisSpacing: 4.0,
        padding: const EdgeInsets.all(16.0),
        childAspectRatio: 8.0 / 9.0,
        crossAxisCount: 2,
        // Generate 100 Widgets that display their index in the List
        children: List.generate(_processedData.length, (i) {
              return ProcessedImageElement(
                index: i,
                callbackToRemove: removeProcessedData,
                data: _processedData[i],
              );
            }
          )
        ):Container();
    }

    Widget _buildSumaryView(){
      List totalLabel = [];
      if(_processedData.length!=0){
        for(var data in _processedData){
          if(data["recognitions"]["label"]!=null){
            totalLabel.addAll(data["recognitions"]["label"]);
          }
        }

        if(totalLabel.length!=0){
          return SumaryTable(data: totalLabel);
        } else {
          return Container();
        }

      } else{
        return Container();
      }
    }

    return DefaultTabController(
        length: 2,
        child: Scaffold(
          floatingActionButton: _buildFloatingButton(context),
          appBar: AppBar(
            actions: [_buildParameterSettingMenuButton()],
            bottom: TabBar(
              indicatorColor: Colors.green,
              tabs: [
                Tab(
                  icon: Icon(Icons.apps),
                ),
                Tab(icon: Icon(Icons.assignment)),
              ],
            ),
            title: Text('Object detection'),
          ),
          body: TabBarView(
            children: [
              _buildGridView(),
              _buildSumaryView(),
            ]
          )
       )
    );
  }
}

Future<File> getImage(String imageSource) async {
  File image;
  if(imageSource == 'camera'){
    image = await ImagePicker.pickImage(source: ImageSource.camera);
  } else if (imageSource == 'gallery'){
    image = await ImagePicker.pickImage(source: ImageSource.gallery);
  }
  return image;
}

Future detectObjectFromImage(File image, int maximumObject, double confidenceThreshold) async {
  final permissionResult = await Permission.requestPermissions([PermissionName.Storage]);
  var results = await platform.invokeMethod('imageClassifier', {'path': image.path,'maximumObject':maximumObject, 'confidenceThreshold':confidenceThreshold});
  return results;
}


class ProcessedImageElement extends StatefulWidget {
  final int index;
  final Function(int) callbackToRemove;
  final Map data;
  const ProcessedImageElement({Key key, @required this.data, this.index, this.callbackToRemove}) : super(key: key);

  @override
  ProcessedImageElementState createState() => new ProcessedImageElementState();
}

class ProcessedImageElementState extends State<ProcessedImageElement>{
  Widget _buildElement(BuildContext context){
    return Card(
       child: Column(
         children: [
           GestureDetector(
             child: Container(
               child: Image.memory(
                 widget.data["detectedImage"],
                 fit: BoxFit.fill,
               ),
             ),
             onTap: (){
               Navigator.push(
                   context,
                   MaterialPageRoute(builder: (context) => DetectedDetails(data: widget.data)),
                 );
             }
           ),
           Container(
             padding: const EdgeInsets.all(3.0),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: <Widget>[
                 Text(
                   "Objects: ${widget.data['recognitions']['id'].length}",
                    style: TextStyle(
                     color: Colors.grey[500],
                     fontSize: 10.0
                   ),
                 ),
                 GestureDetector(
                   child: Icon(
                     Icons.delete,
                     color: Colors.grey[500],
                     size: 13.0,
                   ),
                   onTap: (){
                     widget.callbackToRemove(widget.index);
                   }
                 )
               ],
             )
           ),
         ],
       )
    );
  }

  @override
  Widget build(BuildContext context){
    return _buildElement(context);
  }
}

class FullScreenImage extends StatefulWidget {
  final Uint8List image;
  const FullScreenImage({Key key, @required this.image}) : super(key: key);

  @override
  FullScreenImageState createState() => new FullScreenImageState();
}

class FullScreenImageState extends State<FullScreenImage>{
  @override
  Widget build(BuildContext context){
    return Scaffold(
      body: Image.memory(widget.image)
    );
  }
}

class ParameterDialog extends StatefulWidget {
  final Function callbackToSetParameter;
  final String maximumObject;
  final String confidenceThreshold;
  const ParameterDialog({Key key, this.callbackToSetParameter, this.maximumObject, this.confidenceThreshold }) : super(key: key);

  @override
  ParameterDialogState createState() => new ParameterDialogState();
}

class ParameterDialogState extends State<ParameterDialog>{
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String currentMaximumObject ="10";
  String currentConfidenceThreshold;

  String _validateMaximumObject(String value) {
     if (value.isEmpty)
       return 'The parameter is required.';

    final number = int.parse(value);

     if (number<0 || number>1000)
       return 'Maximum detected objects is from 0 to 1000.';
     return null;
  }

  String _validateConfidenceThreshold(String value) {
    if (value.isEmpty)
      return 'The parameter is required.';
    final number = double.parse(value);
    if (number<0||number>100){
      return 'Confidence is from 0.0 to 1.0.';
    }
    return null;
  }

  void _hanldParameterSettingSubmit() {
    final FormState form = _formKey.currentState;
    form.save();
  }

  @override
  Widget build(BuildContext context){
    return AlertDialog(
        actions: <Widget>[
              FlatButton(
                child: Text('OK'),
                onPressed: () {
                  _hanldParameterSettingSubmit();
                  setState((){
                    widget.callbackToSetParameter(currentMaximumObject, currentConfidenceThreshold);
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
        title: Text('Parameter Settings'),
        content:
          SingleChildScrollView(
            child:  Form(
              autovalidate: true,
              key: _formKey,
              child: ListBody(
                children: <Widget>[
                  // TextFormField(
                  //   keyboardType: TextInputType.number,
                  //   initialValue: widget.maximumObject,
                  //   validator: _validateMaximumObject,
                  //   decoration: InputDecoration(
                  //     labelText: 'Maximum detected objects'
                  //   ),
                  //   onSaved: (String value) {
                  //     setState((){
                  //       currentMaximumObject = value;
                  //     });
                  //    },
                  // ),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    initialValue: widget.confidenceThreshold,
                    validator: _validateConfidenceThreshold,
                    decoration: InputDecoration(
                      labelText: 'Confidence threshold'
                    ),
                    onSaved: (String value) {
                      setState((){
                        currentConfidenceThreshold = value;
                      });
                     },
                  )
                ]
              )
            ),
      )
    );
  }
}
