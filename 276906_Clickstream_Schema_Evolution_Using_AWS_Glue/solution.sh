export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

mkdir -p ./clickstream_sample/year=2025/month=06/day=20/hour=14
cat <<EOF > ./clickstream_sample/year=2025/month=06/day=20/hour=14/data.csv
user_id,event_time,event_type,page_url
u123,2025-06-20T14:01:05Z,view,/home
u456,2025-06-20T14:02:30Z,click,/product/42
u123,2025-06-20T14:05:12Z,view,/cart
EOF


aws iam create-role   --role-name GlueETLServiceRole   --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "glue.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  }' --no-cli-pager

# aws iam create-role   --role-name GlueETLServiceRole   --assume-role-policy-document '{"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Principal": { "Service": "glue.amazonaws.com" }, "Action": "sts:AssumeRole"}]}' --no-cli-pager

aws iam attach-role-policy   --role-name GlueETLServiceRole   --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole --no-cli-pager
aws iam attach-role-policy   --role-name GlueETLServiceRole   --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess   --no-cli-pager
aws iam attach-role-policy   --role-name GlueETLServiceRole   --policy-arn arn:aws:iam::aws:policy/AmazonSQSReadOnlyAccess   --no-cli-pager
aws iam list-attached-role-policies   --role-name GlueETLServiceRole   --no-cli-pager

aws glue create-database   --database-input '{"Name":"clickstream_db"}'   --region us-west-2   --no-cli-pager
aws s3 cp --recursive clickstream_sample   s3://clickstream-schema-evolution-bucket-${ACCOUNT_ID}/   --region us-west-2
aws glue create-crawler   --name raw-clickstream-crawler   --role GlueETLServiceRole   --database-name clickstream_db   --targets "S3Targets=[{Path=\"s3://clickstream-schema-evolution-bucket-${ACCOUNT_ID}/\"}]"   --region us-west-2   --no-cli-pager

aws glue create-classifier   --csv-classifier '{
    "Name": "clickstream-csv-classifier",
    "Delimiter": ",",
    "QuoteSymbol": "\"",
    "ContainsHeader": "PRESENT",
    "Header": [
      "user_id",
      "event_time",
      "event_type",
      "page_url"
    ]
  }'   --region us-west-2   --no-cli-pager

# aws glue create-classifier   --csv-classifier '{"Name": "clickstream-csv-classifier", "Delimiter": ",", "QuoteSymbol": "\"", "ContainsHeader": "PRESENT", "Header": ["user_id", "event_time", "event_type", "page_url"]}'   --region us-west-2   --no-cli-pager

aws glue get-crawler   --name raw-clickstream-crawler   --region us-west-2   --no-cli-pager
aws glue update-crawler   --name raw-clickstream-crawler   --classifiers clickstream-csv-classifier   --region us-west-2   --no-cli-pager

aws glue start-crawler   --name raw-clickstream-crawler   --region us-west-2   --no-cli-pager

sleep 45
aws glue get-tables   --database-name clickstream_db   --region us-west-2   --no-cli-pager