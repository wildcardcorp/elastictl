#!/bin/bash
OLD_HOST=XXXXXXXXXXXXXXXXXXXXxx
OLD_USER=XXXXXXXXXXXXXXXXXXXXXXXXXX
OLD_PWD=XXXXXXXXXXXXXXXXXXXXx
NEW_HOST=XXXXXXXXXXXXXXXXXXXXXx
NEW_USER=XXXXXXXXXXXXXXXXXXXX
NEW_PWD=XXXXXXXXXXXXXXXXXXXX


#the following helps match say on a date or only a index with certain content. Running:  "./index_migrate.sh SOMETEXT 2023.01.01"  will copy index matching index-name-SOMETEXT-2023.01.01
INDEX_MATCH=$1
MATCHER=$2

for index in `curl -s "https://$OLD_USER:$OLD_PWD@$OLD_HOST/_aliases?pretty=true" | awk -F\" '!/aliases/ && $2 != "" {print $2}' | grep $1 | grep $2 | sort -r`; do
    printf 'Moving: %s\n' "$index"

minimumsize=50
FILE=indexes/$index.json.gz

if [ -f "$FILE" ]; then
    echo "$FILE export already  exists."

if [[ $(stat -c%s $FILE) -le $minimumsize ]]; then
    rm $FILE
fi


else
    echo "$FILE export does not exist. Exporting..."
    ./elastictl export  --host https://$OLD_USER:$OLD_PWD@$OLD_HOST:443 $index | gzip >  $FILE
fi

echo "Importing whatever was in the $FILE over the top of new location.. this will cause 'deleted' docs if same id exists..."
zcat $FILE | ./elastictl import --host https://$NEW_USER:$NEW_PWD@$NEW_HOST:443 --replicas 0 --shards 1 --workers 50 --no-create $index


OLD_COUNT=$(curl -s "https://$OLD_USER:$OLD_PWD@$OLD_HOST/_cat/indices?pretty=true" | grep $index | awk '{print $7}')
NEW_COUNT$(curl -s "https://$NEW_USER:$NEW_PWD@$NEW_HOST/_cat/indices?pretty=true" | grep $index | awk '{print $7}')

if [[ "OLD_COUNT" != "NEW_COUNT" ]]; then
    echo "Mismatch OLD: $OLD_COUNT != $NEW_COUNT trying import one more time "
    zcat $FILE | ./elastictl import --host https://$NEW_USER:$NEW_PWD@$NEW_HOST:443 --replicas 0 --shards 1 --workers 50 --no-create $index
fi



done
