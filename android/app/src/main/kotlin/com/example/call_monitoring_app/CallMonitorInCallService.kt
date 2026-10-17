package com.example.call_monitoring_app

import android.telecom.InCallService

/**
 * Required by Android's dialer role. It intentionally does not capture audio.
 * A production dialer must also supply a complete, accessible in-call UI.
 */
class CallMonitorInCallService : InCallService()
