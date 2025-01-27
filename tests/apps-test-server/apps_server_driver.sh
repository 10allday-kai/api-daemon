#!/bin/bash

set -e

if [ -z ${CI_PROJECT_DIR+x} ];
then
    echo "Please set CI_PROJECT_DIR to the path of your SIDL repository.";
    exit 1;
fi

function kill_server() {
    pid=$(ps -ef | grep apps_test_server | grep -v grep | awk '{print $2}');
    if [ -n "$pid" ]; then
        kill -9 $pid;
        echo "Killed apps_test_server (pid $pid)";
    fi
}

# Reset apps
rm -rf $CI_PROJECT_DIR/prebuilts/http_root/webapps/

cd $CI_PROJECT_DIR/tests/apps-test-server

# Align with config-webdriver.toml
rm -rf ../webapps
rm -f $CI_PROJECT_DIR/daemon/settings.*
rm -f $CI_PROJECT_DIR/services/apps/test-fixtures/webapps/apps
ln -s $CI_PROJECT_DIR/services/apps/test-fixtures/webapps ../webapps
ln -s $CI_PROJECT_DIR/services/apps/client $CI_PROJECT_DIR/services/apps/test-fixtures/webapps/apps

$CI_PROJECT_DIR/target/release/apps_test_server &

# Copy v1 of apps to the app server.
$CI_PROJECT_DIR/tests/apps-test-server/v1.sh
DONT_CREATE_WEBAPPS=1 $CI_PROJECT_DIR/tests/webdriver.sh http://apps.localhost:8081/test/tests.html

# Copy v2 of apps to the app server.
$CI_PROJECT_DIR/tests/apps-test-server/v2.sh
DONT_CREATE_WEBAPPS=1 $CI_PROJECT_DIR/tests/webdriver.sh http://apps.localhost:8081/test/tests_update_app.html

# Reset the apps with different set of preload apps.
rm -rf ../webapps
rm -f $CI_PROJECT_DIR/daemon/settings.*
rm -f $CI_PROJECT_DIR/services/apps/test-fixtures/webapps2/apps
ln -s $CI_PROJECT_DIR/services/apps/test-fixtures/webapps2 ../webapps
ln -s $CI_PROJECT_DIR/services/apps/client $CI_PROJECT_DIR/services/apps/test-fixtures/webapps2/apps

# Set apps to old version on the app server.
# Expect that no app update is available.
$CI_PROJECT_DIR/tests/apps-test-server/v1.sh
DONT_CREATE_WEBAPPS=1 $CI_PROJECT_DIR/tests/webdriver.sh \
    http://apps.localhost:8081/test/not_allow_downgrade.html \
    http://apps.localhost:8081/test/tests_update_preload_pwa_app.html \
    http://apps.localhost:8081/test/uninstall_apps.html \
    http://apps.localhost:8081/test/install_apps.html \
    http://apps.localhost:8081/test/install_apps_with_origin.html \
    http://apps.localhost:8081/test/install_power_off.html

# installing_power_off to simulate power off during installing
# Then, test if install same app works.
DONT_CREATE_WEBAPPS=1 $CI_PROJECT_DIR/tests/webdriver.sh \
    http://apps.localhost:8081/test/install_power_back_on.html

kill_server

rm ../webapps

echo "WebDriver apps tests success"
