for var in "$@"
do
    curl -s localhost:9991/$var | rg "HOST\":\"([^\"]+)" --only-matching --replace "$var: \$1"
done