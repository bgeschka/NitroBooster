#!/bin/sh
BUILDDIR=/tmp/NitroBooster
rm -rv "$BUILDDIR"
cp -L -r ./ "$BUILDDIR"
zip -rv -0 "$BUILDDIR.zip" "$BUILDDIR"
