package tw.avianjay.taiwanbus.flutter

import android.content.Context
import android.content.Intent

object AppLaunchConstants {
    const val TARGET_ROUTE_DETAIL = "route_detail"
    const val TARGET_STATION_DETAIL = "station_detail"
    const val TARGET_FAVORITES_GROUP = "favorites_group"
    const val TARGET_AUTH_CALLBACK = "auth_callback"

    private const val EXTRA_TARGET = "launch_target"
    private const val EXTRA_PROVIDER = "provider"
    private const val EXTRA_ROUTE_KEY = "route_key"
    private const val EXTRA_ROUTE_ID = "route_id"
    private const val EXTRA_PATH_ID = "path_id"
    private const val EXTRA_STOP_ID = "stop_id"
    private const val EXTRA_DESTINATION_PATH_ID = "destination_path_id"
    private const val EXTRA_DESTINATION_STOP_ID = "destination_stop_id"
    private const val EXTRA_GROUP_NAME = "group_name"
    private const val EXTRA_STATION_ID = "station_id"

    fun createRouteDetailIntent(
        context: Context,
        provider: String,
        routeKey: Int,
        routeId: String? = null,
        pathId: Int? = null,
        stopId: Long? = null,
        destinationPathId: Int? = null,
        destinationStopId: Long? = null,
    ): Intent {
        return Intent(context, MainActivity::class.java).apply {
            putExtra(EXTRA_TARGET, TARGET_ROUTE_DETAIL)
            putExtra(EXTRA_PROVIDER, provider)
            putExtra(EXTRA_ROUTE_KEY, routeKey)
            routeId?.takeIf { it.isNotBlank() }?.let { putExtra(EXTRA_ROUTE_ID, it) }
            pathId?.let { putExtra(EXTRA_PATH_ID, it) }
            stopId?.let { putExtra(EXTRA_STOP_ID, it) }
            if (destinationPathId != null) {
                putExtra(EXTRA_DESTINATION_PATH_ID, destinationPathId)
            }
            if (destinationStopId != null) {
                putExtra(EXTRA_DESTINATION_STOP_ID, destinationStopId)
            }
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
    }

    fun createStationDetailIntent(
        context: Context,
        provider: String,
        stationId: String,
    ): Intent {
        return Intent(context, MainActivity::class.java).apply {
            putExtra(EXTRA_TARGET, TARGET_STATION_DETAIL)
            putExtra(EXTRA_PROVIDER, provider)
            putExtra(EXTRA_STATION_ID, stationId)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
    }

    fun createFavoritesGroupIntent(
        context: Context,
        groupName: String,
    ): Intent {
        return Intent(context, MainActivity::class.java).apply {
            putExtra(EXTRA_TARGET, TARGET_FAVORITES_GROUP)
            putExtra(EXTRA_GROUP_NAME, groupName)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
    }

    fun extractLaunchPayload(intent: Intent?): Map<String, Any?>? {
        intent ?: return null
        extractAuthCallbackPayload(intent.data)?.let { return it }

        val target = intent.getStringExtra(EXTRA_TARGET)?.trim().orEmpty()
        if (target.isEmpty()) {
            return null
        }

        return when (target) {
            TARGET_ROUTE_DETAIL -> {
                val provider = intent.getStringExtra(EXTRA_PROVIDER) ?: return null
                val routeKey = intent.getIntExtra(EXTRA_ROUTE_KEY, Int.MIN_VALUE)
                if (routeKey == Int.MIN_VALUE) {
                    return null
                }
                val payload = mutableMapOf<String, Any?>(
                    "target" to TARGET_ROUTE_DETAIL,
                    "provider" to provider,
                    "routeKey" to routeKey,
                )
                intent.getStringExtra(EXTRA_ROUTE_ID)?.takeIf { it.isNotBlank() }
                    ?.let { payload["routeId"] = it }
                if (intent.hasExtra(EXTRA_PATH_ID)) {
                    payload["pathId"] = intent.getIntExtra(EXTRA_PATH_ID, 0)
                }
                // Stop ids are sent at full width, because Dart keys stops by
                // the raw feed id: 高雄's exceed Int, and narrowing them here
                // would name a different stop than the app's models hold. The
                // native-only fold (`foldStopId`) is for joining the live
                // feeds, not for identifying a stop to Flutter.
                stopIdExtra(intent, EXTRA_STOP_ID)?.let { payload["stopId"] = it }
                val destinationPathId = intent.getIntExtra(
                    EXTRA_DESTINATION_PATH_ID,
                    Int.MIN_VALUE,
                )
                if (destinationPathId != Int.MIN_VALUE) {
                    payload["destinationPathId"] = destinationPathId
                }
                stopIdExtra(intent, EXTRA_DESTINATION_STOP_ID)
                    ?.let { payload["destinationStopId"] = it }
                payload
            }

            TARGET_STATION_DETAIL -> {
                val provider = intent.getStringExtra(EXTRA_PROVIDER) ?: return null
                val stationId = intent.getStringExtra(EXTRA_STATION_ID)
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() }
                    ?: return null
                mapOf(
                    "target" to TARGET_STATION_DETAIL,
                    "provider" to provider,
                    "stationId" to stationId,
                )
            }

            TARGET_FAVORITES_GROUP -> {
                val groupName = intent.getStringExtra(EXTRA_GROUP_NAME) ?: return null
                mapOf(
                    "target" to TARGET_FAVORITES_GROUP,
                    "groupName" to groupName,
                )
            }

            else -> null
        }
    }

    /**
     * Reads a stop id extra as a `Long` whichever width it was stored at.
     *
     * New intents store a `Long`. Shortcuts pinned to the home screen before
     * that keep the `Int` they were created with for as long as they exist, and
     * `getLongExtra` answers its default for an extra of another type — which
     * would quietly open those shortcuts with no stop selected.
     */
    @Suppress("DEPRECATION")
    private fun stopIdExtra(intent: Intent, key: String): Long? {
        return (intent.extras?.get(key) as? Number)?.toLong()
    }

    private fun extractAuthCallbackPayload(uri: android.net.Uri?): Map<String, Any?>? {
        uri ?: return null
        if (uri.scheme?.lowercase() != "yabus" || uri.host?.lowercase() != "auth-callback") {
            return null
        }

        val payload = mutableMapOf<String, Any?>("target" to TARGET_AUTH_CALLBACK)
        for (key in listOf("token", "account_id", "device_id", "role", "provider", "display_name", "error")) {
            uri.getQueryParameter(key)?.let { payload[key] = it }
        }
        uri.fragment
            ?.split("&")
            ?.mapNotNull { part ->
                val pieces = part.split("=", limit = 2)
                if (pieces.isEmpty() || pieces[0].isBlank()) {
                    null
                } else {
                    val key = android.net.Uri.decode(pieces[0])
                    val value = android.net.Uri.decode(pieces.getOrElse(1) { "" })
                    key to value
                }
            }
            ?.forEach { (key, value) -> payload[key] = value }

        return payload
    }
}
