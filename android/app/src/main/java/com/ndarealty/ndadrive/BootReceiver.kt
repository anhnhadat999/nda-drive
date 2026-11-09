package com.ndarealty.ndadrive

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

// Bat dien thoai / cap nhat app -> khoi dong dich vu cho xe
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        if (Prefs(c).autoRun) EngineService.send(c, EngineService.ACT_WAIT)
    }
}
