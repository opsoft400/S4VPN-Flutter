package com.s4vpn.soft400

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import java.io.FileInputStream
import java.io.FileOutputStream

/**
 * The system half of the tunnel.
 *
 * The Dart app decides *what* to run and *where* the local proxy is; this class
 * only does the two things an app is allowed to do itself: build the interface,
 * and move packets between that interface and the proxy the cores opened. It
 * deliberately knows nothing about which engine is behind the proxy -- Aether,
 * Psiphon, Mihomo and Lantern all end in a SOCKS5 listener, so the interface is
 * configured the same way for every one of them.
 */
class S4VpnService : VpnService() {

    private var descriptor: ParcelFileDescriptor? = null
    private var bridge: TunBridge? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null || intent.action == ACTION_STOP) {
            stopEverything()
            return START_NOT_STICKY
        }

        startInForeground()

        val socksPort = intent.getIntExtra(EXTRA_SOCKS_PORT, 1819)
        val splitMode = intent.getStringExtra(EXTRA_SPLIT_MODE) ?: MODE_OFF
        val excluded = intent.getStringArrayListExtra(EXTRA_EXCLUDED) ?: arrayListOf()
        val allowed = intent.getStringArrayListExtra(EXTRA_ALLOWED) ?: arrayListOf()

        try {
            val established = establish(splitMode, excluded, allowed)
            if (established == null) {
                lastError = "the system refused the interface"
                stopEverything()
                return START_NOT_STICKY
            }
            descriptor = established
            bridge = TunBridge(
                // One descriptor, two streams: reading and writing a tun are
                // independent syscalls, and closing either stream would take the
                // descriptor with it -- so neither is closed until teardown.
                input = FileInputStream(established.fileDescriptor),
                output = FileOutputStream(established.fileDescriptor),
                proxyHost = LOOPBACK,
                proxyPort = socksPort,
            ).also { it.start() }
            isRunning = true
            lastError = null
        } catch (error: Exception) {
            lastError = error.message ?: error.javaClass.simpleName
            stopEverything()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    /**
     * Build the interface.
     *
     * The address is from the shared address space rather than RFC1918: a
     * phone's own network is very likely to be using 192.168/16 or 10/8, and an
     * overlap would capture the local subnet instead of carrying traffic away
     * from it. Our own package is always excluded -- a core that dialed back
     * into the interface it is serving would loop forever.
     */
    private fun establish(
        splitMode: String,
        excluded: List<String>,
        allowed: List<String>,
    ): ParcelFileDescriptor? {
        val builder = Builder()
            .setSession(SESSION)
            .setMtu(MTU)
            .addAddress(TUN_ADDRESS, 32)
            .addRoute("0.0.0.0", 0)
            .addDnsServer("1.1.1.1")
            .addDnsServer("1.0.0.1")

        runCatching { builder.addDisallowedApplication(packageName) }

        when (splitMode) {
            MODE_BYPASS -> excluded.forEach { pkg ->
                runCatching { builder.addDisallowedApplication(pkg) }
            }
            MODE_VPN_ONLY -> allowed.forEach { pkg ->
                runCatching { builder.addAllowedApplication(pkg) }
            }
        }

        return builder.establish()
    }

    private fun startInForeground() {
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("S4VPN")
            .setContentText(SESSION)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "S4VPN",
            NotificationManager.IMPORTANCE_LOW,
        ).apply { setShowBadge(false) }
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    private fun stopEverything() {
        isRunning = false
        runCatching { bridge?.stop() }
        bridge = null
        runCatching { descriptor?.close() }
        descriptor = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
        stopSelf()
    }

    override fun onRevoke() {
        // The system took the interface away -- another VPN app, or the switch
        // in settings. Either way we no longer own packets.
        stopEverything()
        super.onRevoke()
    }

    override fun onDestroy() {
        stopEverything()
        super.onDestroy()
    }

    companion object {
        const val ACTION_STOP = "com.s4vpn.soft400.STOP"
        const val EXTRA_SOCKS_PORT = "socksPort"
        const val EXTRA_SPLIT_MODE = "splitMode"
        const val EXTRA_EXCLUDED = "excludedPackages"
        const val EXTRA_ALLOWED = "allowedPackages"

        const val MODE_OFF = "off"
        const val MODE_BYPASS = "bypass"
        const val MODE_VPN_ONLY = "vpnonly"

        private const val CHANNEL_ID = "s4vpn"
        private const val NOTIFICATION_ID = 4102
        private const val SESSION = "S4VPN"
        private const val MTU = 1500
        private const val TUN_ADDRESS = "198.18.0.1"
        private const val LOOPBACK = "127.0.0.1"

        @Volatile
        var isRunning: Boolean = false

        @Volatile
        var lastError: String? = null

        /** Byte counters for the Dart readout, or null while nothing runs. */
        fun traffic(): Pair<Long, Long>? {
            if (!isRunning) return null
            val active = TunBridge.active ?: return null
            return Pair(active.rxBytes, active.txBytes)
        }
    }
}
