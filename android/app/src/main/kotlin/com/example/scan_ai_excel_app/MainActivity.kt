package com.example.scan_ai_excel_app

import com.example.scan_ai_excel_app.scanner.NativeDocumentChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeDocumentChannel.register(flutterEngine)
    }
}
