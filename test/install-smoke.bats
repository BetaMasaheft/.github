#!/usr/bin/env bats

# Basic start-up and install tests: does this package deploy cleanly into a
# bare eXist on its own? These expect a running container at port 8080
# named "exist" (see BetaMasaheft/.github's install-smoke.yml reusable
# workflow), and $PACKAGE_URI set to the calling repo's expath-pkg.xml
# `name` value.
# Adapted from https://github.com/eeditiones/jinks/blob/main/test/01-smoke.bats

@test "container jvm responds from client" {
  run docker exec exist java -version
  [ "$status" -eq 0 ]
}

@test "container can be reached via http" {
  result=$(curl -Is http://127.0.0.1:8080/ | grep -o 'Jetty')
  [ "$result" == 'Jetty' ]
}

@test "container reports healthy to docker" {
  result=$(docker ps | grep -c '(healthy)')
  [ "$result" -eq 1 ]
}

@test "logs show clean start" {
  result=$(docker logs exist | grep -o 'Server has started')
  [ "$result" == 'Server has started' ]
}

# Make sure the package has been deployed. Two valid signals depending on
# when install happened: a fresh deploy, or "already installed" if it was
# deployed once earlier and persisted. At least one of these two lines -
# not a bare URI count, which a fresh install also inflates via one
# "depends on <this URI>" line per dependency. Not exactly one either:
# AutoDeploymentTrigger's scan has been observed logging the same
# package's "already installed" line twice in a single boot.
@test "logs show package deployment" {
  result=$(docker logs exist | grep -cF -e "Deploying package $PACKAGE_URI" -e "Application package $PACKAGE_URI already installed")
  [ "$result" -ge 1 ]
}

@test "logs are error free" {
  result=$(docker logs exist | grep -ow -c 'ERROR' || true)
  [ "$result" -eq 0 ]
}

@test "no fatalities in logs" {
  result=$(docker logs exist | grep -ow -c 'FATAL' || true)
  [ "$result" -eq 0 ]
}

# Check for cgroup config warning
@test "check logs for cgroup file warning" {
  result=$(docker logs exist | grep -ow -c 'Unable to open cgroup memory limit file' || true)
  [ "$result" -eq 0 ]
}
