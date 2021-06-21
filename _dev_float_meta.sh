#!/bin/sh

echo Combing archives for 'meta', writing import script...

echo \#!/bin/sh > ./_dev_import_meta_items_from_archives.sh

for f in ./archive/*.gz; do
  echo Searching in $f for 'meta'
  tar -xzf $f --to-command='grep -iHnl --label="tar -zxvf $TAR_ARCHIVE $TAR_FILENAME" meta || true' | grep txt$ >> ./_dev_import_meta_items_from_archives.sh
  echo Found: `wc -l _dev_import_meta_items_from_archives.sh`
done

chmod +x ./_dev_import_meta_items_from_archives.sh

echo run ./_dev_import_meta_items_from_archives.sh to import

