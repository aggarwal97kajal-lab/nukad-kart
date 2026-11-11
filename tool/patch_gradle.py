"""Signs release builds with the fixed upload key so the SHA-1 never changes."""
import pathlib, sys

p = pathlib.Path("android/app/build.gradle.kts")
s = p.read_text()
block = '''    signingConfigs {
        create("release") {
            val props = java.util.Properties().apply {
                rootProject.file("key.properties").inputStream().use { load(it) }
            }
            keyAlias = props.getProperty("keyAlias")
            keyPassword = props.getProperty("keyPassword")
            storePassword = props.getProperty("storePassword")
            storeFile = file(props.getProperty("storeFile"))
        }
    }

    buildTypes {'''
if 'create("release")' not in s:
    if "    buildTypes {" not in s:
        sys.exit("buildTypes block not found")
    s = s.replace("    buildTypes {", block, 1)
if 'signingConfigs.getByName("debug")' not in s:
    sys.exit("debug signing line not found")
s = s.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
p.write_text(s)
print(s)
