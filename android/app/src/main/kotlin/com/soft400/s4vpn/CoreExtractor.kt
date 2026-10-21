package com.s4vpn.soft400

import android.content.Context
import java.io.File

/**
 * Locates an engine executable on Android.
 *
 * An app may not exec from its own data directory on a modern device, but it
 * may exec from `nativeLibraryDir` -- which is only ever populated by files
 * named like shared objects. So every core ships as `lib<name>.so`, and this
 * copies the one asked for somewhere writable and marks it executable. The copy
 * exists so a core can keep its state beside itself without ever needing to
 * write into a directory the system owns.
 */
object CoreExtractor {
    private const val OUT_DIR = "core"

    /** Native library names, mirroring `CoreLocator.executableNames` in Dart. */
    private val LIB_NAMES = mapOf(
        "aether" to "libaether.so",
        "psiphon" to "libpsiphon.so",
        "mihomo" to "libmihomo.so",
        "lantern" to "liblantern.so",
        "stormdns" to "libstormdns_client.so",
        "cottendns" to "libcottendns_client.so",
    )

    @Volatile
    private var prepared = false

    fun pathFor(context: Context, core: String): String? {
        val libName = LIB_NAMES[core] ?: return null
        val out = File(File(context.filesDir, OUT_DIR), core)
        if (out.exists() && out.canExecute()) {
            return out.absolutePath
        }

        val candidate = File(File(context.applicationInfo.nativeLibraryDir), libName)
        if (!candidate.exists()) {
            return null
        }

        out.parentFile?.mkdirs()
        candidate.copyTo(out, overwrite = true)
        out.setReadable(true, true)
        out.setExecutable(true, false)
        prepared = true
        return if (out.canExecute()) out.absolutePath else null
    }

    /** True once at least one core has been extracted in this process. */
    fun isPrepared(): Boolean = prepared
}
