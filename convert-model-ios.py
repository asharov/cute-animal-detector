#!/usr/bin/env python3

import coremltools

coreml_model = coremltools.converters.keras.convert('iscute.h5',
                                                    image_input_names='input1',
                                                    input_name_shape_dict={'input1': [None, 299, 299, 3]},
                                                    class_labels=['cute', 'notcute'])
coreml_model.save('iscute.mlmodel')
