// App Attest with a DeviceCheck fallback, behind the flutter_starter/attestation
// channel. Copy to ios/Runner/ and add it to the Runner target in Xcode.
// App Attest needs iOS 14+, a real device, and an App Attest-enabled App ID.
// The template deploys to iOS 13, so every App Attest call is availability-gated
// and falls back to DeviceCheck (iOS 11+).

import CryptoKit
import DeviceCheck
import Flutter
import UIKit

public class AttestationPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flutter_starter/attestation",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(AttestationPlugin(), channel: channel)
  }

  // True only on iOS 14+ with App Attest available for this App ID.
  private var appAttestSupported: Bool {
    if #available(iOS 14.0, *) {
      return DCAppAttestService.shared.isSupported
    }
    return false
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "warmUp":
      result(appAttestSupported || DCDevice.current.isSupported)
    case "attestKey":
      attestKey(challenge: args["challenge"] as? String ?? "", result: result)
    case "getToken":
      getToken(
        requestHash: args["requestHash"] as? String ?? "",
        keyId: args["keyId"] as? String,
        result: result
      )
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // One-time per install. Apple throttles key generation, so never call it in a loop.
  private func attestKey(challenge: String, result: @escaping FlutterResult) {
    guard #available(iOS 14.0, *), appAttestSupported else {
      result(FlutterError(code: "unsupported", message: "App Attest unavailable", details: nil))
      return
    }
    let service = DCAppAttestService.shared
    service.generateKey { keyId, error in
      guard let keyId = keyId else {
        result(
          FlutterError(
            code: "generate_key_failed", message: error?.localizedDescription, details: nil))
        return
      }
      let clientDataHash = Data(SHA256.hash(data: Data(challenge.utf8)))
      service.attestKey(keyId, clientDataHash: clientDataHash) { attestation, error in
        guard let attestation = attestation else {
          result(
            FlutterError(code: "attest_failed", message: error?.localizedDescription, details: nil))
          return
        }
        result(["keyId": keyId, "attestationObject": attestation.base64EncodedString()])
      }
    }
  }

  // Assertions are cheap; DeviceCheck is the fallback when no key is registered.
  private func getToken(requestHash: String, keyId: String?, result: @escaping FlutterResult) {
    let clientDataHash = Data(SHA256.hash(data: Data(requestHash.utf8)))

    if #available(iOS 14.0, *), appAttestSupported, let keyId = keyId, !keyId.isEmpty {
      DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: clientDataHash) {
        assertion, error in
        guard let assertion = assertion else {
          result(
            FlutterError(
              code: "assertion_failed", message: error?.localizedDescription, details: nil))
          return
        }
        result([
          "kind": "appAttestAssertion",
          "token": assertion.base64EncodedString(),
          "keyId": keyId,
        ])
      }
      return
    }

    guard DCDevice.current.isSupported else {
      result(FlutterError(code: "unsupported", message: "DeviceCheck unavailable", details: nil))
      return
    }
    DCDevice.current.generateToken { token, error in
      guard let token = token else {
        result(
          FlutterError(code: "devicecheck_failed", message: error?.localizedDescription, details: nil)
        )
        return
      }
      result(["kind": "deviceCheck", "token": token.base64EncodedString()])
    }
  }
}
