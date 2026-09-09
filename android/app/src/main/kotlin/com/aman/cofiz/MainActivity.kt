package com.aman.cofiz

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.telegram.login.TelegramLogin

class MainActivity : FlutterActivity() {

    private val channelName = "com.cofiz.telegram_login"
    private val clientId = "8777989279"
    private val redirectHost = BuildConfig.TG_LOGIN_HOST
    private val redirectPath = "/tglogin"
    private var pendingResult: MethodChannel.Result? = null
    private var loginInProgress = false
    private var channel: MethodChannel? = null
    private var handledRedirectUri: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            TelegramLogin.init(
                clientId = clientId,
                redirectUri = "https://$redirectHost$redirectPath",
                scopes = listOf("profile", "phone"),
            )
        } catch (e: Exception) {
            Log.e("CofizAuth", "TelegramLogin.init failed", e)
        }

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(isTelegramLoginAvailable())
                "login" -> {
                    if (Build.VERSION.SDK_INT < 23) {
                        result.error("UNSUPPORTED", "Telegram login requires Android 6.0+", null)
                        return@setMethodCallHandler
                    }
                    if (loginInProgress) {
                        result.error("BUSY", "Login already in progress", null)
                        return@setMethodCallHandler
                    }
                    pendingResult = result
                    loginInProgress = true
                    try {
                        TelegramLogin.startLogin(this)
                    } catch (e: Exception) {
                        Log.e("CofizAuth", "startLogin failed", e)
                        pendingResult?.error("START_FAILED", e.message ?: "unknown", null)
                        pendingResult = null
                        loginInProgress = false
                    }
                }
                else -> result.notImplemented()
            }
        }

        handleCallback(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleCallback(intent)
    }

    private fun isTelegramLoginAvailable(): Boolean {
        if (Build.VERSION.SDK_INT < 23) return false
        val pm = packageManager
        for (pkg in listOf("org.telegram.messenger", "org.telegram.messenger.web")) {
            try {
                pm.getPackageInfo(pkg, 0)
                return true
            } catch (_: PackageManager.NameNotFoundException) {
                continue
            }
        }
        return try {
            val i = Intent(Intent.ACTION_VIEW, Uri.parse("tg://resolve?domain=telegram"))
            pm.queryIntentActivities(i, 0).isNotEmpty()
        } catch (_: Exception) {
            false
        }
    }

    private fun handleCallback(intent: Intent) {
        val uri: Uri? = intent.data
        if (uri == null) return
        if (uri.host != redirectHost) return
        val uriString = uri.toString()
        if (uriString == handledRedirectUri) return
        handledRedirectUri = uriString
        intent.data = null
        setIntent(intent)
        loginInProgress = false
        TelegramLogin.handleLoginResponse(
            uri,
            onSuccess = { loginData ->
                val payload = mapOf(
                    "idToken" to loginData.idToken,
                )
                val result = pendingResult
                if (result != null) {
                    result.success(payload)
                    pendingResult = null
                } else {
                    channel?.invokeMethod("onTelegramLogin", payload)
                }
            },
            onError = { error ->
                val result = pendingResult
                if (result != null) {
                    result.error("TELEGRAM_LOGIN_ERROR", error.message ?: "unknown", null)
                    pendingResult = null
                } else {
                    channel?.invokeMethod("onTelegramLoginError", error.message ?: "unknown")
                }
            },
        )
    }
}
