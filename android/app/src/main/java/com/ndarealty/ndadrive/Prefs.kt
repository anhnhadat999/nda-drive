package com.ndarealty.ndadrive

import android.content.Context
import android.util.Base64

class Prefs(ctx: Context) {
    private val p = ctx.getSharedPreferences("nda", Context.MODE_PRIVATE)
    var preset: String get() = p.getString("preset", "gt3")!!; set(v) = p.edit().putString("preset", v).apply()
    var volume: Float get() = p.getFloat("vol", 0.8f); set(v) = p.edit().putFloat("vol", v).apply()
    var tone: Float get() = p.getFloat("tone", 0.5f); set(v) = p.edit().putFloat("tone", v).apply()
    var rearAmt: Float get() = p.getFloat("rear", 0.3f); set(v) = p.edit().putFloat("rear", v).apply()
    var subAmt: Float get() = p.getFloat("sub", 0.6f); set(v) = p.edit().putFloat("sub", v).apply()
    var growl: Float get() = p.getFloat("growl", 0.6f); set(v) = p.edit().putFloat("growl", v).apply()
    var crisp: Float get() = p.getFloat("crisp", 0.6f); set(v) = p.edit().putFloat("crisp", v).apply()
    var zeroTo100: Float get() = p.getFloat("car0to100", 5.8f); set(v) = p.edit().putFloat("car0to100", v).apply()
    var carHP: Float get() = p.getFloat("hp", 349f); set(v) = p.edit().putFloat("hp", v).apply()
    var carWeight: Float get() = p.getFloat("wt", 1900f); set(v) = p.edit().putFloat("wt", v).apply()
    var interior: Float get() = p.getFloat("interior", 0.4f); set(v) = p.edit().putFloat("interior", v).apply()
    var mech: Float get() = p.getFloat("mech", 0.3f); set(v) = p.edit().putFloat("mech", v).apply()
    var leadMs: Int get() = p.getInt("lead", 200); set(v) = p.edit().putInt("lead", v).apply()
    var pops: Boolean get() = p.getBoolean("pops", true); set(v) = p.edit().putBoolean("pops", v).apply()
    var shiftPop: Boolean get() = p.getBoolean("shiftPop", true); set(v) = p.edit().putBoolean("shiftPop", v).apply()
    var autoVol: Boolean get() = p.getBoolean("autoVol", true); set(v) = p.edit().putBoolean("autoVol", v).apply()
    var learn: Boolean get() = p.getBoolean("learn", true); set(v) = p.edit().putBoolean("learn", v).apply()
    var record: Boolean get() = p.getBoolean("record", true); set(v) = p.edit().putBoolean("record", v).apply()
    var autoRun: Boolean get() = p.getBoolean("autoRun", true); set(v) = p.edit().putBoolean("autoRun", v).apply()
    var needSpeaker: Boolean get() = p.getBoolean("needSpk", true); set(v) = p.edit().putBoolean("needSpk", v).apply()
    var collectMode: Boolean get() = p.getBoolean("collectMode", false); set(v) = p.edit().putBoolean("collectMode", v).apply()
    var trim: Float get() = p.getFloat("trim", 0f); set(v) = p.edit().putFloat("trim", v).apply()

    var learnBlob: ByteArray?
        get() = p.getString("learn.v1", null)?.let { Base64.decode(it, Base64.NO_WRAP) }
        set(v) { p.edit().putString("learn.v1", v?.let { Base64.encodeToString(it, Base64.NO_WRAP) }).apply() }
    var cal: DoubleArray?
        get() = p.getString("cal", null)?.split(",")?.mapNotNull { it.toDoubleOrNull() }?.takeIf { it.size == 4 }?.toDoubleArray()
        set(v) { p.edit().putString("cal", v?.joinToString(",")).apply() }

    fun counter(key: String): Int = p.getInt("cnt.$key", 0)
    fun bump(key: String) { p.edit().putInt("cnt.$key", counter(key) + 1).apply() }
    fun counters(): Map<String, Int> = p.all.filterKeys { it.startsWith("cnt.") }.mapKeys { it.key.removePrefix("cnt.") }.mapValues { (it.value as? Int) ?: 0 }

    // Giai doan thu nghiem 7 ngay
    fun trialAddDrive(km: Double, sec: Double) {
        if (sec < 20) return
        val days = (p.getStringSet("tr.days", emptySet()) ?: emptySet()).toMutableSet()
        days.add(java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date()))
        p.edit().putStringSet("tr.days", days)
            .putFloat("tr.km", p.getFloat("tr.km", 0f) + km.toFloat())
            .putFloat("tr.sec", p.getFloat("tr.sec", 0f) + sec.toFloat())
            .putInt("tr.trips", p.getInt("tr.trips", 0) + 1).apply()
    }
    fun trialMarkToday() {
        val days = (p.getStringSet("tr.days", emptySet()) ?: emptySet()).toMutableSet()
        if (days.add(java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date()))) p.edit().putStringSet("tr.days", days).apply()
    }
    fun trialDays(): Int = (p.getStringSet("tr.days", emptySet()) ?: emptySet()).size
    fun trialKm(): Float = p.getFloat("tr.km", 0f)
    fun trialTrips(): Int = p.getInt("tr.trips", 0)
    fun trialComplete(): Boolean = trialDays() >= 7
    fun trialReset() { p.edit().remove("tr.days").remove("tr.km").remove("tr.sec").remove("tr.trips").apply() }
    fun perfCap(): Double = if (zeroTo100 > 1) 27.78 / zeroTo100 * 1.4 else 0.0
    fun perfKnee(): Double {
        val cap = perfCap(); if (cap < 0.5 || carHP < 10 || carWeight < 100) return 50.0
        return (carHP * 746.0 * 0.85 / (carWeight * cap) * 3.6).coerceIn(25.0, 160.0)
    }
    fun presetIndex(): Int {
        Core.ensureInit()
        for (i in 0 until Core.presetCount()) if (Core.presetKey(i) == preset) return i
        return 0
    }
    fun apply() {
        Core.ensureInit()
        Core.setParams(presetIndex(), volume.toDouble(), tone.toDouble(), pops, shiftPop, autoVol, rearAmt > 0.01f,
            rearAmt.toDouble(), subAmt.toDouble(), growl.toDouble(), crisp.toDouble(),
            perfCap(), perfKnee(), interior.toDouble(), mech.toDouble(), learn, trim.toDouble(), 1.0)
        Core.setLead(leadMs / 1000.0)
        Core.setMute(collectMode)   // im lang: van chay am thanh + vat ly, chi tat tieng
    }
}
