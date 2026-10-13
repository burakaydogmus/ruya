package com.burakaydogmus.ruya

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Rect

/**
 * Draws a companion for the home screen widgets from the same sprite sheets the
 * app uses (Flutter assets), so widgets and app always show the same art.
 * A sheet is one row of 64×64 frames; an accessory is a second sheet with only
 * the pixels it changes, drawn on top.
 */
object PetArt {
    private const val CELL = 64
    private const val SHEETS = "flutter_assets/assets/pets"

    private val PETS = setOf("pamuk", "fistik", "tarcin", "lokum", "mehtap", "boncuk")
    private val ACCESSORIES = setOf("bow", "daisy", "beanie", "scarf", "flower", "party")

    /** First frame of each pose, see tool/pets/pets.py. */
    private val FRAMES = mapOf("idle" to 0, "sleep" to 3, "cozy" to 5, "comfort" to 7, "happy" to 9, "tea" to 11)

    /**
     * Pose for the widgets: cozy or comforting when today's log says so,
     * otherwise it follows the clock only (stretching in the morning, tea in
     * the evening, asleep at night). It never depends on how the app is used.
     */
    fun pose(mood: String, hour: Int): String = when {
        mood == "cozy" || mood == "comfort" -> mood
        hour >= 22 || hour < 6 -> "sleep"
        hour < 10 -> "happy"
        hour >= 18 -> "tea"
        else -> "idle"
    }

    /** One frame scaled by a whole factor with hard pixels, or null if the art is missing. */
    fun render(context: Context, pet: String, pose: String, accessory: String, scale: Int): Bitmap? {
        if (pet !in PETS) return null
        val frame = FRAMES[pose] ?: 0
        return try {
            val out = Bitmap.createBitmap(CELL * scale, CELL * scale, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(out)
            val src = Rect(frame * CELL, 0, (frame + 1) * CELL, CELL)
            val dst = Rect(0, 0, CELL * scale, CELL * scale)
            val sheets = mutableListOf("$SHEETS/$pet.png")
            if (accessory in ACCESSORIES) sheets.add("$SHEETS/acc/${pet}_$accessory.png")
            for (path in sheets) {
                val sheet = context.assets.open(path).use { BitmapFactory.decodeStream(it) } ?: continue
                // no Paint: nearest-neighbour scaling keeps the pixels square
                canvas.drawBitmap(sheet, src, dst, null)
                sheet.recycle()
            }
            out
        } catch (e: Exception) {
            null
        }
    }
}
