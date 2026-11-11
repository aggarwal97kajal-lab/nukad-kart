"""Signs release builds with the fixed upload key so the SHA-1 never changes."""
import pathlib, sys

p = pathlib.Path("android/app/build.gradle.kts")
s = p.read_text()
if "nkKeyProps" not in s:
    if "\nandroid {" not in s:
        sys.exit("android block not found")
    top = '''
val nkKeyProps = java.util.Properties().apply {
    rootProject.file("key.properties").inputStream().use { stream -> this.load(stream) }
}

android {'''
    s = s.replace("\nandroid {", top, 1)
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
p.write_text(s)
print(s)
