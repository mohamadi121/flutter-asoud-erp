package ir.asoud.asoud_erp

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "ir.asoud.asoud_erp/actions"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchUri" -> {
                        val uri = call.argument<String>("uri")
                        if (uri.isNullOrBlank()) {
                            result.error("INVALID_URI", "URI is empty", null)
                        } else {
                            runCatching {
                                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(uri)))
                            }.onSuccess {
                                result.success(null)
                            }.onFailure {
                                result.error("NO_HANDLER", it.message, null)
                            }
                        }
                    }
                    "shareText" -> {
                        val text = call.argument<String>("text").orEmpty()
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        startActivity(Intent.createChooser(intent, "اشتراک‌گذاری اطلاعات"))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
