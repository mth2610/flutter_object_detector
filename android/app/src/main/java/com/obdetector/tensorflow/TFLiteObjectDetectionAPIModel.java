package com.obdetector.tensorflow;

import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.BitmapFactory;
import android.os.SystemClock;
import android.os.Trace;
import android.os.Environment;
import android.util.Log;
import android.graphics.RectF;
import android.graphics.Paint;
import android.graphics.Paint.Style;
import android.graphics.Color;
import android.content.Context;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.PriorityQueue;
import java.util.Vector;
import java.util.Map;
import java.util.HashMap;
import org.tensorflow.lite.Interpreter;

/** A classifier specialized to label images using TensorFlow. */
public class TFLiteObjectDetectionAPIModel implements Classifier {
  private static final String TAG = "TFLiteObjectDetectionAPIModel";

  // Only return this many results with at least this confidence.

  // Only return this many results.
  private static final int NUM_DETECTIONS = 10;
  private boolean isModelQuantized;
  // Float model
  private static final float IMAGE_MEAN = 128.0f;
  private static final float IMAGE_STD = 128.0f;
  // Number of threads in the java app
  private static final int NUM_THREADS = 4;
  // Config values.
  private int inputSize;
  // Pre-allocated buffers.
  private Vector<String> labels = new Vector<String>();
  private int[] intValues;
  // outputLocations: array of shape [Batchsize, NUM_DETECTIONS,4]
  // contains the location of detected boxes
  private float[][][] outputLocations;
  // outputClasses: array of shape [Batchsize, NUM_DETECTIONS]
  // contains the classes of detected boxes
  private float[][] outputClasses;
  // outputScores: array of shape [Batchsize, NUM_DETECTIONS]
  // contains the scores of detected boxes
  private float[][] outputScores;
  // numDetections: array of shape [Batchsize]
  // contains the number of detected boxes
  private float[] numDetections;

  private ByteBuffer imgData;

  private Interpreter tfLite;

  private Bitmap droppedBitmap;
  private double confidenceThreshold;


  public TFLiteObjectDetectionAPIModel() {}

