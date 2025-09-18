package com.example.iphone_bt_epaper

import android.os.Bundle
import android.content.Context
import android.net.wifi.WifiManager
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.Executors

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.hch.epaper.ble_sdk.api.DefaultSDKFactory
import com.hch.epaper.ble_sdk.api.EInkSDK
import com.hch.epaper.ble_sdk.api.SDKError
import com.hch.epaper.ble_sdk.api.SDKOperationDelegate
import io.flutter.plugin.common.BasicMessageChannel // callback.message 送信用
import io.flutter.plugin.common.StringCodec
import android.os.Handler
import android.os.Looper
import org.json.JSONObject

import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.iphone_bt_epaper/channel"
    private val WIFI_CHANNEL = "com.example.wifi/helper"

    // SDK / data
    private var sdk: EInkSDK? = null
    private var deviceName: String? = null
    private var imageUrl: String? = null

    // message channel and helpers (class-level)
    private lateinit var messageChannel: BasicMessageChannel<String>
    private val sendingMessages = mutableSetOf<String>()

    private val httpClient = OkHttpClient()
    private val pollHandler = Handler(Looper.getMainLooper())
    private var pollingRunnable: Runnable? = null
    private val POLL_INTERVAL_MS = 2000L
    private val pollExecutor = Executors.newSingleThreadExecutor()

    // 送信ヘルパー（クラスメソッドに）
    private fun sendMessageToFlutter(callbackName: String, message: String?, progressPercent: Int?) {
        if (!::messageChannel.isInitialized) {
            Log.w("MainActivity", "messageChannel not initialized yet")
            return
        }

        val data: MutableMap<String, Any?> = mutableMapOf(
            "callbackName" to callbackName,
            "message" to message,
            "progressPercent" to progressPercent
        )

        Log.d("channel.send", "data: $data")

        if (sendingMessages.contains(callbackName)) return
        sendingMessages.add(callbackName)

        Handler(Looper.getMainLooper()).post {
            try {
                val json = JSONObject(data as Map<*, *>)
                messageChannel.send(json.toString())
            } catch (ex: Exception) {
                Log.e("channel.send", "failed to send message", ex)
            } finally {
                sendingMessages.remove(callbackName)
            }
        }
    }

    // FlutterEngine が利用可能になるタイミングでチャネルやデリゲートを初期化
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        messageChannel = BasicMessageChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL, StringCodec.INSTANCE)

        // SDK のデリゲートをここで作る（messageChannel が使える状態）
        val delegate: SDKOperationDelegate = object : SDKOperationDelegate {
            override fun onSetupSDKStart() {
                Log.d("MainActivity", "onSetupSDKStart")
            }
            override fun onSetupSDKComplete() {
                Log.d("MainActivity", "onSetupSDKComplete")
                // connect
                deviceName?.let {
                    Log.d("MainActivity", "call connectBleDevice [$it]")
                    sdk?.connectBleDevice(it)
                }
            }
            override fun onSetupSDKFailed(error: SDKError?) {
                Log.d("MainActivity", "onSetupSDKFailed: ${error?.message}")
                sendMessageToFlutter("onSetupSDKFailed", error?.message, null)
            }
            override fun onBLEDeviceCancelFailed(error: SDKError?) {
                Log.d("MainActivity", "onBLEDeviceCancelFailed: ${error?.message}")
                sendMessageToFlutter("onBLEDeviceCancelFailed", error?.message, null)
            }
            override fun onBLEDeviceConnectCanceled() {
                Log.d("MainActivity", "onBLEDeviceConnectCanceled")
                sendMessageToFlutter("onBLEDeviceConnectCanceled", "DeviceConnectCanceled", null)
                sdk?.cancelConnection()
            }
            override fun onBLEDeviceConnectComplete() {
                Log.d("MainActivity", "onBLEDeviceConnectComplete")
                sendMessageToFlutter("onBLEDeviceConnectComplete", "Complete", null)
                // send image
                imageUrl?.let {
                    Log.d("MainActivity", "call sendImageToDevice")
                    sdk?.sendImageToDevice("3000K-5.65", it)
                }
            }
            override fun onBLEDeviceConnectFailed(error: SDKError?) {
                Log.d("MainActivity", "onBLEDeviceConnectFailed: ${error?.message}")
                sendMessageToFlutter("onBLEDeviceConnectFailed", error?.message, null)
            }
            override fun onBLEDeviceDisconnect() {
                Log.d("MainActivity", "onBLEDeviceDisconnect")
                sendMessageToFlutter("onBLEDeviceDisconnect", "DeviceDisconnect", null)
            }
            override fun onSendImageToDeviceStart() {
                Log.d("MainActivity", "onSendImageToDeviceStart")
                sendMessageToFlutter("onSendImageToDeviceStart", "Start", null)
            }
            override fun onSendImageToDeviceComplete() {
                Log.d("MainActivity", "onSendImageToDeviceComplete")
                sendMessageToFlutter("onSendImageToDeviceComplete", "Complete", null)
            }
            override fun onSendImageToDeviceFailed(error: SDKError?) {
                Log.d("MainActivity", "onSendImageToDeviceFailed: ${error?.message}")
                sendMessageToFlutter("onSendImageToDeviceFailed", error?.message, null)
                sdk?.cancelConnection()
            }
            override fun onSendImageToDeviceCanceled() {
                Log.d("MainActivity", "onSendImageToDeviceCanceled")
                sendMessageToFlutter("onSendImageToDeviceCanceled", "DeviceCanceled", null)
                sdk?.cancelConnection()
            }
            override fun onSendImageToDeviceProgress(progressPercent: Int) {
                Log.d("MainActivity", "onSendImageToDeviceProgress: $progressPercent")
                sendMessageToFlutter("onSendImageToDeviceProgress", "SendImage", progressPercent)
            }
        }

        // WIFI チャネル（MethodChannel）はここで設定
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIFI_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkWifiReady" -> {
                        try {
                            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                            val map = HashMap<String, Any?>()
                            if (!wifiManager.isWifiEnabled) {
                                map["status"] = "WIFI_OFF"
                                result.success(map)
                                return@setMethodCallHandler
                            }
                            val info = wifiManager.connectionInfo
                            val rawSsid = info?.ssid ?: ""
                            val ssid = rawSsid.removePrefix("\"").removeSuffix("\"")
                            val ipInt = info?.ipAddress ?: 0
                            fun intToIp(ip: Int): String {
                                return if (ip == 0) "" else
                                    "${ip and 0xff}.${ip shr 8 and 0xff}.${ip shr 16 and 0xff}.${ip shr 24 and 0xff}"
                            }
                            val ipString = intToIp(ipInt)
                            map["status"] = if (ipString.isEmpty()) "NO_IP" else "READY"
                            map["ssid"] = ssid
                            map["ip"] = ipString
                            result.success(map)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "checkWifiReady error", e)
                            val err = HashMap<String, Any?>()
                            err["status"] = "ERROR"
                            err["message"] = e.message
                            result.success(err)
                        }
                    }

                    // ポーリングの開始/停止をここで受けられるようにする
                    "startStatusPolling" -> {
                        val serverBaseUrl = call.argument<String>("serverBaseUrl") ?: ""
                        if (serverBaseUrl.isNotEmpty()) {
                            startStatusPolling(serverBaseUrl)
                            result.success(mapOf("started" to true))
                        } else {
                            result.success(mapOf("started" to false, "error" to "no serverBaseUrl"))
                        }
                    }
                    "stopStatusPolling" -> {
                        stopStatusPolling()
                        result.success(mapOf("stopped" to true))
                    }
                    else -> result.notImplemented()
                }
            }

        // Main SDK MethodChannel (既存) — Flutter 側から SDK 呼び出しを受ける
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "callSdk") {
                if (sdk == null) {
                    val factory = DefaultSDKFactory.instance
                    sdk = factory.createSDK()
                }

                deviceName = call.argument<String>("deviceName")
                imageUrl = call.argument<String>("imageUrl")
                Log.d("MainActivity", "deviceName: $deviceName")
                Log.d("MainActivity", "imageUrl: $imageUrl")

                // SDKの初期化： context は this@MainActivity
                val res = sdk?.setupSDK(this@MainActivity, delegate)
                Log.d("MainActivity", "setupSDK: $res")
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    // serverBaseUrl 例: "http://192.168.0.5:5000"
    fun startStatusPolling(serverBaseUrl: String) {
        stopStatusPolling()

        pollingRunnable = Runnable {
            pollExecutor.execute {
                try {
                    val req = Request.Builder().url("$serverBaseUrl/status").get().build()
                    httpClient.newCall(req).execute().use { resp ->
                        if (!resp.isSuccessful) {
                            Log.w("StatusPoll", "Non-successful response: ${resp.code}")
                            sendMessageToFlutter("epaper_unreachable", "サーバに接続できませんでした", null)
                        } else {
                            val body = resp.body?.string() ?: ""
                            Log.d("StatusPoll", "body: $body")
                            val json = JSONObject(body)
                            val status = json.optString("status", "")
                            if (status == "error") {
                                val lastErr = json.optJSONObject("last_error")
                                val msg = lastErr?.optString("message") ?: "電子ペーパーに配信できませんでした"
                                sendMessageToFlutter("epaper_error", msg, null)
                                stopStatusPolling()
                            } else if (status == "done") {
                                sendMessageToFlutter("epaper_done", "表示完了", null)
                                stopStatusPolling()
                            } else {
                                pollHandler.postDelayed(pollingRunnable!!, POLL_INTERVAL_MS)
                            }
                        }
                    }
                } catch (ex: Exception) {
                    Log.e("StatusPoll", "poll failed", ex)
                    sendMessageToFlutter("epaper_unreachable", ex.message ?: "通信エラー", null)
                    stopStatusPolling()
                }
            }
        }

        pollHandler.post(pollingRunnable!!)
    }

    fun stopStatusPolling() {
        pollingRunnable?.let {
            pollHandler.removeCallbacks(it)
        }
        pollingRunnable = null
    }
}
