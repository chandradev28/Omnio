package com.example.flutter_app

import android.content.Context
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.FrameLayout
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import `is`.xyz.mpv.BaseMPVView
import `is`.xyz.mpv.MPVLib
import `is`.xyz.mpv.Utils
import java.io.File
import java.util.Locale

private const val NATIVE_PLAYER_VIEW_TYPE = "omnio/native_player"

class OmnioNativePlayerFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(
        context: Context,
        viewId: Int,
        args: Any?,
    ): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = (args as? Map<*, *>)
            ?.entries
            ?.associate { it.key.toString() to it.value }
            ?: emptyMap()
        return OmnioNativePlayerPlatformView(context, messenger, params)
    }
}

class OmnioNativePlayerPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    params: Map<String, Any?>,
) : PlatformView {
    private val playerView = OmnioNativePlayerView(context, params)
    private val channelName = "omnio/native_player/${params["instanceKey"]}"
    private val channel = MethodChannel(messenger, channelName)

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                result.success(playerView.handle(call))
            } catch (error: Throwable) {
                result.error(
                    "native_player_error",
                    error.message ?: error.javaClass.simpleName,
                    null,
                )
            }
        }
        playerView.start()
    }

    override fun getView(): View = playerView

    override fun dispose() {
        channel.setMethodCallHandler(null)
        playerView.release()
    }
}

