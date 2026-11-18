package com.shicomp.monshika

import android.content.Intent
import android.net.Uri
import android.os.Build
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.mlkit.common.MlKitException
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// FragmentActivity dibutuhkan local_auth (sidik jari / wajah).
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null

    /** Gambar dari menu Bagikan yang belum diambil Dart (misalnya karena aplikasi masih terkunci). */
    private var pendingImage: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "monshika/receipt").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeSharedImage" -> {
                        result.success(pendingImage)
                        pendingImage = null
                    }
                    "recognize" -> recognize(call.argument<String>("path") ?: "", result)
                    else -> result.notImplemented()
                }
            }
        }
        takeShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (takeShare(intent)) channel?.invokeMethod("shared", null)
    }

    /** Salin gambar yang dibagikan ke cache, karena izin baca URI-nya hilang begitu activity berganti. */
    private fun takeShare(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_SEND || intent.type?.startsWith("image/") != true) return false
        val uri: Uri? = if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
        // Jangan diproses ulang saat activity dibuat ulang dengan intent yang sama.
        intent.action = null
        if (uri == null) return false
        return try {
            val dir = File(cacheDir, "shared").apply { mkdirs() }
            dir.listFiles()?.forEach { it.delete() }
            val out = File(dir, "receipt_${System.currentTimeMillis()}.jpg")
            contentResolver.openInputStream(uri)?.use { input -> out.outputStream().use { input.copyTo(it) } }
                ?: return false
            pendingImage = out.absolutePath
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Baca teks di gambar dengan ML Kit lewat Google Play Services: berjalan di HP,
     * tanpa internet, dan modelnya tidak ikut membesarkan APK.
     */
    private fun recognize(path: String, result: MethodChannel.Result) {
        val image = try {
            InputImage.fromFilePath(this, Uri.fromFile(File(path)))
        } catch (e: Exception) {
            result.error("read", e.message, null)
            return
        }
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        recognizer.process(image)
            .addOnSuccessListener { text ->
                val lines = ArrayList<Map<String, Any>>()
                for (block in text.textBlocks) {
                    for (line in block.lines) {
                        val b = line.boundingBox ?: continue
                        lines.add(mapOf("text" to line.text, "l" to b.left, "t" to b.top, "r" to b.right, "b" to b.bottom))
                    }
                }
                result.success(lines)
            }
            .addOnFailureListener { e ->
                if (e is MlKitException && e.errorCode == MlKitException.UNAVAILABLE) {
                    // Model belum terunduh: minta Play Services mengunduhnya sekarang.
                    ModuleInstall.getClient(this)
                        .installModules(ModuleInstallRequest.newBuilder().addApi(recognizer).build())
                    result.error("model", e.message, null)
                } else {
                    result.error("ocr", e.message, null)
                }
            }
            .addOnCompleteListener { recognizer.close() }
    }
}
