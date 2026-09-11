package com.volume_button_override

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.KeyEvent
import android.view.Window.Callback
import android.view.Window

class VolumeButtonOverridePlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private var context: Context? = null
  private var activity: Activity? = null
  private var volumeUpAction: String? = null
  private var volumeDownAction: String? = null
  private var isListening: Boolean = false
  private var originalCallback: Callback? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.volume_button_override/channel")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "startListening" -> {
        val args = call.arguments as? Map<String, Any>
        volumeUpAction = args?.get("volumeUpAction") as? String
        volumeDownAction = args?.get("volumeDownAction") as? String
        isListening = true
        setupKeyListener()
        result.success(true)
      }
      "stopListening" -> {
        isListening = false
        volumeUpAction = null
        volumeDownAction = null
        restoreOriginalCallback()
        result.success(true)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    context = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    restoreOriginalCallback()
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }
  
  private fun setupKeyListener() {
    val currentActivity = activity ?: return
    
    if (originalCallback == null) {
      originalCallback = currentActivity.window.callback
      
      currentActivity.window.callback = object : Window.Callback by originalCallback as Window.Callback {
        override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
          event?.let {
            if (isListening && it.action == KeyEvent.ACTION_DOWN) {
              
              when (it.keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                  volumeUpAction?.let { action ->
                    channel.invokeMethod("onVolumeButtonPressed", mapOf("action" to action))
                    return true
                  }
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                  volumeDownAction?.let { action ->
                    channel.invokeMethod("onVolumeButtonPressed", mapOf("action" to action))
                    return true
                  }
                }
              }
            }
          }
          
          return originalCallback?.dispatchKeyEvent(event) ?: false
        }
      }
    }
  }
  
  private fun restoreOriginalCallback() {
    if (originalCallback != null && activity != null) {
      activity?.window?.callback = originalCallback
      originalCallback = null
    }
  }
}
