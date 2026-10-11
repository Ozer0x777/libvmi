#!/bin/bash -e
# $1=compiler $2=builder  -- mirrors .github/workflows/compile.yml
cd /w && bash -e deps-compile.sh
git clone -q /src /w/libvmi && cd /w/libvmi
export CC=$1
if [ "$2" = cmake ]; then
  while IFS= read -r options; do
    echo "Building with '$options'"
    mkdir -p build; cd build; cmake $options ..; make; make clean; cd ..; git clean -xdf
    echo "Done building with '$options'"
  done < .github/cmake_options.txt
else
  while IFS= read -r options; do
    echo "Building with '$options'"
    autoreconf -vif; ./configure $options; make; make clean; git clean -xdf
    echo "Done building with '$options'"
  done < .github/configure_options.txt
fi
echo JOB_OK
