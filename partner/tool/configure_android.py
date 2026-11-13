"""Partner app Android settings: permissions, UPI app list, the UPI pay channel. Safe to run again."""
import pathlib, re

m = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = m.read_text()
# FOREGROUND_SERVICE_LOCATION + WAKE_LOCK: a thela's location keeps going with the screen off (ongoing notification).
# REQUEST_IGNORE_BATTERY_OPTIMIZATIONS: one tap "Allow" so the phone does not stop it.
for perm in ["INTERNET", "CAMERA", "ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION", "POST_NOTIFICATIONS",
             "FOREGROUND_SERVICE", "FOREGROUND_SERVICE_LOCATION", "WAKE_LOCK", "REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"]:
    tag = f'<uses-permission android:name="android.permission.{perm}"/>'
    if tag not in s:
        s = s.replace("<application", tag + "\n    <application", 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Nukad Kart Partner"', s, count=1)
# UPI apps register "upi://pay" (scheme + host). Asking only for "upi" hides most of them on Android 11+,
# so ask for both, and name the common UPI apps too.
# Package names from Razorpay's list of UPI apps (docs: payments/payment-methods/upi/supported-apps),
# plus CheQ (com.cheq.retail, Google Play). Wrong guesses from before (slice, kiwi, bharatpe, cheq) are fixed.
UPI_PACKAGES = [
    "com.google.android.apps.nbu.paisa.user", "com.phonepe.app", "net.one97.paytm", "com.dreamplug.androidapp",
    "in.org.npci.upiapp", "com.tatadigital.tcp", "com.csam.icici.bank.imobile", "in.amazon.mShop.android.shopping",
    "com.samsung.android.spay", "com.mobikwik_new", "in.gokiwi.kiwitpap", "com.naviapp", "money.super.payments",
    "com.shriram.one", "com.kotak811mobilebankingapp.instantsavingsupiscanandpayrecharge", "indwin.c3.shareapp",
    "com.hdfcbank.payzapp", "com.epifi.paisa", "com.popclub.android", "org.altruist.BajajExperia", "com.postpe.app",
    "com.whatsapp", "com.whatsapp.w4b", "com.fampay.in", "com.olive.kotak.upi", "com.msf.kbank.mobile", "com.sbi.upi",
    "com.sbi.lotusintouch", "com.snapwork.hdfc", "com.upi.axispay", "com.axis.mobile", "money.jupiter",
    "com.idfcfirstbank.optimus", "com.canarabank.mobility", "com.bankofbaroda.upi", "com.fss.pnbpsp", "com.mgs.pnbupi",
    "com.fedmobile", "com.iexceed.appzillon.ippbMB", "com.jio.myjio", "com.infrasoft.uboi", "com.freecharge.android",
    "com.SIBMobile", "com.nextbillion.groww", "com.dbs.in.digitalbank", "com.IndianBank.IndOASIS",
    "com.ausmallfinancebank.amb", "com.infrasofttech.CentralBank", "com.rblbank.mobank", "com.fss.indus",
    "com.indusind.indie", "com.lcode.ucoupi", "in.irisbyyes.app", "com.icicibank.pockets", "com.lcode.csbupi",
    "com.euronet.iobupi", "com.flipkart.android", "com.myairtelapp", "com.cheq.retail",
]
queries = [
    '<intent><action android:name="android.intent.action.VIEW"/><data android:scheme="upi" android:host="pay"/></intent>',
    '<intent><action android:name="android.intent.action.VIEW"/><category android:name="android.intent.category.BROWSABLE"/><data android:scheme="upi" android:host="pay"/></intent>',
] + [f'<package android:name="{p}"/>' for p in UPI_PACKAGES] + [
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
            when (call.method) {{
                "id" -> result.success(android.provider.Settings.Secure.getString(contentResolver, android.provider.Settings.Secure.ANDROID_ID) ?: "")
                "brand" -> result.success(android.os.Build.MANUFACTURER.lowercase())
                "batteryFree" -> {{
                    val pm = getSystemService(POWER_SERVICE) as android.os.PowerManager
                    result.success(android.os.Build.VERSION.SDK_INT < 23 || pm.isIgnoringBatteryOptimizations(packageName))
                }}
                "askBattery" -> {{
                    try {{
                        startActivity(Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
                    }} catch (e: Exception) {{
                        try {{ startActivity(Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) }} catch (_: Exception) {{}}
                    }}
                    result.success(null)
                }}
                "autostart" -> {{
                    // Xiaomi, Oppo/Realme, Vivo, Huawei/Honor, Samsung, Asus keep their own "auto start" lists.
                    val comps = listOf(
                        "com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity",
                        "com.coloros.safecenter/com.coloros.safecenter.permission.startup.StartupAppListActivity",
                        "com.coloros.safecenter/com.coloros.safecenter.startupapp.StartupAppListActivity",
                        "com.oppo.safe/com.oppo.safe.permission.startup.StartupAppListActivity",
                        "com.iqoo.secure/com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
                        "com.vivo.permissionmanager/com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                        "com.huawei.systemmanager/com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                        "com.samsung.android.lool/com.samsung.android.sm.ui.battery.BatteryActivity",
                        "com.asus.mobilemanager/com.asus.mobilemanager.entry.FunctionActivity")
                    var opened = false
                    for (c in comps) {{
                        try {{
                            startActivity(Intent().setComponent(android.content.ComponentName.unflattenFromString(c)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            opened = true
                            break
                        }} catch (_: Exception) {{}}
                    }}
                    if (!opened) startActivity(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                    result.success(opened)
                }}
                else -> result.notImplemented()
            }}
        }}
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nukadpartner/upi").setMethodCallHandler {{ call, result ->
            when (call.method) {{
                "apps" -> {{
                    try {{
                        val pm = packageManager
                        val flags = if (android.os.Build.VERSION.SDK_INT >= 23) android.content.pm.PackageManager.MATCH_ALL else 0
                        val list = pm.queryIntentActivities(Intent(Intent.ACTION_VIEW, Uri.parse("upi://pay?pa=test@upi&pn=Test&am=1&cu=INR")), flags)
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
