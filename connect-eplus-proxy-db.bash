#!/usr/bin/env nix-shell
#! nix-shell -i bash -p awscli2 -p pgcli
eplus_db_host="$(aws rds describe-db-clusters --query "DBClusters[?TagList[?Key=='project'&&Value=='elevate-plus']].Endpoint" --output text)"
dbpass="$(aws rds generate-db-auth-token --hostname "$eplus_db_host" --port 5432 --region eu-west-1 --username db-readonly)"
pgcli "host=localhost port=9876 dbname=postgres user=db-readonly password=${dbpass}"
