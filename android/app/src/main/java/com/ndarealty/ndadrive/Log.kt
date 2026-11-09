package com.ndarealty.ndadrive

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

// Nhat ky chan doan (tep van ban, giu ~200 KB cuoi)
object NLog {
    private var file: File? = null
    private val df = SimpleDateFormat("dd/MM HH:mm:ss.SSS", Locale.US)
    fun init(ctx: Context) { if (file == null) file = File(ctx.filesDir, "ndadrive-log.txt") }
    @Synchronized fun i(msg: String) {
        android.util.Log.i("NDADrive", msg)
        val f = file ?: return
        try {
            if (f.length() > 400_000) { val keep = f.readText().takeLast(200_000); f.writeText(keep) }
            f.appendText("${df.format(Date())}  $msg\n")
        } catch (_: Exception) {}
    }
    fun file(): File? = file
}
