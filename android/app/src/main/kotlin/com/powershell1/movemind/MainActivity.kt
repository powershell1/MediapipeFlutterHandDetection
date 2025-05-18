package com.powershell1.movemind

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.annotation.NonNull
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.vision.core.RunningMode
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.io.File
import java.io.FileOutputStream
import org.json.JSONArray
import org.json.JSONObject

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.powershell1.movemind/handlandmarker"
    private var handLandmarker: HandLandmarker? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeHandLandmarker" -> {
                    try {
                        initializeHandLandmarker()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INIT_ERROR", "Failed to initialize HandLandmarker", e.message)
                    }
                }
                "testMessage" -> {
                    val message = call.argument<String>("message")
                    result.success("Received message: $message")
                }
                "detectHandLandmarks" -> {
                    val imageBytes = call.argument<ByteArray>("imageBytes")
                    val width = call.argument<Int>("width") ?: 0
                    val height = call.argument<Int>("height") ?: 0

                    if (imageBytes == null) {
                        result.error("DETECTION_ERROR", "Image data is null", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val landmarks = detectHandLandmarks(imageBytes, width, height)
                        result.success(landmarks)
                    } catch (e: Exception) {
                        result.error("DETECTION_ERROR", "Hand landmark detection failed", e.message)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun returnLivestreamResult(result: HandLandmarkerResult, image: MPImage) {
        println("HandLandmarker result: $result")
    }

    private fun returnLivestreamError(error: Exception) {
        println("HandLandmarker error: ${error.message}")
    }

    private fun initializeHandLandmarker() {
        println("Initializing HandLandmarker...")
        try {
            val context = applicationContext
            println("Context: $context")
            val modelName = "hand_landmarker.task"

            // Copy model file with verification
            val modelFile = context.assets.open(modelName).use { input ->
                val outputFile = context.cacheDir.resolve(modelName)
                outputFile.outputStream().use { output ->
                    input.copyTo(output)
                    println("Copied ${input.available()} bytes to cache")
                }
                outputFile
            }

            if (!modelFile.exists() || modelFile.length() == 0L) {
                throw Exception("Model file not copied correctly")
            }

            println("Model file path: ${modelFile.absolutePath}")

            // Create HandLandmarker with additional logging
            println("Creating base options...")
            val baseOptions = BaseOptions.builder()
                .setModelAssetPath(modelFile.absolutePath)
                .build()

            println("Creating HandLandmarker options...")
            val options = HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setNumHands(2)
                .setMinHandDetectionConfidence(0.5f)
                .setMinHandPresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setRunningMode(RunningMode.IMAGE)
                .build()
                /*
                .setResultListener(this::returnLivestreamResult)
                .setErrorListener(this::returnLivestreamError)

                 */

            println("About to create HandLandmarker...")
            handLandmarker = HandLandmarker.createFromOptions(context, options)
            println("HandLandmarker created successfully")
        } catch (e: Exception) {
            println("HandLandmarker initialization failed: ${e.javaClass.name}: ${e.message}")
            e.printStackTrace()
            throw e
        }
    }

    private fun detectHandLandmarks(imageBytes: ByteArray, width: Int, height: Int): String {
        // Convert RGB (3 bytes per pixel) to ARGB (4 bytes per pixel)
        val argbBytes = ByteArray(width * height * 4)

        for (i in 0 until width * height) {
            // RGB source positions
            val rgbOffset = i * 3
            // ARGB destination positions
            val argbOffset = i * 4

            // Set alpha to 255 (fully opaque)
            argbBytes[argbOffset] = imageBytes[rgbOffset]  // 255 as a byte
            // Copy RGB values
            argbBytes[argbOffset + 1] = imageBytes[rgbOffset + 1]     // R
            argbBytes[argbOffset + 2] = imageBytes[rgbOffset + 2] // G
            argbBytes[argbOffset + 3] = -1 // B
        }

        // Convert byte array to bitmap
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val buffer = ByteBuffer.wrap(argbBytes)
        bitmap.copyPixelsFromBuffer(buffer)
        // Save bitmap to PNG file
        /*
        try {
            val filename = "hand_image_${System.currentTimeMillis()}.png"
            val file = File(context.cacheDir, filename)

            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                out.flush()
            }

            println("Saved bitmap to: ${file.absolutePath}")
        } catch (e: Exception) {
            println("Failed to save bitmap: ${e.message}")
        }

         */


        // Create MediaPipe image and run inference
        val mpImage = BitmapImageBuilder(bitmap).build()
        val result = handLandmarker?.detect(mpImage) ?: return "[]"

        // Convert result to JSON
        return handLandmarkerResultToJson(result)
    }

    private fun handLandmarkerResultToJson(result: HandLandmarkerResult): String {
        val jsonArray = JSONArray()

        for (handIndex in 0 until result.handednesses().size) {
            val handObject = JSONObject()

            // Get handedness (left/right hand)
            val handedness = result.handednesses()[handIndex]
            handObject.put("handedness", handedness[0].categoryName())
            handObject.put("score", handedness[0].score())

            // Get landmarks
            val landmarks = result.landmarks()[handIndex]
            val landmarksArray = JSONArray()

            for (landmark in landmarks) {
                val landmarkObject = JSONObject()
                landmarkObject.put("x", landmark.x())
                landmarkObject.put("y", landmark.y())
                landmarkObject.put("z", landmark.z())
                landmarksArray.put(landmarkObject)
            }

            handObject.put("landmarks", landmarksArray)
            jsonArray.put(handObject)
        }

        return jsonArray.toString()
    }
}