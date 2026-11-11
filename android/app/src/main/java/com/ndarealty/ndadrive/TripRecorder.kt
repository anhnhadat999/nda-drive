package com.ndarealty.ndadrive

import android.content.Context
import org.json.JSONObject
import java.io.BufferedWriter
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

// Ghi chuyen di 10 dong/giay, cung dinh dang cot voi ban iOS (+ vai cot rieng Android)
class TripRecorder(private val ctx: Context) {
    companion object {
        fun folder(ctx: Context): File = File(ctx.getExternalFilesDir(null) ?: ctx.filesDir, "trips").also { it.mkdirs() }
        const val HEAD = "t_s,gps_kmh,gps_acc_ms,fused_kmh,a_long_ms2,ax,ay,az,gyro_rads,grade_pct,tilt_deg,calibrated,stationary,gps_ok,src,synth_kmh,rpm,gear,load,state,cal_theta_deg,rx,ry,rz,gvx,gvy,gvz,gps_new,gps_delay_s,cal_turn,gps_car,lead_ms,audio_lat_ms,speaker"
    }
    private var w: BufferedWriter? = null
    private var file: File? = null
    private var t0 = 0.0; private var lastT = 0.0; private var rows = 0
    private var dist = 0.0; private var vmax = 0.0; private var amax = 0.0; private var bmax = 0.0
    private var lastGps = -2.0
    private val start = System.currentTimeMillis()

    fun start() {
        val name = "trip_" + SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date()) + ".csv"
        file = File(folder(ctx), name)
        w = file!!.bufferedWriter().also { it.write(HEAD + "\n") }
        NLog.i("Ghi chuyen di: $name")
        // giu 40 chuyen gan nhat
        folder(ctx).listFiles { f -> f.name.endsWith(".csv") }?.sortedByDescending { it.name }?.drop(40)?.forEach { it.delete(); File(it.path + ".json").delete() }
    }

    fun row(t: Double, gpsKmh: Double, gpsAcc: Double, s: DoubleArray, lin: DoubleArray, rot: DoubleArray, grav: DoubleArray, spk: Boolean) {
        val out = w ?: return
        if (t0 == 0.0) t0 = t
        val v = s[Core.V]; val dt = if (lastT > 0) t - lastT else 0.0; lastT = t
        if (dt > 0 && dt < 1) dist += v / 3600.0 * dt
        if (v > vmax) vmax = v
        if (s[Core.CAL] > 0) { if (s[Core.A] > amax) amax = s[Core.A]; if (-s[Core.A] > bmax) bmax = -s[Core.A] }
        val gm = Math.sqrt(rot[0] * rot[0] + rot[1] * rot[1] + rot[2] * rot[2])
        val gn = Math.sqrt(grav[0] * grav[0] + grav[1] * grav[1] + grav[2] * grav[2])
        val tilt = if (gn > 0) Math.toDegrees(Math.acos(Math.min(1.0, Math.abs(grav[2]) / gn))) else 0.0
        val newFix = if (gpsKmh != lastGps) 1 else 0; lastGps = gpsKmh
        out.write(String.format(Locale.US,
            "%.2f,%.2f,%.2f,%.2f,%.3f,%.3f,%.3f,%.3f,%.3f,%.2f,%.1f,%d,%d,%d,1,%.2f,%.0f,%d,%.2f,%d,%.1f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%d,%.2f,%d,0,%.0f,0,%d\n",
            t - t0, gpsKmh, gpsAcc, v, s[Core.A], lin[0], lin[1], lin[2], gm, s[Core.GRADE], tilt,
            s[Core.CAL].toInt(), s[Core.STILL].toInt(), s[Core.GPSOK].toInt(), s[Core.SYN_V], s[Core.RPM], s[Core.GEAR].toInt(), s[Core.LOAD],
            s[Core.SSTATE].toInt(), s[Core.THETA], rot[0], rot[1], rot[2], -grav[0] / 9.81, -grav[1] / 9.81, -grav[2] / 9.81,
            newFix, s[Core.GPSDLY], s[Core.CALTURN].toInt(), s[Core.LEAD] * 1000, if (spk) 1 else 0))
        rows++
        if (rows == 600) Prefs(ctx).trialMarkToday()   // 1 phut du lieu -> tinh ngay
        if (rows % 20 == 0) out.flush()
    }

    fun distKm(): Double = dist
    fun durSec(): Double = (System.currentTimeMillis() - start) / 1000.0
    fun stop() {
        val f = file ?: return
        try { w?.close() } catch (_: Exception) {}
        w = null
        val st = DoubleArray(24); Core.state(st)
        val j = JSONObject().apply {
            put("file", f.name); put("app", "android-" + BuildConfigLite.VERSION); put("start", start / 1000.0)
            put("duration_s", (System.currentTimeMillis() - start) / 1000); put("rows", rows)
            put("distance_km", Math.round(dist * 100) / 100.0); put("vmax_kmh", Math.round(vmax * 10) / 10.0)
            put("accel_max_ms2", Math.round(amax * 100) / 100.0); put("brake_max_ms2", Math.round(bmax * 100) / 100.0)
            put("sport", Math.round(st[Core.SPORT] * 100) / 100.0); put("zero_to_100_est_s", Math.round(st[Core.Z100] * 10) / 10.0)
        }
        File(f.path + ".json").writeText(j.toString(2))
        NLog.i("Ket thuc chuyen di: %.1f km, %d dong".format(Locale.US, dist, rows))
    }
}

object BuildConfigLite { const val VERSION = "0.6.0" }
