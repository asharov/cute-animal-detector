package fi.iki.ashar.iscute

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View

/**
 * A view that draws itself as a hollow red rectangle.
 */
class RectangleView(context: Context, attrs: AttributeSet): View(context, attrs) {

    private val lineWidth = 10.0f
    private val paint: Paint

    init {
        // Create a paint object that draws thick red lines
        paint = Paint()
        paint.color = Color.RED
        paint.strokeWidth = lineWidth
        paint.style = Paint.Style.STROKE
    }

    // Override the drawing method to draw the rectangle. This seems to be the best
    // way to draw a hollow rectangle.
    override fun onDraw(canvas: Canvas?) {
        super.onDraw(canvas)

        // Offsets from the edges are needed since otherwise half of the line would
        // be outside the boundaries of the view
        canvas?.drawRect(lineWidth / 2,
            lineWidth / 2,
            width.toFloat() - lineWidth / 2,
            height.toFloat() - lineWidth / 2,
            paint)
    }
}
