# pupcycler

:dog2: :recycle:

[![Build Status](https://travis-ci.org/travis-ci/pupcycler.svg?branch=master)](https://travis-ci.org/travis-ci/pupcycler)
[![codecov](https://codecov.io/gh/travis-ci/pupcycler/branch/master/graph/badge.svg)](https://codecov.io/gh/travis-ci/pupcycler)

Pupcycler (Packet Upcycler) (Doggo Recycler) is an application that interacts
with the [Packet API](https://www.packet.net/developers/api/) and
[travis-worker](https://github.com/travis-ci/worker) processes to restart
servers based on certain events or time intervals.

## deployment

The intended deployment is via Heroku as `web` and `worker` dynos (see
[`Procfile`](./Procfile)) with a Redis provider that is configured via
`REDIS_URL` or a `REDIS_PROVIDER` indirect env lookup.

## development

Patches welcome!  Please be sure to review the [code of
conduct](./CODE_OF_CONDUCT.md).

Verification may be done via the same command run on Travis CI:

``` bash
bundle exec rake
```

:warning: This project uses [RuboCop](http://batsov.com/rubocop/), which may
mean that the above command fails after making changes.  If you aren't familiar
with RuboCop and you'd rather not have to deal with it, you can choose to
automatically correct any issues like so:

``` bash
bundle exec rubocop --auto-correct --auto-gen-config
```

## license

Please see [`./LICENSE`](./LICENSE)
