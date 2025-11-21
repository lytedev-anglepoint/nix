#!/usr/bin/env nix-shell
#! nix-shell -i bash -p awscli2
eplus_db_host="$(aws rds describe-db-clusters --query "DBClusters[?TagList[?Key=='project'&&Value=='elevate-plus']].Endpoint" --output text)"
./ssh-to-jump-host.bash -L "9876:$eplus_db_host:5432"
