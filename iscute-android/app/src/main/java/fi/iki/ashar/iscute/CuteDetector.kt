package fi.iki.ashar.iscute

import android.content.Context
import android.graphics.Bitmap
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import java.util.concurrent.Executors
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

/**
 * Detector for the probability of cuteness of a picture.
 */
class CuteDetector(context: Context) {

    // Interpreter is what is used for predictions
    private val tflite: Interpreter
    // Image data for the predictor is best passed in as a byte buffer
    private val imageData: ByteBuffer
    // Before converting to a byte buffer, it is necessary to extract the pixel
    // values from the image. Since the array is quite large, it is a good idea
    // to preallocate it as a member variable.
    private val pixels = IntArray(299 * 299)
    // It takes a while to run the prediction, so it needs to be done in a
    // background thread.
    private val executor = Executors.newSingleThreadExecutor()

    init {
        // Access the model file from the assets, and create a MappedByteBuffer
        // that the Interpreter constructor takes as the model argument.
        val fd = context.assets.openFd("iscute.tflite")
        val input = FileInputStream(fd.fileDescriptor)
        val channel = input.channel
        val buffer = channel.map(FileChannel.MapMode.READ_ONLY, fd.startOffset, fd.declaredLength)
        tflite = Interpreter(buffer, null)

        // Create the byte buffer for the image data. The 299's are the width and
        // height of the image, 3 is the number of colors in the RGB image, and the
        // pixel values are given as floats, which are 4 bytes in size.
        imageData = ByteBuffer.allocateDirect(299 * 299 * 3 * 4)
        imageData.order(ByteOrder.nativeOrder())
    }

    /**
     * Compute the amount of cuteness in a picture. The passed-in picture should be a
     * square bitmap. The result is passed to the callback after processing is complete.
     * The callback will be called from the processing thread, which is not the main
     * thread.
     */
    fun cutenessPercentage(picture: Bitmap, resultCallback: (result: Float) -> Unit) {
        // Run in the background thread by submitting the block to the executor.
        executor.submit {
            // Start filling the image data buffer from the beginning
            imageData.rewind()

            // Scale the passed-in picture to dimensions 299x299, which is what the
            // InceptionV3 model requires.
            val scaledPicture = Bitmap.createScaledBitmap(picture, 299, 299, false)

            // Extract the pixels of the image into the one-dimensional int array.
            scaledPicture.getPixels(pixels, 0, 299, 0, 0, 299, 299)

            // Loop over all the pixels and transfer their values into the image data
            // buffer in a format that is usable by the model.
            var pixelIndex = 0
            for (i in 1..299) {
                for (j in 1..299) {
                    val pixelValue = pixels[pixelIndex++]
                    // Each of the three RGB components of a pixel is converted to a float value
                    // in the range [-1, 1), which is what the InceptionV3 preprocessor did
                    // during the training. Here it needs to be done manually.
                    imageData.putFloat((((pixelValue shr 16) and 0xFF).toFloat() - 128.0f) / 128.0f)
                    imageData.putFloat((((pixelValue shr 8) and 0xFF).toFloat() - 128.0f) / 128.0f)
                    imageData.putFloat(((pixelValue and 0xFF).toFloat() - 128.0f) / 128.0f)
                }
            }
            // Run the predictor. It takes an input and output parameter. These parameters
            // are very generic, probably because this same method handles any kind of
            // task. For image classification, the input is the byte buffer that was
            // constructed above. The output is an array of size 1, containing an array
            // of floats, the size of which is the number of classes.
            val labelProbabilities = Array(1, { FloatArray(2) })
            tflite.run(imageData, labelProbabilities)

            // The result array will have two probabilities, one for cute and the other
            // for not cute. I couldn't find how to tell which is which, but experimentally
            // it seemed that index 0 corresponds to the cute probability.
            resultCallback(labelProbabilities[0][0])
        }
    }
}
