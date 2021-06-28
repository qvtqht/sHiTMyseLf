#!/bin/sh

echo Combing archives for 'meta', writing import script...

echo \#!/bin/sh > ./_temp_import_meta_items_from_archives.sh

for f in ./archive/*.gz; do
  echo Searching in $f for 'meta'
  tar -xzf $f --to-command='grep -iHnl --label="tar -zxvf $TAR_ARCHIVE $TAR_FILENAME ; mv $TAR_FILENAME html/txt" meta || true' | grep "txt ;" >> ./_temp_import_meta_items_from_archives.sh
  echo Found: `wc -l _temp_import_meta_items_from_archives.sh`
done

chmod +x ./_temp_import_meta_items_from_archives.sh

echo run ./_temp_import_meta_items_from_archives.sh to import

