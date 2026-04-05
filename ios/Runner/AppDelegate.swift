import Flutter
import UIKit
import flutter_compass
import geolocator_apple
import maplibre_ios
import package_info_plus
import pointer_interceptor_ios
import shared_preferences_foundation
import url_launcher_ios

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let registry = controller as FlutterPluginRegistry
    FlutterCompassPlugin.register(with: registry.registrar(forPlugin: "FlutterCompassPlugin")!)
    GeolocatorPlugin.register(with: registry.registrar(forPlugin: "GeolocatorPlugin")!)
    MapLibrePlugin.register(with: registry.registrar(forPlugin: "MapLibrePlugin")!)
    FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin")!)
    PointerInterceptorIosPlugin.register(with: registry.registrar(forPlugin: "PointerInterceptorIosPlugin")!)
    SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin")!)
    URLLauncherPlugin.register(with: registry.registrar(forPlugin: "URLLauncherPlugin")!)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
