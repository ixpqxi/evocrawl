#rm -rf data/$1
#mkdir -p data/$1
BROWSER=${TESTCAFE_BROWSER:-chrome --headless}
node ../node_modules/testcafe/bin/testcafe.js "$BROWSER" evolutionarycrawler.js \
-e -u --disable-multiple-windows -q --ajax-request-timeout 4000 --selector-timeout 2000
