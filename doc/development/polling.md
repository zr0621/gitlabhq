# Polling with ETag caching

Polling for changes (repeatedly asking server if there are any new changes)
introduces high load on a GitLab instance, because it usually requires
executing at least a few SQL queries. This makes scaling large GitLab
instances (like GitLab.com) very difficult so we do not allow adding new
features that require polling and hit the database.

Instead you should use polling mechanism with ETag caching in Redis.

## How to use it

1. Add the path of the endpoint which you want to poll to
   `Gitlab::EtagCaching::Middleware`.
1. Implement cache invalidation for the path of your endpoint using
   `Gitlab::EtagCaching::Store`. Whenever a resource changes you
   have to invalidate the ETag for the path that depends on this
   resource.
1. Check that the mechanism works:
   - requests should return status code 304
   - there should be no SQL queries logged in `log/development.log`

## How it works

![Cache miss](img/cache-miss.svg)
![Cache hit](img/cache-hit.svg)

1. Whenever a resource changes we generate a random value and store it in
   Redis.
1. When a client makes a request we set the `ETag` response header to the value
   from Redis.
1. The client caches the response (client-side caching) and sends the ETag as
   the `If-None-Match` header with every subsequent request for the same
   resource.
1. If the `If-None-Match` header matches the current value in Redis we know
   that the resource did not change so we can send 304 response immediately,
   without querying the database at all. The client's browser will use the
   cached response.
1. If the `If-None-Match` header does not match the current value in Redis
   we have to generate a new response, because the resource changed.

For more information see:
- [RFC 7232](https://tools.ietf.org/html/rfc7232)
- [ETag proposal](https://gitlab.com/gitlab-org/gitlab-ce/issues/26926)