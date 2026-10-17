
package com.our.loveStory

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaCodecInfo
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
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
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
                                    // توحيد القنوات الصوتية إلى Stereo (قناتين) لتسهيل مزج المؤثرات المتعددة في Rust
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
                            } catch (_: Exception) {
                                runOnUiThread { result.success(null) }
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
                        val sourceFps = (call.argument<Number>("fps")?.toInt() ?: 30).coerceAtLeast(1)
                        val requestedTargetFps = (call.argument<Number>("targetFps")?.toInt() ?: sourceFps).coerceAtLeast(sourceFps)
                        val rawWidth = (call.argument<Number>("width")?.toInt() ?: 1080)
                        val rawHeight = (call.argument<Number>("height")?.toInt() ?: 1920)
                        val codecMime = call.argument<String>("codecMime") ?: MediaFormat.MIMETYPE_VIDEO_AVC
                        val bitrateBps = (call.argument<Number>("bitrateBps")?.toInt() ?: 12_000_000).coerceIn(2_000_000, 24_000_000)

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
                                    requestedBitrateBps = bitrateBps
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
                        val mimeType = call.argument<String>("mimeType") ?: "video/mp4"
                        if (filePath.isNullOrBlank() || fileName.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing filePath or fileName", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val savedPath = saveFileToDownloadsAndGallery(filePath, fileName, mimeType)
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
                        if (filePath.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing filePath", null)
                            return@setMethodCallHandler
                        }
                        try {
                            shareOrOpenMedia(filePath, title)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ─── Hardware H.264 (.mp4) + AAC Audio Transcoder & Muxer ──────────────────

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
        requestedBitrateBps: Int = 12_000_000
    ): File {
        val frames = extractPngFramesFromAvi(File(aviPath))
        if (frames.isEmpty()) {
            throw IllegalStateException("No frames found in AVI container")
        }

        // دعم دقة 1080p Full HD و 720p HD مع محاذاة زوجية متوافقة مع كافة معالجات MediaCodec العتادية
        val isFullHd = max(requestedWidth, requestedHeight) >= 1400 || min(requestedWidth, requestedHeight) >= 1000
        val aspect = requestedWidth.toDouble() / max(1, requestedHeight).toDouble()
        val (encWidth, encHeight) = when {
            aspect < 0.8 -> if (isFullHd) Pair(1080, 1920) else Pair(720, 1280)   // 9:16 Portrait (1080p / 720p)
            aspect > 1.2 -> if (isFullHd) Pair(1920, 1080) else Pair(1280, 720)   // 16:9 Landscape (1080p / 720p)
            else -> if (isFullHd) Pair(1080, 1080) else Pair(720, 720)            // 1:1 Square (1080p / 720p)
        }

        val repeatFactor = max(1, (requestedTargetFps + sourceFps / 2) / max(1, sourceFps))
        val targetFps = (sourceFps * repeatFactor).coerceIn(15, 60)
        val totalOutputFrames = frames.size * repeatFactor
        val totalDurationUs = (totalOutputFrames.toLong() * 1_000_000L) / targetFps.toLong()

        // 1. ترميز الفيديو عتادياً إلى H.264 (AVC) أو H.265 (HEVC) بمعيار ITU-R BT.709 Studio-Swing
        val (videoFormat, videoPackets) = try {
            encodeFramesToH264(
                pngFrames = frames,
                width = encWidth,
                height = encHeight,
                targetFps = targetFps,
                repeatFactor = repeatFactor,
                codecMime = requestedCodecMime,
                bitrateBps = requestedBitrateBps
            )
        } catch (_: Exception) {
            // في حال عدم دعم المعالج لـ HEVC أو 1080p، الانتقال التلقائي الآمن إلى H.264 القياسي
            encodeFramesToH264(
                pngFrames = frames,
                width = if (aspect < 0.8) 720 else if (aspect > 1.2) 1280 else 720,
                height = if (aspect < 0.8) 1280 else if (aspect > 1.2) 720 else 720,
                targetFps = 30,
                repeatFactor = max(1, 30 / max(1, sourceFps)),
                codecMime = MediaFormat.MIMETYPE_VIDEO_AVC,
                bitrateBps = 8_000_000
            )
        }

        // 2. ترميز الصوت إلى AAC-LC (من مخرجات مازج Rust متعدد المسارات أو من ملف الصوت مباشرة)
        var audioFormat: MediaFormat? = null
        var audioPackets: List<EncodedPacket> = emptyList()
        try {
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
        } catch (_: Exception) {}

        // 3. تجميع مساري الفيديو (H.264) والصوت (AAC) داخل حاوية MP4 قياسية
        val outFile = File(outputMp4Path)
        if (outFile.exists()) outFile.delete()

        val muxer = MediaMuxer(outFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val videoTrackIdx = muxer.addTrack(videoFormat)
        val audioTrackIdx = if (audioFormat != null && audioPackets.isNotEmpty()) {
            muxer.addTrack(audioFormat)
        } else {
            -1
        }

        muxer.start()

        val bufferInfo = MediaCodec.BufferInfo()
        for (pkt in videoPackets) {
            bufferInfo.set(0, pkt.data.size, pkt.presentationTimeUs, pkt.flags)
            muxer.writeSampleData(videoTrackIdx, ByteBuffer.wrap(pkt.data), bufferInfo)
        }

        if (audioTrackIdx >= 0) {
            for (pkt in audioPackets) {
                bufferInfo.set(0, pkt.data.size, pkt.presentationTimeUs, pkt.flags)
                muxer.writeSampleData(audioTrackIdx, ByteBuffer.wrap(pkt.data), bufferInfo)
            }
        }

        muxer.stop()
        muxer.release()

        // 4. الفحص الذاتي الصارم (Oracle Verification) عبر MediaMetadataRetriever للتأكد من سلامة ملف الـ MP4
        verifyExportedMp4WithRetriever(outFile)

        return outFile
    }

    private fun verifyExportedMp4WithRetriever(mp4File: File) {
        if (!mp4File.exists() || mp4File.length() < 256) {
            throw IllegalStateException("Exported MP4 file is empty or corrupt")
        }
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(mp4File.absolutePath)
            val hasVideo = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO)
            if (hasVideo == null || !hasVideo.equals("yes", ignoreCase = true)) {
                throw IllegalStateException("MediaMetadataRetriever verification failed: no valid video track")
            }
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {}
        }
    }

    private fun extractPngFramesFromAvi(aviFile: File): List<ByteArray> {
        val bytes = aviFile.readBytes()
        val buf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        val frames = ArrayList<ByteArray>()

        var i = 12
        while (i + 8 <= bytes.size) {
            val c0 = bytes[i].toInt() and 0xFF
            val c1 = bytes[i + 1].toInt() and 0xFF
            val c2 = bytes[i + 2].toInt() and 0xFF
            val c3 = bytes[i + 3].toInt() and 0xFF
            val chunkSize = buf.getInt(i + 4)

            if (c0 == 0x4C && c1 == 0x49 && c2 == 0x53 && c3 == 0x54) {
                i += 12
                continue
            }

            if (c0 == 0x30 && c1 == 0x30 && c2 == 0x64 && c3 == 0x63) {
                val start = i + 8
                val end = start + chunkSize
                if (chunkSize > 0 && end <= bytes.size) {
                    frames.add(bytes.copyOfRange(start, end))
                }
            }

            val padded = chunkSize + (if (chunkSize % 2 != 0) 1 else 0)
            i += 8 + padded
        }
        return frames
    }

    private fun encodeFramesToH264(
        pngFrames: List<ByteArray>,
        width: Int,
        height: Int,
        targetFps: Int,
        repeatFactor: Int,
        codecMime: String = MediaFormat.MIMETYPE_VIDEO_AVC,
        bitrateBps: Int = 12_000_000
    ): Pair<MediaFormat, List<EncodedPacket>> {
        val mime = if (codecMime.equals("video/hevc", ignoreCase = true)) {
            MediaFormat.MIMETYPE_VIDEO_HEVC
        } else {
            MediaFormat.MIMETYPE_VIDEO_AVC
        }
        val format = MediaFormat.createVideoFormat(mime, width, height).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible
            )
            setInteger(MediaFormat.KEY_BIT_RATE, bitrateBps)
            setInteger(MediaFormat.KEY_FRAME_RATE, targetFps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            // ضبط معايير الألوان ITU-R BT.709 Studio-Swing لتطابق ألوان شاشة الاستوديو مع المعرض
            setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT709)
            setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED)
            setInteger(MediaFormat.KEY_COLOR_TRANSFER, MediaFormat.COLOR_TRANSFER_SDR_VIDEO)
        }

        val encoder = MediaCodec.createEncoderByType(mime)
        encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        encoder.start()

        val packets = ArrayList<EncodedPacket>()
        var outputFormat: MediaFormat? = null
        val bufferInfo = MediaCodec.BufferInfo()
        val argbPixels = IntArray(width * height)

        var outputFrameIndex = 0L
        var inputDone = false
        var outputDone = false
        var pngIdx = 0

        while (!outputDone) {
            if (!inputDone) {
                val inBufIdx = encoder.dequeueInputBuffer(10_000)
                if (inBufIdx >= 0) {
                    if (pngIdx >= pngFrames.size) {
                        val ptsUs = (outputFrameIndex * 1_000_000L) / targetFps.toLong()
                        encoder.queueInputBuffer(
                            inBufIdx,
                            0,
                            0,
                            ptsUs,
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM
                        )
                        inputDone = true
                    } else {
                        val rawBitmap = BitmapFactory.decodeByteArray(
                            pngFrames[pngIdx],
                            0,
                            pngFrames[pngIdx].size
                        )
                        val scaledBitmap = if (rawBitmap.width == width && rawBitmap.height == height) {
                            rawBitmap
                        } else {
                            Bitmap.createScaledBitmap(rawBitmap, width, height, true)
                        }
                        scaledBitmap.getPixels(argbPixels, 0, width, 0, 0, width, height)
                        if (scaledBitmap !== rawBitmap) {
                            scaledBitmap.recycle()
                        }
                        rawBitmap.recycle()

                        val inputImage = encoder.getInputImage(inBufIdx)
                        val inputBuffer = encoder.getInputBuffer(inBufIdx)
                        val yuvSize = (width * height * 3) / 2

                        if (inputImage != null) {
                            fillBt709Yuv420ImageFromArgb(argbPixels, inputImage, width, height)
                            val cap = inputBuffer?.capacity() ?: yuvSize
                            val ptsUs = (outputFrameIndex * 1_000_000L) / targetFps.toLong()
                            encoder.queueInputBuffer(inBufIdx, 0, max(yuvSize, cap), ptsUs, 0)
                        } else if (inputBuffer != null) {
                            inputBuffer.clear()
                            fillBt709Nv12BufferFromArgb(argbPixels, inputBuffer, width, height)
                            val ptsUs = (outputFrameIndex * 1_000_000L) / targetFps.toLong()
                            encoder.queueInputBuffer(inBufIdx, 0, yuvSize, ptsUs, 0)
                        }

                        outputFrameIndex++
                        if (outputFrameIndex % repeatFactor.toLong() == 0L) {
                            pngIdx++
                        }
                    }
                }
            }

            val outStatus = encoder.dequeueOutputBuffer(bufferInfo, 10_000)
            when {
                outStatus == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (inputDone) Thread.sleep(5)
                }
                outStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    outputFormat = encoder.outputFormat
                }
                outStatus >= 0 -> {
                    val outBuf = encoder.getOutputBuffer(outStatus)
                    if (outBuf != null && bufferInfo.size > 0 &&
                        (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0
                    ) {
                        outBuf.position(bufferInfo.offset)
                        outBuf.limit(bufferInfo.offset + bufferInfo.size)
                        val bytes = ByteArray(bufferInfo.size)
                        outBuf.get(bytes)
                        packets.add(
                            EncodedPacket(
                                data = bytes,
                                presentationTimeUs = bufferInfo.presentationTimeUs,
                                flags = bufferInfo.flags
                            )
                        )
                    }
                    encoder.releaseOutputBuffer(outStatus, false)
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        outputDone = true
                    }
                }
            }
        }

        val finalFormat = outputFormat ?: encoder.outputFormat
        encoder.stop()
        encoder.release()
        return Pair(finalFormat, packets)
    }

    /// تحويل ARGB إلى ITU-R BT.709 Studio-Swing YUV420 مع فلتر 2x2 Box-Filter للكروما
    private fun fillBt709Yuv420ImageFromArgb(
        argb: IntArray,
        image: android.media.Image,
        width: Int,
        height: Int
    ) {
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
                if (yIdx < yCap) {
                    yBuf.put(yIdx, yVal.toByte())
                }
            }
        }

        // 2. Chroma (Cb/Cr) عبر متوسط مربع 2x2 بكسل بمعاملات ITU-R BT.709
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
                if (uIdx < uCap) uBuf.put(uIdx, uVal.toByte())
                if (vIdx < vCap) vBuf.put(vIdx, vVal.toByte())
            }
        }
    }

    private fun fillBt709Nv12BufferFromArgb(
        argb: IntArray,
        buffer: ByteBuffer,
        width: Int,
        height: Int
    ) {
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
        buffer.put(yuv, 0, min(buffer.remaining(), yuv.size))
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

        decoder.stop()
        decoder.release()
        extractor.release()

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
        val bytesPerSecond = sampleRate * channelCount * 2

        applyVolumeAndFadesToPcm16(
            pcmBytes = rawPcmBytes,
            bytesPerSecond = bytesPerSecond,
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
        encoder.stop()
        encoder.release()
        return Pair(finalAacFormat, aacPackets)
    }

    private fun applyVolumeAndFadesToPcm16(
        pcmBytes: ByteArray,
        bytesPerSecond: Int,
        baseVolume: Double,
        fadeIn: Boolean,
        fadeOut: Boolean
    ) {
        val totalSamples = pcmBytes.size / 2
        val totalSeconds = pcmBytes.size.toDouble() / max(1, bytesPerSecond).toDouble()
        val fadeWindowSec = 1.2
        val kneeStart = 28000.0
        val maxCeiling = 32700.0
        val headroom = maxCeiling - kneeStart

        var byteIdx = 0
        for (sampleIdx in 0 until totalSamples) {
            val currentSec = (sampleIdx * 2).toDouble() / max(1, bytesPerSecond).toDouble()
            var gain = baseVolume
            if (fadeIn && currentSec < fadeWindowSec) {
                val ratio = (currentSec / fadeWindowSec).coerceIn(0.0, 1.0)
                gain *= sin(ratio * PI * 0.5)
            }
            if (fadeOut && (totalSeconds - currentSec) < fadeWindowSec) {
                val ratio = ((totalSeconds - currentSec) / fadeWindowSec).coerceIn(0.0, 1.0)
                gain *= sin(ratio * PI * 0.5)
            }

            val lo = pcmBytes[byteIdx].toInt() and 0xFF
            val hi = pcmBytes[byteIdx + 1].toInt()
            val sample = ((hi shl 8) or lo).toDouble() * gain
            val absS = kotlin.math.abs(sample)
            val limited = if (absS <= kneeStart) {
                sample.roundToInt()
            } else {
                val sign = if (sample >= 0.0) 1.0 else -1.0
                val compressed = kneeStart + headroom * tanh((absS - kneeStart) / headroom)
                (sign * compressed).roundToInt().coerceIn(-32767, 32767)
            }

            pcmBytes[byteIdx] = (limited and 0xFF).toByte()
            pcmBytes[byteIdx + 1] = ((limited shr 8) and 0xFF).toByte()
            byteIdx += 2
        }
    }

    // ─── Save to Public Downloads AND Gallery (MediaStore.Video + Downloads) ───

    private fun saveFileToDownloadsAndGallery(
        sourcePath: String,
        fileName: String,
        mimeType: String
    ): String {
        val srcFile = File(sourcePath)
        if (!srcFile.exists()) {
            throw IllegalArgumentException("Source file does not exist: $sourcePath")
        }

        val subFolder = "OurLoveStory"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver

            // 1. التسجيل في معرض الفيديو (Movies/OurLoveStory) ليظهر مباشرة في تطبيق "المعرض / Gallery"
            if (mimeType.startsWith("video/")) {
                try {
                    val videoValues = ContentValues().apply {
                        put(MediaStore.Video.Media.DISPLAY_NAME, fileName)
                        put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
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
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
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

            return "/storage/emulated/0/${Environment.DIRECTORY_DOWNLOADS}/$subFolder/$fileName"
        } else {
            val downloadsDir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            )
            val targetDir = File(downloadsDir, subFolder)
            if (!targetDir.exists()) {
                targetDir.mkdirs()
            }
            val destFile = File(targetDir, fileName)
            FileInputStream(srcFile).use { inStream ->
                FileOutputStream(destFile).use { outStream ->
                    inStream.copyTo(outStream, bufferSize = 64 * 1024)
                }
            }
            MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(destFile.absolutePath),
                arrayOf(mimeType),
                null
            )
            return destFile.absolutePath
        }
    }

    private fun shareOrOpenMedia(filePath: String, title: String) {
        val srcFile = File(filePath)
        if (!srcFile.exists()) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val isMp4 = srcFile.extension.lowercase() == "mp4"
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, srcFile.name)
                put(MediaStore.MediaColumns.MIME_TYPE, if (isMp4) "video/mp4" else "video/avi")
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DOWNLOADS}/OurLoveStory"
                )
            }
            val uri = resolver.insert(
                MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                values
            )
            if (uri != null) {
                resolver.openOutputStream(uri)?.use { out ->
                    FileInputStream(srcFile).use { input ->
                        input.copyTo(out)
                    }
                }
                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "video/mp4"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    putExtra(Intent.EXTRA_TITLE, title)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(Intent.createChooser(shareIntent, title))
            }
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