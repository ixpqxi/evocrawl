BROWSER=${TESTCAFE_BROWSER:-chrome --headless}
node ../node_modules/testcafe/bin/testcafe.js "$BROWSER" ../replay/customized_replayer.js \
-e -u --disable-multiple-windows -q --ajax-request-timeout 4000 --selector-timeout 1500
