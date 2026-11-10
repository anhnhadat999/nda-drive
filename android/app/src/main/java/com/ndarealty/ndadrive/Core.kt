package com.ndarealty.ndadrive

// Loi C dung chung voi ban iOS: bo tao tieng (PASynth), hop nhat cam bien (PAFusion), hoc thich nghi (PALearn)
object Core {
    init { System.loadLibrary("ndacore") }
    @Volatile private var inited = false
    @Synchronized fun ensureInit() { if (!inited) { init(); inited = true } }

    @JvmStatic external fun init()
    @JvmStatic external fun presetCount(): Int
    @JvmStatic external fun presetKey(i: Int): String
    @JvmStatic external fun presetName(i: Int): String
    @JvmStatic external fun presetCar(i: Int): String
    @JvmStatic external fun setParams(preset: Int, vol: Double, tone: Double, pops: Boolean, shiftPop: Boolean, autoVol: Boolean,
                                      rearFx: Boolean, rearAmt: Double, subAmt: Double, growl: Double, crisp: Double, perfCap: Double, perfKnee: Double, interior: Double, mech: Double, learn: Boolean, trim: Double, resp: Double)
    @JvmStatic external fun setLead(s: Double)
    @JvmStatic external fun engineStart()
    @JvmStatic external fun engineStop()
    @JvmStatic external fun setTest(on: Boolean, kmh: Double)
    @JvmStatic external fun imu(ax: Double, ay: Double, az: Double, gx: Double, gy: Double, gz: Double,
                                rx: Double, ry: Double, rz: Double, t: Double)
    @JvmStatic external fun gps(speed: Double, acc: Double, course: Double, t: Double)
    @JvmStatic external fun baro(alt: Double, t: Double)
    @JvmStatic external fun render(buf: FloatArray, n: Int, sr: Double)
    @JvmStatic external fun state(out: DoubleArray)
    @JvmStatic external fun learnGet(): ByteArray
    @JvmStatic external fun learnSet(b: ByteArray)
    @JvmStatic external fun learnReset()
    @JvmStatic external fun calGet(): DoubleArray?
    @JvmStatic external fun calSet(th: Double, gx: Double, gy: Double, gz: Double)
    @JvmStatic external fun calReset()

    // chi so trong mang state()
    const val V = 0; const val A = 1; const val CAL = 2; const val STILL = 3; const val GPSOK = 4; const val CALPROG = 5
    const val THETA = 6; const val GPSDLY = 7; const val CALTURN = 8; const val GRADE = 9
    const val SYN_V = 10; const val RPM = 11; const val GEAR = 12; const val LOAD = 13; const val SSTATE = 14; const val LEAD = 15
    const val SPORT = 16; const val CONF = 17; const val Z100 = 18; const val LDIST = 19; const val LSAMP = 20
    const val QUAL = 21; const val GPSREP = 22
}
