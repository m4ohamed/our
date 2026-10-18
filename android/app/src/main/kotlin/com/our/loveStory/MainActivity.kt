package com.our.loveStory

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.net.Uri
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.opengl.GLUtils
import android.opengl.Matrix
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.view.Surface
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.concurrent.Executors
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.tanh

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.our.loveStory/media_bridge"
    private val pickAudioRequestCode = 9041
    private var pendingAudioResult: MethodChannel.Result? = null

    // خيط مخصص وثابت لجميع عمليات جلسة EGL المباشرة لضمان ارتباط EGLContext بنفس الخيط دائماً
    private val eglSessionExecutor = Executors.newSingleThreadExecutor()
    private var activeRgbaSession: RgbaStreamEncoder? = null

    private class EncodedPacket(
        val data: ByteArray,
        val presentationTimeUs: Long,
        val flags: Int
    )

    private class AviFrameLocation(
        val offset: Long,
        val size: Int
    )

    companion object {
        private val PNG_MAGIC = byteArrayOf(
            0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
        )
    }

    override fun onDestroy() {
        try {
            eglSessionExecutor.execute {
                try {
                    activeRgbaSession?.abort()
                } catch (_: Exception) {}
                activeRgbaSession = null
            }
            eglSessionExecutor.shutdown()
        } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "queryEncoderCapabilities" -> {
                        Thread {
                            try {
                                val caps = queryDeviceEncoderCapabilities()
                                runOnUiThread { result.success(caps) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("CAPABILITY_QUERY_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    }

                    "decodeAudioToPcmFile" -> {
                        val audioPath = call.argument<String>("audioPath")
                        val outputPcmPath = call.argument<String>("outputPcmPath")
                        val startOffsetMs = (call.argument<Number>("startOffsetMs")?.toLong() ?: 0L)
                        val durationMs = (call.argument<Number>("durationMs")?.toLong() ?: 5000L)
                        val loopIfShorter = call.argument<Boolean>("loopIfShorter") ?: true

                        if (audioPath.isNullOrBlank() || outputPcmPath.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing audioPath or outputPcmPath", null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            try {
                                val info = decodeAudioFileToRawPcm16(
                                    audioPath = audioPath,
                                    startOffsetUs = startOffsetMs * 1000L,
                                    totalDurationUs = durationMs * 1000L,
                                    loopIfShorter = loopIfShorter
                                )
                                if (info == null) {
                                    runOnUiThread { result.success(null) }
                                } else {
                                    val stereoBytes = if (info.third == 1) {
                                        monoPcm16ToStereo(info.first)
                                    } else {
                                        info.first
                                    }
                                    val outFile = File(outputPcmPath)
                                    outFile.writeBytes(stereoBytes)
                                    runOnUiThread {
                                        result.success(
                                            mapOf(
                                                "pcmPath" to outFile.absolutePath,
                                                "sampleRate" to info.second,
                                                "channels" to 2
                                            )
                                        )
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("AUDIO_DECODE_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    }

                    "startDirectMp4EncodeSession" -> {
                        val outputMp4Path = call.argument<String>("outputMp4Path")
                        val processedPcmPath = call.argument<String>("processedPcmPath")
                        val audioPath = call.argument<String>("audioPath")
                        val pcmSampleRate = (call.argument<Number>("pcmSampleRate")?.toInt() ?: 44100)
                        val pcmChannels = (call.argument<Number>("pcmChannels")?.toInt() ?: 2)
                        val fps = (call.argument<Number>("fps")?.toInt() ?: 30).coerceIn(15, 60)
                        val rawWidth = (call.argument<Number>("width")?.toInt() ?: 1080)
                        val rawHeight = (call.argument<Number>("height")?.toInt() ?: 1920)
                        val codecMime = call.argument<String>("codecMime") ?: MediaFormat.MIMETYPE_VIDEO_AVC
                        val bitrateBps = (call.argument<Number>("bitrateBps")?.toInt() ?: 14_000_000)
                            .coerceIn(2_000_000, 24_000_000)
                        val cropToFill = call.argument<Boolean>("cropToFill") ?: false

                        if (outputMp4Path.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing outputMp4Path", null)
                            return@setMethodCallHandler
                        }

                        eglSessionExecutor.execute {
                            try {
                                activeRgbaSession?.abort()
                                activeRgbaSession = null

                                val session = RgbaStreamEncoder(
                                    outputMp4File = File(outputMp4Path),
                                    requestedWidth = rawWidth,
                                    requestedHeight = rawHeight,
                                    targetFps = fps,
                                    requestedCodecMime = codecMime,
                                    bitrateBps = bitrateBps,
                                    processedPcmPath = processedPcmPath,
                                    audioPath = audioPath,
                                    pcmSampleRate = pcmSampleRate,
                                    pcmChannels = pcmChannels,
                                    cropToFill = cropToFill
                                )
                                session.start()
                                activeRgbaSession = session
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                activeRgbaSession?.abort()
                                activeRgbaSession = null
                                runOnUiThread {
                                    result.error("DIRECT_SESSION_START_FAILED", e.message, null)
                                }
                            }
                        }
                    }

                    "appendRgbaFrameToSession" -> {
                        val rgbaBytes = call.argument<ByteArray>("rgbaBytes")
                        val frameIndex = call.argument<Number>("frameIndex")?.toInt() ?: 0
                        val frameWidth = call.argument<Number>("width")?.toInt()
                        val frameHeight = call.argument<Number>("height")?.toInt()

                        if (rgbaBytes == null || rgbaBytes.isEmpty()) {
                            result.error("INVALID_ARGS", "Empty rgbaBytes", null)
                            return@setMethodCallHandler
                        }

                        eglSessionExecutor.execute {
                            val session = activeRgbaSession
                            if (session == null) {
                                runOnUiThread {
                                    result.error("NO_ACTIVE_SESSION", "Direct MP4 session is not active", null)
                                }
                                return@execute
                            }
                            try {
                                session.appendFrame(
                                    rgbaBytes = rgbaBytes,
                                    frameIndex = frameIndex,
                                    srcWidth = frameWidth ?: session.width,
                                    srcHeight = frameHeight ?: session.height
                                )
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                session.abort()
                                activeRgbaSession = null
                                runOnUiThread {
                                    result.error("DIRECT_FRAME_APPEND_FAILED", e.message, null)
                                }
                            }
                        }
                    }

                    "finishDirectMp4EncodeSession" -> {
                        eglSessionExecutor.execute {
                            val session = activeRgbaSession
                            activeRgbaSession = null
                            if (session == null) {
                                runOnUiThread {
                                    result.error("NO_ACTIVE_SESSION", "No active direct MP4 session to finish", null)
                                }
                                return@execute
                            }
                            try {
                                val outFile = session.finish()
                                runOnUiThread { result.success(outFile.absolutePath) }
                            } catch (e: Exception) {
                                session.abort()
                                runOnUiThread {
                                    result.error("DIRECT_SESSION_FINISH_FAILED", e.message, null)
                                }
                            }
                        }
                    }

                    "abortDirectMp4EncodeSession" -> {
                        eglSessionExecutor.execute {
                            try {
                                activeRgbaSession?.abort()
                            } catch (_: Exception) {}
                            activeRgbaSession = null
                            runOnUiThread { result.success(true) }
                        }
                    }

                    "muxToMp4WithAudio" -> {
                        val aviPath = call.argument<String>("aviPath")
                        val outputMp4Path = call.argument<String>("outputMp4Path")
                        val audioPath = call.argument<String>("audioPath")
                        val processedPcmPath = call.argument<String>("processedPcmPath")
                        val pcmSampleRate = (call.argument<Number>("pcmSampleRate")?.toInt() ?: 44100)
                        val pcmChannels = (call.argument<Number>("pcmChannels")?.toInt() ?: 2)
                        val audioStartOffsetMs = (call.argument<Number>("audioStartOffsetMs")?.toLong() ?: 0L)
                        val audioVolume = (call.argument<Number>("audioVolume")?.toDouble() ?: 0.85)
                        val audioFadeIn = call.argument<Boolean>("audioFadeIn") ?: true
                        val audioFadeOut = call.argument<Boolean>("audioFadeOut") ?: true
                        val sourceFps = (call.argument<Number>("fps")?.toInt() ?: 30).coerceIn(1, 240)
                        val requestedTargetFps = (call.argument<Number>("targetFps")?.toInt() ?: sourceFps).coerceIn(15, 60)
                        val rawWidth = (call.argument<Number>("width")?.toInt() ?: 1080)
                        val rawHeight = (call.argument<Number>("height")?.toInt() ?: 1920)
                        val codecMime = call.argument<String>("codecMime") ?: MediaFormat.MIMETYPE_VIDEO_AVC
                        val bitrateBps = (call.argument<Number>("bitrateBps")?.toInt() ?: 14_000_000).coerceIn(2_000_000, 24_000_000)
                        val allowCodecFallback = call.argument<Boolean>("allowCodecFallback") ?: false
                        val useGpuSurface = call.argument<Boolean>("useGpuSurface") ?: true
                        val cropToFill = call.argument<Boolean>("cropToFill") ?: false

                        if (aviPath.isNullOrBlank() || outputMp4Path.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing aviPath or outputMp4Path", null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            try {
                                val mp4File = transcodeAviToMp4WithAudio(
                                    aviPath = aviPath,
                                    outputMp4Path = outputMp4Path,
                                    audioPath = audioPath,
                                    processedPcmPath = processedPcmPath,
                                    pcmSampleRate = pcmSampleRate,
                                    pcmChannels = pcmChannels,
                                    audioStartOffsetUs = audioStartOffsetMs * 1000L,
                                    audioVolume = audioVolume,
                                    audioFadeIn = audioFadeIn,
                                    audioFadeOut = audioFadeOut,
                                    sourceFps = sourceFps,
                                    requestedTargetFps = requestedTargetFps,
                                    requestedWidth = rawWidth,
                                    requestedHeight = rawHeight,
                                    requestedCodecMime = codecMime,
                                    requestedBitrateBps = bitrateBps,
                                    allowCodecFallback = allowCodecFallback,
                                    useGpuSurface = useGpuSurface,
                                    cropToFill = cropToFill
                                )
                                runOnUiThread {
                                    result.success(mp4File.absolutePath)
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("MUX_MP4_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    }

                    "saveToPublicDownloads" -> {
                        val filePath = call.argument<String>("filePath")
                        val fileName = call.argument<String>("fileName")
                        val mimeType = call.argument<String>("mimeType")
                        if (filePath.isNullOrBlank() || fileName.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing filePath or fileName", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val srcFile = File(filePath)
                                val actualMime = if (!mimeType.isNullOrBlank()) {
                                    mimeType
                                } else {
                                    detectContainerMimeType(srcFile)
                                }
                                val savedPath = saveFileToDownloadsAndGallery(filePath, fileName, actualMime)
                                runOnUiThread {
                                    result.success(savedPath)
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("SAVE_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    }

                    "pickAudioFile" -> {
                        if (pendingAudioResult != null) {
                            result.error("BUSY", "Audio picker already active", null)
                            return@setMethodCallHandler
                        }
                        pendingAudioResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "audio/*"
                        }
                        startActivityForResult(intent, pickAudioRequestCode)
                    }

                    "shareVideoFile" -> {
                        val filePath = call.argument<String>("filePath")
                        val title = call.argument<String>("title") ?: "فيديو ذكرياتنا"
                        val requestedMime = call.argument<String>("mimeType")
                        if (filePath.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing filePath", null)
                            return@setMethodCallHandler
                        }
                        try {
                            shareOrOpenMedia(filePath, title, requestedMime)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ─── Hardware Encoder Capabilities Check (VID-017) ─────────────────────────

    private fun queryDeviceEncoderCapabilities(): Map<String, Any> {
        val supportsH264 = isEncoderSupported(MediaFormat.MIMETYPE_VIDEO_AVC, 1280, 720, 30, 8_000_000)
        val supportsHevc = isEncoderSupported(MediaFormat.MIMETYPE_VIDEO_HEVC, 1280, 720, 30, 8_000_000)
        val supports1080p60H264 = isEncoderSupported(MediaFormat.MIMETYPE_VIDEO_AVC, 1080, 1920, 60, 14_000_000)
        val supports1080p60Hevc = isEncoderSupported(MediaFormat.MIMETYPE_VIDEO_HEVC, 1080, 1920, 60, 14_000_000)
        return mapOf(
            "supportsH264" to supportsH264,
            "supportsHevc" to supportsHevc,
            "supports1080p60H264" to supports1080p60H264,
            "supports1080p60Hevc" to supports1080p60Hevc,
            "maxSupportedBitrateBps" to 24_000_000
        )
    }

    private fun isEncoderSupported(
        mime: String,
        width: Int,
        height: Int,
        fps: Int,
        bitrateBps: Int
    ): Boolean {
        return try {
            val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            val testWidth = max(width, height)
            val testHeight = min(width, height)
            for (info in codecList.codecInfos) {
                if (!info.isEncoder) continue
                val types = info.supportedTypes
                if (types.none { it.equals(mime, ignoreCase = true) }) continue
                val caps = info.getCapabilitiesForType(mime)
                val videoCaps = caps.videoCapabilities ?: continue
                if (videoCaps.areSizeAndRateSupported(testWidth, testHeight, fps.toDouble()) ||
                    videoCaps.areSizeAndRateSupported(width, height, fps.toDouble())
                ) {
                    if (videoCaps.bitrateRange.contains(bitrateBps) || videoCaps.bitrateRange.upper >= bitrateBps) {
                        return true
                    }
                }
            }
            false
        } catch (_: Exception) {
            mime.equals(MediaFormat.MIMETYPE_VIDEO_AVC, ignoreCase = true)
        }
    }

    private fun resolveEncoderDimensions(requestedWidth: Int, requestedHeight: Int): Pair<Int, Int> {
        val isFullHd = max(requestedWidth, requestedHeight) >= 1400 || min(requestedWidth, requestedHeight) >= 1000
        val aspect = requestedWidth.toDouble() / max(1, requestedHeight).toDouble()
        return when {
            aspect < 0.8 -> if (isFullHd) Pair(1080, 1920) else Pair(720, 1280)   // 9:16 Portrait
            aspect > 1.2 -> if (isFullHd) Pair(1920, 1080) else Pair(1280, 720)   // 16:9 Landscape
            else -> if (isFullHd) Pair(1080, 1080) else Pair(720, 720)            // 1:1 Square
        }
    }

    /// حساب مصفوفة التحويل في OpenGL مع الحفاظ على نسبة العرض إلى الارتفاع (Contain Letterbox/Pillarbox أو Cover Center-Crop)
    private fun computeAspectRatioMvpMatrix(
        srcWidth: Int,
        srcHeight: Int,
        dstWidth: Int,
        dstHeight: Int,
        cropToFill: Boolean,
        outMatrix: FloatArray
    ) {
        Matrix.setIdentityM(outMatrix, 0)
        val srcAspect = srcWidth.toFloat() / max(1, srcHeight).toFloat()
        val dstAspect = dstWidth.toFloat() / max(1, dstHeight).toFloat()
        if (abs(srcAspect - dstAspect) > 0.005f) {
            if (cropToFill) {
                // وضع Cover: ملء الشاشة بالكامل مع قص الحواف الزائدة دون تمدد
                if (srcAspect > dstAspect) {
                    Matrix.scaleM(outMatrix, 0, srcAspect / dstAspect, 1.0f, 1.0f)
                } else {
                    Matrix.scaleM(outMatrix, 0, 1.0f, dstAspect / srcAspect, 1.0f)
                }
            } else {
                // وضع Contain: احتواء كامل للصورة داخل الإطار (Letterbox / Pillarbox) دون تشويه
                if (srcAspect > dstAspect) {
                    Matrix.scaleM(outMatrix, 0, 1.0f, dstAspect / srcAspect, 1.0f)
                } else {
                    Matrix.scaleM(outMatrix, 0, srcAspect / dstAspect, 1.0f, 1.0f)
                }
            }
        }
    }

    /// تحجيم Bitmap في مسار الـ CPU مع الحفاظ التام على نسبة الأبعاد (Contain أو Cover) لمنع التمدد
    private fun scaleBitmapPreservingAspect(
        src: Bitmap,
        dstWidth: Int,
        dstHeight: Int,
        cropToFill: Boolean
    ): Bitmap {
        if (src.width == dstWidth && src.height == dstHeight) {
            return src
        }
        val srcAspect = src.width.toFloat() / max(1, src.height).toFloat()
        val dstAspect = dstWidth.toFloat() / max(1, dstHeight).toFloat()
        if (abs(srcAspect - dstAspect) <= 0.005f) {
            return Bitmap.createScaledBitmap(src, dstWidth, dstHeight, true)
        }

        val outBitmap = Bitmap.createBitmap(dstWidth, dstHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(outBitmap)
        canvas.drawColor(Color.BLACK)

        val scale = if (cropToFill) {
            max(dstWidth.toFloat() / src.width.toFloat(), dstHeight.toFloat() / src.height.toFloat())
        } else {
            min(dstWidth.toFloat() / src.width.toFloat(), dstHeight.toFloat() / src.height.toFloat())
        }

        val scaledW = src.width * scale
        val scaledH = src.height * scale
        val left = (dstWidth - scaledW) * 0.5f
        val top = (dstHeight - scaledH) * 0.5f
        val dstRect = RectF(left, top, left + scaledW, top + scaledH)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        canvas.drawBitmap(src, null, dstRect, paint)
        return outBitmap
    }

    // ─── Direct Raw RGBA8888 Streaming Encoder Session (Zero-AVI / Zero-PNG) ───

    private inner class RgbaStreamEncoder(
        val outputMp4File: File,
        requestedWidth: Int,
        requestedHeight: Int,
        val targetFps: Int,
        requestedCodecMime: String,
        val bitrateBps: Int,
        val processedPcmPath: String?,
        val audioPath: String?,
        val pcmSampleRate: Int,
        val pcmChannels: Int,
        val cropToFill: Boolean = false
    ) {
        val width: Int
        val height: Int
        val codecMime: String

        private var encoder: MediaCodec? = null
        private var muxer: MediaMuxer? = null
        private var inputSurface: Surface? = null
        private var eglCore: EglCore? = null
        private var eglSurface: EGLSurface? = null
        private var gpuProgram: GpuTextureProgram? = null
        private val textureIds = IntArray(1)
        private var textureInitialized = false
        private var lastTexWidth = 0
        private var lastTexHeight = 0

        private var directRgbaBuffer: ByteBuffer? = null
        private val mvpMatrix = FloatArray(16)
        private val bufferInfo = MediaCodec.BufferInfo()
        private val audInfo = MediaCodec.BufferInfo()

        private var audioFormat: MediaFormat? = null
        private var audioPackets: List<EncodedPacket> = emptyList()
        private var audioPacketCursor = 0

        private var encoderStarted = false
        private var muxerStarted = false
        private var videoTrackIdx = -1
        private var audioTrackIdx = -1
        private var useCpuFallback = false
        private var cpuArgbScratch: IntArray? = null
        private var framesEncodedCount = 0
        private var lastFrameIndex = 0
        private var closed = false

        init {
            val (encW, encH) = resolveEncoderDimensions(requestedWidth, requestedHeight)
            width = encW
            height = encH
            codecMime = if (requestedCodecMime.equals("video/hevc", ignoreCase = true)) {
                MediaFormat.MIMETYPE_VIDEO_HEVC
            } else {
                MediaFormat.MIMETYPE_VIDEO_AVC
            }
        }

        fun start() {
            if (outputMp4File.exists()) {
                outputMp4File.delete()
            }

            // 1. تجهيز مسار الصوت المضغوط (AAC) للتداخل المباشر مع الإطارات
            if (!processedPcmPath.isNullOrBlank() && File(processedPcmPath).exists()) {
                val pcmFile = File(processedPcmPath)
                if (pcmFile.length() > 0L) {
                    val encoded = encodePcmFileStreamToAac(
                        pcmFile = pcmFile,
                        sampleRate = pcmSampleRate,
                        channelCount = pcmChannels
                    )
                    audioFormat = encoded.first
                    audioPackets = encoded.second
                }
            } else if (!audioPath.isNullOrBlank() && File(audioPath).exists()) {
                val transcoded = transcodeAudioToAac(
                    audioPath = audioPath,
                    startOffsetUs = 0L,
                    totalDurationUs = 600_000_000L,
                    volume = 0.85,
                    fadeIn = true,
                    fadeOut = true
                )
                if (transcoded != null) {
                    audioFormat = transcoded.first
                    audioPackets = transcoded.second
                }
            }

            // 2. محاولة بدء مسار GPU Surface المباشر، مع سقوط آمن لمسار CPU عند الضرورة
            try {
                startGpuSurfacePipeline()
                useCpuFallback = false
            } catch (_: Exception) {
                releaseGpuResourcesOnly()
                startCpuBufferPipeline()
                useCpuFallback = true
            }
        }

        private fun startGpuSurfacePipeline() {
            val format = MediaFormat.createVideoFormat(codecMime, width, height).apply {
                setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface
                )
                setInteger(MediaFormat.KEY_BIT_RATE, bitrateBps)
                setInteger(MediaFormat.KEY_FRAME_RATE, targetFps)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
                setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT709)
                setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED)
                setInteger(MediaFormat.KEY_COLOR_TRANSFER, MediaFormat.COLOR_TRANSFER_SDR_VIDEO)
            }

            val enc = MediaCodec.createEncoderByType(codecMime)
            enc.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            val surface = enc.createInputSurface()
            enc.start()

            encoder = enc
            inputSurface = surface
            encoderStarted = true

            muxer = MediaMuxer(outputMp4File.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            val core = EglCore()
            val winSurface = core.createWindowSurface(surface)
            core.makeCurrent(winSurface)

            val prog = GpuTextureProgram()
            GLES20.glGenTextures(1, textureIds, 0)
            val texId = textureIds[0]
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)

            eglCore = core
            eglSurface = winSurface
            gpuProgram = prog
        }

        private fun startCpuBufferPipeline() {
            val format = MediaFormat.createVideoFormat(codecMime, width, height).apply {
                setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible
                )
                setInteger(MediaFormat.KEY_BIT_RATE, bitrateBps)
                setInteger(MediaFormat.KEY_FRAME_RATE, targetFps)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
                setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT709)
                setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED)
                setInteger(MediaFormat.KEY_COLOR_TRANSFER, MediaFormat.COLOR_TRANSFER_SDR_VIDEO)
            }

            val enc = MediaCodec.createEncoderByType(codecMime)
            enc.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            enc.start()
            encoder = enc
            encoderStarted = true

            muxer = MediaMuxer(outputMp4File.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            cpuArgbScratch = IntArray(width * height)
        }

        fun appendFrame(
            rgbaBytes: ByteArray,
            frameIndex: Int,
            srcWidth: Int,
            srcHeight: Int
        ) {
            if (closed) {
                throw IllegalStateException("Session is already closed")
            }
            val expectedBytes = srcWidth * srcHeight * 4
            if (srcWidth <= 0 || srcHeight <= 0 || rgbaBytes.size < expectedBytes) {
                throw IllegalArgumentException(
                    "RGBA frame buffer size (${rgbaBytes.size}) is smaller than ${srcWidth}x$srcHeight*4 ($expectedBytes)"
                )
            }

            val effectiveFrameIdx = if (frameIndex >= 0) frameIndex else framesEncodedCount
            lastFrameIndex = effectiveFrameIdx

            if (!useCpuFallback) {
                val core = eglCore ?: throw IllegalStateException("EGLCore not initialized")
                val winSurface = eglSurface ?: throw IllegalStateException("EGLSurface not initialized")
                val prog = gpuProgram ?: throw IllegalStateException("GpuTextureProgram not initialized")

                core.makeCurrent(winSurface)

                var buf = directRgbaBuffer
                if (buf == null || buf.capacity() < expectedBytes) {
                    buf = ByteBuffer.allocateDirect(expectedBytes).order(ByteOrder.nativeOrder())
                    directRgbaBuffer = buf
                }
                buf.clear()
                buf.put(rgbaBytes, 0, expectedBytes)
                buf.position(0)

                GLES20.glViewport(0, 0, width, height)
                GLES20.glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

                val texId = textureIds[0]
                GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
                GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1)
                if (!textureInitialized || lastTexWidth != srcWidth || lastTexHeight != srcHeight) {
                    GLES20.glTexImage2D(
                        GLES20.GL_TEXTURE_2D,
                        0,
                        GLES20.GL_RGBA,
                        srcWidth,
                        srcHeight,
                        0,
                        GLES20.GL_RGBA,
                        GLES20.GL_UNSIGNED_BYTE,
                        buf
                    )
                    textureInitialized = true
                    lastTexWidth = srcWidth
                    lastTexHeight = srcHeight
                } else {
                    GLES20.glTexSubImage2D(
                        GLES20.GL_TEXTURE_2D,
                        0,
                        0,
                        0,
                        srcWidth,
                        srcHeight,
                        GLES20.GL_RGBA,
                        GLES20.GL_UNSIGNED_BYTE,
                        buf
                    )
                }
                GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)

                computeAspectRatioMvpMatrix(
                    srcWidth = srcWidth,
                    srcHeight = srcHeight,
                    dstWidth = width,
                    dstHeight = height,
                    cropToFill = cropToFill,
                    outMatrix = mvpMatrix
                )
                prog.draw(texId, mvpMatrix)

                val ptsNs = (effectiveFrameIdx.toLong() * 1_000_000_000L) / targetFps.toLong()
                core.setPresentationTime(winSurface, ptsNs)
                core.swapBuffers(winSurface)

                drainEncoder(endOfStream = false)
            } else {
                appendFrameCpuFallback(rgbaBytes, effectiveFrameIdx, srcWidth, srcHeight)
            }

            framesEncodedCount++
        }

        private fun appendFrameCpuFallback(
            rgbaBytes: ByteArray,
            frameIndex: Int,
            srcWidth: Int,
            srcHeight: Int
        ) {
            val enc = encoder ?: throw IllegalStateException("CPU encoder not initialized")
            val argb = cpuArgbScratch ?: IntArray(width * height).also { cpuArgbScratch = it }

            if (srcWidth == width && srcHeight == height) {
                val pxCount = width * height
                for (i in 0 until pxCount) {
                    val base = i * 4
                    val r = rgbaBytes[base].toInt() and 0xFF
                    val g = rgbaBytes[base + 1].toInt() and 0xFF
                    val b = rgbaBytes[base + 2].toInt() and 0xFF
                    val a = rgbaBytes[base + 3].toInt() and 0xFF
                    argb[i] = (a shl 24) or (r shl 16) or (g shl 8) or b
                }
            } else {
                val srcBitmap = Bitmap.createBitmap(srcWidth, srcHeight, Bitmap.Config.ARGB_8888)
                srcBitmap.copyPixelsFromBuffer(ByteBuffer.wrap(rgbaBytes, 0, srcWidth * srcHeight * 4))
                val scaled = scaleBitmapPreservingAspect(srcBitmap, width, height, cropToFill)
                try {
                    scaled.getPixels(argb, 0, width, 0, 0, width, height)
                } finally {
                    if (scaled !== srcBitmap) scaled.recycle()
                    srcBitmap.recycle()
                }
            }

            val ptsUs = (frameIndex.toLong() * 1_000_000L) / targetFps.toLong()
            var queued = false
            while (!queued) {
                val inBufIdx = enc.dequeueInputBuffer(10_000L)
                if (inBufIdx >= 0) {
                    val inputImage = try {
                        enc.getInputImage(inBufIdx)
                    } catch (_: Exception) {
                        null
                    }
                    if (inputImage != null) {
                        val bytesWritten = try {
                            fillBt709Yuv420ImageFromArgb(argb, inputImage, width, height)
                        } finally {
                            inputImage.close()
                        }
                        val cap = enc.getInputBuffer(inBufIdx)?.capacity() ?: bytesWritten
                        enc.queueInputBuffer(inBufIdx, 0, min(bytesWritten, cap), ptsUs, 0)
                    } else {
                        val inputBuffer = enc.getInputBuffer(inBufIdx)
                            ?: throw IllegalStateException("Null inputBuffer at $inBufIdx")
                        inputBuffer.clear()
                        val bytesWritten = fillBt709Nv12BufferFromArgb(argb, inputBuffer, width, height)
                        enc.queueInputBuffer(inBufIdx, 0, bytesWritten, ptsUs, 0)
                    }
                    queued = true
                } else {
                    drainEncoder(endOfStream = false)
                }
            }
            drainEncoder(endOfStream = false)
        }

        private fun writeInterleavedAudioUpTo(maxPtsUs: Long) {
            val mux = muxer ?: return
            if (!muxerStarted || audioTrackIdx < 0) return
            while (audioPacketCursor < audioPackets.size) {
                val pkt = audioPackets[audioPacketCursor]
                if (pkt.presentationTimeUs > maxPtsUs) break
                audInfo.set(0, pkt.data.size, pkt.presentationTimeUs, pkt.flags)
                mux.writeSampleData(audioTrackIdx, ByteBuffer.wrap(pkt.data), audInfo)
                audioPacketCursor++
            }
        }

        private fun drainEncoder(endOfStream: Boolean) {
            val enc = encoder ?: return
            val mux = muxer ?: return

            if (endOfStream) {
                if (!useCpuFallback) {
                    enc.signalEndOfInputStream()
                } else {
                    val eosPtsUs = ((lastFrameIndex + 1).toLong() * 1_000_000L) / targetFps.toLong()
                    var queuedEos = false
                    var attempts = 0
                    while (!queuedEos && attempts < 100) {
                        val inIdx = enc.dequeueInputBuffer(10_000L)
                        if (inIdx >= 0) {
                            enc.queueInputBuffer(
                                inIdx,
                                0,
                                0,
                                eosPtsUs,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            queuedEos = true
                        } else {
                            attempts++
                        }
                    }
                }
            }

            var eosTryAgainCount = 0
            val maxEosRetries = 200
            while (true) {
                val outStatus = enc.dequeueOutputBuffer(bufferInfo, if (endOfStream) 10_000L else 0L)
                when {
                    outStatus == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        if (!endOfStream) return
                        eosTryAgainCount++
                        if (eosTryAgainCount > maxEosRetries) {
                            break
                        }
                    }
                    outStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        if (muxerStarted) throw IllegalStateException("Output format changed twice")
                        videoTrackIdx = mux.addTrack(enc.outputFormat)
                        val af = audioFormat
                        if (af != null && audioPackets.isNotEmpty()) {
                            audioTrackIdx = mux.addTrack(af)
                        }
                        mux.start()
                        muxerStarted = true
                    }
                    outStatus >= 0 -> {
                        eosTryAgainCount = 0
                        val outBuf = enc.getOutputBuffer(outStatus)
                        if (outBuf != null &&
                            bufferInfo.size > 0 &&
                            (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0
                        ) {
                            if (!muxerStarted) {
                                videoTrackIdx = mux.addTrack(enc.outputFormat)
                                val af = audioFormat
                                if (af != null && audioPackets.isNotEmpty()) {
                                    audioTrackIdx = mux.addTrack(af)
                                }
                                mux.start()
                                muxerStarted = true
                            }
                            outBuf.position(bufferInfo.offset)
                            outBuf.limit(bufferInfo.offset + bufferInfo.size)
                            mux.writeSampleData(videoTrackIdx, outBuf, bufferInfo)
                            writeInterleavedAudioUpTo(bufferInfo.presentationTimeUs)
                        }
                        enc.releaseOutputBuffer(outStatus, false)
                        if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            return
                        }
                    }
                }
            }
        }

        fun finish(): File {
            if (closed) return outputMp4File
            try {
                if (framesEncodedCount <= 0) {
                    throw IllegalStateException("No frames were appended to the direct MP4 session")
                }
                drainEncoder(endOfStream = true)
                writeInterleavedAudioUpTo(Long.MAX_VALUE)
            } finally {
                releaseAll()
            }

            verifyExportedMp4WithRetriever(
                mp4File = outputMp4File,
                expectedWidth = width,
                expectedHeight = height
            )
            return outputMp4File
        }

        fun abort() {
            releaseAll()
            try {
                if (outputMp4File.exists()) {
                    outputMp4File.delete()
                }
            } catch (_: Exception) {}
        }

        private fun releaseGpuResourcesOnly() {
            try {
                if (textureIds[0] != 0) {
                    GLES20.glDeleteTextures(1, textureIds, 0)
                    textureIds[0] = 0
                }
            } catch (_: Exception) {}
            try { gpuProgram?.release() } catch (_: Exception) {}
            gpuProgram = null
            try {
                val core = eglCore
                val surf = eglSurface
                if (core != null && surf != null) {
                    core.releaseSurface(surf)
                }
            } catch (_: Exception) {}
            eglSurface = null
            try { eglCore?.release() } catch (_: Exception) {}
            eglCore = null
            try { inputSurface?.release() } catch (_: Exception) {}
            inputSurface = null
            if (encoderStarted) {
                try { encoder?.stop() } catch (_: Exception) {}
            }
            try { encoder?.release() } catch (_: Exception) {}
            encoder = null
            encoderStarted = false
            try { muxer?.release() } catch (_: Exception) {}
            muxer = null
            muxerStarted = false
        }

        private fun releaseAll() {
            if (closed) return
            closed = true
            try {
                if (textureIds[0] != 0) {
                    GLES20.glDeleteTextures(1, textureIds, 0)
                    textureIds[0] = 0
                }
            } catch (_: Exception) {}
            try { gpuProgram?.release() } catch (_: Exception) {}
            gpuProgram = null
            try {
                val core = eglCore
                val surf = eglSurface
                if (core != null && surf != null) {
                    core.releaseSurface(surf)
                }
            } catch (_: Exception) {}
            eglSurface = null
            try { eglCore?.release() } catch (_: Exception) {}
            eglCore = null
            try { inputSurface?.release() } catch (_: Exception) {}
            inputSurface = null

            if (encoderStarted) {
                try { encoder?.stop() } catch (_: Exception) {}
            }
            try { encoder?.release() } catch (_: Exception) {}
            encoder = null

            if (muxerStarted) {
                try { muxer?.stop() } catch (_: Exception) {}
            }
            try { muxer?.release() } catch (_: Exception) {}
            muxer = null
            directRgbaBuffer = null
            cpuArgbScratch = null
        }
    }

    // ─── Hardware H.264 / HEVC (.mp4) + AAC Audio Transcoder & Muxer ───────────

    private fun transcodeAviToMp4WithAudio(
        aviPath: String,
        outputMp4Path: String,
        audioPath: String?,
        processedPcmPath: String?,
        pcmSampleRate: Int,
        pcmChannels: Int,
        audioStartOffsetUs: Long,
        audioVolume: Double,
        audioFadeIn: Boolean,
        audioFadeOut: Boolean,
        sourceFps: Int,
        requestedTargetFps: Int = 30,
        requestedWidth: Int,
        requestedHeight: Int,
        requestedCodecMime: String = MediaFormat.MIMETYPE_VIDEO_AVC,
        requestedBitrateBps: Int = 14_000_000,
        allowCodecFallback: Boolean = false,
        useGpuSurface: Boolean = true,
        cropToFill: Boolean = false
    ): File {
        val aviFile = File(aviPath)
        if (!aviFile.exists() || aviFile.length() < 32L) {
            throw IllegalArgumentException("AVI file is missing or corrupt: $aviPath")
        }

        val frameLocations = indexPngFramesInAvi(aviFile)
        if (frameLocations.isEmpty()) {
            throw IllegalStateException("No valid PNG frames (00dc) found in AVI container")
        }

        val aspect = requestedWidth.toDouble() / max(1, requestedHeight).toDouble()
        val (encWidth, encHeight) = resolveEncoderDimensions(requestedWidth, requestedHeight)
        if (encWidth % 2 != 0 || encHeight % 2 != 0) {
            throw IllegalArgumentException("Encoder dimensions must be even: ${encWidth}x$encHeight")
        }

        val safeSourceFps = max(1, sourceFps)
        val targetFps = requestedTargetFps.coerceIn(15, 60)
        val totalOutputFrames = max(
            1,
            ((frameLocations.size.toLong() * targetFps.toLong() + (safeSourceFps / 2)) / safeSourceFps.toLong()).toInt()
        )
        val totalDurationUs = (totalOutputFrames.toLong() * 1_000_000L) / targetFps.toLong()

        val normalizedMime = if (requestedCodecMime.equals("video/hevc", ignoreCase = true)) {
            MediaFormat.MIMETYPE_VIDEO_HEVC
        } else {
            MediaFormat.MIMETYPE_VIDEO_AVC
        }

        if (!allowCodecFallback && !isEncoderSupported(normalizedMime, encWidth, encHeight, targetFps, requestedBitrateBps)) {
            throw IllegalStateException(
                "الجهاز لا يدعم ترميز $normalizedMime بدقة ${encWidth}x$encHeight ومعدل $targetFps FPS."
            )
        }

        var audioFormat: MediaFormat? = null
        var audioPackets: List<EncodedPacket> = emptyList()
        if (!processedPcmPath.isNullOrBlank() && File(processedPcmPath).exists()) {
            val pcmFile = File(processedPcmPath)
            if (pcmFile.length() > 0L) {
                val encoded = encodePcmFileStreamToAac(
                    pcmFile = pcmFile,
                    sampleRate = pcmSampleRate,
                    channelCount = pcmChannels
                )
                audioFormat = encoded.first
                audioPackets = encoded.second
            }
        } else if (!audioPath.isNullOrBlank() && File(audioPath).exists() && audioVolume > 0.01) {
            val transcodedAudio = transcodeAudioToAac(
                audioPath = audioPath,
                startOffsetUs = audioStartOffsetUs,
                totalDurationUs = totalDurationUs,
                volume = audioVolume,
                fadeIn = audioFadeIn,
                fadeOut = audioFadeOut
            )
            if (transcodedAudio != null) {
                audioFormat = transcodedAudio.first
                audioPackets = transcodedAudio.second
            }
        }

        val outFile = File(outputMp4Path)
        if (outFile.exists()) outFile.delete()

        try {
            if (useGpuSurface) {
                try {
                    streamEncodeFramesWithGpuSurfaceAndMuxToMp4(
                        aviFile = aviFile,
                        frameLocations = frameLocations,
                        outputMp4File = outFile,
                        width = encWidth,
                        height = encHeight,
                        sourceFps = safeSourceFps,
                        targetFps = targetFps,
                        totalOutputFrames = totalOutputFrames,
                        codecMime = normalizedMime,
                        bitrateBps = requestedBitrateBps,
                        audioFormat = audioFormat,
                        audioPackets = audioPackets,
                        cropToFill = cropToFill
                    )
                } catch (_: Exception) {
                    if (outFile.exists()) outFile.delete()
                    streamEncodeFramesAndMuxToMp4(
                        aviFile = aviFile,
                        frameLocations = frameLocations,
                        outputMp4File = outFile,
                        width = encWidth,
                        height = encHeight,
                        sourceFps = safeSourceFps,
                        targetFps = targetFps,
                        totalOutputFrames = totalOutputFrames,
                        codecMime = normalizedMime,
                        bitrateBps = requestedBitrateBps,
                        audioFormat = audioFormat,
                        audioPackets = audioPackets,
                        cropToFill = cropToFill
                    )
                }
            } else {
                streamEncodeFramesAndMuxToMp4(
                    aviFile = aviFile,
                    frameLocations = frameLocations,
                    outputMp4File = outFile,
                    width = encWidth,
                    height = encHeight,
                    sourceFps = safeSourceFps,
                    targetFps = targetFps,
                    totalOutputFrames = totalOutputFrames,
                    codecMime = normalizedMime,
                    bitrateBps = requestedBitrateBps,
                    audioFormat = audioFormat,
                    audioPackets = audioPackets,
                    cropToFill = cropToFill
                )
            }
        } catch (e: Exception) {
            if (outFile.exists()) outFile.delete()
            if (!allowCodecFallback) {
                throw IllegalStateException(
                    "فشل الترميز العتادي ($normalizedMime ${encWidth}x$encHeight @ $targetFps FPS): ${e.message}",
                    e
                )
            }
            val fallbackW = if (aspect < 0.8) 720 else if (aspect > 1.2) 1280 else 720
            val fallbackH = if (aspect < 0.8) 1280 else if (aspect > 1.2) 720 else 720
            streamEncodeFramesAndMuxToMp4(
                aviFile = aviFile,
                frameLocations = frameLocations,
                outputMp4File = outFile,
                width = fallbackW,
                height = fallbackH,
                sourceFps = safeSourceFps,
                targetFps = 30,
                totalOutputFrames = max(1, ((frameLocations.size.toLong() * 30L) / safeSourceFps.toLong()).toInt()),
                codecMime = MediaFormat.MIMETYPE_VIDEO_AVC,
                bitrateBps = 8_000_000,
                audioFormat = audioFormat,
                audioPackets = audioPackets,
                cropToFill = cropToFill
            )
        }

        verifyExportedMp4WithRetriever(
            mp4File = outFile,
            expectedWidth = encWidth,
            expectedHeight = encHeight
        )

        return outFile
    }

    private fun verifyExportedMp4WithRetriever(
        mp4File: File,
        expectedWidth: Int,
        expectedHeight: Int
    ) {
        if (!mp4File.exists() || mp4File.length() < 256L) {
            throw IllegalStateException("Exported MP4 file is empty or corrupt")
        }
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(mp4File.absolutePath)
            val hasVideo = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO)
            if (hasVideo == null || !hasVideo.equals("yes", ignoreCase = true)) {
                throw IllegalStateException("MediaMetadataRetriever verification failed: no valid video track")
            }
            val actualW = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            val actualH = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            if (actualW <= 0 || actualH <= 0) {
                throw IllegalStateException("MediaMetadataRetriever verification failed: invalid video dimensions ${actualW}x$actualH")
            }
            if ((actualW != expectedWidth || actualH != expectedHeight) &&
                (actualW != expectedHeight || actualH != expectedWidth)
            ) {
                throw IllegalStateException(
                    "Exported video dimensions (${actualW}x$actualH) do not match requested (${expectedWidth}x$expectedHeight)"
                )
            }
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {}
        }
    }

    /// فهرسة مواقع إطارات PNG (`00dc`) داخل حاوية RIFF/AVI عبر `RandomAccessFile` بدون قراءة الملف كاملًا في الذاكرة
    private fun indexPngFramesInAvi(aviFile: File): List<AviFrameLocation> {
        val fileLen = aviFile.length()
        if (fileLen < 32L) return emptyList()

        val locations = ArrayList<AviFrameLocation>()
        RandomAccessFile(aviFile, "r").use { raf ->
            val header = ByteArray(12)
            if (raf.read(header) != 12) return emptyList()

            if (header[0] != 0x52.toByte() ||
                header[1] != 0x49.toByte() ||
                header[2] != 0x46.toByte() ||
                header[3] != 0x46.toByte() ||
                header[8] != 0x41.toByte() ||
                header[9] != 0x56.toByte() ||
                header[10] != 0x49.toByte() ||
                header[11] != 0x20.toByte()
            ) {
                return emptyList()
            }

            val riffSizeUnsigned = ByteBuffer.wrap(header, 4, 4)
                .order(ByteOrder.LITTLE_ENDIAN)
                .int.toLong() and 0xFFFFFFFFL
            val containerEnd = min(fileLen, riffSizeUnsigned + 8L)
            if (containerEnd < 24L) return emptyList()

            val chunkHdr = ByteArray(8)
            val listTypeBuf = ByteArray(4)
            val pngSigBuf = ByteArray(8)
            var pos = 12L

            while (pos + 8L <= containerEnd) {
                raf.seek(pos)
                if (raf.read(chunkHdr) != 8) break

                val c0 = chunkHdr[0].toInt() and 0xFF
                val c1 = chunkHdr[1].toInt() and 0xFF
                val c2 = chunkHdr[2].toInt() and 0xFF
                val c3 = chunkHdr[3].toInt() and 0xFF
                val chunkSize = ByteBuffer.wrap(chunkHdr, 4, 4)
                    .order(ByteOrder.LITTLE_ENDIAN)
                    .int.toLong() and 0xFFFFFFFFL
                val dataStart = pos + 8L
                val dataEnd = dataStart + chunkSize

                if (dataEnd > containerEnd) break

                if (c0 == 0x4C && c1 == 0x49 && c2 == 0x53 && c3 == 0x54 && chunkSize >= 4L) {
                    if (raf.read(listTypeBuf) != 4) break
                    if (listTypeBuf[0] == 0x6D.toByte() &&
                        listTypeBuf[1] == 0x6F.toByte() &&
                        listTypeBuf[2] == 0x76.toByte() &&
                        listTypeBuf[3] == 0x69.toByte()
                    ) {
                        var mpos = dataStart + 4L
                        while (mpos + 8L <= dataEnd) {
                            raf.seek(mpos)
                            if (raf.read(chunkHdr) != 8) break
                            val mc0 = chunkHdr[0].toInt() and 0xFF
                            val mc1 = chunkHdr[1].toInt() and 0xFF
                            val mc2 = chunkHdr[2].toInt() and 0xFF
                            val mc3 = chunkHdr[3].toInt() and 0xFF
                            val mSize = ByteBuffer.wrap(chunkHdr, 4, 4)
                                .order(ByteOrder.LITTLE_ENDIAN)
                                .int.toLong() and 0xFFFFFFFFL
                            val mStart = mpos + 8L
                            val mEnd = mStart + mSize

                            if (mEnd > dataEnd) break

                            if (mc0 == 0x4C && mc1 == 0x49 && mc2 == 0x53 && mc3 == 0x54 && mSize >= 4L) {
                                if (raf.read(listTypeBuf) == 4 &&
                                    listTypeBuf[0] == 0x72.toByte() &&
                                    listTypeBuf[1] == 0x65.toByte() &&
                                    listTypeBuf[2] == 0x63.toByte() &&
                                    listTypeBuf[3] == 0x20.toByte()
                                ) {
                                    mpos = mStart + 4L
                                    continue
                                }
                            } else if (mc0 == 0x30 && mc1 == 0x30 && mc2 == 0x64 && mc3 == 0x63 &&
                                mSize >= 8L && mSize <= 32L * 1024L * 1024L
                            ) {
                                if (raf.read(pngSigBuf) == 8 && pngSigBuf.contentEquals(PNG_MAGIC)) {
                                    locations.add(AviFrameLocation(offset = mStart, size = mSize.toInt()))
                                }
                            }

                            val mPadded = mSize + (mSize and 1L)
                            val nextMpos = mStart + mPadded
                            if (nextMpos <= mpos) break
                            mpos = nextMpos
                        }
                    }
                }

                val padded = chunkSize + (chunkSize and 1L)
                val nextPos = dataStart + padded
                if (nextPos <= pos) break
                pos = nextPos
            }
        }
        return locations
    }

    /// ترميز الإطارات عبر مسار CPU مع الحفاظ على نسبة الأبعاد والكتابة المتداخلة للصوت والفيديو
    private fun streamEncodeFramesAndMuxToMp4(
        aviFile: File,
        frameLocations: List<AviFrameLocation>,
        outputMp4File: File,
        width: Int,
        height: Int,
        sourceFps: Int,
        targetFps: Int,
        totalOutputFrames: Int,
        codecMime: String,
        bitrateBps: Int,
        audioFormat: MediaFormat?,
        audioPackets: List<EncodedPacket>,
        cropToFill: Boolean = false
    ) {
        if (width <= 0 || height <= 0 || width % 2 != 0 || height % 2 != 0) {
            throw IllegalArgumentException("Video dimensions must be positive even integers: ${width}x$height")
        }

        val format = MediaFormat.createVideoFormat(codecMime, width, height).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible
            )
            setInteger(MediaFormat.KEY_BIT_RATE, bitrateBps)
            setInteger(MediaFormat.KEY_FRAME_RATE, targetFps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT709)
            setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED)
            setInteger(MediaFormat.KEY_COLOR_TRANSFER, MediaFormat.COLOR_TRANSFER_SDR_VIDEO)
        }

        val encoder = MediaCodec.createEncoderByType(codecMime)
        val muxer = MediaMuxer(outputMp4File.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var encoderStarted = false
        var muxerStarted = false
        var videoTrackIdx = -1
        var audioTrackIdx = -1
        var audioPacketCursor = 0
        val audInfo = MediaCodec.BufferInfo()

        fun writeInterleavedAudioUpTo(maxPtsUs: Long) {
            if (!muxerStarted || audioTrackIdx < 0) return
            while (audioPacketCursor < audioPackets.size) {
                val pkt = audioPackets[audioPacketCursor]
                if (pkt.presentationTimeUs > maxPtsUs) break
                audInfo.set(0, pkt.data.size, pkt.presentationTimeUs, pkt.flags)
                muxer.writeSampleData(audioTrackIdx, ByteBuffer.wrap(pkt.data), audInfo)
                audioPacketCursor++
            }
        }

        try {
            encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()
            encoderStarted = true

            val bufferInfo = MediaCodec.BufferInfo()
            val argbPixels = IntArray(width * height)
            var cachedSrcFrameIdx = -1

            var outFrameIndex = 0
            var inputDone = false
            var outputDone = false
            var eosTryAgainCount = 0
            val maxEosRetries = 250

            RandomAccessFile(aviFile, "r").use { raf ->
                while (!outputDone) {
                    if (!inputDone) {
                        val inBufIdx = encoder.dequeueInputBuffer(10_000)
                        if (inBufIdx >= 0) {
                            if (outFrameIndex >= totalOutputFrames) {
                                val ptsUs = (outFrameIndex.toLong() * 1_000_000L) / targetFps.toLong()
                                encoder.queueInputBuffer(
                                    inBufIdx,
                                    0,
                                    0,
                                    ptsUs,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                )
                                inputDone = true
                            } else {
                                val srcIdx = ((outFrameIndex.toLong() * sourceFps.toLong()) / targetFps.toLong())
                                    .toInt()
                                    .coerceIn(0, frameLocations.size - 1)

                                if (srcIdx != cachedSrcFrameIdx) {
                                    val loc = frameLocations[srcIdx]
                                    val pngBytes = ByteArray(loc.size)
                                    raf.seek(loc.offset)
                                    raf.readFully(pngBytes)

                                    val rawBitmap = BitmapFactory.decodeByteArray(pngBytes, 0, pngBytes.size)
                                        ?: throw IllegalStateException("Failed to decode PNG frame at index $srcIdx")
                                    try {
                                        val scaledBitmap = scaleBitmapPreservingAspect(
                                            src = rawBitmap,
                                            dstWidth = width,
                                            dstHeight = height,
                                            cropToFill = cropToFill
                                        )
                                        try {
                                            scaledBitmap.getPixels(argbPixels, 0, width, 0, 0, width, height)
                                        } finally {
                                            if (scaledBitmap !== rawBitmap) {
                                                scaledBitmap.recycle()
                                            }
                                        }
                                    } finally {
                                        rawBitmap.recycle()
                                    }
                                    cachedSrcFrameIdx = srcIdx
                                }

                                val ptsUs = (outFrameIndex.toLong() * 1_000_000L) / targetFps.toLong()

                                val inputImage = try {
                                    encoder.getInputImage(inBufIdx)
                                } catch (_: Exception) {
                                    null
                                }

                                if (inputImage != null) {
                                    val bytesWritten = try {
                                        fillBt709Yuv420ImageFromArgb(
                                            argb = argbPixels,
                                            image = inputImage,
                                            width = width,
                                            height = height
                                        )
                                    } finally {
                                        inputImage.close()
                                    }
                                    val inputCap = encoder.getInputBuffer(inBufIdx)?.capacity() ?: bytesWritten
                                    encoder.queueInputBuffer(inBufIdx, 0, min(bytesWritten, inputCap), ptsUs, 0)
                                } else {
                                    val inputBuffer = encoder.getInputBuffer(inBufIdx)
                                        ?: throw IllegalStateException("MediaCodec returned null inputBuffer for index $inBufIdx")
                                    inputBuffer.clear()
                                    val bytesWritten = fillBt709Nv12BufferFromArgb(
                                        argb = argbPixels,
                                        buffer = inputBuffer,
                                        width = width,
                                        height = height
                                    )
                                    encoder.queueInputBuffer(inBufIdx, 0, bytesWritten, ptsUs, 0)
                                }

                                outFrameIndex++
                            }
                        }
                    }

                    val outStatus = encoder.dequeueOutputBuffer(bufferInfo, 10_000)
                    when {
                        outStatus == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                            if (inputDone) {
                                eosTryAgainCount++
                                if (eosTryAgainCount > maxEosRetries) {
                                    outputDone = true
                                } else {
                                    Thread.sleep(4)
                                }
                            }
                        }
                        outStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            if (muxerStarted) {
                                throw IllegalStateException("MediaCodec output format changed twice")
                            }
                            videoTrackIdx = muxer.addTrack(encoder.outputFormat)
                            if (audioFormat != null && audioPackets.isNotEmpty()) {
                                audioTrackIdx = muxer.addTrack(audioFormat)
                            }
                            muxer.start()
                            muxerStarted = true
                        }
                        outStatus >= 0 -> {
                            eosTryAgainCount = 0
                            val outBuf = encoder.getOutputBuffer(outStatus)
                            if (outBuf != null &&
                                bufferInfo.size > 0 &&
                                (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0
                            ) {
                                if (!muxerStarted) {
                                    videoTrackIdx = muxer.addTrack(encoder.outputFormat)
                                    if (audioFormat != null && audioPackets.isNotEmpty()) {
                                        audioTrackIdx = muxer.addTrack(audioFormat)
                                    }
                                    muxer.start()
                                    muxerStarted = true
                                }
                                outBuf.position(bufferInfo.offset)
                                outBuf.limit(bufferInfo.offset + bufferInfo.size)
                                muxer.writeSampleData(videoTrackIdx, outBuf, bufferInfo)
                                writeInterleavedAudioUpTo(bufferInfo.presentationTimeUs)
                            }
                            encoder.releaseOutputBuffer(outStatus, false)
                            if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                                outputDone = true
                            }
                        }
                    }
                }
            }

            // كتابة أي حزم صوت متبقية بعد آخر إطار فيديو
            writeInterleavedAudioUpTo(Long.MAX_VALUE)
        } finally {
            if (encoderStarted) {
                try {
                    encoder.stop()
                } catch (_: Exception) {}
            }
            try {
                encoder.release()
            } catch (_: Exception) {}

            if (muxerStarted) {
                try {
                    muxer.stop()
                } catch (_: Exception) {}
            }
            try {
                muxer.release()
            } catch (_: Exception) {}
        }
    }

    /// تحويل ARGB إلى ITU-R BT.709 Studio-Swing YUV420 مع فلتر 2x2 Box-Filter للكروما
    /// وإرجاع مدى البايتات الفعلي شاملاً محاذاة الأسطر (`yRowStride > width`) لمنع اقتطاع قنوات الألوان
    private fun fillBt709Yuv420ImageFromArgb(
        argb: IntArray,
        image: android.media.Image,
        width: Int,
        height: Int
    ): Int {
        val planes = image.planes
        val yBuf = planes[0].buffer
        val yRowStride = planes[0].rowStride
        val yPixelStride = planes[0].pixelStride

        val uBuf = planes[1].buffer
        val uRowStride = planes[1].rowStride
        val uPixelStride = planes[1].pixelStride

        val vBuf = planes[2].buffer
        val vRowStride = planes[2].rowStride
        val vPixelStride = planes[2].pixelStride

        val yCap = yBuf.capacity()
        val uCap = uBuf.capacity()
        val vCap = vBuf.capacity()

        var maxYWritten = 0
        for (y in 0 until height) {
            val rowOffset = y * width
            val yRowOffset = y * yRowStride
            for (x in 0 until width) {
                val c = argb[rowOffset + x]
                val r = (c shr 16) and 0xFF
                val g = (c shr 8) and 0xFF
                val b = c and 0xFF

                val yVal = (((47 * r + 157 * g + 16 * b + 128) shr 8) + 16).coerceIn(16, 235)
                val yIdx = yRowOffset + x * yPixelStride
                if (yIdx in 0 until yCap) {
                    yBuf.put(yIdx, yVal.toByte())
                    if (yIdx + 1 > maxYWritten) maxYWritten = yIdx + 1
                }
            }
        }

        var maxUWritten = 0
        var maxVWritten = 0
        val halfH = height / 2
        val halfW = width / 2
        for (uy in 0 until halfH) {
            val y0 = uy * 2
            val y1 = min(y0 + 1, height - 1)
            val row0 = y0 * width
            val row1 = y1 * width
            val uRowOffset = uy * uRowStride
            val vRowOffset = uy * vRowStride

            for (ux in 0 until halfW) {
                val x0 = ux * 2
                val x1 = min(x0 + 1, width - 1)

                val c00 = argb[row0 + x0]
                val c01 = argb[row0 + x1]
                val c10 = argb[row1 + x0]
                val c11 = argb[row1 + x1]

                val rAvg = (((c00 shr 16) and 0xFF) + ((c01 shr 16) and 0xFF) +
                        ((c10 shr 16) and 0xFF) + ((c11 shr 16) and 0xFF) + 2) shr 2
                val gAvg = (((c00 shr 8) and 0xFF) + ((c01 shr 8) and 0xFF) +
                        ((c10 shr 8) and 0xFF) + ((c11 shr 8) and 0xFF) + 2) shr 2
                val bAvg = ((c00 and 0xFF) + (c01 and 0xFF) +
                        (c10 and 0xFF) + (c11 and 0xFF) + 2) shr 2

                val uVal = (((-25 * rAvg - 87 * gAvg + 112 * bAvg + 128) shr 8) + 128).coerceIn(16, 240)
                val vVal = (((112 * rAvg - 102 * gAvg - 10 * bAvg + 128) shr 8) + 128).coerceIn(16, 240)

                val uIdx = uRowOffset + ux * uPixelStride
                val vIdx = vRowOffset + ux * vPixelStride
                if (uIdx in 0 until uCap) {
                    uBuf.put(uIdx, uVal.toByte())
                    if (uIdx + 1 > maxUWritten) maxUWritten = uIdx + 1
                }
                if (vIdx in 0 until vCap) {
                    vBuf.put(vIdx, vVal.toByte())
                    if (vIdx + 1 > maxVWritten) maxVWritten = vIdx + 1
                }
            }
        }

        val logicalYuvSize = (width * height * 3) / 2
        val chromaSpan = if (uPixelStride == 1 && vPixelStride == 1) {
            maxUWritten + maxVWritten
        } else {
            max(maxUWritten, maxVWritten)
        }
        val actualPlaneSpan = maxYWritten + chromaSpan
        return max(logicalYuvSize, actualPlaneSpan)
    }

    private fun fillBt709Nv12BufferFromArgb(
        argb: IntArray,
        buffer: ByteBuffer,
        width: Int,
        height: Int
    ): Int {
        val frameSize = width * height
        val yuv = ByteArray((frameSize * 3) / 2)
        var yIndex = 0
        var uvIndex = frameSize

        for (j in 0 until height) {
            val isEvenRow = (j and 1) == 0
            val nextJ = min(j + 1, height - 1)
            val row0 = j * width
            val row1 = nextJ * width

            for (i in 0 until width) {
                val c00 = argb[row0 + i]
                val r = (c00 shr 16) and 0xFF
                val g = (c00 shr 8) and 0xFF
                val b = c00 and 0xFF

                val yVal = (((47 * r + 157 * g + 16 * b + 128) shr 8) + 16).coerceIn(16, 235)
                yuv[yIndex++] = yVal.toByte()

                if (isEvenRow && (i and 1) == 0 && uvIndex + 1 < yuv.size) {
                    val nextI = min(i + 1, width - 1)
                    val c01 = argb[row0 + nextI]
                    val c10 = argb[row1 + i]
                    val c11 = argb[row1 + nextI]

                    val rAvg = (r + ((c01 shr 16) and 0xFF) + ((c10 shr 16) and 0xFF) + ((c11 shr 16) and 0xFF) + 2) shr 2
                    val gAvg = (g + ((c01 shr 8) and 0xFF) + ((c10 shr 8) and 0xFF) + ((c11 shr 8) and 0xFF) + 2) shr 2
                    val bAvg = (b + (c01 and 0xFF) + (c10 and 0xFF) + (c11 and 0xFF) + 2) shr 2

                    val uVal = (((-25 * rAvg - 87 * gAvg + 112 * bAvg + 128) shr 8) + 128).coerceIn(16, 240)
                    val vVal = (((112 * rAvg - 102 * gAvg - 10 * bAvg + 128) shr 8) + 128).coerceIn(16, 240)
                    yuv[uvIndex++] = uVal.toByte()
                    yuv[uvIndex++] = vVal.toByte()
                }
            }
        }
        val bytesToWrite = min(buffer.remaining(), yuv.size)
        buffer.put(yuv, 0, bytesToWrite)
        return bytesToWrite
    }

    // ─── Audio Decoding (MP3/WAV/M4A) + Stereo Normalization + AAC Encoding ───

    private fun monoPcm16ToStereo(monoBytes: ByteArray): ByteArray {
        val sampleCount = monoBytes.size / 2
        val stereo = ByteArray(sampleCount * 4)
        for (i in 0 until sampleCount) {
            val lo = monoBytes[i * 2]
            val hi = monoBytes[i * 2 + 1]
            val dst = i * 4
            stereo[dst] = lo
            stereo[dst + 1] = hi
            stereo[dst + 2] = lo
            stereo[dst + 3] = hi
        }
        return stereo
    }

    private fun decodeAudioFileToRawPcm16(
        audioPath: String,
        startOffsetUs: Long,
        totalDurationUs: Long,
        loopIfShorter: Boolean = true
    ): Triple<ByteArray, Int, Int>? {
        val extractor = MediaExtractor()
        extractor.setDataSource(audioPath)

        var audioTrackIndex = -1
        var inputFormat: MediaFormat? = null
        var inputMime = ""

        for (i in 0 until extractor.trackCount) {
            val fmt = extractor.getTrackFormat(i)
            val mime = fmt.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("audio/")) {
                audioTrackIndex = i
                inputFormat = fmt
                inputMime = mime
                break
            }
        }

        if (audioTrackIndex < 0 || inputFormat == null) {
            extractor.release()
            return null
        }

        extractor.selectTrack(audioTrackIndex)
        if (startOffsetUs > 0) {
            extractor.seekTo(startOffsetUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
        }

        var sampleRate = if (inputFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
            inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        } else {
            44100
        }
        var channelCount = if (inputFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
            inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceIn(1, 2)
        } else {
            2
        }

        var bytesPerSecond = sampleRate * channelCount * 2
        var targetTotalPcmBytes = ((totalDurationUs * bytesPerSecond.toLong()) / 1_000_000L).toInt()
        if (targetTotalPcmBytes <= 0) {
            extractor.release()
            return null
        }

        val decoder = MediaCodec.createDecoderByType(inputMime)
        decoder.configure(inputFormat, null, null, 0)
        decoder.start()

        val pcmOut = ByteArrayOutputStream(targetTotalPcmBytes + 8192)
        val decInfo = MediaCodec.BufferInfo()
        val scratchBuf = ByteBuffer.allocate(65536)
        var decoderDone = false
        var extractorEOS = false

        // الحفاظ على طوابع زمنية متصاعدة (Monotonic PTS) عند تكرار المقطع الصوتي
        var loopTimeOffsetUs = 0L
        var maxSeenPtsUs = 0L

        try {
            while (!decoderDone && pcmOut.size() < targetTotalPcmBytes) {
                if (!extractorEOS) {
                    val inIdx = decoder.dequeueInputBuffer(10_000)
                    if (inIdx >= 0) {
                        val inBuf = decoder.getInputBuffer(inIdx) ?: scratchBuf
                        inBuf.clear()
                        val sampleSize = extractor.readSampleData(inBuf, 0)
                        if (sampleSize < 0) {
                            if (loopIfShorter) {
                                loopTimeOffsetUs = maxSeenPtsUs + 23_220L
                                extractor.seekTo(0L, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                                val retrySize = extractor.readSampleData(inBuf, 0)
                                if (retrySize < 0) {
                                    decoder.queueInputBuffer(
                                        inIdx,
                                        0,
                                        0,
                                        maxSeenPtsUs,
                                        MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                    )
                                    extractorEOS = true
                                } else {
                                    val rawPts = max(0L, extractor.sampleTime)
                                    val monotonicPts = loopTimeOffsetUs + rawPts
                                    if (monotonicPts > maxSeenPtsUs) maxSeenPtsUs = monotonicPts
                                    decoder.queueInputBuffer(inIdx, 0, retrySize, monotonicPts, 0)
                                    extractor.advance()
                                }
                            } else {
                                decoder.queueInputBuffer(
                                    inIdx,
                                    0,
                                    0,
                                    maxSeenPtsUs,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                )
                                extractorEOS = true
                            }
                        } else {
                            val rawPts = max(0L, extractor.sampleTime)
                            val monotonicPts = loopTimeOffsetUs + rawPts
                            if (monotonicPts > maxSeenPtsUs) maxSeenPtsUs = monotonicPts
                            decoder.queueInputBuffer(inIdx, 0, sampleSize, monotonicPts, 0)
                            extractor.advance()
                        }
                    }
                }

                val outStatus = decoder.dequeueOutputBuffer(decInfo, 10_000)
                when {
                    outStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val actualFmt = decoder.outputFormat
                        if (actualFmt.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                            sampleRate = actualFmt.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        }
                        if (actualFmt.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                            channelCount = actualFmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceIn(1, 2)
                        }
                        bytesPerSecond = sampleRate * channelCount * 2
                        targetTotalPcmBytes = ((totalDurationUs * bytesPerSecond.toLong()) / 1_000_000L).toInt()
                    }
                    outStatus >= 0 -> {
                        val outBuf = decoder.getOutputBuffer(outStatus)
                        if (outBuf != null && decInfo.size > 0) {
                            outBuf.position(decInfo.offset)
                            outBuf.limit(decInfo.offset + decInfo.size)
                            val chunk = ByteArray(decInfo.size)
                            outBuf.get(chunk)
                            val needed = targetTotalPcmBytes - pcmOut.size()
                            if (needed > 0) {
                                pcmOut.write(chunk, 0, min(chunk.size, needed))
                            }
                        }
                        decoder.releaseOutputBuffer(outStatus, false)
                        if ((decInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            decoderDone = true
                        }
                    }
                    outStatus == MediaCodec.INFO_TRY_AGAIN_LATER && extractorEOS -> {
                        break
                    }
                }
            }
        } finally {
            try {
                decoder.stop()
            } catch (_: Exception) {}
            try {
                decoder.release()
            } catch (_: Exception) {}
            try {
                extractor.release()
            } catch (_: Exception) {}
        }

        val rawPcmBytes = pcmOut.toByteArray()
        if (rawPcmBytes.isEmpty()) return null
        return Triple(rawPcmBytes, sampleRate, channelCount)
    }

    private fun transcodeAudioToAac(
        audioPath: String,
        startOffsetUs: Long,
        totalDurationUs: Long,
        volume: Double,
        fadeIn: Boolean,
        fadeOut: Boolean
    ): Pair<MediaFormat, List<EncodedPacket>>? {
        val decoded = decodeAudioFileToRawPcm16(audioPath, startOffsetUs, totalDurationUs, true) ?: return null
        val rawPcmBytes = decoded.first
        val sampleRate = decoded.second
        val channelCount = decoded.third

        applyVolumeAndFadesToPcm16(
            pcmBytes = rawPcmBytes,
            sampleRate = sampleRate,
            channelCount = channelCount,
            baseVolume = volume.coerceIn(0.0, 1.5),
            fadeIn = fadeIn,
            fadeOut = fadeOut
        )

        return encodeRawPcm16ToAac(rawPcmBytes, sampleRate, channelCount)
    }

    /// ترميز تيار ملف PCM 16-bit إلى AAC بدفعات تدفقية 16 كيلوبايت دون قراءة الملف كاملاً في RAM
    private fun encodePcmFileStreamToAac(
        pcmFile: File,
        sampleRate: Int,
        channelCount: Int
    ): Pair<MediaFormat, List<EncodedPacket>> {
        val bytesPerSecond = max(1, sampleRate * channelCount * 2)
        val aacMime = MediaFormat.MIMETYPE_AUDIO_AAC
        val aacFormat = MediaFormat.createAudioFormat(aacMime, sampleRate, channelCount).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, 128_000)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
        }

        val encoder = MediaCodec.createEncoderByType(aacMime)
        encoder.configure(aacFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        encoder.start()

        val aacPackets = ArrayList<EncodedPacket>()
        var aacOutFormat: MediaFormat? = null
        val encInfo = MediaCodec.BufferInfo()
        val chunkBuffer = ByteArray(16384)
        var totalBytesRead = 0L
        var encInputDone = false
        var encOutputDone = false

        FileInputStream(pcmFile).use { fis ->
            try {
                while (!encOutputDone) {
                    if (!encInputDone) {
                        val inIdx = encoder.dequeueInputBuffer(10_000)
                        if (inIdx >= 0) {
                            val inBuf = encoder.getInputBuffer(inIdx)
                            if (inBuf == null) {
                                Thread.sleep(2)
                            } else {
                                inBuf.clear()
                                val maxChunk = min(chunkBuffer.size, inBuf.remaining())
                                val bytesRead = fis.read(chunkBuffer, 0, maxChunk)
                                if (bytesRead <= 0) {
                                    val ptsUs = (totalBytesRead * 1_000_000L) / bytesPerSecond.toLong()
                                    encoder.queueInputBuffer(
                                        inIdx,
                                        0,
                                        0,
                                        ptsUs,
                                        MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                    )
                                    encInputDone = true
                                } else {
                                    inBuf.put(chunkBuffer, 0, bytesRead)
                                    val ptsUs = (totalBytesRead * 1_000_000L) / bytesPerSecond.toLong()
                                    encoder.queueInputBuffer(inIdx, 0, bytesRead, ptsUs, 0)
                                    totalBytesRead += bytesRead
                                }
                            }
                        }
                    }

                    val outStatus = encoder.dequeueOutputBuffer(encInfo, 10_000)
                    when {
                        outStatus == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                            if (encInputDone) Thread.sleep(5)
                        }
                        outStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            aacOutFormat = encoder.outputFormat
                        }
                        outStatus >= 0 -> {
                            val outBuf = encoder.getOutputBuffer(outStatus)
                            if (outBuf != null && encInfo.size > 0 &&
                                (encInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0
                            ) {
                                outBuf.position(encInfo.offset)
                                outBuf.limit(encInfo.offset + encInfo.size)
                                val data = ByteArray(encInfo.size)
                                outBuf.get(data)
                                aacPackets.add(
                                    EncodedPacket(
                                        data = data,
                                        presentationTimeUs = encInfo.presentationTimeUs,
                                        flags = encInfo.flags
                                    )
                                )
                            }
                            encoder.releaseOutputBuffer(outStatus, false)
                            if ((encInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                                encOutputDone = true
                            }
                        }
                    }
                }
            } finally {
                try { encoder.stop() } catch (_: Exception) {}
                try { encoder.release() } catch (_: Exception) {}
            }
        }

        val finalAacFormat = aacOutFormat ?: encoder.outputFormat
        return Pair(finalAacFormat, aacPackets)
    }

    private fun encodeRawPcm16ToAac(
        rawPcmBytes: ByteArray,
        sampleRate: Int,
        channelCount: Int
    ): Pair<MediaFormat, List<EncodedPacket>> {
        val bytesPerSecond = max(1, sampleRate * channelCount * 2)
        val aacMime = MediaFormat.MIMETYPE_AUDIO_AAC
        val aacFormat = MediaFormat.createAudioFormat(aacMime, sampleRate, channelCount).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, 128_000)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
        }

        val encoder = MediaCodec.createEncoderByType(aacMime)
        encoder.configure(aacFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        encoder.start()

        val aacPackets = ArrayList<EncodedPacket>()
        var aacOutFormat: MediaFormat? = null
        val encInfo = MediaCodec.BufferInfo()
        var pcmCursor = 0
        var encInputDone = false
        var encOutputDone = false

        try {
            while (!encOutputDone) {
                if (!encInputDone) {
                    val inIdx = encoder.dequeueInputBuffer(10_000)
                    if (inIdx >= 0) {
                        val inBuf = encoder.getInputBuffer(inIdx)
                        if (pcmCursor >= rawPcmBytes.size || inBuf == null) {
                            val ptsUs = (pcmCursor.toLong() * 1_000_000L) / bytesPerSecond.toLong()
                            encoder.queueInputBuffer(
                                inIdx,
                                0,
                                0,
                                ptsUs,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            encInputDone = true
                        } else {
                            inBuf.clear()
                            val chunkLen = min(min(4096, inBuf.remaining()), rawPcmBytes.size - pcmCursor)
                            inBuf.put(rawPcmBytes, pcmCursor, chunkLen)
                            val ptsUs = (pcmCursor.toLong() * 1_000_000L) / bytesPerSecond.toLong()
                            encoder.queueInputBuffer(inIdx, 0, chunkLen, ptsUs, 0)
                            pcmCursor += chunkLen
                        }
                    }
                }

                val outStatus = encoder.dequeueOutputBuffer(encInfo, 10_000)
                when {
                    outStatus == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        if (encInputDone) Thread.sleep(5)
                    }
                    outStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        aacOutFormat = encoder.outputFormat
                    }
                    outStatus >= 0 -> {
                        val outBuf = encoder.getOutputBuffer(outStatus)
                        if (outBuf != null && encInfo.size > 0 &&
                            (encInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0
                        ) {
                            outBuf.position(encInfo.offset)
                            outBuf.limit(encInfo.offset + encInfo.size)
                            val data = ByteArray(encInfo.size)
                            outBuf.get(data)
                            aacPackets.add(
                                EncodedPacket(
                                    data = data,
                                    presentationTimeUs = encInfo.presentationTimeUs,
                                    flags = encInfo.flags
                                )
                            )
                        }
                        encoder.releaseOutputBuffer(outStatus, false)
                        if ((encInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            encOutputDone = true
                        }
                    }
                }
            }

            val finalAacFormat = aacOutFormat ?: encoder.outputFormat
            return Pair(finalAacFormat, aacPackets)
        } finally {
            try {
                encoder.stop()
            } catch (_: Exception) {}
            try {
                encoder.release()
            } catch (_: Exception) {}
        }
    }

    private fun applyVolumeAndFadesToPcm16(
        pcmBytes: ByteArray,
        sampleRate: Int,
        channelCount: Int,
        baseVolume: Double,
        fadeIn: Boolean,
        fadeOut: Boolean
    ) {
        val safeRate = max(1, sampleRate)
        val safeChannels = max(1, channelCount)
        val frameByteStride = safeChannels * 2
        val totalFrames = pcmBytes.size / frameByteStride
        if (totalFrames <= 0) return

        val totalSeconds = totalFrames.toDouble() / safeRate.toDouble()
        val defaultFadeSec = 1.2
        val fadeWindowSec = when {
            fadeIn && fadeOut -> min(defaultFadeSec, totalSeconds * 0.5)
            fadeIn || fadeOut -> min(defaultFadeSec, totalSeconds)
            else -> 0.0
        }

        val kneeStart = 28000.0
        val maxCeiling = 32700.0
        val headroom = maxCeiling - kneeStart

        for (frameIdx in 0 until totalFrames) {
            val currentSec = frameIdx.toDouble() / safeRate.toDouble()
            val remainingFrames = max(0, totalFrames - 1 - frameIdx)
            val remainingSec = remainingFrames.toDouble() / safeRate.toDouble()

            var gain = baseVolume
            if (fadeIn && fadeWindowSec > 1e-9 && currentSec < fadeWindowSec) {
                val ratio = (currentSec / fadeWindowSec).coerceIn(0.0, 1.0)
                gain *= sin(ratio * PI * 0.5)
            }
            if (fadeOut && fadeWindowSec > 1e-9 && remainingSec < fadeWindowSec) {
                val ratio = (remainingSec / fadeWindowSec).coerceIn(0.0, 1.0)
                gain *= sin(ratio * PI * 0.5)
            }

            val frameBase = frameIdx * frameByteStride
            for (ch in 0 until safeChannels) {
                val byteIdx = frameBase + ch * 2
                val lo = pcmBytes[byteIdx].toInt() and 0xFF
                val hi = pcmBytes[byteIdx + 1].toInt()
                val sample = ((hi shl 8) or lo).toDouble() * gain
                val absS = abs(sample)
                val limited = if (absS <= kneeStart) {
                    sample.roundToInt()
                } else {
                    val sign = if (sample >= 0.0) 1.0 else -1.0
                    val compressed = kneeStart + headroom * tanh((absS - kneeStart) / headroom)
                    (sign * compressed).roundToInt().coerceIn(-32767, 32767)
                }

                pcmBytes[byteIdx] = (limited and 0xFF).toByte()
                pcmBytes[byteIdx + 1] = ((limited shr 8) and 0xFF).toByte()
            }
        }
    }

    // ─── Container MIME Inspection, Save & Share (VID-008) ─────────────────────

    private fun detectContainerMimeType(file: File): String {
        try {
            if (file.exists() && file.length() >= 12L) {
                RandomAccessFile(file, "r").use { raf ->
                    val hdr = ByteArray(12)
                    if (raf.read(hdr) == 12) {
                        if (hdr[0] == 0x52.toByte() &&
                            hdr[1] == 0x49.toByte() &&
                            hdr[2] == 0x46.toByte() &&
                            hdr[3] == 0x46.toByte() &&
                            hdr[8] == 0x41.toByte() &&
                            hdr[9] == 0x56.toByte() &&
                            hdr[10] == 0x49.toByte() &&
                            hdr[11] == 0x20.toByte()
                        ) {
                            return "video/x-msvideo"
                        }
                        if (hdr[4] == 0x66.toByte() &&
                            hdr[5] == 0x74.toByte() &&
                            hdr[6] == 0x79.toByte() &&
                            hdr[7] == 0x70.toByte()
                        ) {
                            return "video/mp4"
                        }
                    }
                }
            }
        } catch (_: Exception) {}
        return if (file.extension.lowercase() == "avi") "video/x-msvideo" else "video/mp4"
    }

    private fun findExistingDownloadUri(fileName: String, expectedSizeBytes: Long): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        return try {
            val resolver = applicationContext.contentResolver
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val projection = arrayOf(
                MediaStore.MediaColumns._ID,
                MediaStore.MediaColumns.SIZE
            )
            val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
            val selectionArgs = arrayOf(fileName)
            resolver.query(collection, projection, selection, selectionArgs, null)?.use { cursor ->
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(0)
                    val size = cursor.getLong(1)
                    if (size == expectedSizeBytes && size > 0L) {
                        return ContentUris.withAppendedId(collection, id)
                    }
                }
            }
            null
        } catch (_: Exception) {
            null
        }
    }

    private fun saveFileToDownloadsAndGallery(
        sourcePath: String,
        fileName: String,
        mimeType: String
    ): String {
        val srcFile = File(sourcePath)
        if (!srcFile.exists()) {
            throw IllegalArgumentException("Source file does not exist: $sourcePath")
        }

        val actualMime = detectContainerMimeType(srcFile)
        val expectedExt = if (actualMime == "video/x-msvideo") "avi" else "mp4"
        val normalizedFileName = if (fileName.lowercase().endsWith(".$expectedExt")) {
            fileName
        } else {
            val base = fileName.substringBeforeLast('.', fileName)
            "$base.$expectedExt"
        }

        val subFolder = "OurLoveStory"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver

            if (actualMime.startsWith("video/")) {
                try {
                    val videoValues = ContentValues().apply {
                        put(MediaStore.Video.Media.DISPLAY_NAME, normalizedFileName)
                        put(MediaStore.Video.Media.MIME_TYPE, actualMime)
                        put(
                            MediaStore.Video.Media.RELATIVE_PATH,
                            "${Environment.DIRECTORY_MOVIES}/$subFolder"
                        )
                        put(MediaStore.Video.Media.IS_PENDING, 1)
                    }
                    val videoCollection = MediaStore.Video.Media.getContentUri(
                        MediaStore.VOLUME_EXTERNAL_PRIMARY
                    )
                    val videoUri = resolver.insert(videoCollection, videoValues)
                    if (videoUri != null) {
                        resolver.openOutputStream(videoUri)?.use { outStream ->
                            FileInputStream(srcFile).use { inStream ->
                                inStream.copyTo(outStream, bufferSize = 64 * 1024)
                            }
                        }
                        videoValues.clear()
                        videoValues.put(MediaStore.Video.Media.IS_PENDING, 0)
                        resolver.update(videoUri, videoValues, null, null)
                    }
                } catch (_: Exception) {}
            }

            val existingUri = findExistingDownloadUri(normalizedFileName, srcFile.length())
            if (existingUri == null) {
                val downloadValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, normalizedFileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, actualMime)
                    put(
                        MediaStore.MediaColumns.RELATIVE_PATH,
                        "${Environment.DIRECTORY_DOWNLOADS}/$subFolder"
                    )
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }

                val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                val itemUri = resolver.insert(collection, downloadValues)
                    ?: throw IllegalStateException("Failed to create MediaStore entry")

                resolver.openOutputStream(itemUri)?.use { outStream ->
                    FileInputStream(srcFile).use { inStream ->
                        inStream.copyTo(outStream, bufferSize = 64 * 1024)
                    }
                }

                downloadValues.clear()
                downloadValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(itemUri, downloadValues, null, null)
            }

            return "/storage/emulated/0/${Environment.DIRECTORY_DOWNLOADS}/$subFolder/$normalizedFileName"
        } else {
            val downloadsDir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            )
            val targetDir = File(downloadsDir, subFolder)
            if (!targetDir.exists()) {
                targetDir.mkdirs()
            }
            val destFile = File(targetDir, normalizedFileName)
            FileInputStream(srcFile).use { inStream ->
                FileOutputStream(destFile).use { outStream ->
                    inStream.copyTo(outStream, bufferSize = 64 * 1024)
                }
            }
            MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(destFile.absolutePath),
                arrayOf(actualMime),
                null
            )
            return destFile.absolutePath
        }
    }

    private fun shareOrOpenMedia(filePath: String, title: String, requestedMime: String? = null) {
        val srcFile = File(filePath)
        if (!srcFile.exists() || srcFile.length() <= 0L) {
            throw IllegalArgumentException("Cannot share non-existent or empty video file: $filePath")
        }

        val actualMime = detectContainerMimeType(srcFile)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            // البحث أولاً عن الـ Uri الموجود في MediaStore لمنع تكرار نسخ الفيديو عند كل مشاركة
            var uri = findExistingDownloadUri(srcFile.name, srcFile.length())
            if (uri == null) {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, srcFile.name)
                    put(MediaStore.MediaColumns.MIME_TYPE, actualMime)
                    put(
                        MediaStore.MediaColumns.RELATIVE_PATH,
                        "${Environment.DIRECTORY_DOWNLOADS}/OurLoveStory"
                    )
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val insertedUri = resolver.insert(
                    MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                    values
                ) ?: throw IllegalStateException("Failed to create shareable MediaStore URI")

                try {
                    resolver.openOutputStream(insertedUri)?.use { out ->
                        FileInputStream(srcFile).use { input ->
                            input.copyTo(out, bufferSize = 64 * 1024)
                        }
                    } ?: throw IllegalStateException("Failed to open output stream for share URI")

                    values.clear()
                    values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    resolver.update(insertedUri, values, null, null)
                    uri = insertedUri
                } catch (e: Exception) {
                    try {
                        resolver.delete(insertedUri, null, null)
                    } catch (_: Exception) {}
                    throw e
                }
            }

            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = actualMime
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TITLE, title)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(shareIntent, title))
        } else {
            val values = ContentValues().apply {
                put(MediaStore.Video.Media.TITLE, title)
                put(MediaStore.Video.Media.DISPLAY_NAME, srcFile.name)
                put(MediaStore.Video.Media.MIME_TYPE, actualMime)
                put(MediaStore.Video.Media.DATA, srcFile.absolutePath)
            }
            val uri = applicationContext.contentResolver.insert(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                values
            ) ?: Uri.fromFile(srcFile)

            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = actualMime
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TITLE, title)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(shareIntent, title))
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == pickAudioRequestCode) {
            val callback = pendingAudioResult
            pendingAudioResult = null
            if (callback == null) return

            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                callback.success(null)
                return
            }

            try {
                val uri: Uri = data.data!!
                val displayName = queryDisplayName(uri) ?: "custom_audio_${System.currentTimeMillis()}.mp3"
                val safeExt = displayName.substringAfterLast('.', "mp3")
                val audioDir = File(filesDir, "studio_audio")
                if (!audioDir.exists()) audioDir.mkdirs()

                val targetFile = File(audioDir, "audio_${System.currentTimeMillis()}.$safeExt")
                contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(targetFile).use { output ->
                        input.copyTo(output)
                    }
                }

                callback.success(
                    mapOf(
                        "path" to targetFile.absolutePath,
                        "name" to displayName
                    )
                )
            } catch (e: Exception) {
                callback.error("AUDIO_PICK_ERROR", e.message, null)
            }
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        var name: String? = null
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0) {
                    name = cursor.getString(idx)
                }
            }
        }
        return name
    }

    // ─── GPU-Native Surface EGL Subsystem & Zero-Copy Hardware Pipeline ─────────

    private class EglCore(sharedContext: EGLContext? = null) {
        private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
        private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
        private var eglConfig: EGLConfig? = null

        companion object {
            private const val EGL_RECORDABLE_ANDROID = 0x3142
        }

        init {
            eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            if (eglDisplay == EGL14.EGL_NO_DISPLAY) {
                throw RuntimeException("Unable to get EGL14 display")
            }
            val version = IntArray(2)
            if (!EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) {
                throw RuntimeException("Unable to initialize EGL14")
            }

            val attribList = intArrayOf(
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL_RECORDABLE_ANDROID, 1,
                EGL14.EGL_NONE
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val numConfigs = IntArray(1)
            EGL14.eglChooseConfig(eglDisplay, attribList, 0, configs, 0, configs.size, numConfigs, 0)
            if (numConfigs[0] <= 0 || configs[0] == null) {
                val fallbackAttribs = intArrayOf(
                    EGL14.EGL_RED_SIZE, 8,
                    EGL14.EGL_GREEN_SIZE, 8,
                    EGL14.EGL_BLUE_SIZE, 8,
                    EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                    EGL14.EGL_NONE
                )
                EGL14.eglChooseConfig(eglDisplay, fallbackAttribs, 0, configs, 0, configs.size, numConfigs, 0)
            }
            eglConfig = configs[0] ?: throw RuntimeException("Unable to find suitable EGLConfig")

            val contextAttribs = intArrayOf(
                EGL14.EGL_CONTEXT_CLIENT_VERSION, 2,
                EGL14.EGL_NONE
            )
            val shareCtx = sharedContext ?: EGL14.EGL_NO_CONTEXT
            eglContext = EGL14.eglCreateContext(eglDisplay, eglConfig, shareCtx, contextAttribs, 0)
            if (eglContext == EGL14.EGL_NO_CONTEXT) {
                throw RuntimeException("Failed to create EGL context")
            }
        }

        fun createWindowSurface(surface: Surface): EGLSurface {
            val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
            val eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, eglConfig, surface, surfaceAttribs, 0)
            if (eglSurface == EGL14.EGL_NO_SURFACE) {
                throw RuntimeException("Failed to create EGL window surface")
            }
            return eglSurface
        }

        fun makeCurrent(eglSurface: EGLSurface) {
            if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)) {
                throw RuntimeException("eglMakeCurrent failed")
            }
        }

        fun swapBuffers(eglSurface: EGLSurface): Boolean {
            return EGL14.eglSwapBuffers(eglDisplay, eglSurface)
        }

        fun setPresentationTime(eglSurface: EGLSurface, nsecs: Long) {
            EGLExt.eglPresentationTimeANDROID(eglDisplay, eglSurface, nsecs)
        }

        fun releaseSurface(eglSurface: EGLSurface) {
            if (eglSurface != EGL14.EGL_NO_SURFACE) {
                EGL14.eglDestroySurface(eglDisplay, eglSurface)
            }
        }

        fun release() {
            if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
                EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
                if (eglContext != EGL14.EGL_NO_CONTEXT) {
                    EGL14.eglDestroyContext(eglDisplay, eglContext)
                    eglContext = EGL14.EGL_NO_CONTEXT
                }
                EGL14.eglTerminate(eglDisplay)
                eglDisplay = EGL14.EGL_NO_DISPLAY
            }
        }
    }

    private class GpuTextureProgram {
        private var programHandle: Int = 0
        private var uMVPMatrixLoc: Int = 0
        private var aPositionLoc: Int = 0
        private var aTextureCoordLoc: Int = 0
        private var sTextureLoc: Int = 0

        private val vertexShaderCode = """
            uniform mat4 uMVPMatrix;
            attribute vec4 aPosition;
            attribute vec2 aTextureCoord;
            varying vec2 vTextureCoord;
            void main() {
                gl_Position = uMVPMatrix * aPosition;
                vTextureCoord = aTextureCoord;
            }
        """.trimIndent()

        private val fragmentShaderCode = """
            precision mediump float;
            varying vec2 vTextureCoord;
            uniform sampler2D sTexture;
            void main() {
                gl_FragColor = texture2D(sTexture, vTextureCoord);
            }
        """.trimIndent()

        private val vertexCoords = floatArrayOf(
            -1.0f, -1.0f,
             1.0f, -1.0f,
            -1.0f,  1.0f,
             1.0f,  1.0f
        )

        private val textureCoords = floatArrayOf(
            0.0f, 1.0f,
            1.0f, 1.0f,
            0.0f, 0.0f,
            1.0f, 0.0f
        )

        private val vertexBuffer: FloatBuffer
        private val textureBuffer: FloatBuffer

        init {
            val vBb = ByteBuffer.allocateDirect(vertexCoords.size * 4).order(ByteOrder.nativeOrder())
            vertexBuffer = vBb.asFloatBuffer().apply {
                put(vertexCoords)
                position(0)
            }

            val tBb = ByteBuffer.allocateDirect(textureCoords.size * 4).order(ByteOrder.nativeOrder())
            textureBuffer = tBb.asFloatBuffer().apply {
                put(textureCoords)
                position(0)
            }

            val vShader = compileShader(GLES20.GL_VERTEX_SHADER, vertexShaderCode)
            val fShader = compileShader(GLES20.GL_FRAGMENT_SHADER, fragmentShaderCode)
            programHandle = GLES20.glCreateProgram()
            GLES20.glAttachShader(programHandle, vShader)
            GLES20.glAttachShader(programHandle, fShader)
            GLES20.glLinkProgram(programHandle)

            // تحرير مقابض الشيدرز المؤقتة فور الربط لمنع تسريب موارد GPU
            GLES20.glDeleteShader(vShader)
            GLES20.glDeleteShader(fShader)

            val linkStatus = IntArray(1)
            GLES20.glGetProgramiv(programHandle, GLES20.GL_LINK_STATUS, linkStatus, 0)
            if (linkStatus[0] != GLES20.GL_TRUE) {
                val error = GLES20.glGetProgramInfoLog(programHandle)
                GLES20.glDeleteProgram(programHandle)
                throw RuntimeException("Could not link GL program: $error")
            }

            uMVPMatrixLoc = GLES20.glGetUniformLocation(programHandle, "uMVPMatrix")
            aPositionLoc = GLES20.glGetAttribLocation(programHandle, "aPosition")
            aTextureCoordLoc = GLES20.glGetAttribLocation(programHandle, "aTextureCoord")
            sTextureLoc = GLES20.glGetUniformLocation(programHandle, "sTexture")
        }

        private fun compileShader(type: Int, shaderCode: String): Int {
            val shader = GLES20.glCreateShader(type)
            GLES20.glShaderSource(shader, shaderCode)
            GLES20.glCompileShader(shader)
            val compiled = IntArray(1)
            GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
            if (compiled[0] == 0) {
                val info = GLES20.glGetShaderInfoLog(shader)
                GLES20.glDeleteShader(shader)
                throw RuntimeException("Could not compile shader $type: $info")
            }
            return shader
        }

        fun draw(textureId: Int, mvpMatrix: FloatArray) {
            GLES20.glUseProgram(programHandle)

            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
            GLES20.glUniform1i(sTextureLoc, 0)

            GLES20.glUniformMatrix4fv(uMVPMatrixLoc, 1, false, mvpMatrix, 0)

            GLES20.glEnableVertexAttribArray(aPositionLoc)
            GLES20.glVertexAttribPointer(aPositionLoc, 2, GLES20.GL_FLOAT, false, 8, vertexBuffer)

            GLES20.glEnableVertexAttribArray(aTextureCoordLoc)
            GLES20.glVertexAttribPointer(aTextureCoordLoc, 2, GLES20.GL_FLOAT, false, 8, textureBuffer)

            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

            GLES20.glDisableVertexAttribArray(aPositionLoc)
            GLES20.glDisableVertexAttribArray(aTextureCoordLoc)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
            GLES20.glUseProgram(0)
        }

        fun release() {
            if (programHandle != 0) {
                GLES20.glDeleteProgram(programHandle)
                programHandle = 0
            }
        }
    }

    /// مسار التصدير العتادي عبر سطح الرسوميات (GPU Surface Pipeline) مع تداخل الصوت والفيديو وحماية EOS
    private fun streamEncodeFramesWithGpuSurfaceAndMuxToMp4(
        aviFile: File,
        frameLocations: List<AviFrameLocation>,
        outputMp4File: File,
        width: Int,
        height: Int,
        sourceFps: Int,
        targetFps: Int,
        totalOutputFrames: Int,
        codecMime: String,
        bitrateBps: Int,
        audioFormat: MediaFormat?,
        audioPackets: List<EncodedPacket>,
        cropToFill: Boolean = false
    ) {
        val format = MediaFormat.createVideoFormat(codecMime, width, height).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface
            )
            setInteger(MediaFormat.KEY_BIT_RATE, bitrateBps)
            setInteger(MediaFormat.KEY_FRAME_RATE, targetFps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT709)
            setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED)
            setInteger(MediaFormat.KEY_COLOR_TRANSFER, MediaFormat.COLOR_TRANSFER_SDR_VIDEO)
        }

        val encoder = MediaCodec.createEncoderByType(codecMime)
        encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val inputSurface = encoder.createInputSurface()
        encoder.start()

        val muxer = MediaMuxer(outputMp4File.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var muxerStarted = false
        var videoTrackIdx = -1
        var audioTrackIdx = -1
        var audioPacketCursor = 0
        val audInfo = MediaCodec.BufferInfo()

        var eglCore: EglCore? = null
        var eglSurface: EGLSurface? = null
        var gpuProgram: GpuTextureProgram? = null
        val textureIds = IntArray(1)

        fun writeInterleavedAudioUpTo(maxPtsUs: Long) {
            if (!muxerStarted || audioTrackIdx < 0) return
            while (audioPacketCursor < audioPackets.size) {
                val pkt = audioPackets[audioPacketCursor]
                if (pkt.presentationTimeUs > maxPtsUs) break
                audInfo.set(0, pkt.data.size, pkt.presentationTimeUs, pkt.flags)
                muxer.writeSampleData(audioTrackIdx, ByteBuffer.wrap(pkt.data), audInfo)
                audioPacketCursor++
            }
        }

        try {
            eglCore = EglCore()
            eglSurface = eglCore.createWindowSurface(inputSurface)
            eglCore.makeCurrent(eglSurface)

            gpuProgram = GpuTextureProgram()

            GLES20.glGenTextures(1, textureIds, 0)
            val texId = textureIds[0]
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)

            val mvpMatrix = FloatArray(16)
            Matrix.setIdentityM(mvpMatrix, 0)

            val bufferInfo = MediaCodec.BufferInfo()
            var cachedSrcFrameIdx = -1
            var cachedBitmap: Bitmap? = null

            fun drainEncoder(endOfStream: Boolean) {
                if (endOfStream) {
                    encoder.signalEndOfInputStream()
                }
                var eosTryAgainCount = 0
                val maxEosRetries = 200
                while (true) {
                    val outStatus = encoder.dequeueOutputBuffer(bufferInfo, if (endOfStream) 10_000L else 0L)
                    when {
                        outStatus == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                            if (!endOfStream) return
                            eosTryAgainCount++
                            if (eosTryAgainCount > maxEosRetries) {
                                break
                            }
                        }
                        outStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            if (muxerStarted) throw IllegalStateException("Format changed twice")
                            videoTrackIdx = muxer.addTrack(encoder.outputFormat)
                            if (audioFormat != null && audioPackets.isNotEmpty()) {
                                audioTrackIdx = muxer.addTrack(audioFormat)
                            }
                            muxer.start()
                            muxerStarted = true
                        }
                        outStatus >= 0 -> {
                            eosTryAgainCount = 0
                            val outBuf = encoder.getOutputBuffer(outStatus)
                            if (outBuf != null && bufferInfo.size > 0 &&
                                (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0
                            ) {
                                if (!muxerStarted) {
                                    videoTrackIdx = muxer.addTrack(encoder.outputFormat)
                                    if (audioFormat != null && audioPackets.isNotEmpty()) {
                                        audioTrackIdx = muxer.addTrack(audioFormat)
                                    }
                                    muxer.start()
                                    muxerStarted = true
                                }
                                outBuf.position(bufferInfo.offset)
                                outBuf.limit(bufferInfo.offset + bufferInfo.size)
                                muxer.writeSampleData(videoTrackIdx, outBuf, bufferInfo)
                                writeInterleavedAudioUpTo(bufferInfo.presentationTimeUs)
                            }
                            encoder.releaseOutputBuffer(outStatus, false)
                            if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                                return
                            }
                        }
                    }
                }
            }

            RandomAccessFile(aviFile, "r").use { raf ->
                for (outIdx in 0 until totalOutputFrames) {
                    val srcIdx = ((outIdx.toLong() * sourceFps.toLong()) / targetFps.toLong())
                        .toInt()
                        .coerceIn(0, frameLocations.size - 1)

                    if (srcIdx != cachedSrcFrameIdx) {
                        val loc = frameLocations[srcIdx]
                        val pngBytes = ByteArray(loc.size)
                        raf.seek(loc.offset)
                        raf.readFully(pngBytes)

                        cachedBitmap?.recycle()
                        val decoded = BitmapFactory.decodeByteArray(pngBytes, 0, pngBytes.size)
                            ?: throw IllegalStateException("Null frame bitmap at index $srcIdx")
                        cachedBitmap = decoded
                        cachedSrcFrameIdx = srcIdx

                        // رفع الـ Texture إلى GPU فقط عند تغير الإطار المصدر الفعلي
                        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
                        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, decoded, 0)
                        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)

                        computeAspectRatioMvpMatrix(
                            srcWidth = decoded.width,
                            srcHeight = decoded.height,
                            dstWidth = width,
                            dstHeight = height,
                            cropToFill = cropToFill,
                            outMatrix = mvpMatrix
                        )
                    }

                    GLES20.glViewport(0, 0, width, height)
                    GLES20.glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
                    GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

                    gpuProgram.draw(texId, mvpMatrix)

                    val ptsNs = (outIdx.toLong() * 1_000_000_000L) / targetFps.toLong()
                    eglCore.setPresentationTime(eglSurface, ptsNs)
                    eglCore.swapBuffers(eglSurface)

                    drainEncoder(false)
                }
            }

            cachedBitmap?.recycle()
            cachedBitmap = null

            drainEncoder(true)
            writeInterleavedAudioUpTo(Long.MAX_VALUE)
        } finally {
            if (textureIds[0] != 0) {
                GLES20.glDeleteTextures(1, textureIds, 0)
            }
            gpuProgram?.release()
            if (eglCore != null && eglSurface != null) {
                eglCore.releaseSurface(eglSurface)
            }
            eglCore?.release()
            inputSurface.release()

            try { encoder.stop() } catch (_: Exception) {}
            try { encoder.release() } catch (_: Exception) {}
            if (muxerStarted) {
                try { muxer.stop() } catch (_: Exception) {}
            }
            try { muxer.release() } catch (_: Exception) {}
        }
    }
}