package com.asetq_apps

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.asetq.apps/file_chooser"
    private val EVENT_CHANNEL = "com.asetq.apps/file_result"
    private val FILE_CHOOSER_REQUEST = 1
    private val PERMISSION_REQUEST = 100
    
    private var eventSink: EventChannel.EventSink? = null
    private var cameraPhotoPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openFileChooser" -> {
                    openFileChooser()
                    result.success(null)
                }
                "checkPermissions" -> {
                    checkAndRequestPermissions()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        // Event Channel untuk return result
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun openFileChooser() {
        if (!checkPermissions()) {
            checkAndRequestPermissions()
            return
        }

        var takePictureIntent: Intent? = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
        var photoFile: File? = null
        
        try {
            photoFile = createImageFile()
            takePictureIntent?.putExtra("PhotoPath", cameraPhotoPath)
        } catch (ex: IOException) {
            ex.printStackTrace()
        }

        if (photoFile != null) {
            cameraPhotoPath = "file:" + photoFile.absolutePath
            val photoURI = FileProvider.getUriForFile(
                this,
                applicationContext.packageName + ".fileprovider",
                photoFile
            )
            takePictureIntent?.putExtra(MediaStore.EXTRA_OUTPUT, photoURI)
        } else {
            takePictureIntent = null
        }

        val contentSelectionIntent = Intent(Intent.ACTION_GET_CONTENT)
        contentSelectionIntent.addCategory(Intent.CATEGORY_OPENABLE)
        contentSelectionIntent.type = "image/*"

        val intentArray: Array<Intent> = if (takePictureIntent != null) {
            arrayOf(takePictureIntent)
        } else {
            arrayOf()
        }

        val chooserIntent = Intent(Intent.ACTION_CHOOSER)
        chooserIntent.putExtra(Intent.EXTRA_INTENT, contentSelectionIntent)
        chooserIntent.putExtra(Intent.EXTRA_TITLE, "Pilih Gambar")
        chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, intentArray)

        startActivityForResult(chooserIntent, FILE_CHOOSER_REQUEST)
    }

    @Throws(IOException::class)
    private fun createImageFile(): File {
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val imageFileName = "JPEG_" + timeStamp + "_"
        val storageDir = getExternalFilesDir(Environment.DIRECTORY_PICTURES)
        return File.createTempFile(imageFileName, ".jpg", storageDir)
    }

    private fun checkPermissions(): Boolean {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(Manifest.permission.CAMERA, Manifest.permission.READ_MEDIA_IMAGES)
        } else {
            arrayOf(
                Manifest.permission.CAMERA,
                Manifest.permission.READ_EXTERNAL_STORAGE,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            )
        }

        return permissions.all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun checkAndRequestPermissions() {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(Manifest.permission.CAMERA, Manifest.permission.READ_MEDIA_IMAGES)
        } else {
            arrayOf(
                Manifest.permission.CAMERA,
                Manifest.permission.READ_EXTERNAL_STORAGE,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            )
        }

        val permissionsToRequest = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (permissionsToRequest.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissionsToRequest.toTypedArray(), PERMISSION_REQUEST)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == FILE_CHOOSER_REQUEST) {
            var resultUri: String? = null

            if (resultCode == Activity.RESULT_OK) {
                if (data == null || data.data == null) {
                    // Camera - gunakan photo path yang sudah disimpan
                    if (cameraPhotoPath != null) {
                        resultUri = cameraPhotoPath
                        println("✅ Camera result: $resultUri")
                    }
                } else {
                    // Gallery
                    resultUri = data.data.toString()
                    println("✅ Gallery result: $resultUri")
                }
            }

            // Kirim result ke Flutter via EventChannel
            if (resultUri != null) {
                eventSink?.success(resultUri)
                println("📤 Sending to Flutter: $resultUri")
            } else {
                eventSink?.success("")
                println("❌ No file selected")
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST) {
            if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                println("✅ Permissions granted")
            } else {
                println("❌ Permissions denied")
            }
        }
    }
}