package com.ndarealty.ndadrive

import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import androidx.core.content.FileProvider
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

// "Xuat bao cao cho Claude": 1 tep .zip (bao-cao.json, nhat ky, 3 chuyen di gan nhat + tom tat moi chuyen)
object Report {
    fun build(ctx: Context, full: Boolean = false): File {
        val p = Prefs(ctx); val svc = EngineService.instance
        val st = DoubleArray(24); Core.ensureInit(); Core.state(st)
        val sm = ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensors = JSONArray(); sm.getSensorList(Sensor.TYPE_ALL).forEach {
            sensors.put("${it.name} (${it.vendor}) loai ${it.type} min ${it.minDelay}us")
        }
        val rep = JSONObject().apply {
            put("platform", "android"); put("app_version", BuildConfigLite.VERSION)
            put("device", "${Build.MANUFACTURER} ${Build.MODEL}"); put("android", Build.VERSION.RELEASE + " (API ${Build.VERSION.SDK_INT})")
            put("generated_at", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ", Locale.US).format(Date()))
            put("settings", JSONObject().apply {
                put("preset", p.preset); put("volume", p.volume); put("tone", p.tone); put("rear", p.rearAmt); put("sub", p.subAmt)
                put("lead_ms", p.leadMs); put("auto_run", p.autoRun); put("need_speaker", p.needSpeaker); put("learn", p.learn); put("record", p.record)
                put("car_hp", p.carHP); put("car_0_100_s", p.zeroTo100); put("car_weight_kg", p.carWeight)
                put("collect_mode", p.collectMode)
                put("interior", p.interior); put("mech", p.mech); put("perf_knee_kmh", p.perfKnee())
            })
            put("state_now", JSONObject().apply {
                put("active", svc?.active ?: false); put("powered", svc?.powered ?: false); put("speaker", svc?.speakerName ?: "")
                put("imu_hz", svc?.imuHz ?: 0.0); put("gps_hz", svc?.gpsHz ?: 0.0); put("gps_acc", svc?.gpsAcc ?: -1.0)
                put("calibrated", st[Core.CAL] > 0); put("cal_by_turn", st[Core.CALTURN] > 0); put("mount_angle_deg", st[Core.THETA])
                put("gps_delay_est_s", st[Core.GPSDLY]); put("gps_repeat_ratio", st[Core.GPSREP]); put("sensor_info", svc?.sensorInfo ?: "")
            })
            put("learned", JSONObject().apply {
                put("sport", st[Core.SPORT]); put("confidence", st[Core.CONF]); put("zero_to_100_s", st[Core.Z100])
                put("distance_km", st[Core.LDIST]); put("samples", st[Core.LSAMP])
            })
            put("thu_nghiem_7_ngay", JSONObject().apply {
                put("ngay_da_thu_thap", p.trialDays()); put("can_du", 7); put("hoan_thanh", p.trialComplete())
                put("tong_km", Math.round(p.trialKm() * 10) / 10.0); put("so_chuyen", p.trialTrips())
            })
            put("events_total", JSONObject(p.counters() as Map<*, *>))
            put("sensors", sensors)
        }
        val name = "NDADrive-Android-bao-cao-" + SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val dir = File(ctx.getExternalFilesDir(null) ?: ctx.filesDir, "reports").also { it.mkdirs(); it.listFiles()?.forEach { f -> f.delete() } }
        val zip = File(dir, "$name.zip")
        ZipOutputStream(zip.outputStream()).use { z ->
            fun put(path: String, bytes: ByteArray) { z.putNextEntry(ZipEntry("$name/$path")); z.write(bytes); z.closeEntry() }
            put("bao-cao.json", rep.toString(2).toByteArray())
            NLog.file()?.takeIf { it.exists() }?.let { put("nhat-ky.txt", it.readBytes()) }
            val trips = TripRecorder.folder(ctx).listFiles()?.sortedByDescending { it.name } ?: emptyList()
            trips.filter { it.name.endsWith(".json") }.forEach { put("chuyen-di/${it.name}", it.readBytes()) }
            trips.filter { it.name.endsWith(".csv") }.take(if (full) 100000 else 3).forEach { put("chuyen-di/${it.name}", it.readBytes()) }
            put("DOC-TOI.txt", "Gửi tệp .zip này cho Claude để phân tích. Không chứa tọa độ GPS, tên hay số điện thoại.\n".toByteArray())
        }
        NLog.i("Xuat bao cao: ${zip.name}")
        return zip
    }

    fun share(ctx: Context, f: File) {
        val uri = FileProvider.getUriForFile(ctx, "com.ndarealty.ndadrive.files", f)
        val i = Intent(Intent.ACTION_SEND).setType("application/zip").putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        ctx.startActivity(Intent.createChooser(i, "Gửi báo cáo cho Claude"))
    }
}
