"""Customer app MainActivity: a small channel that gives the phone's Android ID.
The Android ID stays the same after the app is reinstalled, so one phone shows once under Logged-in devices."""
import pathlib, re

ma = next(pathlib.Path("android/app/src/main").rglob("MainActivity.kt"))
pkg = re.search(r"^package (.+)$", ma.read_text(), re.M).group(1)
ma.write_text(f"""package {pkg}

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {{
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nukadkart/device").setMethodCallHandler {{ call, result ->
            when (call.method) {{
                "id" -> result.success(android.provider.Settings.Secure.getString(contentResolver, android.provider.Settings.Secure.ANDROID_ID) ?: "")
                else -> result.notImplemented()
            }}
        }}
    }}
}}
""")
