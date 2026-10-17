package com.our.loveStory

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
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
                                    // توحيد القنوات الصوتية إلى Stereo (قناتين) مع الاحتفاظ بمعدل العينات الفعلي للمصدر (VID-005)
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
                                    allowCodecFallback = allowCodecFallback
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
        allowCodecFallback: Boolean = false
    ): File {
        val aviFile = File(aviPath)
        if (!aviFile.exists() || aviFile.length() < 32L) {
            throw IllegalArgumentException("AVI file is missing or corrupt: $aviPath")
        }

        // فهرسة مواقع إطارات PNG داخل حاوية AVI بدون تحميل الملف كاملًا في الذاكرة (VID-003 / VID-009)
        val frameLocations = indexPngFramesInAvi(aviFile)
        if (frameLocations.isEmpty()) {
            throw IllegalStateException("No valid PNG frames (00dc) found in AVI container")
        }

        // التحقق من الأبعاد الزوجية المتوافقة مع YUV420 و MediaCodec (VID-011 / VID-017)
        val isFullHd = max(requestedWidth, requestedHeight) >= 1400 || min(requestedWidth, requestedHeight) >= 1000
        val aspect = requestedWidth.toDouble() / max(1, requestedHeight).toDouble()
        val (encWidth, encHeight) = when {
            aspect < 0.8 -> if (isFullHd) Pair(1080, 1920) else Pair(720, 1280)   // 9:16 Portrait
            aspect > 1.2 -> if (isFullHd) Pair(1920, 1080) else Pair(1280, 720)   // 16:9 Landscape
            else -> if (isFullHd) Pair(1080, 1080) else Pair(720, 720)            // 1:1 Square
        }
        if (encWidth % 2 != 0 || encHeight % 2 != 0) {
            throw IllegalArgumentException("Encoder dimensions must be even: ${encWidth}x$encHeight")
        }

        // حساب معدل الإطارات المستهدف بدقة بدون مضاعفة خاطئة تحول 20->30 إلى 40 FPS (VID-002)
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

        // التحقق الصريح من دعم الجهاز لـ HEVC أو الإعداد المختار دون تحويل صامت إلى H.264 (VID-017)
        if (!allowCodecFallback && !isEncoderSupported(normalizedMime, encWidth, encHeight, targetFps, requestedBitrateBps)) {
            throw IllegalStateException(
                "الجهاز لا يدعم ترميز $normalizedMime بدقة ${encWidth}x$encHeight ومعدل $targetFps FPS."
            )
        }

        // 1. ترميز الصوت أولاً (حجم بياناته صغير ومحدود) لتجهيز مسار الصوت في MediaMuxer
        var audioFormat: MediaFormat? = null
        var audioPackets: List<EncodedPacket> = emptyList()
        if (!processedPcmPath.isNullOrBlank() && File(processedPcmPath).exists()) {
            val pcmBytes = File(processedPcmPath).readBytes()
            if (pcmBytes.isNotEmpty()) {
                val encoded = encodeRawPcm16ToAac(
                    rawPcmBytes = pcmBytes,
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

        // 2. ترميز الفيديو وتدفقه مباشرة إلى MediaMuxer إطاراً بإطار دون تخزين حزم الفيديو في الذاكرة (VID-003 / VID-006)
        val outFile = File(outputMp4Path)
        if (outFile.exists()) outFile.delete()

        try {
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
                audioPackets = audioPackets
            )
        } catch (e: Exception) {
            if (outFile.exists()) outFile.delete()
            if (!allowCodecFallback) {
                throw IllegalStateException(
                    "فشل الترميز العتادي ($normalizedMime ${encWidth}x$encHeight @ $targetFps FPS): ${e.message}",
                    e
                )
            }
            // وضع التوافق الاختياري فقط إذا طُلب صراحة (`allowCodecFallback == true`)
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
                audioPackets = audioPackets
            )
        }

        // 3. الفحص الذاتي الصارم (Oracle Verification) عبر MediaMetadataRetriever للتأكد من سلامة ملف الـ MP4 (VID-018)
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

    /// فهرسة مواقع إطارات PNG (`00dc`) داخل حاوية RIFF/AVI عبر `RandomAccessFile` بدون قراءة الملف كاملًا في الذاكرة (VID-003 / VID-009)
    private fun indexPngFramesInAvi(aviFile: File): List<AviFrameLocation> {
        val fileLen = aviFile.length()
        if (fileLen < 32L) return emptyList()

        val locations = ArrayList<AviFrameLocation>()
        RandomAccessFile(aviFile, "r").use { raf ->
            val header = ByteArray(12)
            if (raf.read(header) != 12) return emptyList()

            // التحقق الصارم من توقيع "RIFF" و "AVI " (VID-009)
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

                // فحص قوائم LIST ("LIST" = 0x4C, 0x49, 0x53, 0x54)
                if (c0 == 0x4C && c1 == 0x49 && c2 == 0x53 && c3 == 0x54 && chunkSize >= 4L) {
                    if (raf.read(listTypeBuf) != 4) break
                    // الدخول فقط داخل قائمة "movi" (0x6D, 0x6F, 0x76, 0x69)
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
                                // التحقق من توقيع PNG القياسي في بداية مقطع 00dc (VID-009)
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

    /// ترميز الإطارات وتدفقها مباشرة إلى `MediaMuxer` دون تخزين جميع الإطارات أو حزم الفيديو في الذاكرة (VID-003 / VID-006)
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
        audioPackets: List<EncodedPacket>
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
                                // حساب فهرس الإطار المصدر من الزمن الفعلي للإطار المستهدف دون مضاعفة تشوه التوقيت (VID-002)
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
                                        val scaledBitmap = if (rawBitmap.width == width && rawBitmap.height == height) {
                                            rawBitmap
                                        } else {
                                            Bitmap.createScaledBitmap(rawBitmap, width, height, true)
                                        }
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

                                // احترام عقد MediaCodec الصحيح بين getInputImage و getInputBuffer (VID-006)
                                val inputImage = try {
                                    encoder.getInputImage(inBufIdx)
                                } catch (_: Exception) {
                                    null
                                }

                                if (inputImage != null) {
                                    val bytesWritten: Int
                                    try {
                                        bytesWritten = fillBt709Yuv420ImageFromArgb(
                                            argb = argbPixels,
                                            image = inputImage,
                                            width = width,
                                            height = height
                                        )
                                    } finally {
                                        inputImage.close()
                                    }
                                    encoder.queueInputBuffer(inBufIdx, 0, bytesWritten, ptsUs, 0)
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
                            if (inputDone) Thread.sleep(4)
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
                            }
                            encoder.releaseOutputBuffer(outStatus, false)
                            if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                                outputDone = true
                            }
                        }
                    }
                }
            }

            if (muxerStarted && audioTrackIdx >= 0) {
                val audInfo = MediaCodec.BufferInfo()
                for (pkt in audioPackets) {
                    audInfo.set(0, pkt.data.size, pkt.presentationTimeUs, pkt.flags)
                    muxer.writeSampleData(audioTrackIdx, ByteBuffer.wrap(pkt.data), audInfo)
                }
            }
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
    /// وإرجاع عدد البايتات الصالحة المكتوبة فعلياً بما لا يتجاوز سعة المخزن (VID-006 / VID-011)
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
        // 1. Luma (Y) بمعاملات ITU-R BT.709 Studio-Swing
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

        // 2. Chroma (Cb/Cr) عبر متوسط مربع 2x2 بكسل بمعاملات ITU-R BT.709
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
        val actualPlaneSpan = maxYWritten + max(maxUWritten, maxVWritten)
        return min(logicalYuvSize, max(1, actualPlaneSpan))
    }

    /// تحويل ARGB إلى NV12 وكتابتها في `ByteBuffer` مع إرجاع عدد البايتات الصالحة المكتوبة فعلياً (VID-006 / VID-011)
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

        val sampleRate = if (inputFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
            inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        } else {
            44100
        }
        val channelCount = if (inputFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
            inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceIn(1, 2)
        } else {
            2
        }

        val bytesPerSecond = sampleRate * channelCount * 2
        val targetTotalPcmBytes = ((totalDurationUs * bytesPerSecond.toLong()) / 1_000_000L).toInt()
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
                                extractor.seekTo(0L, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                                val retrySize = extractor.readSampleData(inBuf, 0)
                                if (retrySize < 0) {
                                    decoder.queueInputBuffer(
                                        inIdx,
                                        0,
                                        0,
                                        0L,
                                        MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                    )
                                    extractorEOS = true
                                } else {
                                    decoder.queueInputBuffer(inIdx, 0, retrySize, extractor.sampleTime, 0)
                                    extractor.advance()
                                }
                            } else {
                                decoder.queueInputBuffer(
                                    inIdx,
                                    0,
                                    0,
                                    0L,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                )
                                extractorEOS = true
                            }
                        } else {
                            decoder.queueInputBuffer(inIdx, 0, sampleSize, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                val outStatus = decoder.dequeueOutputBuffer(decInfo, 10_000)
                if (outStatus >= 0) {
                    val outBuf = decoder.getOutputBuffer(outStatus)
                    if (outBuf != null && decInfo.size > 0) {
                        outBuf.position(decInfo.offset)
                        outBuf.limit(decInfo.offset + decInfo.size)
                        val chunk = ByteArray(decInfo.size)
                        outBuf.get(chunk)
                        val needed = targetTotalPcmBytes - pcmOut.size()
                        pcmOut.write(chunk, 0, min(chunk.size, needed))
                    }
                    decoder.releaseOutputBuffer(outStatus, false)
                    if ((decInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        decoderDone = true
                    }
                } else if (outStatus == MediaCodec.INFO_TRY_AGAIN_LATER && extractorEOS) {
                    break
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

    /// حساب التلاشي (Fade-In / Fade-Out) ومستوى الصوت ومحدد الذروة بدقة الإطار الصوتي (Audio Frame)
    /// بحيث يتطابق سلوك Stereo و Mono تماماً مع تنفيذ Rust دون انحراف بين القناتين L و R (VID-001)
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

    /// فحص التوقيع الثنائي للحاوية لتحديد نوع MIME الفعلي بدقة دون الاعتماد الأعمى على الامتداد (VID-008)
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

            // 1. التسجيل في معرض الفيديو (Movies/OurLoveStory) بنوع MIME الفعلي للحاوية (VID-008)
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

            // 2. التسجيل في مجلد التنزيلات العام (Download/OurLoveStory)
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

        // تحديد نوع MIME الفعلي من ترويسة الحاوية (MP4 سواء كان H.264 أو HEVC -> video/mp4، و AVI -> video/x-msvideo) (VID-008)
        val actualMime = detectContainerMimeType(srcFile)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, srcFile.name)
                put(MediaStore.MediaColumns.MIME_TYPE, actualMime)
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DOWNLOADS}/OurLoveStory"
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(
                MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                values
            ) ?: throw IllegalStateException("Failed to create shareable MediaStore URI")

            try {
                resolver.openOutputStream(uri)?.use { out ->
                    FileInputStream(srcFile).use { input ->
                        input.copyTo(out, bufferSize = 64 * 1024)
                    }
                } ?: throw IllegalStateException("Failed to open output stream for share URI")

                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            } catch (e: Exception) {
                try {
                    resolver.delete(uri, null, null)
                } catch (_: Exception) {}
                throw e
            }

            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = actualMime
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TITLE, title)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(shareIntent, title))
        } else {
            // دعم إصدارات أندرويد الأقدم من Android 10 (API < 29) عبر MediaStore.Video
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
}
