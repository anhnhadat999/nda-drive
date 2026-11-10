package com.ndarealty.ndadrive

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.*
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.*
import java.util.Locale

class MainActivity : Activity() {
    private val BG = Color.rgb(9, 9, 11); private val CARD = Color.rgb(20, 20, 23); private val FG = Color.rgb(242, 239, 232)
    private val MUTED = Color.rgb(142, 142, 147); private val GOLD = Color.rgb(212, 178, 106); private val RED = Color.rgb(229, 72, 77)
    private val GREEN = Color.rgb(61, 214, 140)
    private lateinit var prefs: Prefs
    private lateinit var speedTv: TextView; private lateinit var subTv: TextView; private lateinit var modeTv: TextView
    private lateinit var hudTv: TextView; private lateinit var runBtn: Button
    private val h = Handler(Looper.getMainLooper())
    private val st = DoubleArray(24)

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    override fun onCreate(b: Bundle?) {
        super.onCreate(b)
        prefs = Prefs(this); NLog.init(this); Core.ensureInit()
        window.statusBarColor = BG
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(16), dp(20), dp(16), dp(32)) }
        setContentView(ScrollView(this).apply { setBackgroundColor(BG); addView(root) })

        root.addView(text("NDA Drive", 26f, GOLD, true))
        root.addView(text("Pô ảo cho xe điện · bản Android", 14f, MUTED).apply { setPadding(0, 0, 0, dp(12)) })

        // ---- trang thai ----
        val c1 = card(root)
        speedTv = text("0", 64f, FG).apply { typeface = Typeface.create("sans-serif-light", Typeface.NORMAL) }
        c1.addView(LinearLayout(this).apply { gravity = Gravity.BOTTOM; addView(speedTv); addView(text(" km/h", 18f, MUTED).apply { setPadding(0, 0, 0, dp(12)) }) })
        subTv = text("", 15f, MUTED); c1.addView(subTv)
        modeTv = text("", 15f, GOLD).apply { setPadding(0, dp(6), 0, 0) }; c1.addView(modeTv)
        runBtn = button("Nổ máy") {
            val s = EngineService.instance
            if (s?.active == true) EngineService.send(this, EngineService.ACT_STOP) else EngineService.send(this, EngineService.ACT_START)
        }
        c1.addView(runBtn)
        c1.addView(button("Kết nối loa Bluetooth", secondary = true) { startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS)) })

        // ---- chon xe ----
        section(root, "CHỌN XE")
        val c2 = card(root)
        val names = (0 until Core.presetCount()).map { "${Core.presetName(it)} — ${Core.presetCar(it)}" }
        val sp = Spinner(this)
        sp.adapter = object : ArrayAdapter<String>(this, android.R.layout.simple_spinner_item, names) {
            override fun getView(p: Int, v: View?, g: ViewGroup): View = (super.getView(p, v, g) as TextView).apply { setTextColor(FG); textSize = 17f }
            override fun getDropDownView(p: Int, v: View?, g: ViewGroup): View = (super.getDropDownView(p, v, g) as TextView).apply { setTextColor(Color.BLACK); setPadding(dp(16), dp(14), dp(16), dp(14)) }
        }
        sp.setSelection(prefs.presetIndex())
        sp.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(p: AdapterView<*>?, v: View?, i: Int, id: Long) { prefs.preset = Core.presetKey(i); prefs.apply() }
            override fun onNothingSelected(p: AdapterView<*>?) {}
        }
        c2.addView(sp)

        // ---- am thanh ----
        section(root, "ÂM THANH")
        val c3 = card(root)
        slider(c3, "Âm lượng", prefs.volume, 1f, { "%.0f%%".format(it * 100) }) { prefs.volume = it; prefs.apply() }
        slider(c3, "Độ đanh của pô", prefs.tone, 1f, { if (it < 0.34) "Êm" else if (it < 0.67) "Vừa" else "Đanh" }) { prefs.tone = it; prefs.apply() }
        slider(c3, "Độ gằn (uy lực)", prefs.growl, 1f, { "%.0f%%".format(it * 100) }) { prefs.growl = it; prefs.apply() }
        slider(c3, "Độ dòn (tiếng nổ)", prefs.crisp, 1f, { "%.0f%%".format(it * 100) }) { prefs.crisp = it; prefs.apply() }
        slider(c3, "Giống ngồi trong xe", prefs.interior, 1f, { "%.0f%%".format(it * 100) }) { prefs.interior = it; prefs.apply() }
        slider(c3, "Tiếng cơ khí (máy)", prefs.mech, 1f, { "%.0f%%".format(it * 100) }) { prefs.mech = it; prefs.apply() }
        // Thong so xe that
        section(root, "THÔNG SỐ XE THẬT")
        val cc = card(root)
        slider(cc, "Mã lực (HP)", (prefs.carHP - 50f) / 750f, 1f, { "%.0f HP".format(50f + it * 750f) }) { prefs.carHP = 50f + it * 750f; prefs.apply() }
        slider(cc, "Tăng tốc 0–100 km/h", (prefs.zeroTo100 - 3f) / 9f, 1f, { "%.1f s".format(3f + it * 9f) }) { prefs.zeroTo100 = 3f + it * 9f; prefs.apply() }
        slider(cc, "Trọng lượng (kg)", (prefs.carWeight - 800f) / 2200f, 1f, { "%.0f kg".format(800f + it * 2200f) }) { prefs.carWeight = 800f + it * 2200f; prefs.apply() }
        slider(c3, "Cảm giác vọng phía sau", prefs.rearAmt, 1f, { "%.0f%%".format(it * 100) }) { prefs.rearAmt = it; prefs.apply() }
        slider(c3, "Lớp siêu trầm (rung)", prefs.subAmt, 1f, { "%.0f%%".format(it * 100) }) { prefs.subAmt = it; prefs.apply() }
        slider(c3, "Bù trễ loa Bluetooth", prefs.leadMs / 400f, 1f, { "%.0f ms".format(it * 400) }) { prefs.leadMs = (it * 400).toInt(); prefs.apply() }
        toggle(c3, "Nổ lụp bụp khi nhả ga", prefs.pops) { prefs.pops = it; prefs.apply() }
        toggle(c3, "Tiếng \"bụp\" khi lên số", prefs.shiftPop) { prefs.shiftPop = it; prefs.apply() }
        toggle(c3, "Tự tăng âm lượng theo tốc độ", prefs.autoVol) { prefs.autoVol = it; prefs.apply() }

        // ---- tu dong ----
        section(root, "TỰ CHẠY THEO XE")
        val c4 = card(root)
        toggle(c4, "Tự nổ máy khi xe bật (cổng USB có điện)", prefs.autoRun) { prefs.autoRun = it; EngineService.instance?.evaluate() }
        toggle(c4, "Chỉ chạy khi loa Bluetooth đã kết nối", prefs.needSpeaker) { prefs.needSpeaker = it; EngineService.instance?.evaluate() }
        c4.addView(text("Cắm A7 vào cổng USB của xe (cổng chỉ có điện khi xe bật). Khi có điện và loa đã kết nối, app tự nổ máy; mất điện 15 giây thì tự tắt.", 13f, MUTED))
        c4.addView(button("Tắt tối ưu pin cho app (bắt buộc)", secondary = true) {
            try { startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))) }
            catch (_: Exception) { startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) }
        })

        // ---- hoc + thu ----
        section(root, "HỌC & KIỂM THỬ")
        val c5 = card(root)
        toggle(c5, "Học thích nghi theo xe và cách lái", prefs.learn) { prefs.learn = it; prefs.apply() }
        toggle(c5, "Ghi lịch sử chuyến đi", prefs.record) { prefs.record = it }
        toggle(c5, "Thu thập im lặng (không phát tiếng)", prefs.collectMode) { prefs.collectMode = it }
        val trialTv = text("Thử nghiệm 7 ngày: %d/7 ngày · %.0f km".format(prefs.trialDays(), prefs.trialKm()), 13f, MUTED)
        c5.addView(trialTv)
        var testOn = false
        val testSl = slider(c5, "Tốc độ giả lập (khi đỗ)", 0f, 1f, { "%.0f km/h".format(it * 200) }) { EngineService.instance?.testKmh = it * 200.0 }
        toggle(c5, "Giả lập tốc độ (chỉ dùng khi xe đỗ)", false) { testOn = it; EngineService.instance?.testMode = it; if (!it) Core.setTest(false, 0.0) }
        c5.addView(button("Học lại hướng đặt máy", secondary = true) { Core.calReset(); prefs.cal = null; toast("Đã xóa. Lái và rẽ vài khúc cua để máy tự học lại.") })

        section(root, "CẢM BIẾN")
        val c6 = card(root)
        hudTv = text("", 13f, FG).apply { typeface = Typeface.MONOSPACE }; c6.addView(hudTv)
        c6.addView(button("Xuất báo cáo cho Claude") {
            Thread { val f = Report.build(this); runOnUiThread { Report.share(this, f) } }.start()
        })

        askPermissions()
        EngineService.send(this, EngineService.ACT_WAIT)
        h.post(ui)
    }

    override fun onDestroy() { h.removeCallbacks(ui); super.onDestroy() }

    private val ui = object : Runnable {
        override fun run() {
            Core.state(st)
            val s = EngineService.instance
            speedTv.text = "%.0f".format(st[Core.SYN_V])
            val stateName = when (st[Core.SSTATE].toInt()) { 1 -> "đang nổ máy"; 2 -> "nổ máy"; 3 -> "đang tắt"; else -> "tắt máy" }
            subTv.text = "%.0f v/p · số %d · ga %.0f%% · %s".format(st[Core.RPM], st[Core.GEAR].toInt(), st[Core.LOAD] * 100, stateName)
            modeTv.text = when {
                s == null -> "Dịch vụ chưa chạy"
                s.active -> "● Đang chạy" + (if (s.speakerName != null) " → loa ${s.speakerName}" else " (loa trong máy)")
                else -> "Đang chờ xe · nguồn: ${if (s.powered) "có" else "không"} · loa: ${s.speakerName ?: "chưa kết nối"}"
            }
            modeTv.setTextColor(if (s?.active == true) GREEN else GOLD)
            runBtn.text = if (s?.active == true) "Tắt máy" else "Nổ máy"
            if (s != null) {
                val cal = if (st[Core.CAL] > 0) (if (st[Core.CALTURN] > 0) "đã học (vào cua)" else "đã học (GPS)") else "đang học %.0f%%".format(st[Core.CALPROG] * 100)
                hudTv.text = String.format(Locale.US,
                    "Cảm biến   %.0f lần/giây\nGPS        %.1f lần/giây · %s\nTốc độ GPS %s\nHợp nhất   %.1f km/h · a %.2f m/s²\nHướng xe   %s (%.0f°)\nTrễ GPS    %s\nĐã học     %.1f km · thể thao %.2f\n%s",
                    s.imuHz, s.gpsHz, if (st[Core.GPSOK] > 0) "tốt" else "chưa có",
                    if (s.gpsRawKmh >= 0) "%.1f km/h".format(s.gpsRawKmh) else "—",
                    st[Core.V], st[Core.A], cal, st[Core.THETA],
                    if (st[Core.GPSDLY] > 0) "%.1f s".format(st[Core.GPSDLY]) else "đang ước lượng",
                    st[Core.LDIST], st[Core.SPORT], s.sensorInfo)
            }
            h.postDelayed(this, 200)
        }
    }

    // ---------------- quyen ----------------
    private fun askPermissions() {
        val need = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
        if (Build.VERSION.SDK_INT >= 33) need += Manifest.permission.POST_NOTIFICATIONS
        if (Build.VERSION.SDK_INT >= 31) need += Manifest.permission.BLUETOOTH_CONNECT
        val missing = need.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isNotEmpty()) requestPermissions(missing.toTypedArray(), 1)
        else askBackground()
    }
    private fun askBackground() {
        if (Build.VERSION.SDK_INT >= 29 && checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) != PackageManager.PERMISSION_GRANTED)
            requestPermissions(arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), 2)
    }
    override fun onRequestPermissionsResult(rc: Int, p: Array<out String>, r: IntArray) {
        super.onRequestPermissionsResult(rc, p, r)
        if (rc == 1) askBackground()
    }

    // ---------------- giao dien ----------------
    private fun text(s: String, size: Float, color: Int, bold: Boolean = false) = TextView(this).apply {
        text = s; textSize = size; setTextColor(color); if (bold) typeface = Typeface.DEFAULT_BOLD
    }
    private fun section(root: LinearLayout, t: String) = root.addView(text(t, 13f, MUTED).apply { setPadding(dp(4), dp(18), 0, dp(6)); letterSpacing = 0.08f })
    private fun card(root: LinearLayout): LinearLayout {
        val c = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; setPadding(dp(16), dp(14), dp(16), dp(14))
            background = GradientDrawable().apply { setColor(CARD); cornerRadius = dp(14).toFloat() }
        }
        root.addView(c); return c
    }
    private fun button(t: String, secondary: Boolean = false, on: () -> Unit) = Button(this).apply {
        text = t; isAllCaps = false; textSize = 17f
        setTextColor(if (secondary) FG else Color.BLACK)
        background = GradientDrawable().apply { setColor(if (secondary) Color.rgb(38, 38, 43) else GOLD); cornerRadius = dp(12).toFloat() }
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)).apply { topMargin = dp(10) }
        setOnClickListener { on() }
    }
    private fun toggle(c: LinearLayout, t: String, v: Boolean, on: (Boolean) -> Unit) {
        val sw = Switch(this).apply { text = t; textSize = 16f; setTextColor(FG); isChecked = v; setPadding(0, dp(10), 0, dp(10)) }
        sw.setOnCheckedChangeListener { _, b -> on(b) }
        c.addView(sw)
    }
    private fun slider(c: LinearLayout, t: String, v: Float, max: Float, fmt: (Float) -> String, on: (Float) -> Unit): SeekBar {
        val row = LinearLayout(this).apply { setPadding(0, dp(8), 0, 0) }
        val lbl = text(t, 16f, FG).apply { layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f) }
        val valTv = text(fmt(v), 15f, MUTED)
        row.addView(lbl); row.addView(valTv); c.addView(row)
        val sb = SeekBar(this).apply { this.max = 1000; progress = (v / max * 1000).toInt() }
        sb.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(s: SeekBar?, p: Int, u: Boolean) { val x = p / 1000f * max; valTv.text = fmt(x); if (u) on(x) }
            override fun onStartTrackingTouch(s: SeekBar?) {}
            override fun onStopTrackingTouch(s: SeekBar?) {}
        })
        c.addView(sb); return sb
    }
    private fun toast(s: String) = Toast.makeText(this, s, Toast.LENGTH_LONG).show()
}
