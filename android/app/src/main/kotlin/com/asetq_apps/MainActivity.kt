package com.asetq_apps

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.asetq_apps/file_chooser"
    private val EVENT_CHANNEL = "com.asetq_apps/file_result"
    private val FILE_CHOOSER_REQUEST = 1001
    private val CAMERA_REQUEST = 1002
    private val CAMERA_PERMISSION_REQUEST = 1003

    private var eventSink: EventChannel.EventSink? = null
    private var pendingResult: MethodChannel.Result? = null
    private var tempPhotoUri: Uri? = null
    private var pendingCameraIntent: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ✅ Method Channel for triggering file chooser
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openFileChooser" -> {
                        pendingResult = result
                        openFileChooser()
                    }
                    "openCamera" -> {
                        pendingResult = result
                        openCamera()
                    }
                    else -> result.notImplemented()
                }
            }

        // ✅ Event Channel for sending results back
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun openFileChooser() {
        try {
            // ✅ Check camera permission first
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED) {
                // Request permission
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.CAMERA),
                    CAMERA_PERMISSION_REQUEST
                )
            }

            // ✅ Create file picker intent
            val fileIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "*/*"
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                    "image/*",
                    "video/*",
                    "application/pdf",
                    "application/msword",
                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                ))
                addCategory(Intent.CATEGORY_OPENABLE)
            }

            // ✅ Create camera intent
            val photoFile = createImageFile()
            val intents = mutableListOf<Intent>()
            
            if (photoFile != null) {
                tempPhotoUri = FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    photoFile
                )
                
                val cameraIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                    putExtra(MediaStore.EXTRA_OUTPUT, tempPhotoUri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                }
                
                // ✅ Verify camera app exists
                if (cameraIntent.resolveActivity(packageManager) != null) {
                    intents.add(cameraIntent)
                }
            }

            // ✅ Create chooser with camera as extra intent
            val chooserIntent = Intent.createChooser(fileIntent, "Select File or Take Photo")
            if (intents.isNotEmpty()) {
                chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, intents.toTypedArray())
            }

            startActivityForResult(chooserIntent, FILE_CHOOSER_REQUEST)
            pendingResult?.success(null)
        } catch (e: Exception) {
            e.printStackTrace()
            eventSink?.error("FILE_CHOOSER_ERROR", e.message, null)
            pendingResult?.error("FILE_CHOOSER_ERROR", e.message, null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        when (requestCode) {
            CAMERA_PERMISSION_REQUEST -> {
                if (grantResults.isNotEmpty() && 
                    grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    // Permission granted - open file chooser again
                    pendingCameraIntent?.let {
                        startActivityForResult(it, FILE_CHOOSER_REQUEST)
                        pendingCameraIntent = null
                    }
                } else {
                    // Permission denied
                    eventSink?.error("CAMERA_PERMISSION_DENIED", 
                        "Camera permission is required", null)
                }
            }
        }
    }

    private fun openCamera() {
        try {
            val photoFile = createImageFile()
            if (photoFile != null) {
                tempPhotoUri = FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    photoFile
                )

                val cameraIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                    putExtra(MediaStore.EXTRA_OUTPUT, tempPhotoUri)
                }

                startActivityForResult(cameraIntent, CAMERA_REQUEST)
                pendingResult?.success(null)
            } else {
                throw Exception("Failed to create image file")
            }
        } catch (e: Exception) {
            e.printStackTrace()
            eventSink?.error("CAMERA_ERROR", e.message, null)
            pendingResult?.error("CAMERA_ERROR", e.message, null)
        }
    }

    private fun createImageFile(): File? {
        return try {
            val storageDir = cacheDir
            File.createTempFile(
                "JPEG_${System.currentTimeMillis()}_",
                ".jpg",
                storageDir
            )
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            FILE_CHOOSER_REQUEST -> {
                if (resultCode == Activity.RESULT_OK) {
                    val uri = data?.data ?: tempPhotoUri
                    if (uri != null) {
                        val filePath = uri.toString()
                        eventSink?.success(filePath)
                    } else {
                        eventSink?.success("")
                    }
                } else {
                    eventSink?.success("")
                }
            }
            CAMERA_REQUEST -> {
                if (resultCode == Activity.RESULT_OK) {
                    tempPhotoUri?.let { uri ->
                        eventSink?.success(uri.toString())
                    } ?: run {
                        eventSink?.success("")
                    }
                } else {
                    eventSink?.success("")
                }
            }
        }
    }
}