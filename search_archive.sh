#!/bin/sh
exit
#unfinished

for f in ./archive/*.gz; do
  tar -xzf "%f" --to-command='grep -Hn --label="%TAR_ARCHIVE/%TAR_FILENAME" nn3 || true' nn3.txt
done
