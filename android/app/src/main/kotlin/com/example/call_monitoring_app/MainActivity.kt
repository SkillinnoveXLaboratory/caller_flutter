package com.example.call_monitoring_app

import android.app.role.RoleManager
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "call_monitor/dialer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            if (call.method != "requestDefaultDialer") return@setMethodCallHandler result.notImplemented()
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                result.success("Open Android Settings to choose the default Phone app.")
                return@setMethodCallHandler
            }
            val roleManager = getSystemService(RoleManager::class.java)
            if (roleManager.isRoleHeld(RoleManager.ROLE_DIALER)) {
                result.success("Call Monitor is already the default dialer.")
            } else if (roleManager.isRoleAvailable(RoleManager.ROLE_DIALER)) {
                startActivity(Intent(roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER)))
                result.success("Choose Call Monitor in the Android system dialog to continue.")
            } else {
                result.success("This device does not make the default-dialer role available.")
            }
        }
    }
}
