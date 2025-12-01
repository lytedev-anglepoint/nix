#!/usr/bin/env nix-shell
#! nix-shell -i bash -p awscli2 -p pgcli
ex_db_host="$(aws rds describe-db-instances --query "DBClusters[?TagList[?Key=='project'&&Value=='elevate-x-shared']].Endpoint" --output text)"
dbpass="$(aws rds generate-db-auth-token --hostname "$ex_db_host" --port 5432 --region eu-west-1 --username db-readonly)"
pgcli "host=localhost port=9876 dbname=postgres user=db-readonly password=${dbpass}"
