// Play Integrity standard request behind the flutter_starter/attestation channel.
// Copy to android/app/src/main/kotlin/<your/package>/ and fix the package line.
// Requires: implementation("com.google.android.play:integrity:1.5.0")

package com.easital.starter

import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityManager.PrepareIntegrityTokenRequest
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenProvider
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AttestationPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var tokenProvider: StandardIntegrityTokenProvider? = null
    private var binding: FlutterPlugin.FlutterPluginBinding? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        binding = flutterPluginBinding
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_starter/attestation")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        binding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Cloud project number comes from .env via Dart; it is not a secret.
            "warmUp" -> warmUp(call.argument<String>("cloudProjectNumber")?.toLongOrNull() ?: 0L, result)
            // iOS-only; succeed with null so shared Dart code stays simple.
            "attestKey" -> result.success(null)
            "getToken" -> getToken(call.argument<String>("requestHash").orEmpty(), result)
            else -> result.notImplemented()
        }
    }

    // prepareIntegrityToken is the expensive call. Do it once, reuse the provider.
    private fun warmUp(cloudProjectNumber: Long, result: MethodChannel.Result) {
        val context = binding?.applicationContext
        if (context == null || cloudProjectNumber == 0L) {
            result.success(false)
            return
        }
        if (tokenProvider != null) {
            result.success(true)
            return
        }
        IntegrityManagerFactory.createStandard(context)
            .prepareIntegrityToken(
                PrepareIntegrityTokenRequest.builder()
                    .setCloudProjectNumber(cloudProjectNumber)
                    .build()
            )
            .addOnSuccessListener { provider ->
                tokenProvider = provider
                result.success(true)
            }
            .addOnFailureListener { result.success(false) }
    }

    private fun getToken(requestHash: String, result: MethodChannel.Result) {
        val provider = tokenProvider
        if (provider == null) {
            result.error("not_warm", "prepareIntegrityToken has not completed", null)
            return
        }
        provider.request(
            StandardIntegrityTokenRequest.builder()
                .setRequestHash(requestHash)
                .build()
        )
            .addOnSuccessListener { token ->
                result.success(mapOf("kind" to "playIntegrity", "token" to token.token()))
            }
            .addOnFailureListener { e ->
                result.error("integrity_failed", e.message, null)
            }
    }
}
