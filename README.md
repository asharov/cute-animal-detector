# Cute Animal Detector

Do you often find yourself in a situation where you see an animal and
are not sure whether to go "Awwww, how cuuute!"? Machine learning can
help you! Just point the Cute Animal Detector app at the animal and in
a few seconds you will know whether the animal is cute or not. No more
embarrassment at reacting wrong!

Seriously, Cute Animal Detector is an exercise I did to get some
familiarity with making a mobile app that uses machine learning with
an app-specific model. I had to go through a lot of blog posts and
sample code so I hope that putting all of this in one place is helpful
to someone else. It certainly would have been helpful to me.

## Phases

There are two parts to the code here. There are some Python scripts
that train the model, and there is the Android app that uses the
trained model for classifying the images. The trained model is quite
large, so you will need to go through all the phases of training the
model, even if you're only interested in the Android app.

The phases are
1. Set up virtual environment
1. Fetch the image data
1. Prepare the data for training
1. Train the model
1. (Optional) Evaluate the model
1. Convert the model for the app
1. Compile and install the app

## Set up virtual environment

The virtual environment setup is the usual Python way:
```
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Fetch the image data

The image data comes from [ImageNet](http://www.image-net.org/). In
the current version, the image sets are hardcoded and the URL lists
pre-downloaded. It could be interesting to generalize this a bit to
allow more configurability in the image sets.

The selected image sets are `puppy` (cute), `kitty` (cute), `creepies`
(not cute), and `ungulate` (not cute). The URL lists for each are in
the `data` directory, which is also where the images will be fetched.

To fetch the images, run
```
./fetch-data.py
```
This will download the images from all the URL lists and put them
under the `data/raw` directory. Any URLs that don't return a JPEG
image are added to an `*-invalid-urls.txt` file, so it would be
possible to prune them away from the main `*-urls.txt` files.

## Prepare the data for training

To prepare the data for training, it is convenient to create a
directory hierarchy where the images are split into training,
validation, and testing sets, and furthermore labeled
appropriately. Also, the InceptionV3 model that is used needs the
images to be of a specific size, so they need to be resized as well.

All this preparation is done by running
```
./prepare-data.py
```
This will create subdirectories `data/train`, `data/test`, and
`data/valid`, and put appropriate proportions of the resized images
into each for the model training.

## Train the model

The training uses transfer learning with the InceptionV3 model. So
most of the model remains fixed, and only the final layer of the
neural network that does the classification gets trained. On my
Macbook it took about 2.5 hours to train the model (that's training on
the CPU, with 4 cores).

To train the model, run
```
./train-model.py
```
This will create an `iscute.h5` file, which contains the model saved
from Keras. For me it ended up being about 84 MB in size.

## (Optional) Evaluate the model

The dataset was split into three parts in preparation. If you wish to
check the model, you can run
```
./evaluate-model.py
```
to run the trained model on data it didn't see yet, and see the
accuracy that it achieves. Mine was about 98% accurate.

## Convert the model for the apps

There are two apps, one for Android and one for iOS. The trained model
needs to be converted before it can be used in either app.

For Android, the model needs to be in the tensorflow-lite format, not
in the Keras format that the model training step produced. The
conversion is very simple, as there is a ready-made converter in
Tensorflow. Run
```
./convert-model-android.py
```
to create a `iscute.tflite` file. Copy this file to the
`iscute-android/app/src/main/assets` directory.

For iOS, the model needs to be in Apple's CoreML format. Again here,
there is a ready-made converter provided by Apple. Run
```
./convert-model-ios.py
```
to create a `iscute.mlmodel` file. Copy this file to the
`iscute-ios/IsCute` directory.

## Compile and install the app

For the Android app, install
[Android Studio](https://developer.android.com/studio) if you
don't have it already. Open the directory `iscute-android` as a
project there. Then you can either run the app directly on a connected
Android device, or build an APK to install later. The app requires at
least Android 6.

For the iOS app, install [Xcode](https://developer.apple.com/xcode/) if
you don't have it already. Open the project `iscute-ios/IsCute.xcodeproj`
as a project there. Then you can run the app directly on a connected
iPhone. The app requires iOS 13.
