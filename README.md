# Ma'ayan Lab Base Docker Images

When dealing with one programming language, docker works well to provide base images like (python, r, or nodejs), but it frequently becomes a mess when you want to two or more of these. E.g. you can install python on a nodejs image or vice versa, but in both cases you lose the ability to specify the version for the other.

To address this, our base image provides a means to explicitly specify the version of:
- node (installed with the help of nvm)
- R (installed with the help of rig)
- python (installed with the help of uv)

If you don't specify it's version, it will not be installed.

## Usage

### node, python & R
```Dockerfile
FROM maayanlab/base
RUN NODE_VERSION=20 PYTHON_VERSION=3.11 R_VERSION=4.5.3 /install.sh
CMD ["bash"]
```

### just python
```Dockerfile
FROM maayanlab/base
RUN PYTHON_VERSION=3.11 /install.sh
CMD ["python"]
```
