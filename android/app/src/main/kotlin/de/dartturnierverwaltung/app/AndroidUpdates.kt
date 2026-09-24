package de.dartturnierverwaltung.app

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

class AndroidUpdates(private val activity: Activity, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, "dartturnier/updates").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "installed" -> {
                        val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
                        result.success(mapOf("version" to info.versionName, "build" to code(info)))
                    }
                    "permission" -> {
                        if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
                            activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:${activity.packageName}")))
                            result.success(false)
                        } else result.success(true)
                    }
                    "validate" -> { validate(); result.success(null) }
                    "install" -> {
                        val apk = validate()
                        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", apk)
                        activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        })
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("ANDROID_UPDATE", error.message ?: "Installation nicht möglich", null)
            }
        }
    }

    private fun code(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()

    private fun signers(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
        return signatures?.map { it.toCharsString() }?.toSet() ?: emptySet()
    }

    private fun validate(): File {
        val apk = File(activity.cacheDir, "updates/update.apk")
        require(apk.isFile) { "Update-Datei fehlt. Bitte erneut herunterladen." }
        val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val manager = activity.packageManager
        val incoming = manager.getPackageArchiveInfo(apk.path, flags)
            ?: throw IllegalArgumentException("Ungültige APK")
        val current = manager.getPackageInfo(activity.packageName, flags)
        require(incoming.packageName == activity.packageName) { "APK gehört nicht zu dieser App." }
        require(code(incoming) > code(current)) { "APK ist nicht neuer als die installierte Version." }
        require(signers(current).isNotEmpty() && signers(incoming) == signers(current)) {
            "Signaturschlüssel stimmt nicht überein. Bei einer bisherigen Debug-Version zuerst Daten exportieren; nicht ohne Sicherung deinstallieren."
        }
        return apk
    }
}
