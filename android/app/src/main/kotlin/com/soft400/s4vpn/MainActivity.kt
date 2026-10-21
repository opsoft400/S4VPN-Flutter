package com.s4vpn.soft400

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The Dart side of the platform seam.
 *
 * Every method here corresponds to one call in `lib/platform/vpn_platform.dart`.
 * Nothing else is exposed: the app asks where a core is, asks for the interface
 * to be built or torn down, and reads the byte counters the interface produced.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingVpn: MethodChannel.Result? = null
    private var pendingVpnArgs: MethodCall? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = methodChannel
        methodChannel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "corePath" -> {
                    val core = call.argument<String>("core") ?: return result.error(
                        "bad-arg", "core name missing", null,
                    )
                    result.success(CoreExtractor.pathFor(this, core))
                }

                "stateDir" -> result.success(filesDir.absolutePath)

                "isVpnActive" -> result.success(S4VpnService.isRunning)

                "traffic" -> {
                    val counters = S4VpnService.traffic()
                    if (counters == null) {
                        result.success(null)
                    } else {
                        val map = HashMap<String, Any>()
                        map["rx"] = counters.first
                        map["tx"] = counters.second
                        result.success(map)
                    }
                }

                "startVpn" -> startVpn(call, result)

                "stopVpn" -> {
                    stopService(Intent(this, S4VpnService::class.java))
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("s4vpn", error.message ?: error.javaClass.simpleName, null)
        }
    }

    private fun startVpn(call: MethodCall, result: MethodChannel.Result) {
        val consent = VpnService.prepare(this)
        if (consent != null) {
            // The system wants its own screen before an app may build an
            // interface. Hold the call until it comes back, then send it.
            pendingVpn = result
            pendingVpnArgs = call
            startActivityForResult(consent, REQUEST_VPN_CONSENT)
            return
        }
        launchVpn(call, result)
    }

    private fun launchVpn(call: MethodCall, result: MethodChannel.Result) {
        val intent = Intent(this, S4VpnService::class.java).apply {
            putExtra(EXTRA_SOCKS_PORT, (call.argument<Any>("socksPort") as? Number)?.toInt() ?: 1819)
            putExtra(
                EXTRA_HTTP_PORT,
                (call.argument<Any>("httpPort") as? Number)?.toInt() ?: -1,
            )
            putExtra(EXTRA_SPLIT_MODE, call.argument<String>("mode") ?: "off")
            putStringArrayListExtra(
                EXTRA_EXCLUDED,
                ArrayList(call.argument<List<String>>("excludedPackages") ?: emptyList()),
            )
            putStringArrayListExtra(
                EXTRA_ALLOWED,
                ArrayList(call.argument<List<String>>("allowedPackages") ?: emptyList()),
            )
        }
        startForegroundService(intent)
        result.success(null)
    }

    @Deprecated("Deprecated in Activity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_VPN_CONSENT) {
            val pending = pendingVpn
            val args = pendingVpnArgs
            pendingVpn = null
            pendingVpnArgs = null
            if (pending == null || args == null) return
            if (resultCode == Activity.RESULT_OK) {
                launchVpn(args, pending)
            } else {
                pending.error("denied", "the system VPN consent was declined", null)
            }
        }
    }

    companion object {
        private const val CHANNEL = "s4vpn/platform"
        private const val REQUEST_VPN_CONSENT = 4102

        const val EXTRA_SOCKS_PORT = "socksPort"
        const val EXTRA_HTTP_PORT = "httpPort"
        const val EXTRA_SPLIT_MODE = "splitMode"
        const val EXTRA_EXCLUDED = "excludedPackages"
        const val EXTRA_ALLOWED = "allowedPackages"
    }
}
