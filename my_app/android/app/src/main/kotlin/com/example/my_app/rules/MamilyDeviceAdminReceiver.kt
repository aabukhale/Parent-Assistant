package com.example.my_app.rules

import android.app.admin.DeviceAdminReceiver

/**
 * Mamily's device-admin component. It only becomes *device owner* when a
 * phone is provisioned for it (factory-fresh setup, or
 * `adb shell dpm set-device-owner com.example.my_app/.rules.MamilyDeviceAdminReceiver`
 * on a test device with no accounts). Ordinary installs never get these
 * powers and Mamily reports that honestly.
 */
class MamilyDeviceAdminReceiver : DeviceAdminReceiver()
