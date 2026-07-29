import Flutter
import UIKit
import GoogleMaps
import Firebase
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  // MethodChannel voor Flutter ↔ native communicatie rond notificatie-actions.
  // Wordt geinitialiseerd in didFinishLaunchingWithOptions zodra de Flutter
  // engine beschikbaar is. Zie pluggo_push_actions.dart voor de Dart-kant.
  private var pushActionsChannel: FlutterMethodChannel?

  // Buffer voor action-taps die binnenkomen VOORDAT Dart klaar is om te
  // luisteren (bv. cold start via een action-tap). We flushen deze zodra
  // de Dart-kant een "ready" ping stuurt over hetzelfde channel.
  private var pendingActionEvents: [[String: Any]] = []
  private var dartReady: Bool = false

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
    // banners netjes door iOS getoond worden (anders zwijgt iOS bij foreground)
    // én zodat we didReceive-response van action-buttons kunnen opvangen.
    UNUserNotificationCenter.current().delegate = self

    // Categorieën voor de 15-min-warning van task #292 registreren.
    // Elke non-empty subset van {15, 30, 60} krijgt een eigen category-id
    // zodat de SQL-code exact kan matchen op basis van wat conflict-vrij is.
    // Zie pluggo_push_actions.dart / migration 0029 voor de naming-conventie.
    registerBookingExtendCategories()

    // Permissie wordt vanuit Flutter gevraagd (PluggoPush.requestPermission).
    // Hier alleen registreren voor remote notifications zodat APNs token
    // beschikbaar komt zodra permissie verleend is.
    application.registerForRemoteNotifications()

    // MethodChannel opzetten. FlutterViewController komt via de root
    // view controller, die wordt door FlutterAppDelegate klaargezet.
    if let controller = window?.rootViewController as? FlutterViewController {
      wirePushActionsChannel(controller: controller)
    } else {
      // Bij implicit engine (nieuwer patroon): channel opzetten wanneer
      // engine registreert. Zie didInitializeImplicitFlutterEngine.
    }

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

  // Wordt aangeroepen wanneer de user tapt op een action-button op de
  // notification (bv. "Verleng 15 min") OF op de body van de notification.
  // We forwarden actionIdentifier + userInfo (FCM data payload) naar Dart.
  //
  // Belangrijk: firebase_messaging heeft zijn eigen delegate-hook voor
  // body-taps via `onMessageOpenedApp`. Om conflict te voorkomen, sturen
  // we ALLEEN action-taps door — body-taps laten we door de FlutterAppDelegate
  // superclass afhandelen zodat FirebaseMessaging ze doorgeeft.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let actionId = response.actionIdentifier
    let userInfo = response.notification.request.content.userInfo

    // UNNotificationDefaultActionIdentifier = tap op body (niet een action-btn)
    // UNNotificationDismissActionIdentifier = swipe-weg
    if actionId != UNNotificationDefaultActionIdentifier
       && actionId != UNNotificationDismissActionIdentifier {
      var payload: [String: Any] = [
        "action_id": actionId,
      ]
      // FCM zet data-payload onder userInfo (met eventueel google.* keys ernaast).
      // We forwarden alles dat een string is als extra context.
      for (key, value) in userInfo {
        if let keyStr = key as? String {
          if let strVal = value as? String {
            payload[keyStr] = strVal
          }
        }
      }
      sendActionToFlutter(event: payload)
      completionHandler()
      return
    }

    // Body-tap of dismiss: laat de superclass (FirebaseMessaging) afhandelen.
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Bij implicit engine gebruiken we de binaryMessenger van een registrar
    // voor het channel — geen root VC nodig. FlutterPluginRegistry heeft zelf
    // geen .messenger(); die methode zit op FlutterPluginRegistrar. We vragen
    // een registrar aan met een unieke plugin-naam en gebruiken diens messenger.
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "nl.pluggoapp.pluggo.PushActionsChannel"
    ) else {
      NSLog("AppDelegate: kon geen registrar krijgen voor push_actions channel")
      return
    }
    installPushActionsChannel(messenger: registrar.messenger())
  }

  // MARK: - Notification categories

  private func registerBookingExtendCategories() {
    // Actions voor elk minuten-aantal. We gebruiken .foreground zodat iOS
    // de app naar voren haalt bij een tap — nodig omdat de RPC-call naar
    // Supabase vanuit de Dart-runtime moet, en die is niet gegarandeerd
    // beschikbaar in background-mode. UX: de app opent kort, de RPC vuurt,
    // toast verschijnt. Voelt bijna instant en past bij een "cold start
    // via lockscreen"-flow.
    //
    // Alternatief zou een background action zijn (options: []) met een
    // native URLSession-call rechtstreeks naar Supabase — dat scheelt de
    // app-opener maar vraagt duplicatie van auth/JWT in Swift. Post-MVP.
    let a15 = UNNotificationAction(
      identifier: "EXTEND_15",
      title: "Verleng 15 min",
      options: [.foreground]
    )
    let a30 = UNNotificationAction(
      identifier: "EXTEND_30",
      title: "Verleng 30 min",
      options: [.foreground]
    )
    let a60 = UNNotificationAction(
      identifier: "EXTEND_60",
      title: "Verleng 60 min",
      options: [.foreground]
    )

    // 7 non-empty subsets van {15, 30, 60} — één category per subset.
    // Volgorde in de action-array bepaalt de visuele volgorde op het
    // lockscreen (van boven naar beneden).
    let categories: Set<UNNotificationCategory> = [
      UNNotificationCategory(
        identifier: "BOOKING_ENDING_SOON_15_30_60",
        actions: [a15, a30, a60],
        intentIdentifiers: [],
        options: []
      ),
      UNNotificationCategory(
        identifier: "BOOKING_ENDING_SOON_15_30",
        actions: [a15, a30],
        intentIdentifiers: [],
        options: []
      ),
      UNNotificationCategory(
        identifier: "BOOKING_ENDING_SOON_15_60",
        actions: [a15, a60],
        intentIdentifiers: [],
        options: []
      ),
      UNNotificationCategory(
        identifier: "BOOKING_ENDING_SOON_30_60",
        actions: [a30, a60],
        intentIdentifiers: [],
        options: []
      ),
      UNNotificationCategory(
        identifier: "BOOKING_ENDING_SOON_15",
        actions: [a15],
        intentIdentifiers: [],
        options: []
      ),
      UNNotificationCategory(
        identifier: "BOOKING_ENDING_SOON_30",
        actions: [a30],
        intentIdentifiers: [],
        options: []
      ),
      UNNotificationCategory(
        identifier: "BOOKING_ENDING_SOON_60",
        actions: [a60],
        intentIdentifiers: [],
        options: []
      ),
    ]

    UNUserNotificationCenter.current().setNotificationCategories(categories)
  }

  // MARK: - Flutter MethodChannel plumbing

  private func wirePushActionsChannel(controller: FlutterViewController) {
    installPushActionsChannel(messenger: controller.binaryMessenger)
  }

  private func installPushActionsChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "pluggo/push_actions",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "ready":
        // Dart is klaar om events te ontvangen — flush pending queue.
        self.dartReady = true
        for pending in self.pendingActionEvents {
          channel.invokeMethod("onAction", arguments: pending)
        }
        self.pendingActionEvents.removeAll()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.pushActionsChannel = channel
  }

  private func sendActionToFlutter(event: [String: Any]) {
    if dartReady, let ch = pushActionsChannel {
      ch.invokeMethod("onAction", arguments: event)
    } else {
      // Nog niet klaar (cold start via action-tap) — bufferen.
      pendingActionEvents.append(event)
    }
  }
}
