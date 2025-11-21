#!/usr/bin/env nix-shell
#! nix-shell -i bash -p awscli2 -p ssm-session-manager-plugin -p openssh
port=22
instanceid="$(aws ec2 describe-instances --filters Name=tag:component,Values=jump-host Name=instance-state-name,Values=running --query 'Reservations[].Instances[].InstanceId' --output text)"
ssh -o ProxyCommand="aws ssm start-session --target "$instanceid" --document-name AWS-StartSSHSession --parameters 'portNumber=$port'" "ec2-user@$instanceid" "$@"
