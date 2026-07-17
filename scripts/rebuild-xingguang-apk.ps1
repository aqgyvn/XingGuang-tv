param(
    [string]$Configuration = "local"
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$decoded = Join-Path $root "apkwork\decoded"
$apkwork = Join-Path $root "apkwork"
$unsigned = Join-Path $apkwork "unsigned-rebuild.apk"
$aligned = Join-Path $apkwork "aligned-rebuild.apk"
$signed = Join-Path $apkwork "signed-rebuild-$Configuration.apk"
$keystoreDir = Join-Path $apkwork "keystore"
$keystore = Join-Path $keystoreDir "xingguang-rebuild-local.p12"

$defaultToolRoot = "C:\Users\52396\Documents\Codex\2026-07-01\new-chat-3\apkwork\tools"
$javaHome = if ($env:JAVA_HOME) { $env:JAVA_HOME } else { Join-Path $defaultToolRoot "jre17\jdk-17.0.19+10-jre" }
$java = Join-Path $javaHome "bin\java.exe"
$keytool = Join-Path $javaHome "bin\keytool.exe"
$apktool = if ($env:APKTOOL_JAR) { $env:APKTOOL_JAR } else { Join-Path $defaultToolRoot "apktool.jar" }
$buildTools = if ($env:ANDROID_BUILD_TOOLS) { $env:ANDROID_BUILD_TOOLS } else { Join-Path $defaultToolRoot "build-tools-33.0.2\android-13" }
$zipalign = Join-Path $buildTools "zipalign.exe"
$apksigner = Join-Path $buildTools "apksigner.bat"
$password = if ($env:XINGGUANG_REBUILD_PASS) { $env:XINGGUANG_REBUILD_PASS } else { "xingguang-rebuild-20260704" }

foreach ($path in @($decoded, $java, $keytool, $apktool, $zipalign, $apksigner)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required path not found: $path"
    }
}

New-Item -ItemType Directory -Force -Path $keystoreDir | Out-Null

if (-not (Test-Path -LiteralPath $keystore)) {
    & $keytool -genkeypair -v `
        -keystore $keystore `
        -storetype PKCS12 `
        -storepass $password `
        -keypass $password `
        -alias xingguang_rebuild `
        -keyalg RSA `
        -keysize 2048 `
        -validity 3650 `
        -dname "CN=Xingguang Rebuild, OU=Local Rebuild, O=Codex, L=Local, ST=Local, C=CN" | Out-Null
}

& $java -jar $apktool b $decoded -o $unsigned
& $zipalign -f -p 4 $unsigned $aligned

$env:JAVA_HOME = $javaHome
$env:Path = (Join-Path $javaHome "bin") + ";" + $env:Path

& $apksigner sign `
    --ks $keystore `
    --ks-key-alias xingguang_rebuild `
    --ks-pass "pass:$password" `
    --key-pass "pass:$password" `
    --out $signed `
    $aligned

& $apksigner verify --verbose --print-certs $signed
Get-Item -LiteralPath $signed
