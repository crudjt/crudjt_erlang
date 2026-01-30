<p align="center">
  <img src="logos/crud_jt_logo_black.png#gh-light-mode-only" alt="Logo Light" />
  <img src="logos/crud_jt_logo.png#gh-dark-mode-only" alt="Logo Dark" />
</p>

<p align="center">
  Fast, file-backed JSON token for REST APIs with multi-process support
</p>

<p align="center">
  <a href="https://www.patreon.com/crudjt">
    <img src="logos/buy_me_a_coffee_orange.svg" alt="Buy Me a Coffee"/>
  </a>
</p>

## Why?  
[Escape the JWT trap: predictable login, safe logout](https://medium.com/@CoffeeMainer/jwt-trap-login-logout-under-control-7f4495d6024d)

CRUDJT runs a small local coordinator inside your app.
One process acts as a leader, all others talk to it

## In short

CRUDJT gives you stateful sessions without JWT pain and without distributed complexity

# Installation

Rebar3
```erlang
{deps, [{crudjt_erlang, {git, "git@github.com:crudjt/crudjt_erlang.git", {branch, "master"}}}]}.
```

## How to use

- One process starts the master
- All other processes connect to it

## Start CRUDJT master (once)

Start the CRUDJT master when your application boots  

Only **one process** should do this  
The master is responsible for session state and coordination  

### Generate an encrypted key

```sh
export CRUDJT_ENCRYPTED_KEY=$(openssl rand -base64 48)
```

```erlang
application:ensure_all_started(crudjt_erlang),

'Elixir.CRUDJT.Config':start_master([
    {encrypted_key, System.fetch_env!("CRUDJT_ENCRYPTED_KEY")},
    {store_jt_path, <<"path/to/local/storage">>}, % optional
    {grpc_port, 50051} % default
]).
```

The encrypted key must be the same for all processes

## Connect to an existing CRUDJT master

Use this in all other processes  

Typical examples:
- multiple local processes
- background jobs
- forked processes

```erlang
application:ensure_all_started(crudjt_erlang),

'Elixir.CRUDJT.Config':connect_to_master([
    {grpc_port, 50051} # default
]).
```

### Process layout

App boot  
 ├─ Process A → start_master  
 ├─ Process B → connect_to_master  
 └─ Process C → connect_to_master  

# C

```erlang
Data = #{<<"user_id">> => 42, <<"role">> => 11}, % required
Ttl = 3600 * 24 * 30, % optional: token lifetime (seconds)

% Optional: read limit
% Each read decrements the counter
% When it reaches zero — the token is deleted
silence_read = 10,

Token = 'Elixir.CRUDJT':create(data, ttl, silence_read).
% Token == <<"HBmKFXoXgJ46mCqer1WXyQ">>
```

```erlang
Data = #{<<"user_id">> => 42, <<"role">> => 11},

% To disable token expiration or read limits, pass `nil`
Token = 'Elixir.CRUDJT':create(
  Data,
  nil, % disable TTL
  nil % disable read limit
).
```

# R

```erlang
Result = 'Elixir.CRUDJT':read(<<"HBmKFXoXgJ46mCqer1WXyQ">>).
% Result == #{<<"metadata">> => #{<<"ttl">> => 101001, <<"silence_read">> => 9}, <<"data">> => #{<<"user_id">> => 42, <<"role">> => 11}}
```

```erlang
% When expired or not found token
Result = 'Elixir.CRUDJT':read(<<"HBmKFXoXgJ46mCqer1WXyQ">>).
% Result == nil
```

# U

```erlang
Data = #{<<"user_id">> => 42, <<"role">> => 8},

% `nil` disables limits
Ttl = 600,
Silence_read = 100,

Result = 'Elixir.CRUDJT':update("HBmKFXoXgJ46mCqer1WXyQ", Data, Ttl, Silence_read).
% Result == true
```

```erlang
% When expired or not found token
Result = 'Elixir.CRUDJT':update(<<"HBmKFXoXgJ46mCqer1WXyQ">>, #{<<"user_id">> => 42, <<"role">> => 8}).
% Result == false
```

# D
```erlang
Result = 'Elixir.CRUDJT':delete(<<"HBmKFXoXgJ46mCqer1WXyQ">>).
% Result == true
```

```erlang
% When expired or not found token
Result = 'Elixir.CRUDJT':delete(<<"HBmKFXoXgJ46mCqer1WXyQ">>).
% Result == false
```

# Performance
**40k** requests of **256 bytes** — median over 10 runs  
ARM64 (Apple M1+), macOS 15.6.1  
Erlang 1.18.4 (Erlang/OTP 27)

Measured in the master process (in-process execution)  
No gRPC, network, or serialization overhead is included

| Function | CRUDJT (Erlang) | JWT (Erlang) | redis-session-store (Ruby, Rails 8.0.4) |
|----------|-------|------|------|
| C        | `0.388 second` ![Logo Favicon Light](logos/crud_jt_logo_favicon_white.png#gh-light-mode-only) ![Logo Favicon Dark](logos/crud_jt_logo_favicon_black.png#gh-dark-mode-only) | 1.905 seconds | 4.057 seconds |
| R        | `0.083 second` ![Logo Favicon Light](logos/crud_jt_logo_favicon_white.png#gh-light-mode-only) ![Logo Favicon Dark](logos/crud_jt_logo_favicon_black.png#gh-dark-mode-only) | 2.012 seconds | 7.011 seconds |
| U        | `0.454 second` ![Logo Favicon Light](logos/crud_jt_logo_favicon_white.png#gh-light-mode-only) ![Logo Favicon Dark](logos/crud_jt_logo_favicon_black.png#gh-dark-mode-only) | X | 3.49 seconds |
| D        | `0.244 second` ![Logo Favicon Light](logos/crud_jt_logo_favicon_white.png#gh-light-mode-only) ![Logo Favicon Dark](logos/crud_jt_logo_favicon_black.png#gh-dark-mode-only) | X | 6.589 seconds |

[Full benchmark results](https://github.com/exwarvlad/benchmarks)

# Storage (File-backed)  
Backed by a disk-based B-tree for predictable reads, writes, and deletes

## Disk footprint  
**40k** tokens of **256 bytes** each — median over 10 creates  
darwin23, APFS  

`48 MB`  

[Full disk footprint results](https://github.com/Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1y/disk_footprint)

## Path Lookup Order
Stored tokens are placed in the **file system** according to the following order

1. Explicitly set via `'Elixir.CRUDJT.Config':start_master([{store_jt_path, <<"custom/path/to/file_system_db">>}])`
2. Default system location
   - **Linux**: `/var/lib/store_jt`
   - **macOS**: `/usr/local/var/store_jt`
   - **Windows**: `C:\Program Files\store_jt`
3. Project root directory (fallback)

## Storage Characteristics
* CRUDJT **automatically removing expired tokens** after start and every 24 hours without blocking the main thread   
* **Storage automatically fsyncs every 500ms**, meanwhile tokens ​​are available from cache

# Multi-process Coordination
For multi-process scenarios, CRUDJT uses gRPC over an insecure local port for same-host communication only. It is not intended for inter-machine or internet-facing usage

# Limits
The library has the following limits and requirements

- **Erlang version:** tested with 1.17.3 | Erlang/OTP >= 27
- **Supported platforms:** Linux, macOS, Windows (x86_64 / arm64)
- **Maximum json size per token:** 256 bytes
- **`encrypted_key` format:** must be Base64
- **`encrypted_key` size:** must be 32, 48, or 64 bytes

# Contact & Support
<p align="center">
  <img src="logos/crud_jt_logo_favicon_black_160.png#gh-light-mode-only" alt="Visit Light" />
  <img src="logos/crud_jt_logo_favicon_white_160.png#gh-dark-mode-only" alt="Visit Dark" />
</p>

- **Custom integrations / new features / collaboration**: support@crudjt.com  
- **Library support & bug reports:** [open an issue](https://github.com/crudjt/crudjt_erlang/issues)


# Lincense
CRUDJT is released under the [MIT License](LICENSE.txt)

<p align="center">
  💘 Shoot your g . ? Love me out via <a href="https://www.patreon.com/crudjt">Patreon Sponsors</a>!
</p>
