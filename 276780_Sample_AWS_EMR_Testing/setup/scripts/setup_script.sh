set -euo pipefail
TARGET_DIR="/home/user"


create_s3_bucket() {
    local prefix="emr-bucket"
    local region="${AWS_REGION:-us-west-2}"
    local timestamp=$(date +%s)
    local random_part=$RANDOM

    local bucket_name="${prefix}-${timestamp}-${random_part}"
    bucket_name=$(echo "$bucket_name" | tr '[:upper:]' '[:lower:]')
    echo "Creating S3 bucket: s3://${bucket_name} in region ${region}" >&2

    if aws s3 mb "s3://${bucket_name}" --region "$region"; then
        echo "$bucket_name"
    else
        echo "Failed to create bucket ${bucket_name}" >&2
        return 1
    fi
}

create_hive_script() {
    local target_dir="$1"
    mkdir -p "$target_dir/scripts"

    cat << 'EOF' > "$target_dir/scripts/query.sql"
CREATE EXTERNAL TABLE nyc_taxi (
  vendor_id string,
  pickup_datetime timestamp,
  dropoff_datetime timestamp,
  passenger_count int,
  trip_distance double,
  rate_code int,
  store_and_fwd_flag string,
  pickup_location_id int,
  dropoff_location_id int,
  payment_type int,
  fare_amount double,
  extra double,
  mta_tax double,
  tip_amount double,
  tolls_amount double,
  improvement_surcharge double,
  total_amount double
)
PARTITIONED BY (year int, month int)
STORED AS PARQUET
LOCATION 's3://serverless-analytics-canonical-ny-nycpub/';

MSCK REPAIR TABLE nyc_taxi;

SELECT passenger_count, AVG(trip_distance), COUNT(*) as trips
FROM nyc_taxi WHERE year=2016 AND month=1
GROUP BY passenger_count
ORDER BY trips DESC;
EOF

    echo "Hive script created at $target_dir/scripts/query.sql"
}



create_s3_bucket
create_hive_script ${TARGET_DIR}

chown user:user "${TARGET_DIR}/scripts/query.sql" 2>/dev/null || true