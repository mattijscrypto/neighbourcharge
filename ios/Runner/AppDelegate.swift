import Flutter
import UIKit
import GoogleMaps
import Firebase
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyCLt4pD18cnyedvZnLD6f7XEfRkIy4Dtio")

    // Firebase moet eerst geconfigureerd worden voor messaging werkt.
    // De GoogleService-Info.plist in Runner regelt project-id en API key.
    //
    // Guard tegen dubbele configure(): sinds we de scene manifest hebben
    // verwijderd (voor flutter_stripe PaymentSheet compatibility), wordt
    // didFinishLaunchingWithOptions soms twee keer geraakt via de
    // FlutterImplicitEngineDelegate-pad. FirebaseApp.configure() gooit dan
    // 'com.firebase.core: Default app has already been configured' bij de
    // tweede call. Een simpele nil-check voorkomt de crash en is idempotent.
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    // UNUserNotificationCenter delegate aan onszelf hangen zodat foreground
    // banners netjes door iOS getoond worden (anders zwijgt iOS bij foreground).
    UNUserNotificationCenter.current().delegate = self

    // Permissie wordt vanuit Flutter gevraagd (PluggoPush.requestPermission).
    // Hier alleen registreren voor remote notifications zodat APNs token
    // beschikbaar komt zodra permissie verleend is.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // APNs koppelt het device token aan FCM. Zonder deze hook krijgt
  // FirebaseMessaging.getToken() op iOS een lege/nil response.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // Foreground presentation: zorg dat iOS de banner toont ook als app open is.
  // We gebruiken .alert i.p.v. .banner zodat dit werkt op iOS 13 en lager
  // (.banner werd pas in iOS 14 toegevoegd). Functioneel identiek.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .sound, .badge])
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
