package com.ndarealty.ndadrive

import android.annotation.SuppressLint
import android.app.*
import android.content.*
import android.content.pm.ServiceInfo
import android.hardware.*
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.media.*
import android.os.*
import kotlin.math.sqrt

// Dich vu chay nen:
//  - CHO XE: chi nghe su kien nguon dien (cong USB cua xe) va loa Bluetooth -> gan nhu khong ton pin
//  - CHAY: cam bien 100 lan/giay + GPS + phat tieng po ra loa Bluetooth + ghi chuyen di
class EngineService : Service(), SensorEventListener, LocationListener {

    companion object {
        @Volatile var instance: EngineService? = null
        const val ACT_START = "start"; const val ACT_STOP = "stop"; const val ACT_WAIT = "wait"
        fun send(ctx: Context, action: String) {
            val i = Intent(ctx, EngineService::class.java).setAction(action)
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
        }
    }

    lateinit var prefs: Prefs
    @Volatile var active = false; private set          // dang chay cam bien + am thanh
    @Volatile var manual = false                         // nguoi dung bam no may tay
    @Volatile var powered = false; private set
    @Volatile var speakerName: String? = null; private set
    @Volatile var imuHz = 0.0; private set
    @Volatile var gpsHz = 0.0; private set
    @Volatile var gpsAcc = -1.0; private set
    @Volatile var gpsRawKmh = -1.0; private set
    @Volatile var sensorInfo = ""; private set
    @Volatile var testMode = false
    @Volatile var testKmh = 0.0

    private lateinit var sm: SensorManager
    private lateinit var lm: LocationManager
    private lateinit var am: AudioManager
    private var wake: PowerManager.WakeLock? = null
    private val h = Handler(Looper.getMainLooper())
    private var audioThread: Thread? = null
    @Volatile private var audioRun = false
    private var trip: TripRecorder? = null

    // cam bien
    private val lin = DoubleArray(3); private val grav = doubleArrayOf(0.0, -9.81, 0.0); private val acc = DoubleArray(3)
    private var hasLin = false; private var hasGrav = false; private var useRaw = false
    private var imuN = 0L; private var gpsN = 0L; private var rateT = 0L; private var imuN0 = 0L; private var gpsN0 = 0L
    private var lastImuT = 0.0
    private val st = DoubleArray(24)

    override fun onBind(i: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        NLog.init(this)
        prefs = Prefs(this)
        Core.ensureInit()
        prefs.learnBlob?.let { Core.learnSet(it) }
        prefs.cal?.let { Core.calSet(it[0], it[1], it[2], it[3]) }
        prefs.apply()
        sm = getSystemService(SENSOR_SERVICE) as SensorManager
        lm = getSystemService(LOCATION_SERVICE) as LocationManager
        am = getSystemService(AUDIO_SERVICE) as AudioManager
        val ch = NotificationChannel("nda", "NDA Drive", NotificationManager.IMPORTANCE_LOW)
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(ch)
        goForeground("Đang chờ xe khởi động")
        // nguon dien: xe bat -> cong USB co dien
        val f = IntentFilter().apply { addAction(Intent.ACTION_POWER_CONNECTED); addAction(Intent.ACTION_POWER_DISCONNECTED) }
        registerReceiver(powerRx, f)
        powered = isPowered()
        am.registerAudioDeviceCallback(devCb, h)
        updateSpeaker()
        NLog.i("Dich vu khoi dong. Nguon: ${if (powered) "co" else "khong"}, loa: ${speakerName ?: "chua ket noi"}")
        prefs.bump("service_start")
        h.post(tick)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACT_START -> { manual = true; evaluate() }
            ACT_STOP -> { manual = false; userOff = true; offSince = 0; deactivate() }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        deactivate()
        try { unregisterReceiver(powerRx) } catch (_: Exception) {}
        am.unregisterAudioDeviceCallback(devCb)
        h.removeCallbacksAndMessages(null)
        instance = null
        super.onDestroy()
    }

    private fun goForeground(text: String) {
        val pi = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val n = Notification.Builder(this, "nda").setContentTitle("NDA Drive").setContentText(text)
            .setSmallIcon(android.R.drawable.ic_media_play).setContentIntent(pi).setOngoing(true).build()
        if (Build.VERSION.SDK_INT >= 29)
            startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        else startForeground(1, n)
    }

    // ---------------- Nhan biet xe bat / tat ----------------
    private var userOff = false
    private var saveTick = 0
    private var offSince = 0L

