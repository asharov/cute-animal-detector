#!/usr/bin/env python3

import os
import requests
import asyncio
from concurrent import futures

# Function to fetch the content from a URL, and swallow any
# exceptions that the fetching raises. If an exception is
# raised, the function returns None. This is used to make
# sure waiting on all the requests in a list doesn't raise
# exceptions but instead puts in None in the response list.
def get_url_or_none(url):
    try:
        return requests.get(url)
    except:
        return None

# Fetch the content of a set of URLs asynchronously. The
# return value is a list of Response objects and Nones, in
# the same order as the list or URLs passed as argument.
async def fetch_images_from_urls(urls):
    with futures.ThreadPoolExecutor(max_workers=16) as executor:
        event_loop = asyncio.get_event_loop()
        responses = [ event_loop.run_in_executor(executor, get_url_or_none, url)
                      for url in urls ]
    return await asyncio.gather(*responses)

# Hardcoded four image types, with URL lists shipped in files
classes = ['kitty', 'puppy', 'creepies', 'ungulate']
urllists = map(lambda s: 'data/{}-urls.txt'.format(s), classes)

async def fetch():
    for cls, urllist in zip(classes, urllists):

        # The downloaded images will be saved under data/raw
        os.makedirs('data/raw/{}'.format(cls), exist_ok=True)
        print(cls)
        with open(urllist, 'r') as f:
            urls = f.read().splitlines()
        invalid_urls = []

        responses = await fetch_images_from_urls(urls)

        counter = 0
        for url, response in zip(urls, responses):
            # Each image gets a unique name with a running number
            filename = 'data/raw/{0}/{0}{1:04}.jpg'.format(cls, counter)

            # An image is saved only if the server returns a
            # successful response with a JPEG content type. All
            # other URLs are added to the list of invalid URLs.
            if (response is not None
                and response.status_code == 200
                and response.headers['content-type'] == 'image/jpeg'):
                with open(filename, 'wb') as f:
                    f.write(response.content)
                counter += 1
            else:
                invalid_urls.append(url)

        # All URLs that didn't return an image are saved and written into
        # the invalid URLs file afterwards.
        if invalid_urls:
            with open('data/{}-invalid-urls.txt'.format(cls), 'w') as f:
                for url in invalid_urls:
                    f.write('{}\n'.format(url))

asyncio.run(fetch())
