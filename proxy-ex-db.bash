#!/usr/bin/env nix-shell
#! nix-shell -i bash -p awscli2
ex_db_host="$(aws rds describe-db-instances --query "DBClusters[?TagList[?Key=='project'&&Value=='elevate-x-shared']].Endpoint" --output text)"
./ssh-to-jump-host.bash -L "9876:$ex_db_host:5432"
