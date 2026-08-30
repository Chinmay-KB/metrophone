package com.chinmaykb.metrophone

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import java.io.ByteArrayOutputStream
import kotlin.math.abs
import kotlin.math.max

data class RenderedIcon(
    val pngBytes: ByteArray,
    val isNativeMonochrome: Boolean,
)

object IconRenderer {
    fun render(drawable: Drawable, size: Int, monochrome: Boolean): RenderedIcon {
        val source: Drawable
        val nativeMonochrome: Boolean
        val removeLegacyBackground: Boolean

        if (monochrome && drawable is AdaptiveIconDrawable) {
            val nativeLayer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                drawable.monochrome
            } else {
                null
            }
            source = nativeLayer ?: drawable.foreground
            nativeMonochrome = nativeLayer != null
            removeLegacyBackground = false
        } else {
            source = drawable
            nativeMonochrome = false
            removeLegacyBackground = monochrome
        }

        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        source.setBounds(0, 0, size, size)
        source.draw(Canvas(bitmap))
        if (monochrome) whiten(bitmap, removeLegacyBackground)

        val output = ByteArrayOutputStream()
        check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, output))
        return RenderedIcon(output.toByteArray(), nativeMonochrome)
    }

    private fun whiten(bitmap: Bitmap, removeLegacyBackground: Boolean) {
        val width = bitmap.width
        val height = bitmap.height
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        val cornerColor = averageCornerColor(pixels, width, height)
        val opaqueCorners = Color.alpha(cornerColor) > 230
        for (index in pixels.indices) {
            val pixel = pixels[index]
            val sourceAlpha = Color.alpha(pixel)
            if (sourceAlpha == 0) continue
            val alpha = if (removeLegacyBackground && opaqueCorners) {
                val distance = max(
                    abs(Color.red(pixel) - Color.red(cornerColor)),
                    max(
                        abs(Color.green(pixel) - Color.green(cornerColor)),
                        abs(Color.blue(pixel) - Color.blue(cornerColor)),
                    ),
                )
                (sourceAlpha * ((distance - 18).coerceAtLeast(0) / 72f))
                    .toInt()
                    .coerceIn(0, sourceAlpha)
            } else {
                sourceAlpha
            }
            pixels[index] = Color.argb(alpha, 255, 255, 255)
        }
        bitmap.setPixels(pixels, 0, width, 0, 0, width, height)
    }

    private fun averageCornerColor(pixels: IntArray, width: Int, height: Int): Int {
        val corners = intArrayOf(
            pixels[0],
            pixels[width - 1],
            pixels[(height - 1) * width],
            pixels[pixels.lastIndex],
        )
        return Color.argb(
            corners.sumOf(Color::alpha) / corners.size,
            corners.sumOf(Color::red) / corners.size,
            corners.sumOf(Color::green) / corners.size,
            corners.sumOf(Color::blue) / corners.size,
        )
    }
}
