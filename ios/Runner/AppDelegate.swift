import Flutter
import UIKit
import StoreKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private var entitlementChannel: FlutterMethodChannel?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PocoEntitlements") else { return }
    let channel = FlutterMethodChannel(
      name: "com.mizoishun.pocopoco/entitlements", binaryMessenger: registrar.messenger())
    entitlementChannel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "current" || call.method == "restore" else {
        result(FlutterMethodNotImplemented)
        return
      }
      Task { @MainActor in
        do {
          // 明示的な「復元」だけが認証を伴う同期を行う。起動時はローカルの検証済み利用権。
          if call.method == "restore" { try await AppStore.sync() }
          let productIDs: Set<String> = ["yearly_sub", "monthly_sub", "monthly-sub"]
          var current: StoreKit.Transaction?
          for await verification in StoreKit.Transaction.currentEntitlements {
            switch verification {
            case .verified(let transaction):
              guard productIDs.contains(transaction.productID),
                    transaction.revocationDate == nil, !transaction.isUpgraded else { continue }
              if current == nil || transaction.purchaseDate > current!.purchaseDate {
                current = transaction
              }
            case .unverified(let transaction, _):
              if productIDs.contains(transaction.productID) {
                throw NSError(domain: "PocoEntitlements", code: 1,
                  userInfo: [NSLocalizedDescriptionKey: "Purchase verification failed"])
              }
            }
          }
          // currentEntitlementsは有効な契約と猶予期間の利用権を返す。
          // 解約予約だけでは権利を剥奪せず、期限切れ・返金・失効はストアの結果に従う。
          if let transaction = current {
            var value: [String: Any] = ["active": true, "productId": transaction.productID]
            if let expiration = transaction.expirationDate {
              value["expiresAt"] = Int64(expiration.timeIntervalSince1970 * 1000)
            }
            result(value)
          } else {
            result(["active": false])
          }
        } catch {
          result(FlutterError(code: "store_entitlement_failed",
            message: error.localizedDescription, details: nil))
        }
      }
    }
  }
}
