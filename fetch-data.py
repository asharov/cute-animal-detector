#!/usr/bin/env python3

import os
import requests

# Hardcoded four image types, with URL lists shipped in files
classes = ['kitty', 'puppy', 'creepies', 'ungulate']
urllists = map(lambda s: 'data/{}-urls.txt'.format(s), classes)

for cls, urllist in zip(classes, urllists):
    counter = 0

    # The downloaded images will be saved under data/raw
    os.makedirs('data/raw/{}'.format(cls), exist_ok=True)
    print(cls)
    with open(urllist, 'r') as f:
        urls = f.read().splitlines()
    invalid_urls = []

    for url in urls:
        # Each image gets a unique name with a running number
        filename = 'data/raw/{0}/{0}{1:04}.jpg'.format(cls, counter)

        # Fetch the image. Unless the server successfully returns an
        # image/jpeg content type, skip the image. The list of URLs is
        # old and many of the pictures are no longer
        # available. Sometimes even the whole server is gone.
        try:
            r = requests.get(url)
        except:
            invalid_urls.append(url)
            continue

        if r.status_code == 200 and r.headers['content-type'] == 'image/jpeg':
            with open(filename, 'wb') as f:
                f.write(r.content)
            counter += 1

            # Print progress reports every 100 images
            if counter % 100 == 0:
                print(counter)
        else:
            invalid_urls.append(url)

    # All URLs that didn't return an image are saved and written into
    # the invalid URLs file afterwards.
    if invalid_urls:
        with open('data/{}-invalid-urls.txt'.format(cls), 'w') as f:
            for url in invalid_urls:
                f.write('{}\n'.format(url))
