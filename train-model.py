#!/usr/bin/env python3

import pathlib
import keras
from keras.applications.inception_v3 import InceptionV3, preprocess_input
from keras.layers import Dense, Dropout, GlobalAveragePooling2D
from keras.models import Model
from keras.preprocessing.image import ImageDataGenerator

# Use data generators to provide the images for the training.  This
# automatically augments the data with transformed images to produce a
# more robust model.
def make_generator(dataset):
    dataset_path = pathlib.Path('data', dataset)

    # Parameters are set to provide a useful range of different images
    # without producing too much distortion.
    datagen = ImageDataGenerator(preprocessing_function=preprocess_input,
                                 rotation_range=40,
                                 width_shift_range=0.2,
                                 height_shift_range=0.2,
                                 zoom_range=0.2,
                                 horizontal_flip=True)
    return datagen.flow_from_directory(str(dataset_path),
                                       target_size=(299, 299),
                                       batch_size=32,
                                       class_mode='categorical')

keras.backend.clear_session()

# Use the InceptionV3 model with imagenet weights, since our images
# are from imagenet. To facilitate transfer learning, include_top is
# set to False to omit the last layer of the network.
base_model = InceptionV3(weights='imagenet', include_top=False)
base_output = base_model.output

# The current recommendation for image classifiers is to use one
# global average pooling layer at the end only.
avg_pool = Dropout(0.5)(GlobalAveragePooling2D(name='avg_pool')(base_output))

# The final layer uses two neurons, since there are two classes (cute
# and not cute), with softmax to make the values be probabilities.
final_output = Dense(2, activation='softmax')(avg_pool)
model = Model(inputs=base_model.input, outputs=final_output)

# Mark all layers of the prebuilt Inception model as non-trainable, so
# only the final layers that were added above will be trained.
for layer in base_model.layers:
    layer.trainable = False

# Standard values for the training for a classification problem.
model.compile(optimizer='rmsprop',
              loss='categorical_crossentropy',
              metrics=['accuracy'])

train_generator = make_generator('train')
validation_generator = make_generator('test')

# Use the data generator for the training set as the source of images
# for training the model. Training for 5 epochs seems to be quite
# sufficient for this kind of model. I don't know exactly what values
# to pick for steps_per_epoch or validation_steps, but these seemed to
# be fine.
history = model.fit_generator(train_generator,
                              epochs=5,
                              steps_per_epoch=320,
                              validation_data=validation_generator,
                              validation_steps=64)

# Save the complete model after training. Saving the complete model is
# necessary so that it can be converted into a form usable in the app.
model.save('iscute.h5')
