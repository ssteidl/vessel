export VESSEL_DATASET=vessel-test
export VESSEL_METADATA_DB_DIR=/tmp/vessel-test/metadata_db
export VESSEL_TEST_AWS=false
sudo -E mkdir ${VESSEL_METADATA_DB_DIR}
sudo -E vessel init