@androidx.annotation.OptIn(UnstableApi::class)
private class OmnioNativePlayerView(
    context: Context,
    private val params: Map<String, Any?>,
) : FrameLayout(context) {
    private var exoPlayer: ExoPlayer? = null
    private var exoView: PlayerView? = null
    private var mpvView: OmnioMpvSurfaceView? = null
    private var currentUrl: String? = null
    private var currentHeaders: Map<String, String> = emptyMap()
    private var currentFormat: String? = null
    private var currentSubtitles: List<Map<String, String>> = emptyList()
    private var currentEngine = "media3"
    private var requestedEngine = params["engine"]?.toString()?.lowercase(Locale.US) ?: "auto"
    private var autoplay = params["autoplay"] as? Boolean ?: true
    private var released = false
    private var errorMessage: String? = null

    init {
        setBackgroundColor(Color.BLACK)
        clipChildren = true
        clipToPadding = true
    }

    fun start() {
        if (released || currentUrl != null) return
        val url = params["url"]?.toString()?.trim().orEmpty()
        if (url.isBlank()) {
            errorMessage = "No stream URL was provided."
            return
        }
        currentUrl = url
        currentHeaders = stringMap(params["headers"])
        currentFormat = params["format"]?.toString()
        currentSubtitles = subtitleList(params["sourceSubtitles"])
        val startPositionMs = (params["startPositionMs"] as? Number)?.toLong() ?: 0L
        if (requestedEngine == "mpv") {
            startMpv(startPositionMs)
        } else {
            startMedia3(startPositionMs)
        }
    }

    fun handle(call: MethodCall): Any? {
        return when (call.method) {
            "start" -> {
                start()
                null
            }
            "snapshot" -> snapshot()
            "tracks" -> tracks()
            "play" -> {
                exoPlayer?.play()
                mpvView?.setPaused(false)
                null
            }
            "pause" -> {
                exoPlayer?.pause()
                mpvView?.setPaused(true)
                null
            }
            "toggle" -> {
                if (isPlaying()) {
                    exoPlayer?.pause()
                    mpvView?.setPaused(true)
                } else {
                    exoPlayer?.play()
                    mpvView?.setPaused(false)
                }
                null
            }
            "seekTo" -> {
                seekTo((call.argument<Number>("positionMs")?.toLong() ?: 0L))
                null
            }
            "seekBy" -> {
                seekTo(positionMs() + (call.argument<Number>("offsetMs")?.toLong() ?: 0L))
                null
            }
            "setSpeed" -> {
                val speed = call.argument<Number>("speed")?.toFloat() ?: 1f
                exoPlayer?.setPlaybackSpeed(speed)
                mpvView?.setPlaybackSpeed(speed)
                null
            }
            "selectTrack" -> {
                selectTrack(call.argument<Number>("index")?.toInt() ?: -1)
                null
            }
            "disableSubtitles" -> {
                exoPlayer?.trackSelectionParameters = exoPlayer?.trackSelectionParameters
                    ?.buildUpon()
                    ?.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
                    ?.build()
                mpvView?.selectSubtitle(-1)
                null
            }
            "addSubtitle" -> {
                val url = call.argument<String>("url")
                if (!url.isNullOrBlank()) addSubtitle(url, call.argument<String>("name"))
                null
            }
            "switchEngine" -> {
                requestedEngine = if (currentEngine == "mpv") "media3" else "mpv"
                if (requestedEngine == "mpv") startMpv(positionMs()) else startMedia3(positionMs())
                null
            }
            "retry" -> {
                val position = positionMs()
                if (currentEngine == "mpv") startMpv(position) else startMedia3(position)
                null
            }
            "release" -> {
                release()
                null
            }
            else -> throw IllegalArgumentException("Unknown native player method: ${call.method}")
        }
    }

    private fun startMedia3(startPositionMs: Long) {
        val url = currentUrl ?: return
        try {
            releaseMpv()
            releaseMedia3()
            errorMessage = null
            currentEngine = "media3"

            val httpFactory = DefaultHttpDataSource.Factory()
                .setAllowCrossProtocolRedirects(false)
                .setDefaultRequestProperties(currentHeaders)
            val dataSourceFactory = DefaultDataSource.Factory(context, httpFactory)
            val trackSelector = DefaultTrackSelector(context)
            val loadControl = DefaultLoadControl.Builder()
                .setBufferDurationsMs(15_000, 70_000, 1_500, 5_000)
                .build()
            val mediaSourceFactory = androidx.media3.exoplayer.source.DefaultMediaSourceFactory(dataSourceFactory)
            val player = ExoPlayer.Builder(context)
                .setTrackSelector(trackSelector)
                .setLoadControl(loadControl)
                .setMediaSourceFactory(mediaSourceFactory)
                .build()
            player.addListener(object : Player.Listener {
                override fun onPlayerError(error: PlaybackException) {
                    if (requestedEngine == "auto" && currentEngine == "media3") {
                        startMpv(player.currentPosition)
                    } else {
                        errorMessage = error.localizedMessage ?: "Media3 could not play this stream."
                    }
                }

                override fun onPlaybackStateChanged(playbackState: Int) {
                    if (playbackState == Player.STATE_READY) errorMessage = null
                }
            })
            val item = mediaItem(url, currentFormat, currentSubtitles)
            player.setMediaItem(item)
            player.prepare()
            if (startPositionMs > 0) player.seekTo(startPositionMs)
            player.playWhenReady = autoplay
            exoPlayer = player
            showExoPlayer(player)
        } catch (error: Throwable) {
            if (requestedEngine == "auto") startMpv(startPositionMs)
            else errorMessage = error.message ?: "Media3 could not start."
        }
    }

    private fun startMpv(startPositionMs: Long) {
        val url = currentUrl ?: return
        try {
            releaseMedia3()
            releaseMpv()
            errorMessage = null
            currentEngine = "mpv"
            val view = OmnioMpvSurfaceView(context)
            mpvView = view
            addView(view, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
            view.initializePlayer()
            view.setMedia(url, currentHeaders, startPositionMs)
            view.setPaused(!autoplay)
            showMpv(view)
        } catch (error: Throwable) {
            errorMessage = error.message ?: "mpv could not start."
        }
    }

    private fun mediaItem(
        url: String,
        format: String?,
        subtitles: List<Map<String, String>>,
    ): MediaItem {
        val builder = MediaItem.Builder().setUri(toUri(url))
        when (format?.uppercase(Locale.US)) {
            "M3U8", "HLS" -> builder.setMimeType(MimeTypes.APPLICATION_M3U8)
            "DASH", "MPD" -> builder.setMimeType(MimeTypes.APPLICATION_MPD)
        }
        builder.setSubtitleConfigurations(
            subtitles.mapNotNull { subtitle ->
                val subtitleUrl = subtitle["url"]?.trim().orEmpty()
                if (subtitleUrl.isBlank()) return@mapNotNull null
                MediaItem.SubtitleConfiguration.Builder(toUri(subtitleUrl))
                    .setMimeType(subtitleMime(subtitleUrl))
                    .setLanguage(subtitle["lang"] ?: subtitle["name"])
                    .setSelectionFlags(0)
                    .build()
            },
        )
        return builder.build()
    }

    private fun addSubtitle(url: String, name: String?) {
        if (currentEngine == "mpv") {
            mpvView?.addSubtitle(url)
            return
        }
        val player = exoPlayer ?: return
        val item = player.currentMediaItem ?: return
        val subtitles = item.localConfiguration?.subtitleConfigurations.orEmpty().toMutableList()
        subtitles.add(
            MediaItem.SubtitleConfiguration.Builder(toUri(url))
                .setMimeType(subtitleMime(url))
                .setLanguage(name)
                .setSelectionFlags(C.SELECTION_FLAG_DEFAULT)
                .build(),
        )
        val wasPlaying = player.isPlaying
        player.setMediaItem(item.buildUpon().setSubtitleConfigurations(subtitles).build(), player.currentPosition)
        player.prepare()
        player.playWhenReady = wasPlaying
    }

    private fun tracks(): List<Map<String, Any?>> {
        if (currentEngine == "mpv") return mpvView?.tracks().orEmpty()
        val player = exoPlayer ?: return emptyList()
        val output = mutableListOf<Map<String, Any?>>()
        var index = 0
        player.currentTracks.groups.forEachIndexed { groupIndex, group ->
            val type = when (group.type) {
                C.TRACK_TYPE_AUDIO -> "audio"
                C.TRACK_TYPE_TEXT -> "subtitle"
                else -> null
            } ?: return@forEachIndexed
            for (trackIndex in 0 until group.length) {
                val format = group.getTrackFormat(trackIndex)
                output += mapOf(
                    "index" to index++,
                    "type" to type,
                    "selected" to group.isTrackSelected(trackIndex),
                    "metadata" to mapOf(
                        "title" to (format.label ?: format.language ?: "$type track"),
                        "language" to (format.language ?: ""),
                        "codec" to (format.sampleMimeType ?: format.codecs ?: ""),
                        "forced" to ((format.selectionFlags and C.SELECTION_FLAG_FORCED) != 0),
                    ),
                    "group" to groupIndex,
                    "track" to trackIndex,
                )
            }
        }
        return output
    }

    private fun selectTrack(index: Int) {
        if (index < 0) return
        if (currentEngine == "mpv") {
            mpvView?.selectTrack(index)
            return
        }
        val player = exoPlayer ?: return
        var nextIndex = 0
        player.currentTracks.groups.forEach { group ->
            val type = group.type
            if (type != C.TRACK_TYPE_AUDIO && type != C.TRACK_TYPE_TEXT) return@forEach
            for (trackIndex in 0 until group.length) {
                if (nextIndex == index) {
                    player.trackSelectionParameters = player.trackSelectionParameters
                        .buildUpon()
                        .setTrackTypeDisabled(type, false)
                        .clearOverridesOfType(type)
                        .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, listOf(trackIndex)))
                        .build()
                    return
                }
                nextIndex += 1
            }
        }
    }

    private fun snapshot(): Map<String, Any?> {
        val player = exoPlayer
        val mpv = mpvView
        val duration = when {
            player != null && player.duration > 0 -> player.duration
            mpv != null -> mpv.durationMs()
            else -> 0L
        }
        val position = when {
            player != null -> player.currentPosition.coerceAtLeast(0L)
            mpv != null -> mpv.positionMs()
            else -> 0L
        }
        val isPlaying = player?.isPlaying ?: mpv?.isPlayingNow() ?: false
        val isBuffering = player?.playbackState == Player.STATE_BUFFERING ||
            mpv?.isPausedForCacheNow() == true ||
            (mpv != null && mpv.isCoreIdleNow() && !mpv.isEofReached())
        val isCompleted = player?.playbackState == Player.STATE_ENDED || mpv?.isEofReached() == true
        val ready = player?.playbackState == Player.STATE_READY || mpv?.hasVideoTrackSelectedNow() == true
        return mapOf(
            "positionMs" to position,
            "durationMs" to duration,
            "isPlaying" to isPlaying,
            "isBuffering" to isBuffering,
            "isCompleted" to isCompleted,
            "isReady" to ready,
            "speed" to (player?.playbackParameters?.speed ?: mpv?.speed() ?: 1f),
            "engine" to currentEngine,
            "error" to errorMessage,
        )
    }

    private fun positionMs(): Long {
        return exoPlayer?.currentPosition?.coerceAtLeast(0L) ?: mpvView?.positionMs() ?: 0L
    }

    private fun seekTo(position: Long) {
        val target = position.coerceAtLeast(0L)
        exoPlayer?.seekTo(target)
        mpvView?.seekToMs(target)
    }

    private fun isPlaying(): Boolean = exoPlayer?.isPlaying ?: mpvView?.isPlayingNow() ?: false

    private fun showExoPlayer(player: ExoPlayer) {
        val view = exoView ?: PlayerView(context).also {
            it.useController = false
            it.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
            it.setShutterBackgroundColor(Color.BLACK)
            exoView = it
            addView(it, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        }
        view.player = player
        view.visibility = VISIBLE
        mpvView?.visibility = GONE
    }

    private fun showMpv(view: OmnioMpvSurfaceView) {
        exoView?.visibility = GONE
        view.visibility = VISIBLE
    }

    private fun releaseMedia3() {
        exoView?.player = null
        exoPlayer?.release()
        exoPlayer = null
    }

    private fun releaseMpv() {
        mpvView?.destroyPlayer()
        mpvView?.let { removeView(it) }
        mpvView = null
    }

    fun release() {
        if (released) return
        released = true
        releaseMedia3()
        releaseMpv()
    }

    private fun toUri(value: String): Uri {
        return if (value.contains("://")) Uri.parse(value) else Uri.fromFile(File(value))
    }

    private fun subtitleMime(value: String): String {
        return when (value.substringBefore('?').substringAfterLast('.').lowercase(Locale.US)) {
            "vtt", "webvtt" -> MimeTypes.TEXT_VTT
            "ass", "ssa" -> MimeTypes.TEXT_SSA
            else -> MimeTypes.APPLICATION_SUBRIP
        }
    }

    private fun stringMap(value: Any?): Map<String, String> {
        return (value as? Map<*, *>)?.mapNotNull { (key, item) ->
            val name = key?.toString()?.trim().orEmpty()
            val content = item?.toString()?.trim().orEmpty()
            if (name.isBlank() || content.isBlank()) null else name to content
        }?.toMap().orEmpty()
    }

    private fun subtitleList(value: Any?): List<Map<String, String>> {
        return (value as? List<*>)?.mapNotNull { item ->
            val map = stringMap(item)
            map.takeIf { it["url"].orEmpty().isNotBlank() }
        }.orEmpty()
    }
}

