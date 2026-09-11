package com.example.flutter_app

import android.app.Activity
import com.lagradost.api.setContext
import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.metaproviders.TmdbLink
import com.lagradost.cloudstream3.metaproviders.TmdbProvider
import com.lagradost.cloudstream3.plugins.BasePlugin
import com.lagradost.cloudstream3.plugins.Plugin
import com.lagradost.cloudstream3.utils.AppUtils.toJson
import com.lagradost.cloudstream3.utils.ExtractorLink
import com.lagradost.cloudstream3.utils.extractorApis
import dalvik.system.DexClassLoader
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.io.File
import java.lang.ref.WeakReference
import java.security.MessageDigest
import java.util.Collections
import java.util.concurrent.TimeUnit
import java.util.zip.ZipFile

/** Sources only. Repository browsing remains data-only until an explicit install. */
class CloudstreamBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "omnio/cloudstream")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val lock = Mutex()
    private val directory = File(activity.filesDir, "cloudstream").apply { mkdirs() }
    private val client = OkHttpClient.Builder().callTimeout(60, TimeUnit.SECONDS)
        .followSslRedirects(false).build()
    private data class Loaded(val plugin: BasePlugin, val apis: List<MainAPI>)
    private val loaded = mutableMapOf<String, Loaded>()

    init {
        channel.setMethodCallHandler { call, result ->
            scope.launch {
                try {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                    val value: Any? = when (call.method) {
                        "install" -> lock.withLock { install(args) }
                        "unload" -> lock.withLock { unload(key(args)); true }
                        "remove" -> lock.withLock {
                            val key = key(args)
                            unload(key)
                            File(directory, "$key.cs3").delete()
                        }
                        "sources" -> sources(args)
                        else -> throw IllegalArgumentException("Unknown Cloudstream operation")
                    }
                    withContext(Dispatchers.Main) { result.success(value) }
                } catch (error: Throwable) {
                    if (error is CancellationException) throw error
                    withContext(Dispatchers.Main) {
                        result.error("cloudstream_error", "${error.javaClass.simpleName}: ${error.message?.take(200) ?: "Plugin failed"}", null)
                    }
                }
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        scope.cancel()
        loaded.keys.toList().forEach { unload(it) }
    }

    private fun key(args: Map<String, Any?>): String = (args["key"] as? String).also {
        require(it != null && it.matches(Regex("[a-f0-9]{64}"))) { "Invalid plugin key" }
    }!!

    private fun digest(bytes: ByteArray) = MessageDigest.getInstance("SHA-256").digest(bytes)
    private fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it) }

    private fun install(args: Map<String, Any?>): Map<String, Any?> {
        val url = args["url"] as String
        require(url.startsWith("https://")) { "Plugin downloads require HTTPS" }
        val bytes = client.newCall(Request.Builder().url(url).build()).execute().use { response ->
            require(response.isSuccessful) { "Plugin download HTTP ${response.code}" }
            val body = requireNotNull(response.body)
            require(body.contentLength() <= 32L * 1024 * 1024) { "Plugin exceeds 32 MB" }
            body.byteStream().use { input ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    require(output.size() + count <= 32 * 1024 * 1024) { "Plugin exceeds 32 MB" }
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
        }
        val hash = digest(bytes)
        val expected = (args["hash"] as? String).orEmpty()
        if (expected.isNotBlank()) {
            val actual = if (expected.startsWith("sha256-"))
                "sha256-" + android.util.Base64.encodeToString(hash, android.util.Base64.NO_WRAP)
            else hex(hash)
            require(MessageDigest.isEqual(expected.toByteArray(), actual.toByteArray())) { "Plugin SHA-256 mismatch" }
        }
        val key = hex(hash)
        val file = File(directory, "$key.cs3")
        if (!file.exists()) {
            val temp = File.createTempFile("install", ".tmp", directory)
            try {
                temp.outputStream().use { output ->
                    output.write(bytes)
                }
                check(temp.setReadOnly()) { "Could not protect plugin file" }
                validate(temp)
                check(temp.renameTo(file)) { "Could not save plugin" }
            } finally { temp.delete() }
        }
        try {
            val plugin = load(key)
            val names = plugin.apis.map { it.name }
            // Installing does not implicitly enable execution for source searches.
            unload(key)
            return mapOf("key" to key, "providers" to names, "sha256" to key)
        } catch (error: Throwable) {
            unload(key)
            file.delete()
            throw error
        }
    }

    private fun validate(file: File): JSONObject = ZipFile(file).use { zip ->
        require(zip.getEntry("classes.dex") != null) { "Not a CS3 Android plugin" }
        val manifest = requireNotNull(zip.getEntry("manifest.json")) { "Missing plugin manifest" }
        require(manifest.size in 1..65536) { "Invalid plugin manifest size" }
        val json = JSONObject(zip.getInputStream(manifest).bufferedReader().readText())
        require(json.optString("pluginClassName").isNotBlank()) { "Missing plugin entry point" }
        require(!json.optBoolean("requiresResources")) { "This plugin requires Cloudstream app resources and is not compatible" }
        json
    }

    private fun load(key: String): Loaded {
        loaded[key]?.let { return it }
        setContext(WeakReference(activity))
        val file = File(directory, "$key.cs3")
        require(file.exists()) { "Plugin file missing; reinstall it" }
        val manifest = validate(file)
        val loader = DexClassLoader(file.path, activity.codeCacheDir.path, null, activity.classLoader)
        val instance = loader.loadClass(manifest.getString("pluginClassName")).getDeclaredConstructor().newInstance()
        require(instance is BasePlugin) { "Unsupported plugin API" }
        instance.filename = file.path
        try {
            if (instance is Plugin) instance.load(activity as android.content.Context) else instance.load()
            val apis = synchronized(APIHolder.allProviders) {
                APIHolder.allProviders.filter { it.sourcePlugin == file.path }
            }
            return Loaded(instance, apis).also { loaded[key] = it }
        } catch (error: Throwable) {
            clearRegistrations(file.path)
            throw error
        }
    }

    private fun clearRegistrations(path: String) {
        synchronized(APIHolder.allProviders) { APIHolder.allProviders.removeAll { it.sourcePlugin == path } }
        extractorApis.removeAll { it.sourcePlugin == path }
    }

    private fun unload(key: String) {
        try { loaded.remove(key)?.plugin?.beforeUnload() } catch (_: Throwable) { }
        clearRegistrations(File(directory, "$key.cs3").path)
    }

    private suspend fun sources(args: Map<String, Any?>): Map<String, Any?> {
        val key = key(args)
        val apis = lock.withLock { load(key).apis }
        val streams = Collections.synchronizedList(mutableListOf<Map<String, Any?>>())
        val choices = mutableListOf<Map<String, Any?>>()
        val errors = mutableListOf<String>()
        val title = args["title"] as String
        val season = (args["season"] as? Number)?.toInt()
        val episode = (args["episode"] as? Number)?.toInt()
        val isSeries = args["type"] == "tv"
        if (isSeries) require(season != null && episode != null) { "Select a specific episode first" }
        for ((index, api) in apis.withIndex()) {
            if (args["api"] != null && (args["api"] as Number).toInt() != index) continue
            try {
                withTimeout(45000) {
                    val data = if (api is TmdbProvider && args["url"] == null) {
                        TmdbLink(args["imdbId"] as? String, (args["tmdbId"] as? Number)?.toInt(), episode, season, title).toJson()
                    } else {
                        val selectedUrl = args["url"] as? String
                        if (selectedUrl == null) {
                            val matches = api.search(title, 1)?.items.orEmpty().take(20)
                            if (matches.isNotEmpty()) choices.add(mapOf(
                                "key" to key, "api" to index, "provider" to api.name,
                                "items" to matches.map { mapOf("name" to it.name, "url" to it.url, "type" to it.type?.name) }
                            ))
                            return@withTimeout
                        }
                        val detail = api.load(selectedUrl) ?: error("Provider returned no details")
                        when (detail) {
                            is MovieLoadResponse -> {
                                require(!isSeries) { "Selected result is a movie, not this episode" }
                                detail.dataUrl
                            }
                            is TvSeriesLoadResponse -> episodeData(detail.episodes, season, episode)
                            is AnimeLoadResponse -> episodeData(detail.episodes.values.flatten(), season, episode)
                            else -> error("This content type is not supported for movie/episode playback")
                        }
                    }
                    val subs = Collections.synchronizedList(mutableListOf<Map<String, String>>())
                    val links = Collections.synchronizedList(mutableListOf<ExtractorLink>())
                    try {
                        api.loadLinks(data, false, { sub ->
                            if (sub.url.startsWith("https://") || sub.url.startsWith("http://"))
                                subs.add(mapOf("name" to sub.lang, "url" to sub.url))
                        }, { link -> links.add(link) })
                    } finally {
                        synchronized(links) {
                            links.forEach { link ->
                                if (link.url.startsWith("https://") || link.url.startsWith("http://")) {
                                    streams.add(mapOf(
                                        "id" to "cs:$key:$index:${hex(digest((link.url + link.headers.toString()).toByteArray()))}",
                                        "provider" to "cloudstream", "sourceDisplayName" to "CS / ${api.name}",
                                        "title" to link.name, "description" to link.source,
                                        "quality" to if (link.quality > 0) "${link.quality}p" else "Unknown",
                                        "sizeLabel" to "", "isCached" to false, "directUrl" to link.url,
                                        "streamFormat" to link.type.name,
                                        "streamHeaders" to (mapOf("Referer" to link.referer) + link.headers),
                                        "subtitles" to synchronized(subs) { subs.toList() }
                                    ))
                                }
                            }
                        }
                    }
                }
            } catch (error: Throwable) {
                if (error is CancellationException && error !is TimeoutCancellationException) throw error
                errors.add("${api.name}: ${error.javaClass.simpleName}")
            }
        }
        return mapOf("streams" to streams.toList(), "choices" to choices, "errors" to errors)
    }

    private fun episodeData(episodes: List<Episode>, season: Int?, number: Int?): String {
        require(season != null && number != null) { "Select an episode" }
        val matches = episodes.filter { it.episode == number && it.season == season }
        require(matches.isNotEmpty()) { "Exact season/episode not supplied by this provider" }
        return matches.first().data
    }
}
