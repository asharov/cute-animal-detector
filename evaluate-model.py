#!/usr/bin/env python3

import keras
from keras.applications.inception_v3 import preprocess_input
from keras.models import load_model
from keras.preprocessing.image import ImageDataGenerator

# Load the model that was saved by the training
model = load_model('iscute.h5')

# Use a data generator for the validation data that does not perform
# any distortions and provides the images in batches of size 1.
data_generator = (ImageDataGenerator(preprocessing_function=preprocess_input).
                  flow_from_directory('data/valid',
                                      target_size=(299, 299),
                                      batch_size=1,
                                      shuffle=False,
                                      class_mode='categorical'))

# Evaluate the model from the generator, with all the data that the
# generator produces.
result = model.evaluate_generator(data_generator, len(data_generator.filenames))

# The evaluation result is an array of values corresponding to the
# metrics. First print the metric names and then the array of values.
print(model.metrics_names)
print(result)