private class OmnioMpvSurfaceView(context: Context) : BaseMPVView(context, null) {
    private var initialized = false

    fun initializePlayer() {
        if (initialized) return
        runCatching { Utils.copyAssets(context) }
        initialize(context.filesDir.path, context.cacheDir.path)
        initialized = true
    }

    override fun initOptions() {
        setVo("gpu")
        MPVLib.setOptionString("gpu-context", "android")
        MPVLib.setOptionString("hwdec", "auto-safe")
        MPVLib.setOptionString("profile", "fast")
        MPVLib.setOptionString("sub-auto", "fuzzy")
        MPVLib.setOptionString("keep-open", "yes")
        MPVLib.setOptionString("audio-file-auto", "no")
    }

    override fun postInitOptions() = Unit

    override fun observeProperties() = Unit

    fun setMedia(url: String, headers: Map<String, String>, startPositionMs: Long) {
        applyHeaders(headers)
        if (holder.surface?.isValid == true) {
            MPVLib.command(arrayOf("loadfile", url, "replace"))
        } else {
            playFile(url)
        }
        if (startPositionMs > 0) {
            postDelayed({ MPVLib.setPropertyDouble("time-pos", startPositionMs / 1000.0) }, 700)
        }
    }

    fun setPaused(paused: Boolean) {
        if (initialized) MPVLib.setPropertyBoolean("pause", paused)
    }

