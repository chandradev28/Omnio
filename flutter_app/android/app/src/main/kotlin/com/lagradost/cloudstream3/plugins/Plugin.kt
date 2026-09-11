package com.lagradost.cloudstream3.plugins

import android.app.Activity
import android.content.Context
import android.content.res.Resources

/** Android entry point for CS3 plugins; the published library supplies BasePlugin. */
abstract class Plugin : BasePlugin() {
    var resources: Resources? = null
    var openSettings: ((Context) -> Unit)? = null
    open fun load(context: Context) { load(context as? Activity) }
    open fun load(activity: Activity?) { load() }
}
