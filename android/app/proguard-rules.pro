# ============================================================
# Pluggo — ProGuard / R8 rules voor release build
# ============================================================

# ------- Stripe SDK (flutter_stripe) -------
# Stripe push provisioning is een optionele dependency die wij niet gebruiken
# (Apple Wallet / Google Pay kaartuitgifte). R8 valt anders om met
# "Missing class com.stripe.android.pushProvisioning.*" errors.
-dontwarn com.stripe.android.pushProvisioning.**
-keep class com.stripe.android.pushProvisioning.** { *; }

# React Native Stripe SDK proxies refereren ook naar push provisioning
-dontwarn com.reactnativestripesdk.pushprovisioning.**
-keep class com.reactnativestripesdk.pushprovisioning.** { *; }

# Algemene Stripe SDK keep — voorkomt reflectie-issues op model classes
-keep class com.stripe.android.** { *; }
-keep class com.reactnativestripesdk.** { *; }

# ------- Flutter / standaard -------
# Flutter's eigen ProGuard rules worden automatisch toegevoegd door de
# Flutter Gradle Plugin; deze file is alleen voor app-specifieke regels.