    fun isPlayingNow(): Boolean = initialized && MPVLib.getPropertyBoolean("pause") == false

    fun isPausedForCacheNow(): Boolean = initialized && MPVLib.getPropertyBoolean("paused-for-cache") == true

    fun isCoreIdleNow(): Boolean = initialized && MPVLib.getPropertyBoolean("core-idle") == true

    fun isEofReached(): Boolean = initialized && MPVLib.getPropertyBoolean("eof-reached") == true

    fun hasVideoTrackSelectedNow(): Boolean {
        if (!initialized) return false
        val video = MPVLib.getPropertyString("vid")
        return !video.isNullOrBlank() && !video.equals("no", ignoreCase = true)
    }

    fun positionMs(): Long {
        if (!initialized) return 0L
        val seconds = MPVLib.getPropertyDouble("time-pos/full")
            ?: MPVLib.getPropertyDouble("time-pos")
            ?: 0.0
        return (seconds * 1000).toLong().coerceAtLeast(0L)
    }

    fun durationMs(): Long {
        if (!initialized) return 0L
        val seconds = MPVLib.getPropertyDouble("duration/full") ?: 0.0
        return (seconds * 1000).toLong().coerceAtLeast(0L)
    }

    fun speed(): Float = MPVLib.getPropertyDouble("speed")?.toFloat() ?: 1f

