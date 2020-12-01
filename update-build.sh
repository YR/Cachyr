#!/bin/sh

count=$(git rev-list --count master)
xcrun agvtool new-version -all $((count + 1))

