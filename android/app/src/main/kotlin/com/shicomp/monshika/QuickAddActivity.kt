package com.shicomp.monshika

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs

/**
 * Dialog transparan untuk mencatat transaksi langsung dari widget beranda,
 * tanpa membuka aplikasi utama. Menjalankan entrypoint Dart `quickAddMain`.
 */
class QuickAddActivity : FlutterActivity() {
    override fun getDartEntrypointFunctionName(): String = "quickAddMain"

    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode =
        FlutterActivityLaunchConfigs.BackgroundMode.transparent
}
