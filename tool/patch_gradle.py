"""Signs release builds with the fixed upload key so the SHA-1 never changes."""
import pathlib, sys

p = pathlib.Path("android/app/build.gradle.kts")
s = p.read_text()
if "nkKeyProps" not in s:
    if "\nandroid {" not in s:
        sys.exit("android block not found")
    top = '''
val nkKeyProps = Properties().apply {
    FileInputStream(rootProject.file("key.properties")).use { stream -> load(stream) }
}

android {'''
    s = s.replace("\nandroid {", top, 1)
    s = "import java.io.FileInputStream\nimport java.util.Properties\n\n" + s
    block = '''    signingConfigs {
        create("release") {
            keyAlias = nkKeyProps.getProperty("keyAlias")
            keyPassword = nkKeyProps.getProperty("keyPassword")
            storePassword = nkKeyProps.getProperty("storePassword")
            storeFile = file(nkKeyProps.getProperty("storeFile"))
        }
    }

    buildTypes {'''
    if "    buildTypes {" not in s:
        sys.exit("buildTypes block not found")
    s = s.replace("    buildTypes {", block, 1)
if 'signingConfigs.getByName("debug")' not in s:
    sys.exit("debug signing line not found")
s = s.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
# flutter_local_notifications needs Java 8+ library desugaring.
if "isCoreLibraryDesugaringEnabled" not in s:
    if "compileOptions {" not in s:
        sys.exit("compileOptions block not found")
    s = s.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
    s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
p.write_text(s)
print(s)
