from setuptools import setup, Extension

setup(
    name="ipa_levenshtein",
    version="0.5.0",
    ext_modules=[
        Extension('levenshtein', sources=['levenshtein.c'])
    ],
    # other necessary information here
)
