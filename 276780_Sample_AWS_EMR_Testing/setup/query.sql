CREATE EXTERNAL TABLE nyc_taxi (
  vendor_id string, pickup_datetime timestamp, dropoff_datetime timestamp,
  passenger_count int, trip_distance double, rate_code int,
  store_and_fwd_flag string, pickup_location_id int, dropoff_location_id int,
  payment_type int, fare_amount double, extra double, mta_tax double,
  tip_amount double, tolls_amount double, improvement_surcharge double,
  total_amount double
)
PARTITIONED BY (year int, month int)
STORED AS PARQUET
LOCATION 's3://serverless-analytics-canonical-ny-nycpub/';

MSCK REPAIR TABLE nyc_taxi;

SELECT passenger_count, AVG(trip_distance), COUNT(*) as trips
FROM nyc_taxi WHERE year=2016 AND month=1
GROUP BY passenger_count ORDER BY trips DESC;
