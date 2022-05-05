from setuptools import setup

from kadalu_storage.version import VERSION


setup(
    name="kadalu_storage",
    version=VERSION,
    packages=["kadalu_storage"],
    install_requires=['urllib3'],
    author="Aravinda Vishwanathapura",
    author_email="aravinda@kadalu.tech",
    description="",
    license="GPL-v3",
    keywords="kadalu storage, kadalu, storage manager",
    url="https://github.com/kadalu/moana",
    long_description="""
    Python bindings for Kadalu Storage ReST APIs
    """,
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3 :: Only"
    ],
)
