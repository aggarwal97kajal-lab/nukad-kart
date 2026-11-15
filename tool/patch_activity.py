"""Customer app MainActivity: a small channel that gives the phone's Android ID (the same after a reinstall, so one
phone shows once under Logged-in devices), and opens the phone's "Autostart" / battery settings so calls ring
while the app is closed (Xiaomi, Oppo, Vivo… stop closed apps from getting them otherwise)."""
import pathlib, re

ma = next(pathlib.Path("android/app/src/main").rglob("MainActivity.kt"))
pkg = re.search(r"^package (.+)$", ma.read_text(), re.M).group(1)
ma.write_text(f"""package {pkg}

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {{
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nukadkart/device").setMethodCallHandler {{ call, result ->
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
    }}
}}
""")
