#rm -r ../data/$APPNAME-ev/a_nav/
#mkdir ../data/$APPNAME-ev/a_nav/
#mkdir ../data/$APPNAME-ev/sim_responses/
#mkdir ../data/$APPNAME-ev/ev_responses/
BROWSER=${TESTCAFE_BROWSER:-chrome --headless}
node ../node_modules/testcafe/bin/testcafe.js "$BROWSER" ../replay/replayer.js \
-e -u --disable-multiple-windows -q --ajax-request-timeout 4000 --selector-timeout 200
