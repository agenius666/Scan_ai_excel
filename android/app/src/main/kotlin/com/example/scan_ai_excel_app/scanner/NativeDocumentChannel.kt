package com.example.scan_ai_excel_app.scanner

import android.graphics.BitmapFactory
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.MatOfPoint
import org.opencv.core.Point
import org.opencv.core.Scalar
import org.opencv.imgproc.Imgproc
import kotlin.math.max

class NativeDocumentChannel {
    companion object {
        private const val CHANNEL = "scan_ai_excel/native_document"

        fun register(flutterEngine: FlutterEngine) {
            OpenCVLoader.initDebug()
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "detectDocumentCorners" -> handleDetect(call, result)
                        else -> result.notImplemented()
                    }
                }
        }

        private fun handleDetect(call: MethodCall, result: MethodChannel.Result) {
            val imagePath = call.argument<String>("imagePath")
            if (imagePath.isNullOrBlank()) {
                result.error("bad_args", "imagePath is required", null)
                return
            }

            try {
                val bitmap = BitmapFactory.decodeFile(imagePath)
                if (bitmap == null) {
                    result.error("decode_failed", "cannot decode image", null)
                    return
                }

                val rgba = Mat()
                Utils.bitmapToMat(bitmap, rgba)
                val gray = Mat()
                Imgproc.cvtColor(rgba, gray, Imgproc.COLOR_RGBA2GRAY)
                Imgproc.GaussianBlur(gray, gray, org.opencv.core.Size(5.0, 5.0), 0.0)
                val edges = Mat()
                Imgproc.Canny(gray, edges, 75.0, 200.0)

                val contours = ArrayList<MatOfPoint>()
                Imgproc.findContours(edges, contours, Mat(), Imgproc.RETR_LIST, Imgproc.CHAIN_APPROX_SIMPLE)

                var best: Array<Point>? = null
                var bestArea = 0.0
                for (contour in contours) {
                    val contour2f = org.opencv.core.MatOfPoint2f(*contour.toArray())
                    val peri = Imgproc.arcLength(contour2f, true)
                    val approx = org.opencv.core.MatOfPoint2f()
                    Imgproc.approxPolyDP(contour2f, approx, 0.02 * peri, true)
                    val points = approx.toArray()
                    if (points.size == 4) {
                        val area = kotlin.math.abs(Imgproc.contourArea(org.opencv.core.MatOfPoint(*points)))
                        if (area > bestArea) {
                            bestArea = area
                            best = points
                        }
                    }
                }

                if (best != null) {
                    val sorted = sortCorners(best!!.toList())
                    result.success(sorted.flatMap { listOf(it.x, it.y) })
                    return
                }
            } catch (_: Throwable) {
            }

            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(imagePath, options)
            val width = max(options.outWidth.toDouble(), 1.0)
            val height = max(options.outHeight.toDouble(), 1.0)
            val insetX = width * 0.08
            val insetY = height * 0.06
            result.success(
                listOf(
                    insetX, insetY,
                    width - insetX, insetY,
                    width - insetX, height - insetY,
                    insetX, height - insetY,
                )
            )
        }

        private fun sortCorners(points: List<Point>): List<Point> {
            val sorted = points.sortedBy { it.x + it.y }.toMutableList()
            val tl = sorted.first()
            val br = sorted.last()
            val remaining = points.filter { it != tl && it != br }
            val tr = remaining.minByOrNull { it.y - it.x } ?: points[1]
            val bl = remaining.maxByOrNull { it.y - it.x } ?: points[2]
            return listOf(tl, tr, br, bl)
        }
    }
}
