# nginx-hash-test
This repo is used to test and experiment with the NGINX hash module:
https://nginx.org/en/docs/http/ngx_http_upstream_module.html?&_ga=2.209331986.1889057555.1590538279-717970970.1586379081#hash.

## Replacing a Server.
Let's suppose we have an NGINX instance that proxies requests that look like: `localhost:9991/TFXhHud29A`
to an upstream that is configured to hash the request off of the key (`TFXhHud29A` in this case) to 
a pool of servers like: `[web-1, web-2]`.

If you replace `web-2` with `web-3` and reload NGINX, does that mean that requests that were 
previously routed to `web-2` now route to `web-3` (and requests that route to `web-1` are not affected)?

### Answer
I have found that, yes, if you are using the hash module *without consistent hashing*, then you can replace
a server entry in the NGINX configuration without affecting the routing for other servers.

However, if you are using the consistent hashing algorithm, then replacing a server entry will change routes 
that previously mapped to `web-1` to map to different servers (and vise-versa).

### Replicate for yourself:
Spin up the docker-compose environment in this repository:
```
$ docker-compose up -d
```

Validate that the `nginx.conf` has an pool pointing to `[web-1, web-2]`:
```
# in nginx.conf
# ...
        server web-1:8888 max_fails=0;
        server web-2:8888 max_fails=0;
```

Run the `request.sh` script with some given keys and see which server they map to:
```
$ ./request.sh foo bar baz
foo: web-2
bar: web-2
baz: web-1
```

Now change the upstream in `nginx.conf` to point to `[web-1, web-3]`:
```
# in nginx.conf
# ...
        server web-1:8888 max_fails=0;
        server web-3:8888 max_fails=0;
```

And reload nginx:
```
$ docker-compose exec load-balancer nginx -s reload
2020/06/30 20:54:30 [notice] 23#23: signal process started
```

Now run the requests again and notice that only the routes for `web-2` got remapped to `web-3`.
```
$ ./request.sh foo bar baz
foo: web-3
bar: web-3
baz: web-1
```

I used the script `compare.sh` to run this comparison automatically with a larger set of 
random request keys with consistent hashing on and off and found that the consistent 
hashing algorithm does not allow for replacing entries without changing the routing 
for the entire pool.

## Duplicate Entries
NGINX also allows for duplicate entries to the same server. This means if you have a 
pool of servers like: `[web-1, web-2, web-3]` and `web-2` dies, you can replace
`web-2` with `web-1`.

### Replicate for yourself:
Change the upstream in `nginx.conf` to point to `[web-1, web-2, web-3]`:
```
# in nginx.conf
# ...
        server web-1:8888 max_fails=0;
        server web-2:8888 max_fails=0;
        server web-3:8888 max_fails=0;
```

Run requests against a more diverse set of keys to find a mapping where all servers are represented:
```
$ ./request.sh zL9h2Mjwzy TFXhHud29A r46EJTnpwB sP2JubDKQc KrXz2KkuPn IZSvxNIgHX WQlZodeZWa MYYcHfLoHE qK4RfBVxtw L8fzjepkpx ItLYnkt5s2
zL9h2Mjwzy: web-1
TFXhHud29A: web-2
r46EJTnpwB: web-1
sP2JubDKQc: web-1
KrXz2KkuPn: web-1
IZSvxNIgHX: web-2
WQlZodeZWa: web-2
MYYcHfLoHE: web-3
qK4RfBVxtw: web-1
L8fzjepkpx: web-1
ItLYnkt5s2: web-1
```

Replace upstream in `nginx.confg` to point to `[web-1, web-1, web-3]`:
```
# in nginx.conf
# ...
        server web-1:8888 max_fails=0;
        server web-1:8888 max_fails=0;
        server web-3:8888 max_fails=0;
```

And reload nginx:
```
$ docker-compose exec load-balancer nginx -s reload
2020/06/30 20:54:30 [notice] 23#23: signal process started
```

Now run the requests again and notice that only the routes for `web-2` got remapped to `web-1`.
```
$ ./request.sh zL9h2Mjwzy TFXhHud29A r46EJTnpwB sP2JubDKQc KrXz2KkuPn IZSvxNIgHX WQlZodeZWa MYYcHfLoHE qK4RfBVxtw L8fzjepkpx ItLYnkt5s2
zL9h2Mjwzy: web-1
TFXhHud29A: web-1
r46EJTnpwB: web-1
sP2JubDKQc: web-1
KrXz2KkuPn: web-1
IZSvxNIgHX: web-1
WQlZodeZWa: web-1
MYYcHfLoHE: web-3
qK4RfBVxtw: web-1
L8fzjepkpx: web-1
ItLYnkt5s2: web-1
```