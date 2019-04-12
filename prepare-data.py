#!/usr/bin/env python3

import os
import pathlib
import random
import cv2

# Ensure repeatable results by explicitly setting the random number
# generator seed.
random.seed(12345)

# Hardcoded classification for the pictures
cute_classes = ['kitty', 'puppy']
uncute_classes = ['creepies', 'ungulate']

# Create a directory hierarchy suitable for training. Put training,
# validation, and testing data in separate subdirectories, and split
# the images according to their classification. This makes it
# convenient for the training to see the labels.
for dataset in ['train', 'test', 'valid']:
    os.makedirs('data/{}/cute'.format(dataset), exist_ok=True)
    os.makedirs('data/{}/notcute'.format(dataset), exist_ok=True)

# Process all images of a single type, with indication of whether they
# are classified as cute or not.
def process_images(is_cute, cls):

    # Fetch data from the raw image directory, and set the target
    # directories based on the cuteness.
    source_path = pathlib.Path('data', 'raw', cls)
    cute_component = 'cute' if is_cute else 'notcute'
    dataset_paths = dict()
    for dataset in ['train', 'test', 'valid']:
        dataset_paths[dataset] = pathlib.Path('data', dataset, cute_component)

    # Split the image files into training, validation, and testing
    # sets. Done by creating a list of strings, each one of 'train',
    # 'test', or 'valid', in proportions 60-20-20, and then shuffling
    # the list of strings to randomize which image goes into which
    # set.
    image_files = [ f for f in source_path.iterdir() if f.name.endswith('.jpg') ]
    dataset_split = ['train'] * len(image_files)
    split_size = len(image_files) // 5
    for i in range(split_size):
        dataset_split[i] = 'test'
    for i in range(split_size, 2 * split_size):
        dataset_split[i] = 'valid'
    random.shuffle(dataset_split)

    # Process each image
    for i, image_file in enumerate(image_files):
        try:
            # Resize each image to 299x299. The model is InceptionV3,
            # which works with images of this size.
            image = cv2.imread(str(image_file))
            fixed_size_image = cv2.resize(image, (299, 299), interpolation=cv2.INTER_AREA)
            target_path = dataset_paths[dataset_split[i]]
            cv2.imwrite(str(target_path / image_file.name), fixed_size_image)
        except:
            print('Failed: {}'.format(image_file.name))

for cls in cute_classes:
    process_images(True, cls)

for cls in uncute_classes:
    process_images(False, cls)
