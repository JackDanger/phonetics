from setuptools import setup
from setuptools_rust import Binding, RustExtension

setup(
    name="phonetics-ipa",
    version="0.5.0",
    rust_extensions=[
        RustExtension(
            'phonetics-ipa.phonetics-ipa',
            'Cargo.toml',
            binding=Binding.PyO3,
        )
    ],
    packages=["phonetics-ipa"],
    zip_safe=False,
)
