package com.example.objectdetector2;

import android.content.res.AssetManager;
import android.os.Bundle;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.content.Context;
import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import com.obdetector.tensorflow.TFLiteObjectDetectionAPIModel;
import com.obdetector.tensorflow.Classifier;
import java.util.List;
import java.util.Map;

public class MainActivity extends FlutterActivity {
  private static final String CHANNEL = "obdetector.com/tensorflow";

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    GeneratedPluginRegistrant.registerWith(this);

    new MethodChannel(getFlutterView(), CHANNEL).setMethodCallHandler(
        new MethodCallHandler() {
          @Override
          public void onMethodCall(MethodCall call, Result result) {
            if (call.method.equals("imageClassifier")){
              String path = call.argument("path");
              int maximumObject = call.argument("maximumObject");
              double confidenceThresholdh = call.argument("confidenceThreshold");

              AssetManager assetManager = getApplicationContext().getAssets();

              String modelPath = "detect.tflite";
              //String modelPath = "detect.tflite";

              String labelPath = "labelmap.txt";
              int inputSize = 300;
              Bitmap decodedSampleBitmap = BitmapFactory.decodeFile(path);
              Classifier imageClassifier = TFLiteObjectDetectionAPIModel.create(assetManager, modelPath, labelPath, inputSize, true, maximumObject, confidenceThresholdh);
              Map<String, Object> results = imageClassifier.recognizeImage(decodedSampleBitmap, getApplicationContext());
              result.success(results);
              //System.out.print(assetManager.list());
            }
          }
        });
  }
}
