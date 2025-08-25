package com.example.iphone_bt_epaper

import android.os.Bundle
//wifi判定用
import android.content.Context
import android.net.wifi.WifiManager

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.hch.epaper.ble_sdk.api.DefaultSDKFactory
import com.hch.epaper.ble_sdk.api.EInkSDK
import com.hch.epaper.ble_sdk.api.SDKError
import com.hch.epaper.ble_sdk.api.SDKOperationDelegate
import com.hch.epaper.ble_sdk.api.SDKFactory
import io.flutter.plugin.common.BasicMessageChannel // callback.message 送信用
import io.flutter.plugin.common.StringCodec
import android.os.Handler
import android.os.Looper
import org.json.JSONObject

import android.util.Log // Log出力用

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.iphone_bt_epaper/channel"
    // wifi判定のチャンネル
    private val WIFI_CHANNEL = "com.example.wifi/helper"

    var sdk: EInkSDK? = null
    var deviceName: String? = null
    var imageUrl: String? = null
    private val sendingMessages = mutableSetOf<String>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val messageChannel = flutterEngine?.dartExecutor?.binaryMessenger?.let {
            BasicMessageChannel(it, CHANNEL, StringCodec.INSTANCE)
        } ?: throw IllegalStateException("flutterEngine or binaryMessenger is null")

        fun sendMessageToFlutter(channel: BasicMessageChannel<String>, callbackName: String, message: String?, progressPercent: Int?) {
            var data: MutableMap<String, Any?> = mutableMapOf(
                "callbackName" to callbackName,
                "message" to message,
                "progressPercent" to progressPercent)

            Log.d("channel.send", "data: $data")

            if (sendingMessages.contains(callbackName)) return  // すでに送信済みなら何もしない
            // 送信中リストに追加
            sendingMessages.add(callbackName)

            Handler(Looper.getMainLooper()).removeCallbacksAndMessages(null) // 既存の送信をキャンセル

            Handler(Looper.getMainLooper()).postDelayed({
                val json = JSONObject(data)
                Log.d("channel.send", "channel.send start")
                channel.send(json.toString())
                Log.d("channel.send", "channel.send end")
                // 送信完了後、リストから削除
                sendingMessages.remove(callbackName)

            }, 0)
        }