    fun seekToMs(positionMs: Long) {
        if (initialized) MPVLib.setPropertyDouble("time-pos", positionMs.coerceAtLeast(0L) / 1000.0)
    }

    fun setPlaybackSpeed(speed: Float) {
        if (initialized) MPVLib.setPropertyDouble("speed", speed.toDouble())
    }

    fun addSubtitle(url: String) {
        if (initialized) MPVLib.command(arrayOf("sub-add", url, "select"))
    }

    fun selectSubtitle(index: Int) {
        if (!initialized) return
        if (index < 0) {
            MPVLib.setPropertyString("sid", "no")
            return
        }
        trackByIndex("sub", index)?.let { MPVLib.setPropertyString("sid", it.toString()) }
    }

    fun selectTrack(index: Int) {
        if (!initialized) return
        val tracks = tracks()
        val track = tracks.firstOrNull { it["index"] == index } ?: return
        val id = track["id"] ?: return
        if (track["type"] == "audio") MPVLib.setPropertyString("aid", id.toString())
        if (track["type"] == "subtitle") MPVLib.setPropertyString("sid", id.toString())
    }

    fun tracks(): List<Map<String, Any?>> {
        if (!initialized) return emptyList()
        val count = MPVLib.getPropertyInt("track-list/count") ?: 0
        val output = mutableListOf<Map<String, Any?>>()
        for (index in 0 until count) {
            val type = MPVLib.getPropertyString("track-list/$index/type") ?: continue
            val normalized = when (type) {
                "audio" -> "audio"
                "sub" -> "subtitle"
                else -> continue
            }
            val id = MPVLib.getPropertyInt("track-list/$index/id") ?: continue
            output += mapOf(
                "index" to output.size,
                "type" to normalized,
                "selected" to (MPVLib.getPropertyBoolean("track-list/$index/selected") == true),
                "id" to id,
                "metadata" to mapOf(
                    "title" to (MPVLib.getPropertyString("track-list/$index/title")
                        ?: MPVLib.getPropertyString("track-list/$index/lang")
                        ?: "$normalized track"),
                    "language" to (MPVLib.getPropertyString("track-list/$index/lang") ?: ""),
                    "codec" to (MPVLib.getPropertyString("track-list/$index/codec") ?: ""),
                ),
            )
        }
        return output
    }

    private fun trackByIndex(type: String, targetIndex: Int): Int? {
        val count = MPVLib.getPropertyInt("track-list/count") ?: 0
        var index = 0
        for (track in 0 until count) {
            if (MPVLib.getPropertyString("track-list/$track/type") != type) continue
            if (index == targetIndex) return MPVLib.getPropertyInt("track-list/$track/id")
            index += 1
        }
        return null
    }

    private fun applyHeaders(headers: Map<String, String>) {
        val fields = headers.filterKeys { !it.equals("Referer", true) }
            .map { "${it.key}: ${it.value}" }
            .joinToString(",")
        MPVLib.setOptionString("http-header-fields", fields)
        headers.entries.firstOrNull { it.key.equals("Referer", true) }
            ?.value
            ?.let { MPVLib.setOptionString("http-referrer", it) }
    }

    fun destroyPlayer() {
        if (!initialized) return
        initialized = false
        destroy()
    }
}