    private fun isPowered(): Boolean {
        val b = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)) ?: return false
        return b.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) != 0
    }
    private val powerRx = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            powered = i.action == Intent.ACTION_POWER_CONNECTED
            NLog.i(if (powered) "Co dien (xe bat?)" else "Mat dien (xe tat?)")
            prefs.bump(if (powered) "power_on" else "power_off")
            if (powered) userOff = false
            evaluate()
        }
    }
    private val devCb = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(a: Array<out AudioDeviceInfo>) { updateSpeaker(); evaluate() }
        override fun onAudioDevicesRemoved(a: Array<out AudioDeviceInfo>) { updateSpeaker(); evaluate() }
    }
    private fun updateSpeaker() {
        val d = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS).firstOrNull { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP }
        val name = d?.productName?.toString()
        if (name != speakerName) { NLog.i("Loa Bluetooth: ${name ?: "ngat"}"); if (name != null) prefs.bump("speaker_connect") }
        speakerName = name
    }

    fun evaluate() {
        val carOn = powered && (!prefs.needSpeaker || speakerName != null)
        val want = manual || (prefs.autoRun && carOn && !userOff)
        if (want) { offSince = 0; if (!active) activate() }
        else if (active) {
            // cho 15 giay (rut/cam lai, loa ket noi lai) truoc khi tat
            if (offSince == 0L) offSince = SystemClock.elapsedRealtime()
        }
    }

    private val tick = object : Runnable {
        override fun run() {
            if (active && offSince > 0 && SystemClock.elapsedRealtime() - offSince > 15000) { offSince = 0; deactivate() }
            val now = SystemClock.elapsedRealtime()
            if (now - rateT >= 1000) {
                val dt = (now - rateT) / 1000.0
                if (rateT > 0) { imuHz = (imuN - imuN0) / dt; gpsHz = (gpsN - gpsN0) / dt }
                imuN0 = imuN; gpsN0 = gpsN; rateT = now
                if (active && testMode) Core.setTest(true, testKmh)
            }
            if (active && testMode) Core.setTest(true, testKmh)
            // luu ho so hoc + can chinh moi 30 giay
            if (active && ++saveTick % 300 == 0) saveLearn()
            h.postDelayed(this, 100)
        }
    }

    // ---------------- Chay / dung ----------------
    @SuppressLint("MissingPermission")
    private fun activate() {
        active = true
        NLog.i("NO MAY (nguon=${powered}, loa=${speakerName}, tay=${manual})")
        prefs.bump("engine_start")
        goForeground("Đang chạy tiếng pô")
        wake = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "nda:run").apply { acquire(6 * 3600_000L) }
        prefs.apply()
        startSensors()
        try { lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 0L, 0f, this, Looper.getMainLooper()) }
        catch (e: Exception) { NLog.i("GPS loi: ${e.message}") }
        startAudio()
        Core.engineStart()
        if (prefs.record) trip = TripRecorder(this).also { it.start() }
    }

    private fun deactivate() {
        if (!active) return
        NLog.i("TAT MAY")
        prefs.bump("engine_stop")
        Core.engineStop()
        h.postDelayed({
            if (active) return@postDelayed
            stopAudio()
        }, 2500)
        active = false
        sm.unregisterListener(this)
        try { lm.removeUpdates(this) } catch (_: Exception) {}
        trip?.stop(); trip = null
        saveLearn()
        wake?.let { if (it.isHeld) it.release() }; wake = null
        goForeground("Đang chờ xe khởi động")
    }

    fun saveLearn() {
        prefs.learnBlob = Core.learnGet()
        Core.calGet()?.let { prefs.cal = it }
    }

    // ---------------- Cam bien ----------------
    private fun startSensors() {
        val l = sm.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
        val g = sm.getDefaultSensor(Sensor.TYPE_GRAVITY)
        val gy = sm.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
        val a = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        val p = sm.getDefaultSensor(Sensor.TYPE_PRESSURE)
        useRaw = l == null || g == null
        sensorInfo = "gia toc ${if (a != null) "co" else "KHONG"}, con quay ${if (gy != null) "co" else "KHONG"}, " +
            "tuyen tinh ${if (l != null) "co" else "khong"}, trong luc ${if (g != null) "co" else "khong"}, ap ke ${if (p != null) "co" else "khong"}"
        NLog.i("Cam bien: $sensorInfo")
        val us = 10_000
        if (!useRaw) { sm.registerListener(this, l, us); sm.registerListener(this, g, us) }
        a?.let { sm.registerListener(this, it, us) }
        gy?.let { sm.registerListener(this, it, us) }
        p?.let { sm.registerListener(this, it, 100_000) }
    }

    private val rot = DoubleArray(3)
    private var hasGyro = false
    override fun onSensorChanged(e: SensorEvent) {
        val t = e.timestamp / 1e9
        when (e.sensor.type) {
            Sensor.TYPE_LINEAR_ACCELERATION -> { for (i in 0..2) lin[i] = e.values[i].toDouble(); hasLin = true }
            Sensor.TYPE_GRAVITY -> { for (i in 0..2) grav[i] = e.values[i].toDouble(); hasGrav = true }
            Sensor.TYPE_ACCELEROMETER -> {
                for (i in 0..2) acc[i] = e.values[i].toDouble()
                if (useRaw) {   // khong co cam bien ao: tu tach trong luc bang loc thong thap
                    for (i in 0..2) { grav[i] += (acc[i] - grav[i]) * 0.02; lin[i] = acc[i] - grav[i] }
                    if (!hasGyro) feed(t)
                }
            }
            Sensor.TYPE_GYROSCOPE -> { for (i in 0..2) rot[i] = e.values[i].toDouble(); hasGyro = true; feed(t) }
            Sensor.TYPE_PRESSURE -> {
                val alt = SensorManager.getAltitude(SensorManager.PRESSURE_STANDARD_ATMOSPHERE, e.values[0]).toDouble()
                Core.baro(alt, t)
            }
        }
    }
    private fun feed(t: Double) {
        if (t - lastImuT < 0.008) return   // gioi han ~100 lan/giay
        lastImuT = t
        // Android: trong luc huong LEN -> doi dau cho loi C (quy uoc iOS: huong xuong)
        Core.imu(lin[0], lin[1], lin[2], -grav[0], -grav[1], -grav[2], rot[0], rot[1], rot[2], t)
        imuN++
        if (imuN % 10 == 0L) {
            Core.state(st)
            trip?.row(t, gpsRawKmh, gpsAcc, st, lin, rot, grav, speakerName != null)
        }
    }
    override fun onAccuracyChanged(s: Sensor?, a: Int) {}

    // ---------------- GPS ----------------
    override fun onLocationChanged(l: Location) {
        gpsN++
        val sp = if (l.hasSpeed()) l.speed.toDouble() else -1.0
        val sa = if (Build.VERSION.SDK_INT >= 26 && l.hasSpeedAccuracy()) l.speedAccuracyMetersPerSecond.toDouble() else -1.0
        gpsAcc = sa; gpsRawKmh = if (sp >= 0) sp * 3.6 else -1.0
        if (sp < 0 || l.accuracy > 65) return
        Core.gps(sp, sa, if (l.hasBearing()) l.bearing.toDouble() else -1.0, l.elapsedRealtimeNanos / 1e9)
    }
    @Deprecated("") override fun onStatusChanged(p: String?, s: Int, b: Bundle?) {}
    override fun onProviderEnabled(p: String) {}
    override fun onProviderDisabled(p: String) { NLog.i("GPS bi tat trong cai dat") }

    // ---------------- Am thanh ----------------
    private fun startAudio() {
        if (audioThread != null) return
        audioRun = true
        audioThread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            val sr = AudioTrack.getNativeOutputSampleRate(AudioManager.STREAM_MUSIC).takeIf { it > 0 } ?: 48000
            val minB = AudioTrack.getMinBufferSize(sr, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_FLOAT)
            val track = AudioTrack.Builder()
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                .setAudioFormat(AudioFormat.Builder().setSampleRate(sr).setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                .setBufferSizeInBytes(maxOf(minB, sr / 50 * 4))
                .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                .setTransferMode(AudioTrack.MODE_STREAM).build()
            NLog.i("Am thanh: $sr Hz, bo dem ${track.bufferSizeInFrames} mau")
            track.play()
            val buf = FloatArray(256)
            while (audioRun) {
                Core.render(buf, buf.size, sr.toDouble())
                track.write(buf, 0, buf.size, AudioTrack.WRITE_BLOCKING)
            }
            track.stop(); track.release()
        }, "nda-audio").also { it.start() }
    }
    private fun stopAudio() {
        audioRun = false
        audioThread?.join(500); audioThread = null
    }
}
