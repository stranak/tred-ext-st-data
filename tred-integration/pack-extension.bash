#! /bin/bash

## Make tred extension with all macros.
## Author: Jan Stepanek

EXTNAME=pdt_t_st

bindir=$(readlink -f ${0%/*})
EXTDIR=/net/work/projects/tred/extensions
WWW=/home/pajas/WWW/tred/extensions
LOGO=icon.png

#cd "$bindir"/../tred-extension

"$EXTDIR"/make $EXTNAME
mkdir -p "$WWW"/$EXTNAME/icons
cp $EXTNAME/icons/$LOGO  "$WWW"/$EXTNAME/icons
chmod g+w /home/pajas/WWW/tred/extensions/$EXTNAME.zip
rsync -avr "$WWW"/{index.html,$EXTNAME{,.zip}} ufal:/home/pajas/WWW/tred/extensions/
rm -rf "$WWW"/$EXTNAME/icons/