//        fun updateValues(values: Map<String, Any?>) {
//            for ((key, newValue) in values) {
//                // 値の型を確認し、適切に処理
//                if (data.containsKey(key)) {
//                    when (newValue) {
//                        is String -> data[key] = newValue // String型
//                        is String? -> data[key] = newValue // String?型
//                        is Int? -> data[key] = newValue // Int?型
//                        else -> println("無効な型です: $key")
//                    }
//                } else {
//                    println("指定されたキーは存在しません: $key")
//                }
//            }
//        }

        // デリゲートの実装
        val delegate: SDKOperationDelegate = object : SDKOperationDelegate {
            // 未呼び出し
            override fun onSetupSDKStart() {
                // SDK初期化開始時の通知　optinal
                Log.d("MainActivity", "onSetupSDKStart")
//                // Flutter側へメッセージ送信
//                sendMessageToFlutter(messageChannel, "onSetupSDKStart", "Start", null)
            }
            override fun onSetupSDKComplete() {
                // セットアップ完了時の処理
                Log.d("MainActivity", "onSetupSDKComplete")
                // Flutter側へメッセージ送信
//                sendMessageToFlutter(messageChannel, "onSetupSDKComplete", "Complete", null)
                // BL接続
                Log.d("MainActivity", "call connectBleDevice [${deviceName}]")
                sdk?.connectBleDevice(deviceName!!)
            }
            override fun onSetupSDKFailed(error: SDKError?) {
                // セットアップ失敗時の処理
                Log.d("MainActivity", "onSetupSDKFailed: ${error?.message}")
                // Flutter側へメッセージ送信
                sendMessageToFlutter(messageChannel, "onSetupSDKFailed", error?.message, null)
            }
            override fun onBLEDeviceCancelFailed(error: SDKError?) {
                // BL接続切断失敗時の処理
                Log.d("MainActivity", "onBLEDeviceCancelFailed: ${error?.message}")
                sendMessageToFlutter(messageChannel, "onBLEDeviceCancelFailed", error?.message, null)
            }
            //            override fun onBLEDeviceConnectStart() {
//                // BL接続開始時の通知　optional
//                Log.d("MainActivity", "onBLEDeviceConnectStart")
//                // Flutter側へメッセージ送信
//                sendMessageToFlutter(messageChannel, "onBLEDeviceConnectStart", "Start", null)
//            }
            // 仕様書記載なし
            override fun onBLEDeviceConnectCanceled() {
                // BL接続キャンセル時の処理
                Log.d("MainActivity", "onBLEDeviceConnectCanceled")
                // Flutter側へメッセージ送信
                sendMessageToFlutter(messageChannel, "onBLEDeviceConnectCanceled", "DeviceConnectCanceled", null)
//                // BL接続切断
                Log.d("MainActivity", "call cancelConnection")
                sdk?.cancelConnection()
            }
            override fun onBLEDeviceConnectComplete() {
                // BL接続成功時の処理
                Log.d("MainActivity", "onBLEDeviceConnectComplete")
                // Flutter側へメッセージ送信
                sendMessageToFlutter(messageChannel, "onBLEDeviceConnectComplete", "Complete", null)
                // 画像送信
                Log.d("MainActivity", "call sendImageToDevice")
                sdk?.sendImageToDevice("3000K-5.65", imageUrl!!)
            }
            override fun onBLEDeviceConnectFailed(error: SDKError?) {
                // BL接続失敗時の処理
                Log.d("MainActivity", "onBLEDeviceConnectFailed: ${error?.message}")
                // Flutter側へメッセージ送信
                sendMessageToFlutter(messageChannel, "onBLEDeviceConnectFailed", error?.message, null)
            }

            override fun onBLEDeviceDisconnect() {
                // BL切断成功時の処理
                Log.d("MainActivity", "onBLEDeviceDisconnect")
                // Flutter側へメッセージ送信
                sendMessageToFlutter(messageChannel, "onBLEDeviceDisconnect", "DeviceDisconnect", null)
            }

            override fun onSendImageToDeviceStart() {
                // 画像送信開始時通知　optional
                Log.d("MainActivity", "onSendImageToDeviceStart")
                sendMessageToFlutter(messageChannel, "onSendImageToDeviceStart", "Start", null)
            }
            override fun onSendImageToDeviceComplete() {
                // 画像送信成功時の処理
                Log.d("MainActivity", "onSendImageToDeviceComplete")
                // Flutter側へメッセージ送信
                sendMessageToFlutter(messageChannel, "onSendImageToDeviceComplete", "Complete", null)
            }
            override fun onSendImageToDeviceFailed(error: SDKError?) {
                // 画像送信失敗時の処理
                Log.d("MainActivity", "onSendImageToDeviceFailed: ${error?.message}")
                // Flutter側へメッセージ送信
                sendMessageToFlutter(messageChannel, "onSendImageToDeviceFailed", error?.message, null)
                // BL接続切断
                Log.d("MainActivity", "call cancelConnection")
                sdk?.cancelConnection()
            }
            // 呼び出しタイミング：不明　仕様書記載なし
            override fun onSendImageToDeviceCanceled() {
                Log.d("MainActivity", "onSendImageToDeviceCanceled")
                // Flutter側へメッセージ送信
                sendMessageToFlutter(messageChannel, "onSendImageToDeviceCanceled", "DeviceCanceled", null)
                // BL接続切断
                Log.d("MainActivity", "call cancelConnection")
                sdk?.cancelConnection()
            }
            override fun onSendImageToDeviceProgress(progressPercent: Int) {
                // 画像送信進捗通知　optional
                Log.d("MainActivity", "onSendImageToDeviceProgress: ${progressPercent}")
                // Flutter側へメッセージ送信
                sendMessageToFlutter(messageChannel, "onSendImageToDeviceProgress", "SendImage", progressPercent)
            }
        }

        //　接続やwifiの判定を行うときのメソッド
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, WIFI_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    //　androidstudio側から呼び出し
                    "checkWifiReady" -> {
                        try {
                            // ON/OFF や接続情報（SSID, IP）を取れる
                            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

                            if (wifiManager.isWifiEnabled) {
                                // Wi-Fi が ON
                                Log.d("★WiFiCheck", "Wi-Fi は有効です")
                            } else {
                                // Wi-Fi が OFF
                                Log.d("☆WiFiCheck", "Wi-Fi は無効です")
                            }

                            //データを管理する連想配列
                            val map = HashMap<String, Any?>()

                            //　ここでOFFなら結果返して処理終了
                            if (!wifiManager.isWifiEnabled) {
                                map["status"] = "WIFI_OFF"
                                result.success(map)
                                Log.d("MainActivity", "wifi: $map")
                                // 何か条件で処理を中断したい場合
                                return@setMethodCallHandler
                            }

                            //　wi-fiがonで情報を取得できた場合
                            val info = wifiManager.connectionInfo
                            val rawSsid = info?.ssid ?: ""
                            val ssid = rawSsid.removePrefix("\"").removeSuffix("\"") // normalize

                            // ipAddress を取得し文字列へ変換する
                            val ipInt = info?.ipAddress ?: 0
                            fun intToIp(ip: Int): String {
                                return if (ip == 0) "" else
                                    "${ip and 0xff}.${ip shr 8 and 0xff}.${ip shr 16 and 0xff}.${ip shr 24 and 0xff}"
                            }
                            val ipString = intToIp(ipInt)

                            //　上記結果からipアドレスを取得
                            map["status"] = if (ipString.isEmpty()) "NO_IP" else "READY"
                            // 接続中のwifiのIPとssidを取得しmapに結果を返す
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
                }
            }

        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "callSdk") {

                Log.d("MainActivity", "SDK instance: $sdk")
                if (sdk == null) {
                    // SDKファクトリーのインスタンスを取得
                    val factory = DefaultSDKFactory.instance
                    Log.d("MainActivity", "factory: $factory")

                    // SDKインスタンスを作成
                    Log.d("MainActivity", "call createSDK")
                    sdk = factory.createSDK()
                    Log.d("MainActivity", "createSDK: $sdk")
                }

                // デバイス名取得
                deviceName = call.argument<String>("deviceName")
                imageUrl = call.argument<String>("imageUrl")
                Log.d("MainActivity", "deviceName: $deviceName")
                Log.d("MainActivity", "imageUrl: $imageUrl")

                // SDKの初期化
                Log.d("MainActivity", "call setupSDK")
                val res = sdk?.setupSDK(context, delegate)
                Log.d("MainActivity", "setupSDK: $res")

            } else {
                result.notImplemented()
            }
        }
    }
}
