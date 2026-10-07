package com.mediahub.mediacenter

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    private val CHANNEL = "com.mediahub.mediacenter/pip"
    private var isPipMode = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "isPiPAvailable" -> {
                        val available = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.hasSystemFeature(
                                PackageManager.FEATURE_PICTURE_IN_PICTURE
                            )
                        } else false
                        result.success(available)
                    }

                    "enterPiP" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            try {
                                val ratioX = call.argument<Int>("aspectX") ?: 16
                                val ratioY = call.argument<Int>("aspectY") ?: 9
                                val params = PictureInPictureParams.Builder()
                                    .setAspectRatio(Rational(ratioX, ratioY))
                                    .build()
                                enterPictureInPictureMode(params)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("PIP_ERROR", e.message, null)
                            }
                        } else {
                            result.error("PIP_UNSUPPORTED",
                                "يحتاج Android 8.0 أو أحدث", null)
                        }
                    }

                    "setAutoEnter" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            try {
                                val enabled = call.argument<Boolean>("enabled") ?: true
                                val params = PictureInPictureParams.Builder()
                                    .setAutoEnterEnabled(enabled)
                                    .setAspectRatio(Rational(16, 9))
                                    .build()
                                setPictureInPictureParams(params)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("PIP_ERROR", e.message, null)
                            }
                        } else {
                            result.success(false)
                        }
                    }

                    "isInPipMode" -> result.success(isPipMode)

                    else -> result.notImplemented()
                }
            }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration?
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        isPipMode = isInPictureInPictureMode
    }
}