  /** Memory-map the model file in Assets. */
  private static MappedByteBuffer loadModelFile(AssetManager assets, String modelFilename)
      throws IOException {
    AssetFileDescriptor fileDescriptor = assets.openFd(modelFilename);
    FileInputStream inputStream = new FileInputStream(fileDescriptor.getFileDescriptor());
    FileChannel fileChannel = inputStream.getChannel();
    long startOffset = fileDescriptor.getStartOffset();
    long declaredLength = fileDescriptor.getDeclaredLength();
    return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength);
  }

  /**
   * Initializes a native TensorFlow session for classifying images.
   *
   * @param assetManager The asset manager to be used to load assets.
   * @param modelFilename The filepath of the model GraphDef protocol buffer.
   * @param labelFilename The filepath of label file for classes.
   * @param inputSize The input size. A square image of inputSize x inputSize is assumed.
   * @throws IOException
   */

   public static Classifier create(
       final AssetManager assetManager,
       final String modelFilename,
       final String labelFilename,
       final int inputSize,
       final boolean isQuantized,
       final int maximumObject,
       final double confidenceThreshold)
      {
     final TFLiteObjectDetectionAPIModel d = new TFLiteObjectDetectionAPIModel();

     //d.NUM_DETECTIONS = maximumObject;
     d.confidenceThreshold = confidenceThreshold;

     Log.i(TAG, "Reading labels from: " + labelFilename);
     BufferedReader br = null;
     try {
       br = new BufferedReader(new InputStreamReader(assetManager.open(labelFilename)));
       String line;
       while ((line = br.readLine()) != null) {
         d.labels.add(line);
       }
       br.close();
     } catch (IOException e) {
       throw new RuntimeException("Problem reading label file!" , e);
     }


     d.inputSize = inputSize;

     try {
       d.tfLite = new Interpreter(loadModelFile(assetManager, modelFilename));
     } catch (Exception e) {
       throw new RuntimeException(e);
     }

     d.isModelQuantized = isQuantized;
     // Pre-allocate buffers.
     int numBytesPerChannel;
     if (isQuantized) {
       numBytesPerChannel = 1; // Quantized
     } else {
       numBytesPerChannel = 4; // Floating point
     }
     d.imgData = ByteBuffer.allocateDirect(1 * d.inputSize * d.inputSize * 3 * numBytesPerChannel);
     d.imgData.order(ByteOrder.nativeOrder());
     d.intValues = new int[d.inputSize * d.inputSize];

     d.tfLite.setNumThreads(NUM_THREADS);
     d.outputLocations = new float[1][NUM_DETECTIONS][4];
     d.outputClasses = new float[1][NUM_DETECTIONS];
     d.outputScores = new float[1][NUM_DETECTIONS];
     d.numDetections = new float[1];
     return d;
   }

  public static Matrix getTransformationMatrix(
        final int srcWidth,
        final int srcHeight,
        final int dstWidth,
        final int dstHeight,
        final int applyRotation,
        final boolean maintainAspectRatio) {
      final Matrix matrix = new Matrix();

      if (applyRotation != 0) {
        if (applyRotation % 90 != 0) {
          // LOGGER.w("Rotation of %d % 90 != 0", applyRotation);
        }

        // Translate so center of image is at origin.
        matrix.postTranslate(-srcWidth / 2.0f, -srcHeight / 2.0f);

        // Rotate around origin.
        matrix.postRotate(applyRotation);
      }

      // Account for the already applied rotation, if any, and then determine how
      // much scaling is needed for each axis.
      final boolean transpose = (Math.abs(applyRotation) + 90) % 180 == 0;

      final int inWidth = transpose ? srcHeight : srcWidth;
      final int inHeight = transpose ? srcWidth : srcHeight;

      // Apply scaling if necessary.
      if (inWidth != dstWidth || inHeight != dstHeight) {
        final float scaleFactorX = dstWidth / (float) inWidth;
        final float scaleFactorY = dstHeight / (float) inHeight;

        if (maintainAspectRatio) {
          // Scale by minimum factor so that dst is filled completely while
          // maintaining the aspect ratio. Some image may fall off the edge.
          final float scaleFactor = Math.max(scaleFactorX, scaleFactorY);
          matrix.postScale(scaleFactor, scaleFactor);
        } else {
          // Scale exactly to fill dst from src.
          matrix.postScale(scaleFactorX, scaleFactorY);
        }
      }

      if (applyRotation != 0) {
        // Translate back from origin centered reference to destination frame.
        matrix.postTranslate(dstWidth / 2.0f, dstHeight / 2.0f);
      }

      return matrix;
  }

  /** Writes Image data into a {@code ByteBuffer}. */
  private void convertBitmapToByteBuffer(Bitmap bitmapRaw) {
    if (imgData == null) {
      return;
    }
    imgData.rewind();
    Matrix frameToCropTransform = getTransformationMatrix(
      bitmapRaw.getWidth(), bitmapRaw.getHeight(),
      inputSize , inputSize, 90, true
      );

    Matrix cropToFrameTransform = new Matrix();
    frameToCropTransform.invert(cropToFrameTransform);

    Bitmap bitmap = Bitmap.createBitmap( inputSize, inputSize, Bitmap.Config.ARGB_8888);
    final Canvas canvas = new Canvas(bitmap);
    canvas.drawBitmap(bitmapRaw, frameToCropTransform, null);
    droppedBitmap = bitmap;
    bitmap.getPixels(intValues, 0, bitmap.getWidth(), 0, 0, bitmap.getWidth(), bitmap.getHeight());
    // Convert the image to floating point.
    int pixel = 0;
    long startTime = SystemClock.uptimeMillis();
    for (int i = 0; i < inputSize; ++i) {
      for (int j = 0; j < inputSize; ++j) {
        final int val = intValues[pixel++];
        imgData.put((byte) ((val >> 16) & 0xFF));
        imgData.put((byte) ((val >> 8) & 0xFF));
        imgData.put((byte) (val & 0xFF));
      }
    }
    long endTime = SystemClock.uptimeMillis();
    Log.d(TAG, "Timecost to put values into ByteBuffer: " + Long.toString(endTime - startTime));
  }

  @Override
  public Map<String, Object> recognizeImage(final Bitmap bitmap, final Context context) {
    // Log this method so that it can be analyzed with systrace.
     Trace.beginSection("recognizeImage");

     Trace.beginSection("preprocessBitmap");

     long startTime;
     long endTime;
     startTime = SystemClock.uptimeMillis();

     convertBitmapToByteBuffer(bitmap);

     outputLocations = new float[1][NUM_DETECTIONS][4];
     outputClasses = new float[1][NUM_DETECTIONS];
     outputScores = new float[1][NUM_DETECTIONS];
     numDetections = new float[1];

     Object[] inputArray = {imgData};
     Map<Integer, Object> outputMap = new HashMap<>();
     outputMap.put(0, outputLocations);
     outputMap.put(1, outputClasses);
     outputMap.put(2, outputScores);
     outputMap.put(3, numDetections);
     Trace.endSection();

     // Run the inference call.
     Trace.beginSection("run");
     tfLite.runForMultipleInputsOutputs(inputArray, outputMap);
     Trace.endSection();

     // Show the best detections.
     // after scaling them back to the input size.

     Bitmap cropCopyBitmap = droppedBitmap;
     final Canvas new_canvas = new Canvas(cropCopyBitmap);
     final Paint boundingbox_paint = new Paint();

     boundingbox_paint.setStyle(Style.STROKE);
     boundingbox_paint.setStrokeWidth(1.0f);
     boundingbox_paint.setTextSize(12); // Text SizeSize

     int detectedObjects = 0;
     ArrayList<Integer> idlList = new ArrayList<Integer>();
     ArrayList<String> labelList = new ArrayList<String>();
     ArrayList<Float> confidencelList = new ArrayList<Float>();

     for (int i = 0; i < NUM_DETECTIONS; ++i) {
       // ArrayList<Float> detection = new ArrayList<>();
       // detection.add(outputLocations[0][i][1] * inputSize);
       // detection.add(outputLocations[0][i][0] * inputSize);
       // detection.add(outputLocations[0][i][3] * inputSize);
       // detection.add(outputLocations[0][i][2] * inputSize);

      final RectF detectionRect =
        new RectF(
            outputLocations[0][i][1] * inputSize,
            outputLocations[0][i][0] * inputSize,
            outputLocations[0][i][3] * inputSize,
            outputLocations[0][i][2] * inputSize);
      // SSD Mobilenet V1 Model assumes class 0 is background class
     // in label file and class labels start from 1 to number_of_classes+1,
     // while outputClasses correspond to class index from 0 to number_of_classes
       int labelOffset = 1;
       //String colorhex = Integer.toHexString((int) outputClasses[0][i] + labelOffset);
       //Integer decodeColorhex = Color.decodeColorhex("#"+colorhex);

       if(outputScores[0][i] > confidenceThreshold){
         boundingbox_paint.setColor(Color.RED);
         detectedObjects += 1;
         idlList.add(detectedObjects);
         labelList.add(labels.get((int) outputClasses[0][i] + labelOffset));
         confidencelList.add(outputScores[0][i]);
         new_canvas.drawRect(detectionRect, boundingbox_paint);
         new_canvas.drawText(
           labels.get((int) outputClasses[0][i] + labelOffset),
           outputLocations[0][i][3] * inputSize,
           outputLocations[0][i][0] * inputSize,
           boundingbox_paint
         );
       }
     }

     Map<String, Object> recognitions = new HashMap<>();
     recognitions.put("id", idlList);
     recognitions.put("label", labelList);
     recognitions.put("confidence", confidencelList);

     int ouput_size = cropCopyBitmap.getRowBytes() * cropCopyBitmap.getHeight();
     ByteBuffer byteBuffer = ByteBuffer.allocate(ouput_size);
     cropCopyBitmap.copyPixelsToBuffer(byteBuffer);
     Map<String, Object> finalResults = new HashMap<>();
     finalResults.put("recognitions", recognitions);

    try {
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        cropCopyBitmap.compress(Bitmap.CompressFormat.PNG, 0, outputStream);
        finalResults.put("detectedImage", outputStream.toByteArray());

    } catch (Exception e) {
        e.printStackTrace();
    }

     Trace.endSection(); // "recognizeImage"
     return finalResults;

   }

  @Override
  public void enableStatLogging(boolean logStats) {
  }

  @Override
  public String getStatString() {
    return "";
  }

  @Override
  public void close() {
  }
}
