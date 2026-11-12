"""Partner app Android settings: permissions, UPI app list, the UPI pay channel. Safe to run again."""
import pathlib, re

m = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = m.read_text()
for perm in ["INTERNET", "CAMERA", "ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION", "POST_NOTIFICATIONS"]:
    tag = f'<uses-permission android:name="android.permission.{perm}"/>'
    if tag not in s:
        s = s.replace("<application", tag + "\n    <application", 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Nukad Partner"', s, count=1)
queries = [
    '<intent><action android:name="android.intent.action.VIEW"/><data android:scheme="upi"/></intent>',
    '<intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>',
    '<intent><action android:name="android.media.action.IMAGE_CAPTURE"/></intent>',
]
for q in queries:
    if q not in s:
        if "<queries>" in s:
            s = s.replace("<queries>", "<queries>\n        " + q, 1)
        else:
            s = s.replace("</manifest>", "    <queries>\n        " + q + "\n    </queries>\n</manifest>", 1)
m.write_text(s)

# applicationId must be com.nukadkart.partner (Firebase app is registered with it).
g = pathlib.Path("android/app/build.gradle.kts")
gs = g.read_text()
gs = re.sub(r'applicationId = "[^"]*"', 'applicationId = "com.nukadkart.partner"', gs)
g.write_text(gs)

ma = next(pathlib.Path("android/app/src/main").rglob("MainActivity.kt"))
pkg = re.search(r"^package (.+)$", ma.read_text(), re.M).group(1)
ma.write_text(f"""package {pkg}

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {{
    private var upiResult: MethodChannel.Result? = null
    private val upiRequest = 4711

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nukadpartner/device").setMethodCallHandler {{ call, result ->
            if (call.method == "id") result.success(android.provider.Settings.Secure.getString(contentResolver, android.provider.Settings.Secure.ANDROID_ID) ?: "")
            else result.notImplemented()
        }}
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nukadpartner/upi").setMethodCallHandler {{ call, result ->
            when (call.method) {{
                "apps" -> {{
                    try {{
                        val pm = packageManager
                        val list = pm.queryIntentActivities(Intent(Intent.ACTION_VIEW, Uri.parse("upi://pay")), 0)
                        val seen = HashSet<String>()
                        val out = ArrayList<Map<String, Any>>()
                        for (ri in list) {{
                            val p = ri.activityInfo.packageName
                            if (!seen.add(p)) continue
                            val d = ri.loadIcon(pm)
                            val bmp = Bitmap.createBitmap(112, 112, Bitmap.Config.ARGB_8888)
                            d.setBounds(0, 0, 112, 112)
                            d.draw(Canvas(bmp))
                            val bos = ByteArrayOutputStream()
                            bmp.compress(Bitmap.CompressFormat.PNG, 100, bos)
                            out.add(mapOf("package" to p, "name" to ri.loadLabel(pm).toString(), "icon" to bos.toByteArray()))
                        }}
                        result.success(out)
                    }} catch (e: Exception) {{
                        result.error("UPI_LIST", e.message, null)
                    }}
                }}
                "pay" -> {{
                    val uri = call.argument<String>("uri")
                    val p = call.argument<String>("package")
                    if (uri == null) {{ result.error("NO_URI", "No payment link", null); return@setMethodCallHandler }}
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri))
                    if (p != null) intent.setPackage(p)
                    try {{
                        upiResult?.success(null)
                        upiResult = result
                        startActivityForResult(if (p == null) Intent.createChooser(intent, "Pay with") else intent, upiRequest)
                    }} catch (e: Exception) {{
                        upiResult = null
                        result.error("NO_APP", e.message, null)
                    }}
                }}
                else -> result.notImplemented()
            }}
        }}
    }}

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {{
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == upiRequest) {{
            val r = data?.getStringExtra("response") ?: data?.getStringExtra("Status")
            upiResult?.success(r ?: (if (resultCode == RESULT_OK) "" else null))
            upiResult = null
        }}
    }}
}}
""")
print(m.read_text())
